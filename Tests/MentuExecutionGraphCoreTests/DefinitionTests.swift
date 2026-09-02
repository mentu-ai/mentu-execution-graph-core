import Foundation
import Testing
@testable import MentuExecutionGraphCore

/// Baseline fixtures ship with this package under
/// `Tests/MentuExecutionGraphCoreTests/Fixtures/ExecutionGraphCoreBaseline`.
/// When the package is checked out inside the Mentu monorepo, the engine's
/// copy of the same fixtures is the origin and takes precedence, so the two
/// can never drift silently.
func executionGraphBaselineFixture(_ name: String) -> URL {
    let testsDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
    let packaged = testsDirectory
        .appendingPathComponent("Fixtures/ExecutionGraphCoreBaseline/\(name)")
    let monorepo = testsDirectory
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent(
            "mentu-engine/Tests/MentuEngineTests/Fixtures/"
                + "ExecutionGraphCoreBaseline/\(name)"
        )
    return FileManager.default.fileExists(atPath: monorepo.path) ? monorepo : packaged
}

@Suite("Admitted execution definition")
struct DefinitionTests {
    @Test("frozen admitted definition decodes and re-encodes byte exactly")
    func frozenDefinitionParity() throws {
        let bytes = try Data(
            contentsOf: executionGraphBaselineFixture(
                "lowered-definition.json"
            )
        )
        let definition = try JSONDecoder().decode(
            ExecutionGraphDefinition.self,
            from: bytes
        )
        #expect(definition.name == "admitted-execution-graph")
        #expect(definition.steps.map(\.label)
            == ["recon", "implement", "final-verify"])
        #expect(definition.steps[2].verifyRequirements.grepPresentFiles
            == ["Sources/Output.swift"])
        #expect(try ExecutionGraphCanonicalizer.data(definition) == bytes)
    }

    @Test("definition, step, CIR, limits, and tool rules reject unknown keys")
    func strictDefinition() throws {
        let bytes = try Data(
            contentsOf: executionGraphBaselineFixture(
                "lowered-definition.json"
            )
        )
        var object = try #require(
            JSONSerialization.jsonObject(with: bytes) as? [String: Any]
        )

        object["host_extension"] = true
        #expect(throws: ExecutionGraphViolation.self) {
            try JSONDecoder().decode(
                ExecutionGraphDefinition.self,
                from: JSONSerialization.data(withJSONObject: object)
            )
        }
        object.removeValue(forKey: "host_extension")

        var steps = try #require(object["steps"] as? [[String: Any]])
        steps[0]["retry_backoff_ms"] = 10
        object["steps"] = steps
        #expect(throws: ExecutionGraphViolation.self) {
            try JSONDecoder().decode(
                ExecutionGraphDefinition.self,
                from: JSONSerialization.data(withJSONObject: object)
            )
        }
        steps[0].removeValue(forKey: "retry_backoff_ms")

        var cir = try #require(object["cir"] as? [String: Any])
        cir["query_limit"] = 1
        object["cir"] = cir
        object["steps"] = steps
        #expect(throws: ExecutionGraphViolation.self) {
            try JSONDecoder().decode(
                ExecutionGraphDefinition.self,
                from: JSONSerialization.data(withJSONObject: object)
            )
        }
    }

    @Test("mechanical contract preserves every admitted v1 key")
    func mechanicalContract() throws {
        let object: [String: Any] = [
            "grep_present": [["file": "a", "pattern": "b", "min": 1]],
            "grep_absent": [],
            "ordering": [],
            "file_absent": [],
            "git_clean_outside": ["Sources"],
            "json_schema": [],
            "entity_footprint": [],
            "arity_clean": true,
            "tests_cover_impact": false,
            "data_contract": [],
            "data_footprint": [],
            "observe": ["command": "true"],
            "okf_conformance": [],
        ]
        let bytes = try JSONSerialization.data(withJSONObject: object)
        let value = try JSONDecoder().decode(
            MechanicalVerificationContract.self,
            from: bytes
        )
        #expect(Set(value.values.keys)
            == MechanicalVerificationContract.allowedKeys)
        #expect(value.grepPresentFiles == ["a"])
        let roundTrip = try JSONDecoder().decode(
            MechanicalVerificationContract.self,
            from: ExecutionGraphCanonicalizer.data(value)
        )
        #expect(roundTrip == value)
    }

    @Test("semantic and unknown verification keys are refused")
    func mechanicalRefusals() throws {
        for (body, expectedID) in [
            (
                #"{"semantic_assertion":[]}"#,
                "graph.contract.semantic-verification"
            ),
            (
                #"{"future_verifier":true}"#,
                "graph.contract.unknown-verification-key"
            ),
        ] {
            do {
                try JSONDecoder().decode(
                    MechanicalVerificationContract.self,
                    from: Data(body.utf8)
                )
                Issue.record("unsupported verification key decoded")
            } catch let violation as ExecutionGraphViolation {
                #expect(violation.id == expectedID)
            }
        }
        #expect(throws: ExecutionGraphViolation.self) {
            try MechanicalVerificationContract([
                "semantic_assertion": .array([]),
            ])
        }
    }
}
