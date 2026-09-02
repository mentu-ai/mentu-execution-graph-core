import Testing
@testable import MentuExecutionGraphCore

actor SchedulerTestEventSink: GraphSchedulerEventSink {
    private var recorded: [GraphSchedulerEvent] = []

    func record(_ event: GraphSchedulerEvent) async {
        recorded.append(event)
    }

    func events() -> [GraphSchedulerEvent] {
        recorded
    }
}

actor SchedulerTestActivationRecorder {
    private var recorded: [GraphStepActivation] = []

    func append(_ activation: GraphStepActivation) {
        recorded.append(activation)
    }

    func activations() -> [GraphStepActivation] {
        recorded
    }
}

actor SchedulerTestDispatchObserver {
    struct Observation: Sendable, Equatable {
        let nodeID: String
        let dispatchedNodeIDs: [String]
        let completedNodeIDs: [String]
    }

    private var recorded: [Observation] = []

    func append(_ observation: Observation) {
        recorded.append(observation)
    }

    func observations() -> [Observation] {
        recorded
    }
}

actor SchedulerTestGate {
    struct Snapshot: Sendable {
        let started: [String]
        let active: Set<String>
        let completed: [String]
        let peakActive: Int
        let activations: [String: GraphStepActivation]
    }

    private var started: [String] = []
    private var active = Set<String>()
    private var completed: [String] = []
    private var peakActive = 0
    private var activations: [String: GraphStepActivation] = [:]
    private var blocked: [String: CheckedContinuation<Void, Never>] = [:]
    private var startedWaiters: [
        (count: Int, continuation: CheckedContinuation<Void, Never>)
    ] = []
    private var completedWaiters: [
        (count: Int, continuation: CheckedContinuation<Void, Never>)
    ] = []

    func execute(
        _ activation: GraphStepActivation,
        state: GraphNodeState = .succeeded
    ) async -> GraphStepOutcome {
        await withCheckedContinuation { continuation in
            started.append(activation.nodeId)
            active.insert(activation.nodeId)
            peakActive = max(peakActive, active.count)
            activations[activation.nodeId] = activation
            blocked[activation.nodeId] = continuation
            resolveStartedWaiters()
        }

        active.remove(activation.nodeId)
        completed.append(activation.nodeId)
        resolveCompletedWaiters()
        return GraphStepOutcome(nodeId: activation.nodeId, state: state)
    }

    func waitForStartedCount(_ count: Int) async {
        guard started.count < count else {
            return
        }
        await withCheckedContinuation { continuation in
            startedWaiters.append((count, continuation))
        }
    }

    func waitForCompletedCount(_ count: Int) async {
        guard completed.count < count else {
            return
        }
        await withCheckedContinuation { continuation in
            completedWaiters.append((count, continuation))
        }
    }

    func release(_ nodeID: String) {
        blocked.removeValue(forKey: nodeID)?.resume()
    }

    func releaseAll() {
        let continuations = blocked
            .sorted { $0.key < $1.key }
            .map(\.value)
        blocked.removeAll()
        for continuation in continuations {
            continuation.resume()
        }
    }

    func snapshot() -> Snapshot {
        Snapshot(
            started: started,
            active: active,
            completed: completed,
            peakActive: peakActive,
            activations: activations
        )
    }

    private func resolveStartedWaiters() {
        var unresolved: [
            (count: Int, continuation: CheckedContinuation<Void, Never>)
        ] = []
        for waiter in startedWaiters {
            if started.count >= waiter.count {
                waiter.continuation.resume()
            } else {
                unresolved.append(waiter)
            }
        }
        startedWaiters = unresolved
    }

    private func resolveCompletedWaiters() {
        var unresolved: [
            (count: Int, continuation: CheckedContinuation<Void, Never>)
        ] = []
        for waiter in completedWaiters {
            if completed.count >= waiter.count {
                waiter.continuation.resume()
            } else {
                unresolved.append(waiter)
            }
        }
        completedWaiters = unresolved
    }
}

func schedulerTestNode(
    _ id: String,
    dependencies: [String] = [],
    mode: ExecutionDAG.Node.DispatchMode = .parallelSafe
) -> ExecutionDAG.Node {
    ExecutionDAG.Node(
        id: id,
        dependencies: dependencies,
        dispatchMode: mode
    )
}

func schedulerTestRun(
    dag: ExecutionDAG,
    initialStates: [String: GraphNodeState] = [:],
    maximumParallelism: Int = 4,
    failurePolicy: GraphFailurePolicy = .continueIndependentBranches,
    sink: any GraphSchedulerEventSink = NoOpGraphSchedulerEventSink(),
    shouldStopBeforeFrontier:
        @escaping @Sendable (Int) async -> Bool = { _ in false },
    shouldStopBeforeActivation:
        @escaping @Sendable (GraphStepActivation) async -> Bool = { _ in false },
    outcome: @escaping @Sendable (GraphStepActivation) async -> GraphStepOutcome
) async throws -> GraphScheduleResult {
    try await ExecutionGraphScheduler().run(
        dag: dag,
        initialStates: initialStates,
        maximumParallelism: maximumParallelism,
        failurePolicy: failurePolicy,
        eventSink: sink,
        shouldStopBeforeFrontier: shouldStopBeforeFrontier,
        shouldStopBeforeActivation: shouldStopBeforeActivation,
        executor: outcome
    )
}

func schedulerTestRun(
    dag: ExecutionDAG,
    initialStates: [String: GraphNodeState] = [:],
    maximumParallelism: Int = 4,
    failurePolicy: GraphFailurePolicy = .continueIndependentBranches,
    sink: any GraphSchedulerEventSink = NoOpGraphSchedulerEventSink(),
    shouldStopBeforeFrontier:
        @escaping @Sendable (Int) async -> Bool = { _ in false },
    shouldStopBeforeActivation:
        @escaping @Sendable (GraphStepActivation) async -> Bool = { _ in false }
) async throws -> GraphScheduleResult {
    try await schedulerTestRun(
        dag: dag,
        initialStates: initialStates,
        maximumParallelism: maximumParallelism,
        failurePolicy: failurePolicy,
        sink: sink,
        shouldStopBeforeFrontier: shouldStopBeforeFrontier,
        shouldStopBeforeActivation: shouldStopBeforeActivation,
        outcome: {
            GraphStepOutcome(nodeId: $0.nodeId, state: .succeeded)
        }
    )
}

actor SchedulerBoundaryStopSignal {
    private var requested = false

    func request() {
        requested = true
    }

    func isRequested() -> Bool {
        requested
    }
}
