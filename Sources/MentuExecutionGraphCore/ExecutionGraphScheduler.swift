import Foundation

/// Deterministic, effect-injected scheduler for one validated execution DAG.
public actor ExecutionGraphScheduler {
    public init() {}

    public func run(
        dag: ExecutionDAG,
        initialStates: [String: GraphNodeState] = [:],
        maximumParallelism: Int,
        failurePolicy: GraphFailurePolicy,
        eventSink: any GraphSchedulerEventSink,
        shouldStopBeforeFrontier:
            @escaping @Sendable (Int) async -> Bool = { _ in false },
        shouldStopBeforeActivation:
            @escaping @Sendable (GraphStepActivation) async -> Bool = { _ in false },
        executor: @escaping @Sendable (GraphStepActivation) async -> GraphStepOutcome
    ) async throws -> GraphScheduleResult {
        guard maximumParallelism > 0 else {
            throw ExecutionGraphViolation(
                id: GraphSchedulerReasonID.invalidParallelism,
                detail: "maximum parallelism must be greater than zero"
            )
        }

        let frontiers = try dag.validatedFrontiers()
        let nodes = dag.nodes.sorted { $0.id < $1.id }
        let nodesByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        try Self.validate(initialStates: initialStates, nodesByID: nodesByID)

        var states = Dictionary(
            uniqueKeysWithValues: nodes.map { ($0.id, GraphNodeState.pending) }
        )
        for (nodeID, state) in initialStates {
            states[nodeID] = state
        }

        var emitter = EventEmitter(sink: eventSink)
        var dispatchOrder: [String] = []
        var nextOrdinal = 1
        var executedFailureCount = states.values.reduce(into: 0) { count, state in
            if case .failed = state {
                count += 1
            }
        }

        await emitter.emit(kind: .scheduleStarted)

        if Self.shouldOpenCircuit(
            failurePolicy,
            executedFailureCount: executedFailureCount
        ) {
            await Self.propagateDependencySkips(
                nodes: nodes,
                states: &states,
                frontier: nil,
                emitter: &emitter
            )
            await emitter.emit(
                kind: .circuitOpened,
                reasonId: GraphSchedulerReasonID.circuitOpen
            )
            await Self.skipPending(
                nodes: nodes,
                states: &states,
                frontier: nil,
                reasonId: GraphSchedulerReasonID.circuitOpen,
                emitter: &emitter
            )
            await emitter.emit(kind: .scheduleCompleted)
            return Self.result(
                nodes: nodes,
                states: states,
                dispatchOrder: dispatchOrder
            )
        }

        frontierLoop: for (frontierOffset, frontierNodes) in frontiers.enumerated() {
            let frontier = frontierOffset + 1
            if await shouldStopBeforeFrontier(frontier) {
                await emitter.emit(
                    kind: .circuitOpened,
                    frontier: frontier,
                    reasonId: GraphSchedulerReasonID.boundaryStop
                )
                await Self.skipPending(
                    nodes: nodes,
                    states: &states,
                    frontier: frontier,
                    reasonId: GraphSchedulerReasonID.boundaryStop,
                    emitter: &emitter
                )
                break frontierLoop
            }
            await emitter.emit(kind: .frontierStarted, frontier: frontier)

            for node in frontierNodes {
                guard states[node.id] == .pending,
                      let blocker = Self.failedDependency(of: node, states: states)
                else {
                    continue
                }
                let skipped = GraphNodeState.skipped(
                    reasonId: GraphSchedulerReasonID.dependencyFailed,
                    blockedBy: blocker
                )
                states[node.id] = skipped
                await emitter.emit(
                    kind: .nodeSkipped,
                    frontier: frontier,
                    nodeId: node.id,
                    state: skipped,
                    reasonId: GraphSchedulerReasonID.dependencyFailed
                )
            }

            let runnable = frontierNodes.filter {
                states[$0.id] == .pending
                    && $0.dependencies.allSatisfy { states[$0] == .succeeded }
            }
            let exclusive = runnable
                .filter { $0.dispatchMode == .exclusive }
                .sorted { $0.id < $1.id }
            let parallelSafe = runnable
                .filter { $0.dispatchMode == .parallelSafe }
                .sorted { $0.id < $1.id }

            var settled: [String: GraphNodeState] = [:]
            var boundaryStopTriggered = false

            for node in exclusive {
                let activation = GraphStepActivation(
                    nodeId: node.id,
                    ordinal: nextOrdinal,
                    frontier: frontier
                )
                if await shouldStopBeforeActivation(activation) {
                    boundaryStopTriggered = true
                    break
                }
                nextOrdinal += 1
                dispatchOrder.append(node.id)
                states[node.id] = .running
                await emitter.emit(
                    kind: .nodeDispatched,
                    frontier: frontier,
                    nodeId: node.id,
                    state: .running
                )

                let outcome = await executor(activation)
                let terminal = Self.normalizedState(
                    outcome,
                    expectedNodeID: node.id
                )
                states[node.id] = terminal
                settled[node.id] = terminal
            }

            var boundarySkipped: [String] = []
            if !boundaryStopTriggered {
                var parallelActivations: [GraphStepActivation] = []
                for node in parallelSafe {
                    let activation = GraphStepActivation(
                        nodeId: node.id,
                        ordinal: nextOrdinal,
                        frontier: frontier
                    )
                    nextOrdinal += 1
                    parallelActivations.append(activation)
                    dispatchOrder.append(node.id)
                    states[node.id] = .running
                    await emitter.emit(
                        kind: .nodeDispatched,
                        frontier: frontier,
                        nodeId: node.id,
                        state: .running
                    )
                }

                let parallelResult = await Self.executeParallel(
                    activations: parallelActivations,
                    maximumParallelism: maximumParallelism,
                    shouldStopBeforeActivation:
                        shouldStopBeforeActivation,
                    executor: executor
                )
                boundaryStopTriggered =
                    parallelResult.boundaryStopTriggered
                for activation in parallelActivations {
                    if parallelResult.blockedNodeIDs.contains(
                        activation.nodeId
                    ) {
                        let skipped = GraphNodeState.skipped(
                            reasonId:
                                GraphSchedulerReasonID.boundaryStop,
                            blockedBy: nil
                        )
                        states[activation.nodeId] = skipped
                        boundarySkipped.append(activation.nodeId)
                        continue
                    }
                    guard let outcome =
                            parallelResult.outcomes[activation.nodeId]
                    else {
                        continue
                    }
                    let terminal = Self.normalizedState(
                        outcome,
                        expectedNodeID: activation.nodeId
                    )
                    states[activation.nodeId] = terminal
                    settled[activation.nodeId] = terminal
                }
            }

            for nodeID in settled.keys.sorted() {
                guard let state = settled[nodeID] else {
                    continue
                }
                await emitter.emit(
                    kind: .nodeCompleted,
                    frontier: frontier,
                    nodeId: nodeID,
                    state: state,
                    reasonId: state.reasonId
                )
            }
            for nodeID in boundarySkipped.sorted() {
                guard let state = states[nodeID] else {
                    continue
                }
                await emitter.emit(
                    kind: .nodeSkipped,
                    frontier: frontier,
                    nodeId: nodeID,
                    state: state,
                    reasonId: GraphSchedulerReasonID.boundaryStop
                )
            }
            executedFailureCount += settled.values.reduce(into: 0) { count, state in
                if case .failed = state {
                    count += 1
                }
            }

            await emitter.emit(kind: .frontierCompleted, frontier: frontier)

            if boundaryStopTriggered {
                await emitter.emit(
                    kind: .circuitOpened,
                    frontier: frontier,
                    reasonId: GraphSchedulerReasonID.boundaryStop
                )
                await Self.skipPending(
                    nodes: nodes,
                    states: &states,
                    frontier: frontier,
                    reasonId: GraphSchedulerReasonID.boundaryStop,
                    emitter: &emitter
                )
                break frontierLoop
            }

            if Self.shouldOpenCircuit(
                failurePolicy,
                executedFailureCount: executedFailureCount
            ) {
                await Self.propagateDependencySkips(
                    nodes: nodes,
                    states: &states,
                    frontier: frontier,
                    emitter: &emitter
                )
                await emitter.emit(
                    kind: .circuitOpened,
                    frontier: frontier,
                    reasonId: GraphSchedulerReasonID.circuitOpen
                )
                await Self.skipPending(
                    nodes: nodes,
                    states: &states,
                    frontier: frontier,
                    reasonId: GraphSchedulerReasonID.circuitOpen,
                    emitter: &emitter
                )
                break frontierLoop
            }
        }

        await emitter.emit(kind: .scheduleCompleted)
        return Self.result(
            nodes: nodes,
            states: states,
            dispatchOrder: dispatchOrder
        )
    }

    private static func validate(
        initialStates: [String: GraphNodeState],
        nodesByID: [String: ExecutionDAG.Node]
    ) throws {
        if let unknown = initialStates.keys
            .filter({ nodesByID[$0] == nil })
            .sorted()
            .first
        {
            throw ExecutionGraphViolation(
                id: GraphSchedulerReasonID.resumeUnknownNode,
                detail: "initial state names unknown node '\(unknown)'"
            )
        }

        for nodeID in initialStates.keys.sorted() {
            guard let state = initialStates[nodeID],
                  let node = nodesByID[nodeID]
            else {
                continue
            }

            if state == .running {
                throw ExecutionGraphViolation(
                    id: GraphSchedulerReasonID.resumeInconsistent,
                    detail: "node '\(nodeID)' cannot resume from running state"
                )
            }

            switch state {
            case .succeeded, .failed:
                if let dependency = node.dependencies
                    .sorted()
                    .first(where: { initialStates[$0] != .succeeded })
                {
                    throw ExecutionGraphViolation(
                        id: GraphSchedulerReasonID.resumeInconsistent,
                        detail: "completed node '\(nodeID)' lacks successful dependency '\(dependency)'"
                    )
                }
            case .skipped(_, let blockedBy):
                if let blockedBy {
                    guard node.dependencies.contains(blockedBy),
                          let blockerState = initialStates[blockedBy],
                          blockerState.isTerminal,
                          !blockerState.isTerminalSuccessful
                    else {
                        throw ExecutionGraphViolation(
                            id: GraphSchedulerReasonID.resumeInconsistent,
                            detail: "skipped node '\(nodeID)' has inconsistent blocker '\(blockedBy)'"
                        )
                    }
                }
            case .pending, .running:
                break
            }
        }
    }

    private static func executeParallel(
        activations: [GraphStepActivation],
        maximumParallelism: Int,
        shouldStopBeforeActivation:
            @escaping @Sendable (GraphStepActivation) async -> Bool,
        executor: @escaping @Sendable (GraphStepActivation) async -> GraphStepOutcome
    ) async -> ParallelExecutionResult {
        guard !activations.isEmpty else {
            return ParallelExecutionResult(
                outcomes: [:],
                blockedNodeIDs: [],
                boundaryStopTriggered: false
            )
        }

        return await withTaskGroup(
            of: ExecutedOutcome.self,
            returning: ParallelExecutionResult.self
        ) { group in
            var nextIndex = 0
            let initialCount = min(maximumParallelism, activations.count)

            // Check the whole initial batch before starting any member. Once
            // admitted, all of these in-flight siblings are allowed to settle.
            for activation in activations.prefix(initialCount) {
                if await shouldStopBeforeActivation(activation) {
                    return ParallelExecutionResult(
                        outcomes: [:],
                        blockedNodeIDs: Set(
                            activations.map(\.nodeId)
                        ),
                        boundaryStopTriggered: true
                    )
                }
            }
            while nextIndex < initialCount {
                let activation = activations[nextIndex]
                group.addTask {
                    let outcome = await executor(activation)
                    return ExecutedOutcome(
                        expectedNodeID: activation.nodeId,
                        outcome: outcome
                    )
                }
                nextIndex += 1
            }

            var outcomes: [String: GraphStepOutcome] = [:]
            var blockedNodeIDs = Set<String>()
            var boundaryStopTriggered = false
            while let executed = await group.next() {
                outcomes[executed.expectedNodeID] = executed.outcome
                guard !boundaryStopTriggered,
                      nextIndex < activations.count
                else {
                    continue
                }
                let activation = activations[nextIndex]
                if await shouldStopBeforeActivation(activation) {
                    boundaryStopTriggered = true
                    blockedNodeIDs.formUnion(
                        activations[nextIndex...].map(\.nodeId)
                    )
                    nextIndex = activations.count
                    continue
                }
                group.addTask {
                    let outcome = await executor(activation)
                    return ExecutedOutcome(
                        expectedNodeID: activation.nodeId,
                        outcome: outcome
                    )
                }
                nextIndex += 1
            }
            return ParallelExecutionResult(
                outcomes: outcomes,
                blockedNodeIDs: blockedNodeIDs,
                boundaryStopTriggered: boundaryStopTriggered
            )
        }
    }

    private static func normalizedState(
        _ outcome: GraphStepOutcome,
        expectedNodeID: String
    ) -> GraphNodeState {
        guard outcome.nodeId == expectedNodeID else {
            return .failed(reasonId: GraphSchedulerReasonID.outcomeNodeMismatch)
        }
        guard outcome.state.isTerminal else {
            return .failed(reasonId: GraphSchedulerReasonID.outcomeNonterminal)
        }
        return outcome.state
    }

    private static func failedDependency(
        of node: ExecutionDAG.Node,
        states: [String: GraphNodeState]
    ) -> String? {
        node.dependencies.sorted().first {
            guard let state = states[$0] else {
                return false
            }
            switch state {
            case .failed, .skipped:
                return true
            case .pending, .running, .succeeded:
                return false
            }
        }
    }

    private static func propagateDependencySkips(
        nodes: [ExecutionDAG.Node],
        states: inout [String: GraphNodeState],
        frontier: Int?,
        emitter: inout EventEmitter
    ) async {
        var changed = true
        while changed {
            changed = false
            for node in nodes where states[node.id] == .pending {
                guard let blocker = failedDependency(of: node, states: states) else {
                    continue
                }
                let skipped = GraphNodeState.skipped(
                    reasonId: GraphSchedulerReasonID.dependencyFailed,
                    blockedBy: blocker
                )
                states[node.id] = skipped
                changed = true
                await emitter.emit(
                    kind: .nodeSkipped,
                    frontier: frontier,
                    nodeId: node.id,
                    state: skipped,
                    reasonId: GraphSchedulerReasonID.dependencyFailed
                )
            }
        }
    }

    private static func skipPending(
        nodes: [ExecutionDAG.Node],
        states: inout [String: GraphNodeState],
        frontier: Int?,
        reasonId: String,
        emitter: inout EventEmitter
    ) async {
        for node in nodes where states[node.id] == .pending {
            let skipped = GraphNodeState.skipped(
                reasonId: reasonId,
                blockedBy: nil
            )
            states[node.id] = skipped
            await emitter.emit(
                kind: .nodeSkipped,
                frontier: frontier,
                nodeId: node.id,
                state: skipped,
                reasonId: reasonId
            )
        }
    }

    private static func shouldOpenCircuit(
        _ policy: GraphFailurePolicy,
        executedFailureCount: Int
    ) -> Bool {
        switch policy {
        case .continueIndependentBranches:
            return false
        case .stopFutureFrontiers(let maximumExecutedFailures):
            return executedFailureCount >= maximumExecutedFailures
        }
    }

    private static func result(
        nodes: [ExecutionDAG.Node],
        states: [String: GraphNodeState],
        dispatchOrder: [String]
    ) -> GraphScheduleResult {
        GraphScheduleResult(
            states: states,
            dispatchOrder: dispatchOrder,
            outcomes: nodes.compactMap { node in
                states[node.id].map {
                    GraphStepOutcome(nodeId: node.id, state: $0)
                }
            }
        )
    }
}

private struct ExecutedOutcome: Sendable {
    let expectedNodeID: String
    let outcome: GraphStepOutcome
}

private struct ParallelExecutionResult: Sendable {
    let outcomes: [String: GraphStepOutcome]
    let blockedNodeIDs: Set<String>
    let boundaryStopTriggered: Bool
}

private struct EventEmitter {
    let sink: any GraphSchedulerEventSink
    var nextSequence = 1

    mutating func emit(
        kind: GraphSchedulerEvent.Kind,
        frontier: Int? = nil,
        nodeId: String? = nil,
        state: GraphNodeState? = nil,
        reasonId: String? = nil
    ) async {
        let event = GraphSchedulerEvent(
            sequence: nextSequence,
            kind: kind,
            frontier: frontier,
            nodeId: nodeId,
            state: state,
            reasonId: reasonId
        )
        nextSequence += 1
        await sink.record(event)
    }
}
