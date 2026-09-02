import Foundation
import Testing
import MentuExecutionGraphCore

@Suite("Execution graph admission and activation evidence")
struct AdmissionTests {
    @Test("hash-valid incomplete check inventory refuses admission")
    func incompleteQualificationInventoryRefusal() async throws {
        let current = try await QualificationTestSupport.qualified()
        let legacy = try legacyQualifiedExecution(from: current)
        let runtime = try QualificationTestSupport.runtime(
            qualified: legacy
        )
        do {
            _ = try await ExecutionGraphAdmission.admit(
                qualified: legacy,
                runtime: runtime,
                trustedProfile: QualificationTestSupport.trustedProfile,
                clock: FixedExecutionGraphClock(
                    QualificationTestSupport.instant
                )
            )
            Issue.record("incomplete qualification inventory was admitted")
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == "qualification.check-inventory")
        }
        let currentChecks = try ExecutionGraphQualification
            .authoritySubsetChecks(
                bundle: legacy.bundle,
                envelope: legacy.envelope,
                effectivePolicy: legacy.effectivePolicy
            )
        #expect(
            legacy.qualification.envelopeChecks.count
                < currentChecks.count
        )
    }

    @Test("legacy inventory is refused before authority drift evaluation")
    func legacyInventoryAuthorityDrift() async throws {
        let current = try await QualificationTestSupport.qualified()
        let drifted = try legacyQualifiedExecution(
            from: current,
            envelope: QualificationTestSupport.envelope(
                hostBackends: []
            )
        )
        do {
            _ = try await ExecutionGraphAdmission.admit(
                qualified: drifted,
                runtime: try QualificationTestSupport.runtime(
                    qualified: drifted
                ),
                trustedProfile: QualificationTestSupport.trustedProfile,
                clock: FixedExecutionGraphClock(
                    QualificationTestSupport.instant
                )
            )
            Issue.record("current authority drift was hidden by legacy checks")
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == "qualification.check-inventory")
        }
    }

    @Test("tampered legacy qualification hash refuses admission")
    func tamperedLegacyQualificationHash() async throws {
        let current = try await QualificationTestSupport.qualified()
        let legacy = try legacyQualifiedExecution(
            from: current,
            reportHash: String(repeating: "0", count: 64)
        )
        do {
            _ = try await ExecutionGraphAdmission.admit(
                qualified: legacy,
                runtime: try QualificationTestSupport.runtime(
                    qualified: legacy
                ),
                trustedProfile: QualificationTestSupport.trustedProfile,
                clock: FixedExecutionGraphClock(
                    QualificationTestSupport.instant
                )
            )
            Issue.record("tampered legacy report hash was admitted")
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == "qualification.report-hash")
        }
    }

    @Test("admission binds exact qualified and runtime identities")
    func admissionReceipt() async throws {
        let qualified = try await QualificationTestSupport.qualified()
        let runtime = try QualificationTestSupport.runtime(
            qualified: qualified
        )
        let admitted = try await ExecutionGraphAdmission.admit(
            qualified: qualified,
            runtime: runtime,
            trustedProfile: QualificationTestSupport.trustedProfile,
            clock: FixedExecutionGraphClock(
                QualificationTestSupport.instant
            )
        )

        #expect(
            admitted.receipt.executableHash
                == qualified.bundle.executableHash
        )
        #expect(
            admitted.receipt.qualificationReportHash
                == qualified.qualification.reportHash
        )
        #expect(admitted.receipt.runtimeContext == runtime)
        #expect(
            try ExecutionGraphAdmission.receiptHash(
                admitted.receipt
            ) == admitted.receipt.receiptHash
        )
        try await ExecutionGraphAdmission.validateReceipt(
            admitted.receipt,
            qualified: qualified,
            runtime: runtime,
            trustedProfile: QualificationTestSupport.trustedProfile,
            at: QualificationTestSupport.instant
        )
    }

    @Test("captured state drift refuses admission before execution")
    func admissionDrift() async throws {
        let qualified = try await QualificationTestSupport.qualified()
        let drifted = try QualificationTestSupport.runtime(
            qualified: qualified,
            runtimeStateDigest:
                ExecutionGraphDigest.sha256("changed-state")
        )
        do {
            _ = try await ExecutionGraphAdmission.admit(
                qualified: qualified,
                runtime: drifted,
                trustedProfile: QualificationTestSupport.trustedProfile,
                clock: FixedExecutionGraphClock(
                    QualificationTestSupport.instant
                )
            )
            Issue.record("runtime state drift was admitted")
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == "admission.state-drift")
        }
    }

    @Test("receipt hash validation detects mutation")
    func receiptHashDrift() async throws {
        let qualified = try await QualificationTestSupport.qualified()
        let runtime = try QualificationTestSupport.runtime(
            qualified: qualified
        )
        let admitted = try await ExecutionGraphAdmission.admit(
            qualified: qualified,
            runtime: runtime,
            trustedProfile: QualificationTestSupport.trustedProfile,
            clock: FixedExecutionGraphClock(
                QualificationTestSupport.instant
            )
        )
        let encoded = try JSONEncoder().encode(admitted.receipt)
        var object = try #require(
            JSONSerialization.jsonObject(with: encoded)
                as? [String: Any]
        )
        object["receiptHash"] = String(repeating: "0", count: 64)
        let tampered = try JSONDecoder().decode(
            AdmissionReceipt.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        do {
            try await ExecutionGraphAdmission.validateReceipt(
                tampered,
                qualified: qualified,
                runtime: runtime,
                trustedProfile: QualificationTestSupport.trustedProfile,
                at: QualificationTestSupport.instant
            )
            Issue.record("tampered receipt was accepted")
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == "receipt.hash")
        }
    }

    @Test("activation and outcome builders produce verifiable chains")
    func activationOutcomeChain() async throws {
        let admitted = try await QualificationTestSupport.admitted()
        let firstInstant = QualificationTestSupport.instant
            .addingTimeInterval(1)
        let first = try StepActivationChain.makeActivation(
            admitted: admitted,
            parameters: activationParameters(
                admitted: admitted,
                sequence: 1,
                previous: nil
            ),
            clock: FixedExecutionGraphClock(firstInstant)
        )
        #expect(first.sequence == 1)
        #expect(
            first.inputLanes.first?.contentHash
                == ExecutionGraphDigest.sha256(
                    "preserve the exact boundary"
                )
        )
        #expect(
            first.callLane.coveragePolicyHash
                == StepActivationChain.coveragePolicyHash
        )

        let second = try StepActivationChain.makeActivation(
            admitted: admitted,
            parameters: activationParameters(
                admitted: admitted,
                sequence: 2,
                previous: first.activationHash
            ),
            clock: FixedExecutionGraphClock(
                firstInstant.addingTimeInterval(1)
            )
        )
        try StepActivationChain.validateActivationChain(
            [first, second],
            receipt: admitted.receipt
        )

        let firstOutcome = try StepActivationChain.makeOutcome(
            activation: first,
            parameters: StepActivationOutcomeParameters(
                sequence: 1,
                terminationReason: "completion_promise",
                costMicrosUSD: 10,
                turns: 1,
                inputTokens: 20,
                outputTokens: 5,
                outputHash: ExecutionGraphDigest.sha256("output-1"),
                elapsedNanoseconds: 500,
                softDeadlineExceeded: false,
                callRecordRoot:
                    ExecutionGraphDigest.sha256("call-record-1"),
                coverage: "host_boundary_exact",
                previousOutcomeHash: nil
            ),
            clock: FixedExecutionGraphClock(
                firstInstant.addingTimeInterval(2)
            )
        )
        let secondOutcome = try StepActivationChain.makeOutcome(
            activation: second,
            parameters: StepActivationOutcomeParameters(
                sequence: 2,
                terminationReason: "completion_promise",
                costMicrosUSD: 12,
                turns: 1,
                inputTokens: 22,
                outputTokens: 6,
                outputHash: ExecutionGraphDigest.sha256("output-2"),
                elapsedNanoseconds: 600,
                softDeadlineExceeded: false,
                callRecordRoot:
                    ExecutionGraphDigest.sha256("call-record-2"),
                coverage: "host_boundary_exact",
                previousOutcomeHash: firstOutcome.outcomeHash
            ),
            clock: FixedExecutionGraphClock(
                firstInstant.addingTimeInterval(3)
            )
        )
        try StepActivationChain.validateOutcomeChain(
            [firstOutcome, secondOutcome],
            activations: [first, second]
        )

        do {
            try StepActivationChain.validateOutcomeChain(
                [firstOutcome],
                activations: [first, second]
            )
            Issue.record("activation without an outcome was accepted")
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == "activation.outcome-missing")
        }
        do {
            try StepActivationChain.validateActivationChain(
                [first, first],
                receipt: admitted.receipt
            )
            Issue.record("duplicate activation ID was accepted")
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == "activation.duplicate")
        }
        do {
            try StepActivationChain.validateOutcomeChain(
                [firstOutcome, firstOutcome],
                activations: [first, second]
            )
            Issue.record("duplicate activation outcome was accepted")
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == "activation.outcome-duplicate")
        }
        do {
            try StepActivationChain.validateOutcomeChain(
                [firstOutcome],
                activations: [first, first]
            )
            Issue.record("ambiguous activation lookup was accepted")
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == "activation.duplicate")
        }
    }

    @Test("unsupported input lane refuses before evidence append")
    func unsupportedInputLane() async throws {
        let admitted = try await QualificationTestSupport.admitted()
        let sink = InMemoryStepActivationSink()
        let parameters = activationParameters(
            admitted: admitted,
            sequence: 1,
            previous: nil,
            lane: "unsupported-lane"
        )
        do {
            _ = try StepActivationChain.makeActivation(
                admitted: admitted,
                parameters: parameters,
                clock: FixedExecutionGraphClock(
                    QualificationTestSupport.instant
                )
            )
            Issue.record("unsupported input lane was sealed")
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == "activation.input-lane")
        }
        let activations = await sink.activations()
        let outcomes = await sink.outcomes()
        #expect(activations.isEmpty)
        #expect(outcomes.isEmpty)
    }

    @Test("rehashed outcomes cannot bypass accounting invariants")
    func rehashedOutcomeAccountingRefusal() throws {
        let activation = try JSONDecoder().decode(
            StepActivationRecord.self,
            from: QualificationTestSupport.fixtureData("activation.json")
        )
        let outcome = try JSONDecoder().decode(
            StepActivationOutcomeRecord.self,
            from: QualificationTestSupport.fixtureData(
                "activation-outcome.json"
            )
        )
        let invalidValues: [(String, Any)] = [
            ("sequence", 0),
            ("terminationReason", ""),
            ("costMicrosUSD", -1),
            ("turns", -1),
            ("inputTokens", -1),
            ("outputTokens", -1),
        ]

        for (field, value) in invalidValues {
            let changed = try rehashedOutcome(
                outcome,
                field: field,
                value: value
            )
            do {
                try StepActivationChain.validateOutcome(
                    changed,
                    activation: activation
                )
                Issue.record("rehashed invalid \(field) was accepted")
            } catch let violation as ExecutionGraphViolation {
                #expect(violation.id == "activation.outcome-values")
            }
        }
    }

    @Test("activation auth must remain inside the frozen receipt chain")
    func activationAuthChainRefusal() async throws {
        let qualified = try await QualificationTestSupport.qualified(
            envelope: QualificationTestSupport.envelope(
                hostAuthProfiles: ["auth-primary", "auth-extra"]
            )
        )
        let admitted = try await ExecutionGraphAdmission.admit(
            qualified: qualified,
            runtime: QualificationTestSupport.runtime(
                qualified: qualified
            ),
            trustedProfile: QualificationTestSupport.trustedProfile,
            clock: FixedExecutionGraphClock(
                QualificationTestSupport.instant
            )
        )
        do {
            _ = try StepActivationChain.makeActivation(
                admitted: admitted,
                parameters: activationParameters(
                    admitted: admitted,
                    sequence: 1,
                    previous: nil,
                    authProfile: "auth-extra"
                ),
                clock: FixedExecutionGraphClock(
                    QualificationTestSupport.instant
                )
            )
            Issue.record("envelope-only auth profile was activated")
        } catch let violation as ExecutionGraphViolation {
            #expect(violation.id == "activation.effective-config")
        }
    }

    @Test("maximum sequence single-element chains validate without overflow")
    func maximumSequenceChain() async throws {
        let admitted = try await QualificationTestSupport.admitted()
        let activation = try StepActivationChain.makeActivation(
            admitted: admitted,
            parameters: activationParameters(
                admitted: admitted,
                sequence: .max,
                previous: nil
            ),
            clock: FixedExecutionGraphClock(
                QualificationTestSupport.instant
            )
        )
        try StepActivationChain.validateActivationChain(
            [activation],
            initialSequence: .max,
            receipt: admitted.receipt
        )
        let outcome = try StepActivationChain.makeOutcome(
            activation: activation,
            parameters: StepActivationOutcomeParameters(
                sequence: .max,
                terminationReason: "completion_promise",
                costMicrosUSD: 0,
                turns: 1,
                inputTokens: 0,
                outputTokens: 0,
                outputHash: ExecutionGraphDigest.sha256("max-output"),
                elapsedNanoseconds: 0,
                softDeadlineExceeded: false,
                callRecordRoot:
                    ExecutionGraphDigest.sha256("max-call-record"),
                coverage: "host_boundary_exact",
                previousOutcomeHash: nil
            ),
            clock: FixedExecutionGraphClock(
                QualificationTestSupport.instant
            )
        )
        try StepActivationChain.validateOutcomeChain(
            [outcome],
            activations: [activation],
            initialSequence: .max
        )
    }

    @Test("frozen receipt and activation chains preserve v1 hashes")
    func frozenEvidenceHashes() throws {
        let receiptBytes = try QualificationTestSupport.fixtureData(
            "admission-receipt.json"
        )
        let activationBytes = try QualificationTestSupport.fixtureData(
            "activation.json"
        )
        let outcomeBytes = try QualificationTestSupport.fixtureData(
            "activation-outcome.json"
        )
        let receipt = try JSONDecoder().decode(
            AdmissionReceipt.self,
            from: receiptBytes
        )
        let activation = try JSONDecoder().decode(
            StepActivationRecord.self,
            from: activationBytes
        )
        let outcome = try JSONDecoder().decode(
            StepActivationOutcomeRecord.self,
            from: outcomeBytes
        )

        #expect(
            try ExecutionGraphCanonicalizer.data(receipt)
                == receiptBytes
        )
        #expect(
            try ExecutionGraphCanonicalizer.data(activation)
                == activationBytes
        )
        #expect(
            try ExecutionGraphCanonicalizer.data(outcome)
                == outcomeBytes
        )
        #expect(
            try ExecutionGraphAdmission.receiptHash(receipt)
                == receipt.receiptHash
        )
        try StepActivationChain.validateActivationChain(
            [activation],
            receipt: receipt
        )
        try StepActivationChain.validateOutcomeChain(
            [outcome],
            activations: [activation]
        )
    }

    private func activationParameters(
        admitted: AdmittedExecution,
        sequence: Int,
        previous: String?,
        lane: String = "steering",
        authProfile: String? = nil
    ) -> StepActivationParameters {
        StepActivationParameters(
            sequence: sequence,
            stepStart: QualificationTestSupport.stepStart(
                admitted: admitted,
                lane: lane
            ),
            hostCallAttempt: 1,
            nodeHash: ExecutionGraphDigest.sha256("node-\(sequence)"),
            rawPromptHash:
                ExecutionGraphDigest.sha256("raw-\(sequence)"),
            resolvedPromptHash:
                ExecutionGraphDigest.sha256("resolved-\(sequence)"),
            phaseDerivationPolicyHash:
                ExecutionGraphDigest.sha256("phase-policy"),
            backend: admitted.effectivePolicy.fixedBackend,
            model: admitted.effectivePolicy.fixedModel,
            authProfile: authProfile
                ?? admitted.effectivePolicy.initialAuthProfile,
            endpointConfigDigest:
                admitted.effectivePolicy.endpointConfigDigest,
            effectiveConfigurationHash:
                ExecutionGraphDigest.sha256("configuration"),
            stepSoftDeadlineSeconds:
                admitted.effectivePolicy.stepSoftDeadlineSeconds,
            runSoftDeadlineSeconds:
                admitted.effectivePolicy.runSoftDeadlineSeconds,
            monotonicStartNanoseconds: UInt64(sequence),
            boundaryKillPolicyDigest:
                ExecutionGraphDigest.sha256("boundary-only.v1"),
            upstreamOutputHashes: [],
            previousActivationHash: previous
        )
    }

    private func rehashedOutcome(
        _ outcome: StepActivationOutcomeRecord,
        field: String,
        value: Any
    ) throws -> StepActivationOutcomeRecord {
        var object = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(outcome)
            ) as? [String: Any]
        )
        object[field] = value
        var payload = object
        payload.removeValue(forKey: "outcomeHash")
        let payloadBytes = try JSONSerialization.data(
            withJSONObject: payload
        )
        object["outcomeHash"] = ExecutionGraphDigest.sha256(
            try ExecutionGraphCanonicalizer.canonicalize(payloadBytes)
        )
        return try JSONDecoder().decode(
            StepActivationOutcomeRecord.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
    }

    private func legacyQualifiedExecution(
        from current: QualifiedExecution,
        envelope: ExecutionAuthorityEnvelope? = nil,
        reportHash: String? = nil
    ) throws -> QualifiedExecution {
        let envelope = envelope ?? current.envelope
        let storedChecks = Array(
            current.qualification.envelopeChecks.prefix(2)
        )
        let payload = QualificationReportHashPayload(
            linterChecks: current.qualification.linterChecks,
            envelopeChecks: storedChecks,
            resolvedFootprints:
                current.qualification.resolvedFootprints,
            qualificationStateDigest:
                current.qualification.qualificationStateDigest,
            bundleHash: current.qualification.bundleHash,
            envelopeHash:
                try ExecutionGraphCanonicalizer.hash(envelope),
            dependencyReportHash:
                current.qualification.dependencyReportHash
        )
        let effectiveReportHash: String
        if let reportHash {
            effectiveReportHash = reportHash
        } else {
            effectiveReportHash =
                try ExecutionGraphCanonicalizer.hash(payload)
        }
        let report = QualificationReport(
            linterChecks: payload.linterChecks,
            envelopeChecks: payload.envelopeChecks,
            resolvedFootprints: payload.resolvedFootprints,
            qualificationStateDigest:
                payload.qualificationStateDigest,
            bundleHash: payload.bundleHash,
            envelopeHash: payload.envelopeHash,
            dependencyReportHash: payload.dependencyReportHash,
            reportHash: effectiveReportHash
        )
        return QualifiedExecution(
            bundle: current.bundle,
            envelope: envelope,
            effectivePolicy: current.effectivePolicy,
            qualification: report
        )
    }

    private struct QualificationReportHashPayload: Encodable {
        let schema = QualificationReport.currentSchema
        let linterChecks: [QualificationCheck]
        let envelopeChecks: [QualificationCheck]
        let resolvedFootprints: [String]
        let qualificationStateDigest: String
        let bundleHash: String
        let envelopeHash: String
        let dependencyReportHash: String
    }
}
