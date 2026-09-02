import Foundation
import Testing
@testable import MentuExecutionGraphCore

@Suite("Execution DAG validation and value contracts")
struct ExecutionDAGTests {
    @Test("stable topological frontiers sort nodes and dependencies")
    func stableFrontiers() throws {
        let dag = ExecutionDAG(nodes: [
            schedulerTestNode("verify", dependencies: ["left", "right"]),
            schedulerTestNode("right", dependencies: ["root"]),
            schedulerTestNode("left", dependencies: ["root"]),
            schedulerTestNode("root"),
        ])

        let frontiers = try dag.validatedFrontiers()
        #expect(frontiers.map { $0.map(\.id) } == [
            ["root"],
            ["left", "right"],
            ["verify"],
        ])
    }

    @Test(
        "DAG violations use stable reason IDs",
        arguments: [
            (
                ExecutionDAG(nodes: [
                    schedulerTestNode("same"),
                    schedulerTestNode("same"),
                ]),
                GraphSchedulerReasonID.duplicateNode
            ),
            (
                ExecutionDAG(nodes: [schedulerTestNode("../escape")]),
                GraphSchedulerReasonID.invalidNodeID
            ),
            (
                ExecutionDAG(nodes: [
                    schedulerTestNode("a", dependencies: ["missing"]),
                ]),
                GraphSchedulerReasonID.unknownDependency
            ),
            (
                ExecutionDAG(nodes: [
                    schedulerTestNode("a", dependencies: ["a"]),
                ]),
                GraphSchedulerReasonID.selfDependency
            ),
            (
                ExecutionDAG(nodes: [
                    schedulerTestNode("a", dependencies: ["b"]),
                    schedulerTestNode("b", dependencies: ["a"]),
                ]),
                GraphSchedulerReasonID.cycle
            ),
        ]
    )
    func stableViolationIDs(dag: ExecutionDAG, expectedID: String) {
        do {
            _ = try dag.validatedFrontiers()
            Issue.record("expected \(expectedID)")
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == expectedID)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("safe node IDs accept normalized label characters")
    func safeNodeIDs() throws {
        let dag = ExecutionDAG(nodes: [
            schedulerTestNode("alpha"),
            schedulerTestNode("build.verify_2", dependencies: ["alpha"]),
            schedulerTestNode("éxito-3", dependencies: ["build.verify_2"]),
        ])

        #expect(try dag.validatedFrontiers().count == 3)
    }

    @Test(
        "unsafe node IDs are refused",
        arguments: ["", ".", "..", "has space", "slash/name", "line\nbreak", "e\u{301}"]
    )
    func unsafeNodeIDs(id: String) {
        do {
            _ = try ExecutionDAG(nodes: [schedulerTestNode(id)]).validatedFrontiers()
            Issue.record("expected invalid node ID")
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == GraphSchedulerReasonID.invalidNodeID)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("runtime enums use frozen tagged JSON objects")
    func taggedCodableShapes() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let failed = try encoder.encode(GraphNodeState.failed(reasonId: "host.failed"))
        let skipped = try encoder.encode(
            GraphNodeState.skipped(reasonId: "dependency.failed", blockedBy: "build")
        )
        let policy = try encoder.encode(
            GraphFailurePolicy.stopFutureFrontiers(maximumExecutedFailures: 3)
        )

        #expect(String(decoding: failed, as: UTF8.self) ==
            #"{"kind":"failed","reasonId":"host.failed"}"#)
        #expect(String(decoding: skipped, as: UTF8.self) ==
            #"{"blockedBy":"build","kind":"skipped","reasonId":"dependency.failed"}"#)
        #expect(String(decoding: policy, as: UTF8.self) ==
            #"{"kind":"stopFutureFrontiers","maximumExecutedFailures":3}"#)

        #expect(try JSONDecoder().decode(GraphNodeState.self, from: failed) ==
            .failed(reasonId: "host.failed"))
        #expect(try JSONDecoder().decode(GraphNodeState.self, from: skipped) ==
            .skipped(reasonId: "dependency.failed", blockedBy: "build"))
        #expect(try JSONDecoder().decode(GraphFailurePolicy.self, from: policy) ==
            .stopFutureFrontiers(maximumExecutedFailures: 3))
    }

    @Test("DAG and scheduler result expose public construction and round trip")
    func publicValueRoundTrip() throws {
        let dag = ExecutionDAG(nodes: [
            ExecutionDAG.Node(
                id: "only",
                dependencies: [],
                dispatchMode: .exclusive
            ),
        ])
        let result = GraphScheduleResult(
            states: ["only": .succeeded],
            dispatchOrder: ["only"],
            outcomes: [GraphStepOutcome(nodeId: "only", state: .succeeded)]
        )

        let encoder = JSONEncoder()
        #expect(try JSONDecoder().decode(
            ExecutionDAG.self,
            from: encoder.encode(dag)
        ) == dag)
        #expect(try JSONDecoder().decode(
            GraphScheduleResult.self,
            from: encoder.encode(result)
        ) == result)
    }
}
