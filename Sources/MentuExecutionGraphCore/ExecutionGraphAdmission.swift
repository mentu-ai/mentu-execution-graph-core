import Foundation

public struct AdmissionRuntimeContext:
    Codable, Sendable, Equatable
{
    public let runId: String
    public let logicalWorkspaceRoot: String
    public let executionRoot: String
    public let transferMode: String
    public let acquiredLockRoots: [String]
    public let baselineDigests: [String: String]
    public let finalGitHead: String
    public let finalGitStatusDigest: String
    public let selectedReadSetHash: String
    public let dependencyReportHash: String
    public let effectiveVariablesHash: String
    public let effectiveBackend: String
    public let effectiveModel: String
    public let currentAuthProfile: String
    public let endpointConfigDigest: String
    public let permissionMode: String
    public let sandboxPolicy: String
    public let approvalPolicy: String
    public let mcpConfigurationDigest: String
    public let primitiveContractHash: String
    public let backendAdapterDigest: String
    public let engineVersion: String
    public let qualificationSourceStateDigest: String
    public let runtimeStateDigest: String
    public let admittedOuterCallEvidence: Bool
    public let gateRecordOverrideUsed: Bool

    public init(
        runId: String,
        logicalWorkspaceRoot: String,
        executionRoot: String,
        transferMode: String,
        acquiredLockRoots: [String],
        baselineDigests: [String: String],
        finalGitHead: String,
        finalGitStatusDigest: String,
        selectedReadSetHash: String,
        dependencyReportHash: String,
        effectiveVariablesHash: String,
        effectiveBackend: String,
        effectiveModel: String,
        currentAuthProfile: String,
        endpointConfigDigest: String,
        permissionMode: String,
        sandboxPolicy: String,
        approvalPolicy: String,
        mcpConfigurationDigest: String,
        primitiveContractHash: String,
        backendAdapterDigest: String,
        engineVersion: String,
        qualificationSourceStateDigest: String,
        runtimeStateDigest: String,
        admittedOuterCallEvidence: Bool,
        gateRecordOverrideUsed: Bool
    ) {
        self.runId = runId
        self.logicalWorkspaceRoot = logicalWorkspaceRoot
        self.executionRoot = executionRoot
        self.transferMode = transferMode
        self.acquiredLockRoots = acquiredLockRoots
        self.baselineDigests = baselineDigests
        self.finalGitHead = finalGitHead
        self.finalGitStatusDigest = finalGitStatusDigest
        self.selectedReadSetHash = selectedReadSetHash
        self.dependencyReportHash = dependencyReportHash
        self.effectiveVariablesHash = effectiveVariablesHash
        self.effectiveBackend = effectiveBackend
        self.effectiveModel = effectiveModel
        self.currentAuthProfile = currentAuthProfile
        self.endpointConfigDigest = endpointConfigDigest
        self.permissionMode = permissionMode
        self.sandboxPolicy = sandboxPolicy
        self.approvalPolicy = approvalPolicy
        self.mcpConfigurationDigest = mcpConfigurationDigest
        self.primitiveContractHash = primitiveContractHash
        self.backendAdapterDigest = backendAdapterDigest
        self.engineVersion = engineVersion
        self.qualificationSourceStateDigest =
            qualificationSourceStateDigest
        self.runtimeStateDigest = runtimeStateDigest
        self.admittedOuterCallEvidence = admittedOuterCallEvidence
        self.gateRecordOverrideUsed = gateRecordOverrideUsed
    }
}

public struct AdmissionReceipt: Codable, Sendable, Equatable {
    public static let currentSchema =
        "mentu.execution-admission-receipt.v1"

    public let schema: String
    public let receiptId: String
    public let runId: String
    public let sourceHash: String
    public let executableHash: String
    public let envelopeHash: String
    public let planningConstraintsHash: String
    public let qualificationReportHash: String
    public let discoverySnapshotHash: String
    public let qualificationStateDigest: String
    public let runtimeContext: AdmissionRuntimeContext
    public let promptHashes: [String: String]
    public let effectivePolicyHash: String
    public let authFallbackChain: [AuthFallbackBinding]
    public let admittedAt: String
    public let expiresAt: String?
    public let parentReceiptId: String?
    public let epoch: Int?
    public let receiptHash: String

    public init(
        schema: String = AdmissionReceipt.currentSchema,
        receiptId: String,
        runId: String,
        sourceHash: String,
        executableHash: String,
        envelopeHash: String,
        planningConstraintsHash: String,
        qualificationReportHash: String,
        discoverySnapshotHash: String,
        qualificationStateDigest: String,
        runtimeContext: AdmissionRuntimeContext,
        promptHashes: [String: String],
        effectivePolicyHash: String,
        authFallbackChain: [AuthFallbackBinding],
        admittedAt: String,
        expiresAt: String?,
        parentReceiptId: String?,
        epoch: Int?,
        receiptHash: String
    ) {
        self.schema = schema
        self.receiptId = receiptId
        self.runId = runId
        self.sourceHash = sourceHash
        self.executableHash = executableHash
        self.envelopeHash = envelopeHash
        self.planningConstraintsHash = planningConstraintsHash
        self.qualificationReportHash = qualificationReportHash
        self.discoverySnapshotHash = discoverySnapshotHash
        self.qualificationStateDigest = qualificationStateDigest
        self.runtimeContext = runtimeContext
        self.promptHashes = promptHashes
        self.effectivePolicyHash = effectivePolicyHash
        self.authFallbackChain = authFallbackChain
        self.admittedAt = admittedAt
        self.expiresAt = expiresAt
        self.parentReceiptId = parentReceiptId
        self.epoch = epoch
        self.receiptHash = receiptHash
    }
}

public struct AdmittedExecution: Sendable, Equatable {
    public let bundle: ExecutionArtifactBundle
    public let envelope: ExecutionAuthorityEnvelope
    public let qualification: QualificationReport
    public let effectivePolicy: EffectiveExecutionPolicy
    public let receipt: AdmissionReceipt

    public init(
        bundle: ExecutionArtifactBundle,
        envelope: ExecutionAuthorityEnvelope,
        qualification: QualificationReport,
        effectivePolicy: EffectiveExecutionPolicy,
        receipt: AdmissionReceipt
    ) {
        self.bundle = bundle
        self.envelope = envelope
        self.qualification = qualification
        self.effectivePolicy = effectivePolicy
        self.receipt = receipt
    }
}

/// Pure admission over immutable facts captured after locks and baselines.
public enum ExecutionGraphAdmission: Sendable {
    public static let cleanStatusDigest = ExecutionGraphDigest.sha256("")

    public static func admit(
        qualified: QualifiedExecution,
        runtime: AdmissionRuntimeContext,
        trustedProfile: any ExecutionGraphQualificationProfile,
        clock: any ExecutionGraphClock
    ) async throws -> AdmittedExecution {
        let instant = clock.now()
        try await validateRuntime(
            qualified: qualified,
            runtime: runtime,
            trustedProfile: trustedProfile,
            at: instant
        )
        let receipt = try makeReceipt(
            qualified: qualified,
            runtime: runtime,
            admittedAt: timestamp(instant)
        )
        try await validateReceipt(
            receipt,
            qualified: qualified,
            runtime: runtime,
            trustedProfile: trustedProfile,
            at: instant
        )
        return AdmittedExecution(
            bundle: qualified.bundle,
            envelope: qualified.envelope,
            qualification: qualified.qualification,
            effectivePolicy: qualified.effectivePolicy,
            receipt: receipt
        )
    }

    public static func validateRuntime(
        qualified: QualifiedExecution,
        runtime: AdmissionRuntimeContext,
        trustedProfile: any ExecutionGraphQualificationProfile,
        at instant: Date
    ) async throws {
        let policy = qualified.effectivePolicy
        let envelope = qualified.envelope

        do {
            try await ExecutionGraphQualification
                .validateQualifiedExecution(
                    qualified,
                    trustedProfile: trustedProfile,
                    at: instant
                )
        } catch let violation as ExecutionGraphViolation {
            guard violation.id == "qualification.identity-drift" else {
                throw violation
            }
            throw ExecutionGraphViolation(
                id: "admission.qualification-drift",
                detail: "\(violation.id): \(violation.detail)"
            )
        }
        if let expiry = envelope.expiry {
            guard let date = ExecutionGraphQualification
                .parseTimestamp(expiry),
                  date > instant
            else {
                throw ExecutionGraphViolation(
                    id: "envelope.expired",
                    detail: "authority envelope is expired or malformed"
                )
            }
        }

        let logical = standardizedPath(runtime.logicalWorkspaceRoot)
        let execution = standardizedPath(runtime.executionRoot)
        guard logical == standardizedPath(policy.logicalWorkspaceRoot),
              logical == standardizedPath(envelope.workspaceRoot)
        else {
            throw ExecutionGraphViolation(
                id: "admission.logical-root",
                detail: "logical workspace root drifted"
            )
        }
        let worktreePrefix = logical + "/.worktrees/"
        guard runtime.transferMode == "worktree",
              policy.transferMode == "worktree",
              envelope.requiredTransferMode == "worktree",
              execution != logical,
              execution.hasPrefix(worktreePrefix),
              execution.count > worktreePrefix.count
        else {
            throw ExecutionGraphViolation(
                id: "admission.root-mapping",
                detail: "unverified non-worktree root mapping"
            )
        }

        let lockRoots = Set(runtime.acquiredLockRoots.map(standardizedPath))
        let baselineRoots = Set(runtime.baselineDigests.keys.map(
            standardizedPath
        ))
        guard lockRoots.contains(execution),
              baselineRoots.contains(execution)
        else {
            throw ExecutionGraphViolation(
                id: "admission.boundary-order",
                detail: "locks and baselines must precede admission"
            )
        }
        guard runtime.finalGitHead == qualified.bundle.discovery.gitHead,
              runtime.selectedReadSetHash
                == qualified.bundle.discovery.snapshotHash
        else {
            throw ExecutionGraphViolation(
                id: "admission.discovery-drift",
                detail: "HEAD or selected discovery read-set drifted"
            )
        }
        guard runtime.finalGitStatusDigest == cleanStatusDigest else {
            throw ExecutionGraphViolation(
                id: "admission.dirty-state",
                detail: "final worktree is not clean"
            )
        }
        guard runtime.qualificationSourceStateDigest
                == qualified.qualification.qualificationStateDigest,
              runtime.runtimeStateDigest
                == qualified.qualification.qualificationStateDigest
        else {
            throw ExecutionGraphViolation(
                id: "admission.state-drift",
                detail: "qualification state drifted"
            )
        }
        guard runtime.dependencyReportHash
                == qualified.qualification.dependencyReportHash
        else {
            throw ExecutionGraphViolation(
                id: "admission.dependencies",
                detail: "dependency report drifted"
            )
        }
        guard runtime.effectiveBackend == policy.fixedBackend,
              runtime.effectiveModel == policy.fixedModel,
              runtime.currentAuthProfile == policy.initialAuthProfile,
              runtime.endpointConfigDigest == policy.endpointConfigDigest,
              runtime.permissionMode == policy.defaultPermissionMode,
              runtime.sandboxPolicy == policy.defaultSandboxPolicy,
              runtime.approvalPolicy == policy.defaultApprovalPolicy,
              runtime.mcpConfigurationDigest == policy.mcpPolicyDigest
        else {
            throw ExecutionGraphViolation(
                id: "admission.effective-config",
                detail: "effective execution configuration drifted"
            )
        }
        guard runtime.effectiveVariablesHash
                == (try ExecutionGraphCanonicalizer.hash(
                    qualified.bundle.effectiveStaticVariables
                )),
              runtime.primitiveContractHash
                == ExecutionGraphDigest.sha256("host-loop.v1"),
              !runtime.runId.isEmpty,
              !runtime.backendAdapterDigest.isEmpty,
              !runtime.engineVersion.isEmpty,
              runtime.admittedOuterCallEvidence,
              !runtime.gateRecordOverrideUsed
        else {
            throw ExecutionGraphViolation(
                id: "admission.runtime-closure",
                detail: "runtime primitive or evidence posture is not sealed"
            )
        }

        let executableHash = try ExecutionGraphLowerer
            .recomputeExecutableHash(
                bundle: qualified.bundle,
                policy: policy
            )
        guard executableHash == qualified.bundle.executableHash else {
            throw ExecutionGraphViolation(
                id: "admission.bundle-drift",
                detail: "bundle or prompt drifted"
            )
        }
    }

    public static func validateReceipt(
        _ receipt: AdmissionReceipt,
        qualified: QualifiedExecution,
        runtime: AdmissionRuntimeContext,
        trustedProfile: any ExecutionGraphQualificationProfile,
        at instant: Date
    ) async throws {
        try await validateRuntime(
            qualified: qualified,
            runtime: runtime,
            trustedProfile: trustedProfile,
            at: instant
        )
        guard receipt.schema == AdmissionReceipt.currentSchema else {
            throw ExecutionGraphViolation(
                id: "receipt.schema",
                detail: "unsupported receipt schema"
            )
        }
        guard ExecutionGraphQualification.parseTimestamp(
            receipt.admittedAt
        ) != nil else {
            throw ExecutionGraphViolation(
                id: "receipt.timestamp",
                detail: "admission timestamp is malformed"
            )
        }

        let expectedEnvelopeHash = try ExecutionGraphCanonicalizer.hash(
            qualified.envelope
        )
        let expectedPolicyHash = try ExecutionGraphCanonicalizer.hash(
            qualified.effectivePolicy
        )
        let expectedPromptHashes = try promptHashes(
            qualified.bundle.prompts
        )
        let checks: [(String, Bool)] = [
            ("receipt.run-id", receipt.runId == runtime.runId),
            (
                "receipt.source-hash",
                receipt.sourceHash == qualified.bundle.sourceHash
            ),
            (
                "receipt.executable-hash",
                receipt.executableHash == qualified.bundle.executableHash
            ),
            (
                "receipt.envelope-hash",
                receipt.envelopeHash == expectedEnvelopeHash
            ),
            (
                "receipt.planning-constraints",
                receipt.planningConstraintsHash
                    == qualified.bundle.planningConstraintsHash
            ),
            (
                "receipt.qualification-report",
                receipt.qualificationReportHash
                    == qualified.qualification.reportHash
            ),
            (
                "receipt.discovery",
                receipt.discoverySnapshotHash
                    == qualified.bundle.discovery.snapshotHash
            ),
            (
                "receipt.qualification-state",
                receipt.qualificationStateDigest
                    == qualified.qualification.qualificationStateDigest
            ),
            (
                "receipt.runtime-context",
                try canonicalEqual(receipt.runtimeContext, runtime)
            ),
            (
                "receipt.prompts",
                receipt.promptHashes == expectedPromptHashes
            ),
            (
                "receipt.policy",
                receipt.effectivePolicyHash == expectedPolicyHash
            ),
            (
                "receipt.auth-fallback",
                try canonicalEqual(
                    receipt.authFallbackChain,
                    qualified.effectivePolicy.authFallbackChain
                )
            ),
            (
                "receipt.expiry",
                receipt.expiresAt == qualified.envelope.expiry
            ),
            (
                "receipt.parent",
                receipt.parentReceiptId == nil && receipt.epoch == nil
            ),
        ]
        if let failed = checks.first(where: { !$0.1 }) {
            throw ExecutionGraphViolation(
                id: failed.0,
                detail: "receipt-bound value changed"
            )
        }

        let expectedReceiptId = receiptIdentifier(
            runId: runtime.runId,
            executableHash: qualified.bundle.executableHash,
            envelopeHash: expectedEnvelopeHash
        )
        guard receipt.receiptId == expectedReceiptId else {
            throw ExecutionGraphViolation(
                id: "receipt.id",
                detail: "receipt identity mismatch"
            )
        }
        guard try receiptHash(receipt) == receipt.receiptHash else {
            throw ExecutionGraphViolation(
                id: "receipt.hash",
                detail: "receipt hash mismatch"
            )
        }
    }

    public static func receiptHash(
        _ receipt: AdmissionReceipt
    ) throws -> String {
        try ExecutionGraphCanonicalizer.hash(
            AdmissionReceiptPayload(
                schema: receipt.schema,
                receiptId: receipt.receiptId,
                runId: receipt.runId,
                sourceHash: receipt.sourceHash,
                executableHash: receipt.executableHash,
                envelopeHash: receipt.envelopeHash,
                planningConstraintsHash:
                    receipt.planningConstraintsHash,
                qualificationReportHash:
                    receipt.qualificationReportHash,
                discoverySnapshotHash: receipt.discoverySnapshotHash,
                qualificationStateDigest:
                    receipt.qualificationStateDigest,
                runtimeContext: receipt.runtimeContext,
                promptHashes: receipt.promptHashes,
                effectivePolicyHash: receipt.effectivePolicyHash,
                authFallbackChain: receipt.authFallbackChain,
                admittedAt: receipt.admittedAt,
                expiresAt: receipt.expiresAt,
                parentReceiptId: receipt.parentReceiptId,
                epoch: receipt.epoch
            )
        )
    }

    private static func makeReceipt(
        qualified: QualifiedExecution,
        runtime: AdmissionRuntimeContext,
        admittedAt: String
    ) throws -> AdmissionReceipt {
        let envelopeHash = try ExecutionGraphCanonicalizer.hash(
            qualified.envelope
        )
        let policyHash = try ExecutionGraphCanonicalizer.hash(
            qualified.effectivePolicy
        )
        let prompts = try promptHashes(qualified.bundle.prompts)
        let receiptId = receiptIdentifier(
            runId: runtime.runId,
            executableHash: qualified.bundle.executableHash,
            envelopeHash: envelopeHash
        )
        let unhashed = AdmissionReceipt(
            receiptId: receiptId,
            runId: runtime.runId,
            sourceHash: qualified.bundle.sourceHash,
            executableHash: qualified.bundle.executableHash,
            envelopeHash: envelopeHash,
            planningConstraintsHash:
                qualified.bundle.planningConstraintsHash,
            qualificationReportHash:
                qualified.qualification.reportHash,
            discoverySnapshotHash:
                qualified.bundle.discovery.snapshotHash,
            qualificationStateDigest:
                qualified.qualification.qualificationStateDigest,
            runtimeContext: runtime,
            promptHashes: prompts,
            effectivePolicyHash: policyHash,
            authFallbackChain:
                qualified.effectivePolicy.authFallbackChain,
            admittedAt: admittedAt,
            expiresAt: qualified.envelope.expiry,
            parentReceiptId: nil,
            epoch: nil,
            receiptHash: ""
        )
        return AdmissionReceipt(
            schema: unhashed.schema,
            receiptId: unhashed.receiptId,
            runId: unhashed.runId,
            sourceHash: unhashed.sourceHash,
            executableHash: unhashed.executableHash,
            envelopeHash: unhashed.envelopeHash,
            planningConstraintsHash:
                unhashed.planningConstraintsHash,
            qualificationReportHash:
                unhashed.qualificationReportHash,
            discoverySnapshotHash: unhashed.discoverySnapshotHash,
            qualificationStateDigest:
                unhashed.qualificationStateDigest,
            runtimeContext: unhashed.runtimeContext,
            promptHashes: unhashed.promptHashes,
            effectivePolicyHash: unhashed.effectivePolicyHash,
            authFallbackChain: unhashed.authFallbackChain,
            admittedAt: unhashed.admittedAt,
            expiresAt: unhashed.expiresAt,
            parentReceiptId: unhashed.parentReceiptId,
            epoch: unhashed.epoch,
            receiptHash: try receiptHash(unhashed)
        )
    }

    private static func receiptIdentifier(
        runId: String,
        executableHash: String,
        envelopeHash: String
    ) -> String {
        let digest = ExecutionGraphDigest.sha256(
            "\(runId)|\(executableHash)|\(envelopeHash)"
        )
        return "rcpt_" + String(digest.prefix(24))
    }

    private static func promptHashes(
        _ prompts: [SealedExecutionPrompt]
    ) throws -> [String: String] {
        var result: [String: String] = [:]
        for prompt in prompts {
            guard result.updateValue(
                prompt.sha256,
                forKey: prompt.stepLabel
            ) == nil else {
                throw ExecutionGraphViolation(
                    id: "qualification.prompt-duplicate",
                    detail: "duplicate sealed prompt \(prompt.stepLabel)"
                )
            }
        }
        return result
    }

    private static func standardizedPath(_ path: String) -> String {
        ExecutionGraphQualification.standardizedAbsolutePath(path)
    }

    private static func canonicalEqual<T: Encodable>(
        _ lhs: T,
        _ rhs: T
    ) throws -> Bool {
        try ExecutionGraphCanonicalizer.data(lhs)
            == ExecutionGraphCanonicalizer.data(rhs)
    }

    static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds,
        ]
        return formatter.string(from: date)
    }

    private struct AdmissionReceiptPayload: Encodable {
        let schema: String
        let receiptId: String
        let runId: String
        let sourceHash: String
        let executableHash: String
        let envelopeHash: String
        let planningConstraintsHash: String
        let qualificationReportHash: String
        let discoverySnapshotHash: String
        let qualificationStateDigest: String
        let runtimeContext: AdmissionRuntimeContext
        let promptHashes: [String: String]
        let effectivePolicyHash: String
        let authFallbackChain: [AuthFallbackBinding]
        let admittedAt: String
        let expiresAt: String?
        let parentReceiptId: String?
        let epoch: Int?
    }
}

// MARK: - Immutable host-call activation

public struct ActivationInputLaneRecord:
    Codable, Sendable, Equatable, Hashable
{
    public let lane: String
    public let source: String
    public let contentHash: String
    public let byteCount: Int

    public init(
        lane: String,
        source: String,
        contentHash: String,
        byteCount: Int
    ) {
        self.lane = lane
        self.source = source
        self.contentHash = contentHash
        self.byteCount = byteCount
    }
}

public struct ActivationCallLaneBinding:
    Codable, Sendable, Equatable, Hashable
{
    public let runId: String
    public let stepLabel: String
    public let activationId: String
    public let coveragePolicyHash: String

    public init(
        runId: String,
        stepLabel: String,
        activationId: String,
        coveragePolicyHash: String
    ) {
        self.runId = runId
        self.stepLabel = stepLabel
        self.activationId = activationId
        self.coveragePolicyHash = coveragePolicyHash
    }
}

public struct StepActivationRecord: Codable, Sendable, Equatable {
    public static let currentSchema = "mentu.step-activation.v1"

    public let schema: String
    public let activationId: String
    public let receiptId: String
    public let receiptHash: String
    public let sequence: Int
    public let stepLabel: String
    public let logicalStepAttempt: Int
    public let hostCallAttempt: Int
    public let nodeHash: String
    public let rawPromptHash: String
    public let resolvedPromptHash: String
    public let phaseDerivationPolicyHash: String
    public let backend: String
    public let model: String
    public let authProfile: String
    public let endpointConfigDigest: String
    public let effectiveConfigurationHash: String
    public let stepSoftDeadlineSeconds: Int
    public let runSoftDeadlineSeconds: Int
    public let monotonicStartNanoseconds: UInt64
    public let boundaryKillPolicyDigest: String
    public let workspaceSnapshotHash: String
    public let dataSnapshotHashes: [String]
    public let inputLanes: [ActivationInputLaneRecord]
    public let upstreamOutputHashes: [String]
    public let callLane: ActivationCallLaneBinding
    public let previousActivationHash: String?
    public let timestamp: String
    public let activationHash: String

    public init(
        schema: String = StepActivationRecord.currentSchema,
        activationId: String,
        receiptId: String,
        receiptHash: String,
        sequence: Int,
        stepLabel: String,
        logicalStepAttempt: Int,
        hostCallAttempt: Int,
        nodeHash: String,
        rawPromptHash: String,
        resolvedPromptHash: String,
        phaseDerivationPolicyHash: String,
        backend: String,
        model: String,
        authProfile: String,
        endpointConfigDigest: String,
        effectiveConfigurationHash: String,
        stepSoftDeadlineSeconds: Int,
        runSoftDeadlineSeconds: Int,
        monotonicStartNanoseconds: UInt64,
        boundaryKillPolicyDigest: String,
        workspaceSnapshotHash: String,
        dataSnapshotHashes: [String],
        inputLanes: [ActivationInputLaneRecord],
        upstreamOutputHashes: [String],
        callLane: ActivationCallLaneBinding,
        previousActivationHash: String?,
        timestamp: String,
        activationHash: String
    ) {
        self.schema = schema
        self.activationId = activationId
        self.receiptId = receiptId
        self.receiptHash = receiptHash
        self.sequence = sequence
        self.stepLabel = stepLabel
        self.logicalStepAttempt = logicalStepAttempt
        self.hostCallAttempt = hostCallAttempt
        self.nodeHash = nodeHash
        self.rawPromptHash = rawPromptHash
        self.resolvedPromptHash = resolvedPromptHash
        self.phaseDerivationPolicyHash = phaseDerivationPolicyHash
        self.backend = backend
        self.model = model
        self.authProfile = authProfile
        self.endpointConfigDigest = endpointConfigDigest
        self.effectiveConfigurationHash = effectiveConfigurationHash
        self.stepSoftDeadlineSeconds = stepSoftDeadlineSeconds
        self.runSoftDeadlineSeconds = runSoftDeadlineSeconds
        self.monotonicStartNanoseconds = monotonicStartNanoseconds
        self.boundaryKillPolicyDigest = boundaryKillPolicyDigest
        self.workspaceSnapshotHash = workspaceSnapshotHash
        self.dataSnapshotHashes = dataSnapshotHashes
        self.inputLanes = inputLanes
        self.upstreamOutputHashes = upstreamOutputHashes
        self.callLane = callLane
        self.previousActivationHash = previousActivationHash
        self.timestamp = timestamp
        self.activationHash = activationHash
    }
}

public struct StepActivationOutcomeRecord:
    Codable, Sendable, Equatable
{
    public static let currentSchema =
        "mentu.step-activation-outcome.v1"

    public let schema: String
    public let activationId: String
    public let activationHash: String
    public let sequence: Int
    public let stepLabel: String
    public let hostCallAttempt: Int
    public let terminationReason: String
    public let returned: Bool
    public let costMicrosUSD: Int64
    public let turns: Int
    public let inputTokens: Int
    public let outputTokens: Int
    public let outputHash: String
    public let elapsedNanoseconds: UInt64
    public let softDeadlineExceeded: Bool
    public let callRecordRoot: String
    public let coverage: String
    public let timestamp: String
    public let previousOutcomeHash: String?
    public let outcomeHash: String

    public init(
        schema: String = StepActivationOutcomeRecord.currentSchema,
        activationId: String,
        activationHash: String,
        sequence: Int,
        stepLabel: String,
        hostCallAttempt: Int,
        terminationReason: String,
        returned: Bool,
        costMicrosUSD: Int64,
        turns: Int,
        inputTokens: Int,
        outputTokens: Int,
        outputHash: String,
        elapsedNanoseconds: UInt64,
        softDeadlineExceeded: Bool,
        callRecordRoot: String,
        coverage: String,
        timestamp: String,
        previousOutcomeHash: String?,
        outcomeHash: String
    ) {
        self.schema = schema
        self.activationId = activationId
        self.activationHash = activationHash
        self.sequence = sequence
        self.stepLabel = stepLabel
        self.hostCallAttempt = hostCallAttempt
        self.terminationReason = terminationReason
        self.returned = returned
        self.costMicrosUSD = costMicrosUSD
        self.turns = turns
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.outputHash = outputHash
        self.elapsedNanoseconds = elapsedNanoseconds
        self.softDeadlineExceeded = softDeadlineExceeded
        self.callRecordRoot = callRecordRoot
        self.coverage = coverage
        self.timestamp = timestamp
        self.previousOutcomeHash = previousOutcomeHash
        self.outcomeHash = outcomeHash
    }
}

public struct StepActivationParameters: Sendable, Equatable {
    public let sequence: Int
    public let stepStart: StepStartContext
    public let hostCallAttempt: Int
    public let nodeHash: String
    public let rawPromptHash: String
    public let resolvedPromptHash: String
    public let phaseDerivationPolicyHash: String
    public let backend: String
    public let model: String
    public let authProfile: String
    public let endpointConfigDigest: String
    public let effectiveConfigurationHash: String
    public let stepSoftDeadlineSeconds: Int
    public let runSoftDeadlineSeconds: Int
    public let monotonicStartNanoseconds: UInt64
    public let boundaryKillPolicyDigest: String
    public let upstreamOutputHashes: [String]
    public let previousActivationHash: String?

    public init(
        sequence: Int,
        stepStart: StepStartContext,
        hostCallAttempt: Int,
        nodeHash: String,
        rawPromptHash: String,
        resolvedPromptHash: String,
        phaseDerivationPolicyHash: String,
        backend: String,
        model: String,
        authProfile: String,
        endpointConfigDigest: String,
        effectiveConfigurationHash: String,
        stepSoftDeadlineSeconds: Int,
        runSoftDeadlineSeconds: Int,
        monotonicStartNanoseconds: UInt64,
        boundaryKillPolicyDigest: String,
        upstreamOutputHashes: [String],
        previousActivationHash: String?
    ) {
        self.sequence = sequence
        self.stepStart = stepStart
        self.hostCallAttempt = hostCallAttempt
        self.nodeHash = nodeHash
        self.rawPromptHash = rawPromptHash
        self.resolvedPromptHash = resolvedPromptHash
        self.phaseDerivationPolicyHash = phaseDerivationPolicyHash
        self.backend = backend
        self.model = model
        self.authProfile = authProfile
        self.endpointConfigDigest = endpointConfigDigest
        self.effectiveConfigurationHash = effectiveConfigurationHash
        self.stepSoftDeadlineSeconds = stepSoftDeadlineSeconds
        self.runSoftDeadlineSeconds = runSoftDeadlineSeconds
        self.monotonicStartNanoseconds = monotonicStartNanoseconds
        self.boundaryKillPolicyDigest = boundaryKillPolicyDigest
        self.upstreamOutputHashes = upstreamOutputHashes
        self.previousActivationHash = previousActivationHash
    }
}

public struct StepActivationOutcomeParameters: Sendable, Equatable {
    public let sequence: Int
    public let terminationReason: String
    public let returned: Bool
    public let costMicrosUSD: Int64
    public let turns: Int
    public let inputTokens: Int
    public let outputTokens: Int
    public let outputHash: String
    public let elapsedNanoseconds: UInt64
    public let softDeadlineExceeded: Bool
    public let callRecordRoot: String
    public let coverage: String
    public let previousOutcomeHash: String?

    public init(
        sequence: Int,
        terminationReason: String,
        returned: Bool = true,
        costMicrosUSD: Int64,
        turns: Int,
        inputTokens: Int,
        outputTokens: Int,
        outputHash: String,
        elapsedNanoseconds: UInt64,
        softDeadlineExceeded: Bool,
        callRecordRoot: String,
        coverage: String,
        previousOutcomeHash: String?
    ) {
        self.sequence = sequence
        self.terminationReason = terminationReason
        self.returned = returned
        self.costMicrosUSD = costMicrosUSD
        self.turns = turns
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.outputHash = outputHash
        self.elapsedNanoseconds = elapsedNanoseconds
        self.softDeadlineExceeded = softDeadlineExceeded
        self.callRecordRoot = callRecordRoot
        self.coverage = coverage
        self.previousOutcomeHash = previousOutcomeHash
    }
}

/// Stateless construction and validation of the activation evidence chains.
public enum StepActivationChain: Sendable {
    public static let coveragePolicyHash = ExecutionGraphDigest.sha256(
        "host_boundary_exact+child_transcript_reconstructed.v1"
    )

    public static func makeActivation(
        admitted: AdmittedExecution,
        parameters: StepActivationParameters,
        clock: any ExecutionGraphClock
    ) throws -> StepActivationRecord {
        let start = parameters.stepStart
        guard parameters.sequence > 0,
              start.logicalAttempt > 0,
              parameters.hostCallAttempt > 0,
              start.runId == admitted.receipt.runId,
              admitted.bundle.definition.steps.contains(where: {
                  $0.label == start.stepLabel
              })
        else {
            throw ExecutionGraphViolation(
                id: "activation.identity",
                detail: "activation identity or attempt is invalid"
            )
        }
        let unauthorizedLane = start.inputs.first {
            !admitted.envelope.dynamicInputLanes.contains($0.lane)
        }
        guard unauthorizedLane == nil else {
            throw ExecutionGraphViolation(
                id: "activation.input-lane",
                detail: "input lane \(unauthorizedLane!.lane) is outside the envelope"
            )
        }
        guard parameters.backend == admitted.effectivePolicy.fixedBackend,
              parameters.model == admitted.effectivePolicy.fixedModel,
              admitted.effectivePolicy.authFallbackChain.contains(where: {
                  $0.profileId == parameters.authProfile
              }),
              admitted.receipt.authFallbackChain.contains(where: {
                  $0.profileId == parameters.authProfile
              }),
              parameters.endpointConfigDigest
                == admitted.effectivePolicy.endpointConfigDigest
        else {
            throw ExecutionGraphViolation(
                id: "activation.effective-config",
                detail: "activation configuration is outside admitted authority"
            )
        }

        let activationId =
            "act_\(admitted.receipt.runId)_\(parameters.sequence)"
        let inputs = start.inputs.map {
            ActivationInputLaneRecord(
                lane: $0.lane,
                source: $0.source,
                contentHash: ExecutionGraphDigest.sha256($0.content),
                byteCount: Data($0.content.utf8).count
            )
        }
        let workspaceHash = try ExecutionGraphCanonicalizer.hash(
            start.workspaceSnapshot
        )
        let dataHashes = try start.dataSnapshots.map {
            try ExecutionGraphCanonicalizer.hash($0)
        }.sorted()
        let callLane = ActivationCallLaneBinding(
            runId: admitted.receipt.runId,
            stepLabel: start.stepLabel,
            activationId: activationId,
            coveragePolicyHash: coveragePolicyHash
        )
        let payload = StepActivationPayload(
            activationId: activationId,
            receiptId: admitted.receipt.receiptId,
            receiptHash: admitted.receipt.receiptHash,
            sequence: parameters.sequence,
            stepLabel: start.stepLabel,
            logicalStepAttempt: start.logicalAttempt,
            hostCallAttempt: parameters.hostCallAttempt,
            nodeHash: parameters.nodeHash,
            rawPromptHash: parameters.rawPromptHash,
            resolvedPromptHash: parameters.resolvedPromptHash,
            phaseDerivationPolicyHash:
                parameters.phaseDerivationPolicyHash,
            backend: parameters.backend,
            model: parameters.model,
            authProfile: parameters.authProfile,
            endpointConfigDigest: parameters.endpointConfigDigest,
            effectiveConfigurationHash:
                parameters.effectiveConfigurationHash,
            stepSoftDeadlineSeconds:
                parameters.stepSoftDeadlineSeconds,
            runSoftDeadlineSeconds:
                parameters.runSoftDeadlineSeconds,
            monotonicStartNanoseconds:
                parameters.monotonicStartNanoseconds,
            boundaryKillPolicyDigest:
                parameters.boundaryKillPolicyDigest,
            workspaceSnapshotHash: workspaceHash,
            dataSnapshotHashes: dataHashes,
            inputLanes: inputs,
            upstreamOutputHashes:
                parameters.upstreamOutputHashes.sorted(),
            callLane: callLane,
            previousActivationHash:
                parameters.previousActivationHash,
            timestamp: ExecutionGraphAdmission.timestamp(clock.now())
        )
        return StepActivationRecord(
            activationId: payload.activationId,
            receiptId: payload.receiptId,
            receiptHash: payload.receiptHash,
            sequence: payload.sequence,
            stepLabel: payload.stepLabel,
            logicalStepAttempt: payload.logicalStepAttempt,
            hostCallAttempt: payload.hostCallAttempt,
            nodeHash: payload.nodeHash,
            rawPromptHash: payload.rawPromptHash,
            resolvedPromptHash: payload.resolvedPromptHash,
            phaseDerivationPolicyHash:
                payload.phaseDerivationPolicyHash,
            backend: payload.backend,
            model: payload.model,
            authProfile: payload.authProfile,
            endpointConfigDigest: payload.endpointConfigDigest,
            effectiveConfigurationHash:
                payload.effectiveConfigurationHash,
            stepSoftDeadlineSeconds:
                payload.stepSoftDeadlineSeconds,
            runSoftDeadlineSeconds: payload.runSoftDeadlineSeconds,
            monotonicStartNanoseconds:
                payload.monotonicStartNanoseconds,
            boundaryKillPolicyDigest:
                payload.boundaryKillPolicyDigest,
            workspaceSnapshotHash: payload.workspaceSnapshotHash,
            dataSnapshotHashes: payload.dataSnapshotHashes,
            inputLanes: payload.inputLanes,
            upstreamOutputHashes: payload.upstreamOutputHashes,
            callLane: payload.callLane,
            previousActivationHash: payload.previousActivationHash,
            timestamp: payload.timestamp,
            activationHash: try ExecutionGraphCanonicalizer.hash(payload)
        )
    }

    public static func makeOutcome(
        activation: StepActivationRecord,
        parameters: StepActivationOutcomeParameters,
        clock: any ExecutionGraphClock
    ) throws -> StepActivationOutcomeRecord {
        try validateOutcomeValues(
            sequence: parameters.sequence,
            terminationReason: parameters.terminationReason,
            costMicrosUSD: parameters.costMicrosUSD,
            turns: parameters.turns,
            inputTokens: parameters.inputTokens,
            outputTokens: parameters.outputTokens
        )
        try validateActivation(activation)
        let payload = StepActivationOutcomePayload(
            activationId: activation.activationId,
            activationHash: activation.activationHash,
            sequence: parameters.sequence,
            stepLabel: activation.stepLabel,
            hostCallAttempt: activation.hostCallAttempt,
            terminationReason: parameters.terminationReason,
            returned: parameters.returned,
            costMicrosUSD: parameters.costMicrosUSD,
            turns: parameters.turns,
            inputTokens: parameters.inputTokens,
            outputTokens: parameters.outputTokens,
            outputHash: parameters.outputHash,
            elapsedNanoseconds: parameters.elapsedNanoseconds,
            softDeadlineExceeded:
                parameters.softDeadlineExceeded,
            callRecordRoot: parameters.callRecordRoot,
            coverage: parameters.coverage,
            timestamp: ExecutionGraphAdmission.timestamp(clock.now()),
            previousOutcomeHash: parameters.previousOutcomeHash
        )
        return StepActivationOutcomeRecord(
            activationId: payload.activationId,
            activationHash: payload.activationHash,
            sequence: payload.sequence,
            stepLabel: payload.stepLabel,
            hostCallAttempt: payload.hostCallAttempt,
            terminationReason: payload.terminationReason,
            returned: payload.returned,
            costMicrosUSD: payload.costMicrosUSD,
            turns: payload.turns,
            inputTokens: payload.inputTokens,
            outputTokens: payload.outputTokens,
            outputHash: payload.outputHash,
            elapsedNanoseconds: payload.elapsedNanoseconds,
            softDeadlineExceeded: payload.softDeadlineExceeded,
            callRecordRoot: payload.callRecordRoot,
            coverage: payload.coverage,
            timestamp: payload.timestamp,
            previousOutcomeHash: payload.previousOutcomeHash,
            outcomeHash: try ExecutionGraphCanonicalizer.hash(payload)
        )
    }

    public static func validateActivation(
        _ activation: StepActivationRecord
    ) throws {
        guard activation.schema == StepActivationRecord.currentSchema else {
            throw ExecutionGraphViolation(
                id: "activation.schema",
                detail: "unsupported activation schema"
            )
        }
        guard activation.sequence > 0,
              activation.logicalStepAttempt > 0,
              activation.hostCallAttempt > 0,
              activation.callLane.activationId
                == activation.activationId,
              activation.callLane.stepLabel == activation.stepLabel,
              activation.callLane.coveragePolicyHash
                == coveragePolicyHash,
              ExecutionGraphQualification.parseTimestamp(
                activation.timestamp
              ) != nil
        else {
            throw ExecutionGraphViolation(
                id: "activation.binding",
                detail: "activation call-lane or identity binding is invalid"
            )
        }
        let expected = try ExecutionGraphCanonicalizer.hash(
            StepActivationPayload(activation)
        )
        guard expected == activation.activationHash else {
            throw ExecutionGraphViolation(
                id: "activation.hash",
                detail: "activation hash mismatch"
            )
        }
    }

    public static func validateOutcome(
        _ outcome: StepActivationOutcomeRecord,
        activation: StepActivationRecord
    ) throws {
        try validateActivation(activation)
        guard outcome.schema
                == StepActivationOutcomeRecord.currentSchema else {
            throw ExecutionGraphViolation(
                id: "activation.outcome-schema",
                detail: "unsupported activation outcome schema"
            )
        }
        try validateOutcomeValues(
            sequence: outcome.sequence,
            terminationReason: outcome.terminationReason,
            costMicrosUSD: outcome.costMicrosUSD,
            turns: outcome.turns,
            inputTokens: outcome.inputTokens,
            outputTokens: outcome.outputTokens
        )
        guard outcome.activationId == activation.activationId,
              outcome.activationHash == activation.activationHash,
              outcome.stepLabel == activation.stepLabel,
              outcome.hostCallAttempt == activation.hostCallAttempt,
              ExecutionGraphQualification.parseTimestamp(
                outcome.timestamp
              ) != nil
        else {
            throw ExecutionGraphViolation(
                id: "activation.outcome-binding",
                detail: "outcome does not bind the exact activation"
            )
        }
        let expected = try ExecutionGraphCanonicalizer.hash(
            StepActivationOutcomePayload(outcome)
        )
        guard expected == outcome.outcomeHash else {
            throw ExecutionGraphViolation(
                id: "activation.outcome-hash",
                detail: "activation outcome hash mismatch"
            )
        }
    }

    private static func validateOutcomeValues(
        sequence: Int,
        terminationReason: String,
        costMicrosUSD: Int64,
        turns: Int,
        inputTokens: Int,
        outputTokens: Int
    ) throws {
        guard sequence > 0,
              !terminationReason.isEmpty,
              costMicrosUSD >= 0,
              turns >= 0,
              inputTokens >= 0,
              outputTokens >= 0
        else {
            throw ExecutionGraphViolation(
                id: "activation.outcome-values",
                detail: "outcome sequence and accounting values are invalid"
            )
        }
    }

    public static func validateActivationChain(
        _ activations: [StepActivationRecord],
        initialPreviousHash: String? = nil,
        initialSequence: Int = 1,
        receipt: AdmissionReceipt? = nil
    ) throws {
        var previous = initialPreviousHash
        var expectedSequence = initialSequence
        var ids = Set<String>()
        for (index, activation) in activations.enumerated() {
            try validateActivation(activation)
            guard ids.insert(activation.activationId).inserted else {
                throw ExecutionGraphViolation(
                    id: "activation.duplicate",
                    detail: "activation ID is duplicated"
                )
            }
            guard activation.sequence == expectedSequence else {
                throw ExecutionGraphViolation(
                    id: "activation.sequence",
                    detail: "activation sequence is not contiguous"
                )
            }
            guard activation.previousActivationHash == previous else {
                throw ExecutionGraphViolation(
                    id: "activation.chain",
                    detail: "activation previous hash mismatch"
                )
            }
            if let receipt {
                guard activation.receiptId == receipt.receiptId,
                      activation.receiptHash == receipt.receiptHash,
                      activation.callLane.runId == receipt.runId
                else {
                    throw ExecutionGraphViolation(
                        id: "activation.receipt",
                        detail: "activation does not bind the admitted receipt"
                    )
                }
            }
            previous = activation.activationHash
            if index != activations.indices.last {
                let next = expectedSequence.addingReportingOverflow(1)
                guard !next.overflow else {
                    throw ExecutionGraphViolation(
                        id: "activation.sequence",
                        detail: "activation sequence is not contiguous"
                    )
                }
                expectedSequence = next.partialValue
            }
        }
    }

    public static func validateOutcomeChain(
        _ outcomes: [StepActivationOutcomeRecord],
        activations: [StepActivationRecord],
        initialPreviousHash: String? = nil,
        initialSequence: Int = 1
    ) throws {
        var activationById: [String: StepActivationRecord] = [:]
        for activation in activations {
            guard activationById.updateValue(
                activation,
                forKey: activation.activationId
            ) == nil else {
                throw ExecutionGraphViolation(
                    id: "activation.duplicate",
                    detail: "activation ID is duplicated"
                )
            }
        }
        var previous = initialPreviousHash
        var expectedSequence = initialSequence
        var ids = Set<String>()
        for (index, outcome) in outcomes.enumerated() {
            guard ids.insert(outcome.activationId).inserted else {
                throw ExecutionGraphViolation(
                    id: "activation.outcome-duplicate",
                    detail: "activation has more than one outcome"
                )
            }
            guard let activation = activationById[
                outcome.activationId
            ] else {
                throw ExecutionGraphViolation(
                    id: "activation.outcome-orphan",
                    detail: "outcome references an unknown activation"
                )
            }
            try validateOutcome(outcome, activation: activation)
            guard outcome.sequence == expectedSequence else {
                throw ExecutionGraphViolation(
                    id: "activation.outcome-sequence",
                    detail: "outcome sequence is not contiguous"
                )
            }
            guard outcome.previousOutcomeHash == previous else {
                throw ExecutionGraphViolation(
                    id: "activation.outcome-chain",
                    detail: "outcome previous hash mismatch"
                )
            }
            previous = outcome.outcomeHash
            if index != outcomes.indices.last {
                let next = expectedSequence.addingReportingOverflow(1)
                guard !next.overflow else {
                    throw ExecutionGraphViolation(
                        id: "activation.outcome-sequence",
                        detail: "outcome sequence is not contiguous"
                    )
                }
                expectedSequence = next.partialValue
            }
        }
        guard ids.count == activationById.count else {
            throw ExecutionGraphViolation(
                id: "activation.outcome-missing",
                detail: "every activation must have exactly one outcome"
            )
        }
    }

    private struct StepActivationPayload: Encodable {
        let schema = StepActivationRecord.currentSchema
        let activationId: String
        let receiptId: String
        let receiptHash: String
        let sequence: Int
        let stepLabel: String
        let logicalStepAttempt: Int
        let hostCallAttempt: Int
        let nodeHash: String
        let rawPromptHash: String
        let resolvedPromptHash: String
        let phaseDerivationPolicyHash: String
        let backend: String
        let model: String
        let authProfile: String
        let endpointConfigDigest: String
        let effectiveConfigurationHash: String
        let stepSoftDeadlineSeconds: Int
        let runSoftDeadlineSeconds: Int
        let monotonicStartNanoseconds: UInt64
        let boundaryKillPolicyDigest: String
        let workspaceSnapshotHash: String
        let dataSnapshotHashes: [String]
        let inputLanes: [ActivationInputLaneRecord]
        let upstreamOutputHashes: [String]
        let callLane: ActivationCallLaneBinding
        let previousActivationHash: String?
        let timestamp: String

        init(
            activationId: String,
            receiptId: String,
            receiptHash: String,
            sequence: Int,
            stepLabel: String,
            logicalStepAttempt: Int,
            hostCallAttempt: Int,
            nodeHash: String,
            rawPromptHash: String,
            resolvedPromptHash: String,
            phaseDerivationPolicyHash: String,
            backend: String,
            model: String,
            authProfile: String,
            endpointConfigDigest: String,
            effectiveConfigurationHash: String,
            stepSoftDeadlineSeconds: Int,
            runSoftDeadlineSeconds: Int,
            monotonicStartNanoseconds: UInt64,
            boundaryKillPolicyDigest: String,
            workspaceSnapshotHash: String,
            dataSnapshotHashes: [String],
            inputLanes: [ActivationInputLaneRecord],
            upstreamOutputHashes: [String],
            callLane: ActivationCallLaneBinding,
            previousActivationHash: String?,
            timestamp: String
        ) {
            self.activationId = activationId
            self.receiptId = receiptId
            self.receiptHash = receiptHash
            self.sequence = sequence
            self.stepLabel = stepLabel
            self.logicalStepAttempt = logicalStepAttempt
            self.hostCallAttempt = hostCallAttempt
            self.nodeHash = nodeHash
            self.rawPromptHash = rawPromptHash
            self.resolvedPromptHash = resolvedPromptHash
            self.phaseDerivationPolicyHash = phaseDerivationPolicyHash
            self.backend = backend
            self.model = model
            self.authProfile = authProfile
            self.endpointConfigDigest = endpointConfigDigest
            self.effectiveConfigurationHash =
                effectiveConfigurationHash
            self.stepSoftDeadlineSeconds = stepSoftDeadlineSeconds
            self.runSoftDeadlineSeconds = runSoftDeadlineSeconds
            self.monotonicStartNanoseconds =
                monotonicStartNanoseconds
            self.boundaryKillPolicyDigest =
                boundaryKillPolicyDigest
            self.workspaceSnapshotHash = workspaceSnapshotHash
            self.dataSnapshotHashes = dataSnapshotHashes
            self.inputLanes = inputLanes
            self.upstreamOutputHashes = upstreamOutputHashes
            self.callLane = callLane
            self.previousActivationHash = previousActivationHash
            self.timestamp = timestamp
        }

        init(_ record: StepActivationRecord) {
            self.init(
                activationId: record.activationId,
                receiptId: record.receiptId,
                receiptHash: record.receiptHash,
                sequence: record.sequence,
                stepLabel: record.stepLabel,
                logicalStepAttempt: record.logicalStepAttempt,
                hostCallAttempt: record.hostCallAttempt,
                nodeHash: record.nodeHash,
                rawPromptHash: record.rawPromptHash,
                resolvedPromptHash: record.resolvedPromptHash,
                phaseDerivationPolicyHash:
                    record.phaseDerivationPolicyHash,
                backend: record.backend,
                model: record.model,
                authProfile: record.authProfile,
                endpointConfigDigest: record.endpointConfigDigest,
                effectiveConfigurationHash:
                    record.effectiveConfigurationHash,
                stepSoftDeadlineSeconds:
                    record.stepSoftDeadlineSeconds,
                runSoftDeadlineSeconds:
                    record.runSoftDeadlineSeconds,
                monotonicStartNanoseconds:
                    record.monotonicStartNanoseconds,
                boundaryKillPolicyDigest:
                    record.boundaryKillPolicyDigest,
                workspaceSnapshotHash:
                    record.workspaceSnapshotHash,
                dataSnapshotHashes: record.dataSnapshotHashes,
                inputLanes: record.inputLanes,
                upstreamOutputHashes:
                    record.upstreamOutputHashes,
                callLane: record.callLane,
                previousActivationHash:
                    record.previousActivationHash,
                timestamp: record.timestamp
            )
        }
    }

    private struct StepActivationOutcomePayload: Encodable {
        let schema = StepActivationOutcomeRecord.currentSchema
        let activationId: String
        let activationHash: String
        let sequence: Int
        let stepLabel: String
        let hostCallAttempt: Int
        let terminationReason: String
        let returned: Bool
        let costMicrosUSD: Int64
        let turns: Int
        let inputTokens: Int
        let outputTokens: Int
        let outputHash: String
        let elapsedNanoseconds: UInt64
        let softDeadlineExceeded: Bool
        let callRecordRoot: String
        let coverage: String
        let timestamp: String
        let previousOutcomeHash: String?

        init(
            activationId: String,
            activationHash: String,
            sequence: Int,
            stepLabel: String,
            hostCallAttempt: Int,
            terminationReason: String,
            returned: Bool,
            costMicrosUSD: Int64,
            turns: Int,
            inputTokens: Int,
            outputTokens: Int,
            outputHash: String,
            elapsedNanoseconds: UInt64,
            softDeadlineExceeded: Bool,
            callRecordRoot: String,
            coverage: String,
            timestamp: String,
            previousOutcomeHash: String?
        ) {
            self.activationId = activationId
            self.activationHash = activationHash
            self.sequence = sequence
            self.stepLabel = stepLabel
            self.hostCallAttempt = hostCallAttempt
            self.terminationReason = terminationReason
            self.returned = returned
            self.costMicrosUSD = costMicrosUSD
            self.turns = turns
            self.inputTokens = inputTokens
            self.outputTokens = outputTokens
            self.outputHash = outputHash
            self.elapsedNanoseconds = elapsedNanoseconds
            self.softDeadlineExceeded = softDeadlineExceeded
            self.callRecordRoot = callRecordRoot
            self.coverage = coverage
            self.timestamp = timestamp
            self.previousOutcomeHash = previousOutcomeHash
        }

        init(_ record: StepActivationOutcomeRecord) {
            self.init(
                activationId: record.activationId,
                activationHash: record.activationHash,
                sequence: record.sequence,
                stepLabel: record.stepLabel,
                hostCallAttempt: record.hostCallAttempt,
                terminationReason: record.terminationReason,
                returned: record.returned,
                costMicrosUSD: record.costMicrosUSD,
                turns: record.turns,
                inputTokens: record.inputTokens,
                outputTokens: record.outputTokens,
                outputHash: record.outputHash,
                elapsedNanoseconds: record.elapsedNanoseconds,
                softDeadlineExceeded:
                    record.softDeadlineExceeded,
                callRecordRoot: record.callRecordRoot,
                coverage: record.coverage,
                timestamp: record.timestamp,
                previousOutcomeHash: record.previousOutcomeHash
            )
        }
    }
}

public struct AdmittedHostCallRequest: Sendable, Equatable {
    public let activationId: String
    public let stepLabel: String
    public let hostCallAttempt: Int
    public let prompt: String
    public let systemContext: String?
    public let backend: String
    public let model: String
    public let authProfile: String
    public let workingDirectory: String

    public init(
        activationId: String,
        stepLabel: String,
        hostCallAttempt: Int,
        prompt: String,
        systemContext: String?,
        backend: String,
        model: String,
        authProfile: String,
        workingDirectory: String
    ) {
        self.activationId = activationId
        self.stepLabel = stepLabel
        self.hostCallAttempt = hostCallAttempt
        self.prompt = prompt
        self.systemContext = systemContext
        self.backend = backend
        self.model = model
        self.authProfile = authProfile
        self.workingDirectory = workingDirectory
    }
}

public struct AdmittedHostCallResult: Sendable, Equatable {
    public enum Termination:
        String, Codable, Sendable, Equatable, Hashable
    {
        case completed
        case rateLimited
        case failed
        case crashed
    }

    public let termination: Termination
    public let output: String
    public let costMicrosUSD: Int64
    public let turns: Int
    public let inputTokens: Int
    public let outputTokens: Int

    public init(
        termination: Termination,
        output: String,
        costMicrosUSD: Int64 = 0,
        turns: Int = 1,
        inputTokens: Int = 0,
        outputTokens: Int = 0
    ) {
        self.termination = termination
        self.output = output
        self.costMicrosUSD = costMicrosUSD
        self.turns = turns
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}
