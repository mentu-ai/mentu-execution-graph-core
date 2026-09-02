import Foundation
import Testing
@testable import MentuExecutionGraphCore

@Suite("Persisted graph contracts")
struct ContractTests {
    @Test("frozen candidate graph has canonical byte parity")
    func candidateParity() throws {
        let bytes = try Data(
            contentsOf: executionGraphBaselineFixture("candidate-graph.json")
        )
        let candidate = try JSONDecoder().decode(
            CandidateExecutionGraph.self,
            from: bytes
        )
        #expect(candidate.schema == CandidateExecutionGraph.currentSchema)
        #expect(candidate.nodes.map(\.id)
            == ["recon", "implement", "final-verify"])
        #expect(try ExecutionGraphCanonicalizer.data(candidate) == bytes)
    }

    @Test("candidate root, source, node, contract, and tool are strict")
    func strictCandidate() throws {
        let bytes = try Data(
            contentsOf: executionGraphBaselineFixture("candidate-graph.json")
        )
        var root = try #require(
            JSONSerialization.jsonObject(with: bytes) as? [String: Any]
        )
        let pristine = root

        root["unknown"] = true
        #expect(candidateDecodeFails(root))
        root = pristine

        var source = try #require(root["source"] as? [String: Any])
        source["credential"] = "secret"
        root["source"] = source
        #expect(candidateDecodeFails(root))
        root = pristine

        var nodes = try #require(root["nodes"] as? [[String: Any]])
        nodes[0]["unknown"] = true
        root["nodes"] = nodes
        #expect(candidateDecodeFails(root))
        root = pristine

        nodes = try #require(root["nodes"] as? [[String: Any]])
        var contract = try #require(nodes[0]["contract"] as? [String: Any])
        contract["unknown"] = true
        nodes[0]["contract"] = contract
        root["nodes"] = nodes
        #expect(candidateDecodeFails(root))
        root = pristine

        nodes = try #require(root["nodes"] as? [[String: Any]])
        contract = try #require(nodes[0]["contract"] as? [String: Any])
        var rules = try #require(contract["tool_rules"] as? [[String: Any]])
        rules[0]["arguments"] = ["*"]
        contract["tool_rules"] = rules
        nodes[0]["contract"] = contract
        root["nodes"] = nodes
        #expect(candidateDecodeFails(root))
    }

    @Test("frozen bundle and policy decode through core with exact bytes")
    func artifactParity() throws {
        let bundleBytes = try Data(
            contentsOf: executionGraphBaselineFixture("artifact-bundle.json")
        )
        let bundle = try JSONDecoder().decode(
            ExecutionArtifactBundle.self,
            from: bundleBytes
        )
        #expect(bundle.schema == ExecutionArtifactBundle.currentSchema)
        #expect(
            bundle.executableHash
                == "15b112193913f69c58e7427d434176a31b4c803bf7167833843765463c2a3656"
        )
        #expect(try ExecutionGraphCanonicalizer.data(bundle) == bundleBytes)

        let policyBytes = try Data(
            contentsOf: executionGraphBaselineFixture("effective-policy.json")
        )
        let policy = try JSONDecoder().decode(
            EffectiveExecutionPolicy.self,
            from: policyBytes
        )
        #expect(policy.logicalWorkspaceRoot == "/workspace/project")
        #expect(try ExecutionGraphCanonicalizer.data(policy) == policyBytes)
    }

    @Test("violation has a stable persisted ID and localized detail")
    func violationContract() throws {
        let violation = ExecutionGraphViolation(
            id: "graph.example",
            detail: "bounded refusal"
        )
        #expect(violation.errorDescription
            == "graph.example: bounded refusal")
        let bytes = try ExecutionGraphCanonicalizer.data(violation)
        #expect(
            try JSONDecoder().decode(
                ExecutionGraphViolation.self,
                from: bytes
            ) == violation
        )
    }

    private func candidateDecodeFails(_ object: [String: Any]) -> Bool {
        do {
            _ = try JSONDecoder().decode(
                CandidateExecutionGraph.self,
                from: JSONSerialization.data(withJSONObject: object)
            )
            return false
        } catch {
            return true
        }
    }
}
