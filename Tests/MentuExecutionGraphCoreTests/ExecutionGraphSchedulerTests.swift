import Testing
@testable import MentuExecutionGraphCore

@Suite("Execution graph scheduler")
struct ExecutionGraphSchedulerTests {
    @Test("linear three-node graph runs in dependency order")
    func linearGraph() async throws {
        let dag = ExecutionDAG(nodes: [
            schedulerTestNode("third", dependencies: ["second"]),
            schedulerTestNode("first"),
            schedulerTestNode("second", dependencies: ["first"]),
        ])
        let sink = SchedulerTestEventSink()
        let activations = SchedulerTestActivationRecorder()

        let result = try await schedulerTestRun(dag: dag, sink: sink) { activation in
            await activations.append(activation)
            return GraphStepOutcome(nodeId: activation.nodeId, state: .succeeded)
        }

        #expect(result.dispatchOrder == ["first", "second", "third"])
        #expect(result.outcomes.map(\.nodeId) == ["first", "second", "third"])
        #expect(result.states.values.allSatisfy { $0 == .succeeded })
        #expect(await activations.activations() == [
            GraphStepActivation(nodeId: "first", ordinal: 1, frontier: 1),
            GraphStepActivation(nodeId: "second", ordinal: 2, frontier: 2),
            GraphStepActivation(nodeId: "third", ordinal: 3, frontier: 3),
        ])

        let events = await sink.events()
        #expect(events.first?.kind == .scheduleStarted)
        #expect(events.last?.kind == .scheduleCompleted)
        #expect(events.map(\.sequence) == Array(1...events.count))
    }

    @Test("diamond graph executes stable frontiers")
    func diamondGraph() async throws {
        let dag = ExecutionDAG(nodes: [
            schedulerTestNode("join", dependencies: ["right", "left"]),
            schedulerTestNode("right", dependencies: ["root"]),
            schedulerTestNode("root"),
            schedulerTestNode("left", dependencies: ["root"]),
        ])

        let result = try await schedulerTestRun(
            dag: dag,
            maximumParallelism: 2
        )

        #expect(result.dispatchOrder == ["root", "left", "right", "join"])
        #expect(result.outcomes.map(\.nodeId) == ["join", "left", "right", "root"])
        #expect(result.states.values.allSatisfy { $0 == .succeeded })
    }

    @Test("16-node mixed graph preserves exclusive-first stable dispatch")
    func mixedSixteenNodeGraph() async throws {
        let dag = ExecutionDAG(nodes: [
            schedulerTestNode("c3", dependencies: ["c2"]),
            schedulerTestNode("a0"),
            schedulerTestNode("x2", dependencies: ["x1"], mode: .exclusive),
            schedulerTestNode("b1", dependencies: ["b0"]),
            schedulerTestNode("x0", mode: .exclusive),
            schedulerTestNode("a2", dependencies: ["a1", "b1"]),
            schedulerTestNode("c0"),
            schedulerTestNode("x3", dependencies: ["x2"], mode: .exclusive),
            schedulerTestNode("b3", dependencies: ["b2"]),
            schedulerTestNode("a1", dependencies: ["a0"]),
            schedulerTestNode("c2", dependencies: ["c1", "x1"]),
            schedulerTestNode("b0"),
            schedulerTestNode("a3", dependencies: ["a2"]),
            schedulerTestNode("x1", dependencies: ["x0"], mode: .exclusive),
            schedulerTestNode("b2", dependencies: ["b1", "c1"]),
            schedulerTestNode("c1", dependencies: ["c0"]),
        ])

        let result = try await schedulerTestRun(
            dag: dag,
            maximumParallelism: 8
        )

        #expect(result.dispatchOrder == [
            "x0", "a0", "b0", "c0",
            "x1", "a1", "b1", "c1",
            "x2", "a2", "b2", "c2",
            "x3", "a3", "b3", "c3",
        ])
        #expect(result.outcomes.count == 16)
        #expect(result.outcomes.map(\.nodeId) == result.outcomes.map(\.nodeId).sorted())
        #expect(result.states.values.allSatisfy { $0 == .succeeded })
    }

    @Test(
        "parallel-safe execution obeys caps of one, two, and N",
        arguments: [1, 2, 4]
    )
    func boundedParallelism(cap: Int) async throws {
        let ids = ["a", "b", "c", "d"]
        let dag = ExecutionDAG(nodes: ids.reversed().map { schedulerTestNode($0) })
        let gate = SchedulerTestGate()
        let task = Task {
            try await schedulerTestRun(
                dag: dag,
                maximumParallelism: cap
            ) { activation in
                await gate.execute(activation)
            }
        }

        var expectedStarted = min(cap, ids.count)
        await gate.waitForStartedCount(expectedStarted)
        while expectedStarted < ids.count {
            let snapshot = await gate.snapshot()
            #expect(snapshot.active.count <= cap)
            #expect(snapshot.peakActive <= cap)
            await gate.releaseAll()
            expectedStarted = min(ids.count, expectedStarted + cap)
            await gate.waitForStartedCount(expectedStarted)
        }

        let saturated = await gate.snapshot()
        #expect(saturated.peakActive == cap)
        #expect(saturated.active.count <= cap)
        await gate.releaseAll()

        let result = try await task.value
        #expect(result.dispatchOrder == ids)
        #expect(result.states.values.allSatisfy { $0 == .succeeded })
        #expect((await gate.snapshot()).peakActive == cap)
    }

    @Test("parallel-safe siblings overlap")
    func parallelSafeSiblingsOverlap() async throws {
        let gate = SchedulerTestGate()
        let task = Task {
            try await schedulerTestRun(
                dag: ExecutionDAG(nodes: [
                    schedulerTestNode("right"),
                    schedulerTestNode("left"),
                ]),
                maximumParallelism: 2
            ) { activation in
                await gate.execute(activation)
            }
        }

        await gate.waitForStartedCount(2)
        let overlapping = await gate.snapshot()
        #expect(overlapping.active == Set(["left", "right"]))
        #expect(overlapping.peakActive == 2)
        await gate.releaseAll()
        _ = try await task.value
    }

    @Test("sorted dispatch evidence is complete before parallel executors start")
    func dispatchEvidencePrecedesExecutors() async throws {
        let sink = SchedulerTestEventSink()
        let observer = SchedulerTestDispatchObserver()
        let dag = ExecutionDAG(nodes: [
            schedulerTestNode("c"),
            schedulerTestNode("a"),
            schedulerTestNode("b"),
        ])

        let result = try await schedulerTestRun(
            dag: dag,
            maximumParallelism: 1,
            sink: sink
        ) { activation in
            let events = await sink.events()
            await observer.append(.init(
                nodeID: activation.nodeId,
                dispatchedNodeIDs: events
                    .filter { $0.kind == .nodeDispatched }
                    .compactMap(\.nodeId),
                completedNodeIDs: events
                    .filter { $0.kind == .nodeCompleted }
                    .compactMap(\.nodeId)
            ))
            return GraphStepOutcome(nodeId: activation.nodeId, state: .succeeded)
        }

        #expect(result.dispatchOrder == ["a", "b", "c"])
        let observations = await observer.observations()
        #expect(observations.count == 3)
        #expect(observations.allSatisfy {
            $0.dispatchedNodeIDs == ["a", "b", "c"]
                && $0.completedNodeIDs.isEmpty
        })
    }

    @Test("exclusive nodes run sequentially before parallel-safe siblings")
    func exclusiveNodesDoNotOverlap() async throws {
        let gate = SchedulerTestGate()
        let task = Task {
            try await schedulerTestRun(
                dag: ExecutionDAG(nodes: [
                    schedulerTestNode("b"),
                    schedulerTestNode("y", mode: .exclusive),
                    schedulerTestNode("a"),
                    schedulerTestNode("x", mode: .exclusive),
                ]),
                maximumParallelism: 2
            ) { activation in
                await gate.execute(activation)
            }
        }

        await gate.waitForStartedCount(1)
        #expect((await gate.snapshot()).started == ["x"])
        #expect((await gate.snapshot()).active == Set(["x"]))
        await gate.release("x")

        await gate.waitForStartedCount(2)
        #expect((await gate.snapshot()).started == ["x", "y"])
        #expect((await gate.snapshot()).active == Set(["y"]))
        await gate.release("y")

        await gate.waitForStartedCount(4)
        let parallelBatch = await gate.snapshot()
        #expect(Set(parallelBatch.started.suffix(2)) == Set(["a", "b"]))
        #expect(parallelBatch.active == Set(["a", "b"]))
        #expect(parallelBatch.peakActive == 2)
        await gate.releaseAll()

        let result = try await task.value
        #expect(result.dispatchOrder == ["x", "y", "a", "b"])
    }

    @Test("failed parent cascades while unrelated in-flight branch completes")
    func failureCascadePreservesIndependentBranch() async throws {
        let dag = ExecutionDAG(nodes: [
            schedulerTestNode("grandchild", dependencies: ["dependent"]),
            schedulerTestNode("independent-child", dependencies: ["independent"]),
            schedulerTestNode("dependent", dependencies: ["failing"]),
            schedulerTestNode("independent"),
            schedulerTestNode("failing"),
        ])
        let gate = SchedulerTestGate()
        let task = Task {
            try await schedulerTestRun(
                dag: dag,
                maximumParallelism: 2
            ) { activation in
                let state: GraphNodeState = activation.nodeId == "failing"
                    ? .failed(reasonId: "host.failed")
                    : .succeeded
                return await gate.execute(activation, state: state)
            }
        }

        await gate.waitForStartedCount(2)
        await gate.release("failing")
        await gate.waitForCompletedCount(1)
        let siblingStillRunning = await gate.snapshot()
        #expect(siblingStillRunning.active == Set(["independent"]))
        #expect(siblingStillRunning.started.count == 2)
        await gate.release("independent")

        await gate.waitForStartedCount(3)
        #expect((await gate.snapshot()).started.contains("independent-child"))
        await gate.release("independent-child")

        let result = try await task.value
        #expect(result.dispatchOrder == [
            "failing", "independent", "independent-child",
        ])
        #expect(result.states["failing"] == .failed(reasonId: "host.failed"))
        #expect(result.states["independent"] == .succeeded)
        #expect(result.states["independent-child"] == .succeeded)
        #expect(result.states["dependent"] == .skipped(
            reasonId: GraphSchedulerReasonID.dependencyFailed,
            blockedBy: "failing"
        ))
        #expect(result.states["grandchild"] == .skipped(
            reasonId: GraphSchedulerReasonID.dependencyFailed,
            blockedBy: "dependent"
        ))
    }

    @Test("circuit opens after the whole current frontier settles")
    func circuitOpensAtFutureFrontier() async throws {
        let dag = ExecutionDAG(nodes: [
            schedulerTestNode("c-child", dependencies: ["c"]),
            schedulerTestNode("a-child", dependencies: ["a"]),
            schedulerTestNode("c"),
            schedulerTestNode("b"),
            schedulerTestNode("a"),
        ])
        let gate = SchedulerTestGate()
        let sink = SchedulerTestEventSink()
        let task = Task {
            try await schedulerTestRun(
                dag: dag,
                maximumParallelism: 3,
                failurePolicy: .stopFutureFrontiers(maximumExecutedFailures: 2),
                sink: sink
            ) { activation in
                let state: GraphNodeState = activation.nodeId == "c"
                    ? .succeeded
                    : .failed(reasonId: "host.failed")
                return await gate.execute(activation, state: state)
            }
        }

        await gate.waitForStartedCount(3)
        await gate.release("a")
        await gate.waitForCompletedCount(1)
        #expect((await gate.snapshot()).active == Set(["b", "c"]))
        await gate.release("b")
        await gate.release("c")

        let result = try await task.value
        #expect(result.dispatchOrder == ["a", "b", "c"])
        #expect(result.states["a-child"] == .skipped(
            reasonId: GraphSchedulerReasonID.dependencyFailed,
            blockedBy: "a"
        ))
        #expect(result.states["c-child"] == .skipped(
            reasonId: GraphSchedulerReasonID.circuitOpen,
            blockedBy: nil
        ))

        let events = await sink.events()
        let circuitSequence = try #require(
            events.first(where: { $0.kind == .circuitOpened })?.sequence
        )
        let rootCompletionSequences = events
            .filter { $0.kind == .nodeCompleted && ["a", "b", "c"].contains($0.nodeId ?? "") }
            .map(\.sequence)
        #expect(rootCompletionSequences.count == 3)
        #expect(rootCompletionSequences.allSatisfy { $0 < circuitSequence })
        #expect(!events.contains {
            $0.kind == .nodeDispatched
                && ["a-child", "c-child"].contains($0.nodeId ?? "")
        })
    }

    @Test("boundary stop waits for in-flight siblings and blocks the next frontier")
    func boundaryStopPreservesInFlightSiblings() async throws {
        let signal = SchedulerBoundaryStopSignal()
        let activations = SchedulerTestActivationRecorder()
        let sink = SchedulerTestEventSink()
        let dag = ExecutionDAG(nodes: [
            schedulerTestNode("future", dependencies: ["a", "b"]),
            schedulerTestNode("b"),
            schedulerTestNode("a"),
        ])

        let result = try await schedulerTestRun(
            dag: dag,
            maximumParallelism: 2,
            sink: sink,
            shouldStopBeforeFrontier: { _ in
                await signal.isRequested()
            }
        ) { activation in
            await activations.append(activation)
            if activation.nodeId == "a" {
                await signal.request()
            }
            return GraphStepOutcome(
                nodeId: activation.nodeId,
                state: .succeeded
            )
        }

        #expect(result.dispatchOrder == ["a", "b"])
        let activatedNodeIDs = Set(
            await activations.activations().map(\.nodeId)
        )
        #expect(activatedNodeIDs == Set(["a", "b"]))
        #expect(result.states["a"] == .succeeded)
        #expect(result.states["b"] == .succeeded)
        #expect(
            result.states["future"] == .skipped(
                reasonId: GraphSchedulerReasonID.boundaryStop,
                blockedBy: nil
            )
        )
        let events = await sink.events()
        #expect(events.contains {
            $0.kind == .circuitOpened
                && $0.reasonId == GraphSchedulerReasonID.boundaryStop
        })
        #expect(!events.contains {
            $0.kind == .nodeDispatched && $0.nodeId == "future"
        })
    }

    @Test("boundary stop blocks the next exclusive activation in one frontier")
    func boundaryStopBlocksSameFrontierExclusiveActivation() async throws {
        let signal = SchedulerBoundaryStopSignal()
        let activations = SchedulerTestActivationRecorder()
        let dag = ExecutionDAG(nodes: [
            schedulerTestNode("b", mode: .exclusive),
            schedulerTestNode("a", mode: .exclusive),
        ])

        let result = try await schedulerTestRun(
            dag: dag,
            shouldStopBeforeActivation: { _ in
                await signal.isRequested()
            }
        ) { activation in
            await activations.append(activation)
            if activation.nodeId == "a" {
                await signal.request()
            }
            return GraphStepOutcome(
                nodeId: activation.nodeId,
                state: .succeeded
            )
        }

        #expect(result.dispatchOrder == ["a"])
        #expect(await activations.activations().map(\.nodeId) == ["a"])
        #expect(result.states["a"] == .succeeded)
        #expect(
            result.states["b"] == .skipped(
                reasonId: GraphSchedulerReasonID.boundaryStop,
                blockedBy: nil
            )
        )
    }

    @Test("boundary stop blocks capped parallel replacements")
    func boundaryStopBlocksQueuedParallelReplacement() async throws {
        let signal = SchedulerBoundaryStopSignal()
        let activations = SchedulerTestActivationRecorder()
        let dag = ExecutionDAG(nodes: [
            schedulerTestNode("c"),
            schedulerTestNode("b"),
            schedulerTestNode("a"),
        ])

        let result = try await schedulerTestRun(
            dag: dag,
            maximumParallelism: 1,
            shouldStopBeforeActivation: { _ in
                await signal.isRequested()
            }
        ) { activation in
            await activations.append(activation)
            if activation.nodeId == "a" {
                await signal.request()
            }
            return GraphStepOutcome(
                nodeId: activation.nodeId,
                state: .succeeded
            )
        }

        #expect(result.dispatchOrder == ["a", "b", "c"])
        #expect(await activations.activations().map(\.nodeId) == ["a"])
        for nodeID in ["b", "c"] {
            #expect(
                result.states[nodeID] == .skipped(
                    reasonId: GraphSchedulerReasonID.boundaryStop,
                    blockedBy: nil
                )
            )
        }
    }

    @Test("cascade skips do not inflate the executed-failure threshold")
    func cascadeSkipsDoNotOpenCircuit() async throws {
        let sink = SchedulerTestEventSink()
        let dag = ExecutionDAG(nodes: [
            schedulerTestNode("blocked-two", dependencies: ["blocked-one"]),
            schedulerTestNode("independent-child", dependencies: ["independent"]),
            schedulerTestNode("blocked-one", dependencies: ["fails"]),
            schedulerTestNode("independent"),
            schedulerTestNode("fails"),
        ])

        let result = try await schedulerTestRun(
            dag: dag,
            maximumParallelism: 2,
            failurePolicy: .stopFutureFrontiers(maximumExecutedFailures: 3),
            sink: sink
        ) { activation in
            GraphStepOutcome(
                nodeId: activation.nodeId,
                state: activation.nodeId == "fails"
                    ? .failed(reasonId: "host.failed")
                    : .succeeded
            )
        }

        #expect(result.dispatchOrder == [
            "fails", "independent", "independent-child",
        ])
        #expect(result.states["blocked-one"] == .skipped(
            reasonId: GraphSchedulerReasonID.dependencyFailed,
            blockedBy: "fails"
        ))
        #expect(result.states["blocked-two"] == .skipped(
            reasonId: GraphSchedulerReasonID.dependencyFailed,
            blockedBy: "blocked-one"
        ))
        #expect(!(await sink.events()).contains { $0.kind == .circuitOpened })
    }

    @Test("resume accepts completed ancestors and dispatches only pending descendants")
    func resumeCompletedAncestors() async throws {
        let recorder = SchedulerTestActivationRecorder()
        let dag = ExecutionDAG(nodes: [
            schedulerTestNode("c", dependencies: ["b"]),
            schedulerTestNode("b", dependencies: ["a"]),
            schedulerTestNode("a"),
        ])

        let result = try await schedulerTestRun(
            dag: dag,
            initialStates: ["a": .succeeded],
            maximumParallelism: 2
        ) { activation in
            await recorder.append(activation)
            return GraphStepOutcome(nodeId: activation.nodeId, state: .succeeded)
        }

        #expect(result.dispatchOrder == ["b", "c"])
        #expect(result.states == ["a": .succeeded, "b": .succeeded, "c": .succeeded])
        #expect(await recorder.activations() == [
            GraphStepActivation(nodeId: "b", ordinal: 1, frontier: 2),
            GraphStepActivation(nodeId: "c", ordinal: 2, frontier: 3),
        ])
    }

    @Test(
        "invalid scheduler and resume inputs refuse before dispatch",
        arguments: [
            (
                ["unknown": GraphNodeState.succeeded],
                1,
                GraphSchedulerReasonID.resumeUnknownNode
            ),
            (
                ["b": GraphNodeState.succeeded],
                1,
                GraphSchedulerReasonID.resumeInconsistent
            ),
            (
                ["a": GraphNodeState.running],
                1,
                GraphSchedulerReasonID.resumeInconsistent
            ),
            (
                [:],
                0,
                GraphSchedulerReasonID.invalidParallelism
            ),
        ]
    )
    func invalidResumeRefusal(
        initialStates: [String: GraphNodeState],
        parallelism: Int,
        expectedID: String
    ) async {
        let sink = SchedulerTestEventSink()
        let dag = ExecutionDAG(nodes: [
            schedulerTestNode("a"),
            schedulerTestNode("b", dependencies: ["a"]),
        ])

        do {
            _ = try await schedulerTestRun(
                dag: dag,
                initialStates: initialStates,
                maximumParallelism: parallelism,
                sink: sink
            )
            Issue.record("expected \(expectedID)")
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == expectedID)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
        #expect(await sink.events().isEmpty)
    }

    @Test("executor invariant failures are typed and node-local")
    func executorInvariantFailures() async throws {
        let dag = ExecutionDAG(nodes: [
            schedulerTestNode("mismatch"),
            schedulerTestNode("nonterminal"),
            schedulerTestNode("unaffected"),
        ])

        let result = try await schedulerTestRun(
            dag: dag,
            maximumParallelism: 3
        ) { activation in
            switch activation.nodeId {
            case "mismatch":
                return GraphStepOutcome(nodeId: "different", state: .succeeded)
            case "nonterminal":
                return GraphStepOutcome(nodeId: activation.nodeId, state: .running)
            default:
                return GraphStepOutcome(nodeId: activation.nodeId, state: .succeeded)
            }
        }

        #expect(result.states["mismatch"] == .failed(
            reasonId: GraphSchedulerReasonID.outcomeNodeMismatch
        ))
        #expect(result.states["nonterminal"] == .failed(
            reasonId: GraphSchedulerReasonID.outcomeNonterminal
        ))
        #expect(result.states["unaffected"] == .succeeded)
    }

    @Test("inverse host completion produces identical durable evidence and results")
    func inverseCompletionDeterminism() async throws {
        let forward = try await runInverseCompletion(order: ["a", "b"])
        let reverse = try await runInverseCompletion(order: ["b", "a"])

        #expect(forward.result == reverse.result)
        #expect(forward.events == reverse.events)
        #expect(forward.result.dispatchOrder == ["a", "b"])
        #expect(forward.result.outcomes.map(\.nodeId) == ["a", "b"])
        #expect(forward.events
            .filter { $0.kind == .nodeCompleted }
            .compactMap(\.nodeId) == ["a", "b"])
    }

    private func runInverseCompletion(
        order: [String]
    ) async throws -> (
        result: GraphScheduleResult,
        events: [GraphSchedulerEvent]
    ) {
        let gate = SchedulerTestGate()
        let sink = SchedulerTestEventSink()
        let task = Task {
            try await schedulerTestRun(
                dag: ExecutionDAG(nodes: [
                    schedulerTestNode("b"),
                    schedulerTestNode("a"),
                ]),
                maximumParallelism: 2,
                sink: sink
            ) { activation in
                await gate.execute(activation)
            }
        }

        await gate.waitForStartedCount(2)
        for (offset, nodeID) in order.enumerated() {
            await gate.release(nodeID)
            await gate.waitForCompletedCount(offset + 1)
        }
        return (try await task.value, await sink.events())
    }
}
