import Foundation
import Testing
import MentuExecutionGraphCore

@Suite("Execution graph qualification")
struct QualificationTests {
    @Test("qualification is deterministic and preserves profile check order")
    func deterministicQualification() async throws {
        let profile = QualificationPassingProfile(
            checks: [
                QualificationCheck(
                    id: "linter.z-last",
                    passed: true,
                    detail: "last"
                ),
                QualificationCheck(
                    id: "linter.a-first",
                    passed: true,
                    detail: "first"
                ),
            ]
        )
        let first = try await QualificationTestSupport.qualified(
            profile: profile
        )
        let second = try await QualificationTestSupport.qualified(
            profile: profile
        )

        #expect(first == second)
        #expect(
            first.qualification.linterChecks.map(\.id)
                == ["linter.z-last", "linter.a-first"]
        )
        #expect(
            first.qualification.envelopeChecks.map(\.id)
                == first.qualification.envelopeChecks.map(\.id).sorted()
        )
        try ExecutionGraphQualification.validateReport(
            first.qualification,
            trustedProfile: profile.descriptor
        )
    }

    @Test("qualification requires persisted profile and envelope evidence")
    func strippedEvidenceRefusal() async throws {
        do {
            _ = try await QualificationTestSupport.qualified(
                profile: QualificationPassingProfile(checks: [])
            )
            Issue.record("qualification accepted an empty profile verdict")
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == "qualification.check")
        }

        let qualified = try await QualificationTestSupport.qualified()
        let withoutProfile = try rehashedQualifiedExecution(
            qualified,
            removing: "linterChecks"
        )
        do {
            try await ExecutionGraphQualification.validateQualifiedExecution(
                withoutProfile,
                trustedProfile: QualificationTestSupport.trustedProfile,
                at: QualificationTestSupport.instant
            )
            Issue.record("rehashed qualification omitted profile evidence")
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == "qualification.check")
        }

        let withoutEnvelope = try rehashedQualifiedExecution(
            qualified,
            removing: "envelopeChecks"
        )
        do {
            try await ExecutionGraphQualification.validateQualifiedExecution(
                withoutEnvelope,
                trustedProfile: QualificationTestSupport.trustedProfile,
                at: QualificationTestSupport.instant
            )
            Issue.record("rehashed qualification omitted envelope evidence")
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == "qualification.identity-drift")
        }
    }

    @Test("admission refuses partial profile evidence after both hashes are recomputed")
    func partialProfileInventoryRefusal() async throws {
        let profile = QualificationPassingProfile(
            checks: [
                QualificationCheck(
                    id: "linter.first",
                    passed: true,
                    detail: "first expected check"
                ),
                QualificationCheck(
                    id: "linter.second",
                    passed: true,
                    detail: "second expected check"
                ),
            ]
        )
        let qualified = try await QualificationTestSupport.qualified(
            profile: profile
        )
        let remainingChecks = Array(
            qualified.qualification.linterChecks.prefix(1)
        )
        let forgedDescriptor =
            ExecutionGraphQualificationProfileDescriptor(
                profileID: profile.descriptor.profileID,
                expectedCheckIDs: remainingChecks.map(\.id)
            )
        let partial = try rehashedQualifiedExecution(
            qualified,
            linterChecks: remainingChecks,
            forgedProfileDescriptor: forgedDescriptor
        )
        #expect(
            partial.qualification.profileCheckInventoryHash
                != qualified.qualification.profileCheckInventoryHash
        )
        #expect(
            partial.qualification.reportHash
                != qualified.qualification.reportHash
        )

        do {
            _ = try await ExecutionGraphAdmission.admit(
                qualified: partial,
                runtime: try QualificationTestSupport.runtime(
                    qualified: partial
                ),
                trustedProfile: profile,
                clock: FixedExecutionGraphClock(
                    QualificationTestSupport.instant
                )
            )
            Issue.record(
                "admission accepted partial evidence after both hashes changed"
            )
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == "qualification.check-inventory")
        }

        do {
            try ExecutionGraphQualification.validateReport(
                qualified.qualification,
                trustedProfile:
                    ExecutionGraphQualificationProfileDescriptor(
                        profileID: "attacker.relabelled-profile.v1",
                        expectedCheckIDs:
                            profile.descriptor.expectedCheckIDs
                    )
            )
            Issue.record(
                "validation accepted a relabelled trusted profile identity"
            )
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == "qualification.check-inventory")
        }
    }

    @Test("admission replays trusted outcomes after every report hash is recomputed")
    func forgedProfileOutcomeRefusal() async throws {
        let profile = QualificationPassingProfile(
            checks: [
                QualificationCheck(
                    id: "linter.first",
                    passed: true,
                    detail: "first trusted outcome"
                ),
                QualificationCheck(
                    id: "linter.second",
                    passed: true,
                    detail: "second trusted outcome"
                ),
            ]
        )
        let qualified = try await QualificationTestSupport.qualified(
            profile: profile
        )
        let forged = try rehashedQualifiedExecution(
            qualified,
            linterChecks: qualified.qualification.linterChecks.map {
                QualificationCheck(
                    id: $0.id,
                    passed: false,
                    detail: "attacker-controlled non-enforcing failure",
                    enforcing: false
                )
            },
            forgedProfileDescriptor: profile.descriptor
        )

        // The stored report is internally self-consistent. Only replaying the
        // independently trusted profile can distinguish it from authority.
        try ExecutionGraphQualification.validateReport(
            forged.qualification,
            trustedProfile: profile.descriptor
        )
        do {
            _ = try await ExecutionGraphAdmission.admit(
                qualified: forged,
                runtime: try QualificationTestSupport.runtime(
                    qualified: forged
                ),
                trustedProfile: profile,
                clock: FixedExecutionGraphClock(
                    QualificationTestSupport.instant
                )
            )
            Issue.record(
                "admission accepted rehashed attacker-controlled outcomes"
            )
        } catch let violation as ExecutionGraphViolation {
            #expect(
                violation.id == "qualification.profile-outcome-drift"
            )
        }
    }

    @Test("qualification refuses a profile that omits a declared check")
    func qualificationProfileInventoryMismatch() async throws {
        do {
            _ = try await QualificationTestSupport.qualified(
                profile: QualificationPassingProfile(
                    checks: [
                        QualificationCheck(
                            id: "linter.first",
                            passed: true,
                            detail: "first expected check"
                        ),
                    ],
                    declaredCheckIDs: [
                        "linter.first",
                        "linter.second",
                    ]
                )
            )
            Issue.record("incomplete profile evidence was accepted")
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == "qualification.check-inventory")
        }
    }

    @Test("expiry is decided by the injected clock")
    func injectedExpiry() async throws {
        let expired = QualificationTestSupport.envelope(
            expiry: "2025-12-31T23:59:59.000Z"
        )
        do {
            _ = try await QualificationTestSupport.qualified(
                envelope: expired
            )
            Issue.record("expired authority was qualified")
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == "envelope.expired")
        }

        let future = QualificationTestSupport.envelope(
            expiry: "2026-01-01T00:00:01.000Z"
        )
        _ = try await QualificationTestSupport.qualified(
            envelope: future
        )
    }

    @Test("authority excess is a stable typed refusal")
    func authoritySubsetRefusal() async throws {
        do {
            _ = try await QualificationTestSupport.qualified(
                envelope: QualificationTestSupport.envelope(
                    hostBackends: []
                )
            )
            Issue.record("backend outside the envelope was accepted")
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == "envelope.backend")
        }
    }

    @Test("impossible auth fallback chains are refused before admission")
    func authFallbackChainRefusal() async throws {
        let invalidChains: [[AuthFallbackBinding]] = [
            [],
            [
                AuthFallbackBinding(
                    profileId: "auth-secondary",
                    configDigest:
                        ExecutionGraphDigest.sha256("auth-secondary")
                ),
            ],
            [
                AuthFallbackBinding(
                    profileId: "auth-primary",
                    configDigest:
                        ExecutionGraphDigest.sha256("auth-primary")
                ),
                AuthFallbackBinding(
                    profileId: "auth-primary",
                    configDigest:
                        ExecutionGraphDigest.sha256("auth-primary-copy")
                ),
            ],
            [
                AuthFallbackBinding(
                    profileId: "auth-primary",
                    configDigest: ""
                ),
            ],
            [
                AuthFallbackBinding(
                    profileId: "auth-primary",
                    configDigest:
                        ExecutionGraphDigest.sha256("auth-primary")
                ),
                AuthFallbackBinding(
                    profileId: " ",
                    configDigest:
                        ExecutionGraphDigest.sha256("blank-profile")
                ),
            ],
        ]
        for chain in invalidChains {
            do {
                _ = try await QualificationTestSupport.qualified(
                    envelope: QualificationTestSupport.envelope(
                        hostAuthProfiles: [
                            "auth-primary", "auth-secondary", " ",
                        ]
                    ),
                    policy: QualificationTestSupport.policy(
                        authFallbackChain: chain
                    )
                )
                Issue.record("impossible auth fallback chain was qualified")
            } catch let violation as ExecutionGraphViolation {
                #expect(violation.id == "envelope.auth")
            }
        }
    }

    @Test("non-positive policy parallelism is a stable typed refusal")
    func policyParallelismRefusal() async throws {
        for parallelism in [0, -1] {
            do {
                _ = try await QualificationTestSupport.qualified(
                    policy: QualificationTestSupport.policy(
                        maximumParallelSteps: parallelism
                    )
                )
                Issue.record(
                    "policy parallelism \(parallelism) was accepted"
                )
            } catch let violation as ExecutionGraphViolation {
                #expect(violation.id == "envelope.graph-limits")
                #expect(
                    violation.detail
                        == "graph size, depth, or parallelism exceeds the envelope"
                )
            }
        }
    }

    @Test("host-captured sandbox unavailability preserves the envelope reason")
    func sandboxAvailabilityRefusal() async throws {
        do {
            _ = try await QualificationTestSupport.qualified(
                requiredSandboxesAvailable: false
            )
            Issue.record("unavailable required sandbox was qualified")
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == "envelope.sandbox")
            #expect(
                violation.detail
                    == "required sandbox is unavailable or outside the envelope"
            )
        }
    }

    @Test("profile refusal remains typed and enforcing")
    func profileRefusal() async throws {
        let profile = QualificationPassingProfile(
            checks: [
                QualificationCheck(
                    id: "linter.sandbox-available",
                    passed: false,
                    detail: "required sandbox unavailable"
                ),
            ]
        )
        do {
            _ = try await QualificationTestSupport.qualified(
                profile: profile
            )
            Issue.record("enforcing profile failure was accepted")
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == "linter.sandbox-available")
        }
    }

    @Test("admitted definition rejects dependency defects")
    func definitionDependencyValidation() throws {
        let bundle = try QualificationTestSupport.bundle()
        let encoded = try JSONEncoder().encode(bundle.definition)
        let object = try #require(
            JSONSerialization.jsonObject(with: encoded)
                as? [String: Any]
        )
        var changed = object
        var steps = try #require(changed["steps"] as? [[String: Any]])
        steps[0]["depends_on"] = ["inspect"]
        changed["steps"] = steps
        let invalid = try JSONDecoder().decode(
            ExecutionGraphDefinition.self,
            from: JSONSerialization.data(withJSONObject: changed)
        )

        do {
            try ExecutionGraphQualification.validateDefinition(invalid)
            Issue.record("self dependency was accepted")
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == "graph.definition.self-dependency")
        }
    }

    @Test("authority subset rejects a cyclic public artifact with a typed violation")
    func authoritySubsetCycleValidation() throws {
        let encoded = try JSONEncoder().encode(
            QualificationTestSupport.bundle()
        )
        var object = try #require(
            JSONSerialization.jsonObject(with: encoded)
                as? [String: Any]
        )
        var definition = try #require(
            object["definition"] as? [String: Any]
        )
        var steps = try #require(
            definition["steps"] as? [[String: Any]]
        )
        steps[0]["depends_on"] = ["verify"]
        var verify = steps[0]
        verify["label"] = "verify"
        verify["depends_on"] = ["inspect"]
        steps.append(verify)
        definition["steps"] = steps
        object["definition"] = definition
        let cyclic = try JSONDecoder().decode(
            ExecutionArtifactBundle.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        do {
            _ = try ExecutionGraphQualification.authoritySubsetChecks(
                bundle: cyclic,
                envelope: QualificationTestSupport.envelope(),
                effectivePolicy: QualificationTestSupport.policy()
            )
            Issue.record("cyclic artifact reached authority calculations")
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == GraphSchedulerReasonID.cycle)
        }
    }

    @Test("multi-node Int64 budget overflow is a typed envelope refusal")
    func authorityBudgetOverflowRefusal() throws {
        let policy = try QualificationTestSupport.policy(
            runBudgetMicrosUSD: .max,
            perStepBudgetMicrosUSD: .max
        )
        let encoded = try JSONEncoder().encode(
            QualificationTestSupport.bundle(
                policy: policy,
                budgetsMicrosUSD: [.max, .max]
            )
        )
        let decoded = try JSONDecoder().decode(
            ExecutionArtifactBundle.self,
            from: encoded
        )

        do {
            _ = try ExecutionGraphQualification.authoritySubsetChecks(
                bundle: decoded,
                envelope: QualificationTestSupport.envelope(
                    runBudgetMicrosUSD: .max,
                    perStepBudgetMicrosUSD: .max
                ),
                effectivePolicy: policy
            )
            Issue.record("overflowing run budget was accepted")
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == "envelope.budgets")
            #expect(
                violation.detail
                    == "token, cost, or soft-deadline budget exceeds the envelope"
            )
        }
    }

    @Test("multi-node Int token overflow is a typed envelope refusal")
    func authorityTokenOverflowRefusal() throws {
        let policy = try QualificationTestSupport.policy(
            runTokenCeiling: .max,
            perStepTokenCeiling: .max
        )
        let encoded = try JSONEncoder().encode(
            QualificationTestSupport.bundle(
                policy: policy,
                budgetsMicrosUSD: [0, 0],
                tokenLimit: .max
            )
        )
        let decoded = try JSONDecoder().decode(
            ExecutionArtifactBundle.self,
            from: encoded
        )

        do {
            _ = try ExecutionGraphQualification.authoritySubsetChecks(
                bundle: decoded,
                envelope: QualificationTestSupport.envelope(
                    runTokenCeiling: .max,
                    perStepTokenCeiling: .max
                ),
                effectivePolicy: policy
            )
            Issue.record("overflowing run token total was accepted")
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == "envelope.budgets")
            #expect(
                violation.detail
                    == "token, cost, or soft-deadline budget exceeds the envelope"
            )
        }
    }

    @Test("zero step token limit is a pre-dispatch contract refusal")
    func zeroStepTokenRefusal() throws {
        do {
            _ = try ExecutionGraphQualification.authoritySubsetChecks(
                bundle: QualificationTestSupport.bundle(
                    tokenLimit: 0
                ),
                envelope: QualificationTestSupport.envelope(),
                effectivePolicy: QualificationTestSupport.policy()
            )
            Issue.record("zero step token limit was accepted")
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == "graph.lowering.invalid-contract")
            #expect(
                violation.detail
                    == "node 'inspect': token/cost budget is invalid"
            )
        }
    }

    @Test("decoded near-max budget survives lossless contract validation")
    func nearMaxBudgetValidation() async throws {
        let policy = try QualificationTestSupport.policy(
            runBudgetMicrosUSD: .max,
            perStepBudgetMicrosUSD: .max
        )
        let encoded = try JSONEncoder().encode(
            QualificationTestSupport.bundle(
                policy: policy,
                budgetsMicrosUSD: [.max]
            )
        )
        let decoded = try JSONDecoder().decode(
            ExecutionArtifactBundle.self,
            from: encoded
        )

        let qualified = try await ExecutionGraphQualification.qualify(
            definition: decoded.definition,
            bundle: decoded,
            envelope: QualificationTestSupport.envelope(
                runBudgetMicrosUSD: .max,
                perStepBudgetMicrosUSD: .max
            ),
            effectivePolicy: policy,
            capturedFacts: QualificationCapturedFacts(
                qualificationStateDigest:
                    ExecutionGraphDigest.sha256("clean-state"),
                dependencyReportHash:
                    ExecutionGraphDigest.sha256("dependencies")
            ),
            profile: QualificationPassingProfile(),
            clock: FixedExecutionGraphClock(
                QualificationTestSupport.instant
            )
        )

        #expect(qualified.bundle.contracts[0].budgetMicrosUSD == .max)
    }

    @Test("persistent near-max cost drift is a typed builder refusal")
    func nearMaxCostDriftRefusal() async throws {
        let policy = try QualificationTestSupport.policy()
        let original = try QualificationTestSupport.bundle(policy: policy)
        var definitionObject = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(original.definition)
            ) as? [String: Any]
        )
        var steps = try #require(
            definitionObject["steps"] as? [[String: Any]]
        )
        var limits = try #require(
            steps[0]["limits"] as? [String: Any]
        )
        limits["max_cost_usd"] = Double(Int64.max) / 1_000_000.0
        steps[0]["limits"] = limits
        definitionObject["steps"] = steps
        let changedDefinition = try JSONDecoder().decode(
            ExecutionGraphDefinition.self,
            from: JSONSerialization.data(withJSONObject: definitionObject)
        )
        do {
            _ = try ExecutionGraphLowerer.buildBundle(
                definition: changedDefinition,
                prompts: original.prompts,
                effectiveStaticVariables:
                    original.effectiveStaticVariables,
                contracts: original.contracts,
                discovery: original.discovery,
                source: original.source,
                planningConstraintsHash:
                    original.planningConstraintsHash,
                executionPolicy: policy
            )
            Issue.record("drifted near-max cost was accepted")
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == "graph.lowering.invalid-contract")
            #expect(
                violation.detail
                    == "node 'inspect': definition step and persistent contract differ"
            )
        }
    }

    @Test("authority envelope preserves v1 bytes and rejects unknown keys")
    func authorityCompatibilityAndStrictness() throws {
        let bytes = try QualificationTestSupport.fixtureData(
            "authority-envelope.json"
        )
        let envelope = try JSONDecoder().decode(
            ExecutionAuthorityEnvelope.self,
            from: bytes
        )
        #expect(
            try ExecutionGraphCanonicalizer.data(envelope) == bytes
        )

        var object = try #require(
            JSONSerialization.jsonObject(with: bytes)
                as? [String: Any]
        )
        object["ambient_authority"] = true
        let unknown = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: ExecutionGraphViolation.self) {
            try JSONDecoder().decode(
                ExecutionAuthorityEnvelope.self,
                from: unknown
            )
        }
    }

    @Test("qualification report hash detects drift")
    func qualificationReportHashDrift() async throws {
        let qualified = try await QualificationTestSupport.qualified()
        let report = qualified.qualification
        let tampered = QualificationReport(
            schema: report.schema,
            linterChecks: report.linterChecks,
            envelopeChecks: report.envelopeChecks,
            resolvedFootprints: report.resolvedFootprints,
            qualificationStateDigest:
                report.qualificationStateDigest,
            bundleHash: report.bundleHash,
            envelopeHash: report.envelopeHash,
            dependencyReportHash: report.dependencyReportHash,
            profileCheckInventoryHash:
                report.profileCheckInventoryHash,
            reportHash: String(repeating: "0", count: 64)
        )

        do {
            try ExecutionGraphQualification.validateReport(
                tampered,
                trustedProfile: QualificationTestSupport.trustedDescriptor
            )
            Issue.record("tampered report hash was accepted")
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == "qualification.report-hash")
        }
    }

    @Test("frozen legacy report preserves bytes but lacks a trusted descriptor digest")
    func frozenQualificationReport() throws {
        let bytes = try QualificationTestSupport.fixtureData(
            "qualification-report.json"
        )
        let report = try JSONDecoder().decode(
            QualificationReport.self,
            from: bytes
        )
        #expect(
            try ExecutionGraphCanonicalizer.data(report) == bytes
        )
        do {
            try ExecutionGraphQualification.validateReport(
                report,
                trustedProfile:
                    ExecutionGraphQualificationProfileDescriptor(
                        profileID: "mentu.engine.mechanical.v1",
                        expectedCheckIDs: report.linterChecks.map(\.id)
                    )
            )
            Issue.record(
                "legacy report without a descriptor digest was accepted"
            )
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == "qualification.check-inventory")
        }
    }

    private func rehashedQualifiedExecution(
        _ qualified: QualifiedExecution,
        removing checksKey: String? = nil,
        linterChecks linterOverride: [QualificationCheck]? = nil,
        forgedProfileDescriptor:
            ExecutionGraphQualificationProfileDescriptor? = nil
    ) throws -> QualifiedExecution {
        let original = qualified.qualification
        let linterChecks = linterOverride
            ?? (checksKey == "linterChecks" ? [] : original.linterChecks)
        let envelopeChecks = checksKey == "envelopeChecks"
            ? []
            : original.envelopeChecks
        let profileCheckInventoryHash = try forgedProfileDescriptor.map {
            try ExecutionGraphCanonicalizer.hash($0)
        } ?? original.profileCheckInventoryHash
        let unhashed = QualificationReport(
            schema: original.schema,
            linterChecks: linterChecks,
            envelopeChecks: envelopeChecks,
            resolvedFootprints: original.resolvedFootprints,
            qualificationStateDigest:
                original.qualificationStateDigest,
            bundleHash: original.bundleHash,
            envelopeHash: original.envelopeHash,
            dependencyReportHash: original.dependencyReportHash,
            profileCheckInventoryHash: profileCheckInventoryHash,
            reportHash: ""
        )
        var payload = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(unhashed)
            ) as? [String: Any]
        )
        payload.removeValue(forKey: "reportHash")
        let payloadBytes = try JSONSerialization.data(
            withJSONObject: payload
        )
        let reportHash = ExecutionGraphDigest.sha256(
            try ExecutionGraphCanonicalizer.canonicalize(payloadBytes)
        )
        return QualifiedExecution(
            bundle: qualified.bundle,
            envelope: qualified.envelope,
            effectivePolicy: qualified.effectivePolicy,
            qualification: QualificationReport(
                schema: original.schema,
                linterChecks: linterChecks,
                envelopeChecks: envelopeChecks,
                resolvedFootprints: original.resolvedFootprints,
                qualificationStateDigest:
                    original.qualificationStateDigest,
                bundleHash: original.bundleHash,
                envelopeHash: original.envelopeHash,
                dependencyReportHash: original.dependencyReportHash,
                profileCheckInventoryHash: profileCheckInventoryHash,
                reportHash: reportHash
            )
        )
    }
}
