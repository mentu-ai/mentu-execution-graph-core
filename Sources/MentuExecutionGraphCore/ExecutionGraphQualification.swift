import Foundation

/// Closed authority supplied by a Mentu host before planning or execution.
///
/// Coding keys and required/optional behavior intentionally preserve
/// `mentu.execution-authority.v1`.
public struct ExecutionAuthorityEnvelope: Codable, Sendable, Equatable {
    public static let currentSchema = "mentu.execution-authority.v1"

    public let schema: String
    public let workspaceRoot: String
    public let discoveryReadPrefixes: [String]
    public let plannerEgressPrefixes: [String]
    public let plannerEgressByteCeiling: Int
    public let plannerProviders: [String]
    public let plannerModels: [String]
    public let plannerAuthProfiles: [String]
    public let plannerEndpoints: [String]
    public let footprintRoots: [String]
    public let changePrefixes: [String]
    public let executionPrimitive: String
    public let hostBackends: [String]
    public let hostModels: [String]
    public let hostAuthProfiles: [String]
    public let permissionModes: [String]
    public let sandboxPolicies: [String]
    public let approvalPolicies: [String]
    public let executionEndpoints: [String]
    public let toolRules: [CandidateToolRule]
    public let mcpServers: [String]
    public let pluginPolicy: String
    public let backgroundHookPolicy: String
    public let maximumStepCount: Int
    public let maximumDependencyDepth: Int
    public let maximumParallelSteps: Int
    public let perStepTokenCeiling: Int
    public let runTokenCeiling: Int
    public let perStepBudgetMicrosUSD: Int64
    public let runBudgetMicrosUSD: Int64
    public let stepSoftDeadlineSeconds: Int
    public let runSoftDeadlineSeconds: Int
    public let dynamicInputLanes: [String]
    public let requiredTransferMode: String
    public let networkBackendsPermitted: Bool
    public let expiry: String?
    public let provenance: String

    public init(
        workspaceRoot: String,
        discoveryReadPrefixes: [String],
        plannerEgressPrefixes: [String],
        plannerEgressByteCeiling: Int,
        plannerProviders: [String],
        plannerModels: [String],
        plannerAuthProfiles: [String],
        plannerEndpoints: [String],
        footprintRoots: [String],
        changePrefixes: [String],
        executionPrimitive: String = "host-loop.v1",
        hostBackends: [String],
        hostModels: [String],
        hostAuthProfiles: [String],
        permissionModes: [String],
        sandboxPolicies: [String],
        approvalPolicies: [String],
        executionEndpoints: [String],
        toolRules: [CandidateToolRule],
        mcpServers: [String],
        pluginPolicy: String = "disabled",
        backgroundHookPolicy: String = "disabled",
        maximumStepCount: Int,
        maximumDependencyDepth: Int,
        maximumParallelSteps: Int,
        perStepTokenCeiling: Int,
        runTokenCeiling: Int,
        perStepBudgetMicrosUSD: Int64,
        runBudgetMicrosUSD: Int64,
        stepSoftDeadlineSeconds: Int,
        runSoftDeadlineSeconds: Int,
        dynamicInputLanes: [String],
        requiredTransferMode: String = "worktree",
        networkBackendsPermitted: Bool,
        expiry: String? = nil,
        provenance: String,
        schema: String = ExecutionAuthorityEnvelope.currentSchema
    ) {
        self.schema = schema
        self.workspaceRoot = workspaceRoot
        self.discoveryReadPrefixes = discoveryReadPrefixes
        self.plannerEgressPrefixes = plannerEgressPrefixes
        self.plannerEgressByteCeiling = plannerEgressByteCeiling
        self.plannerProviders = plannerProviders
        self.plannerModels = plannerModels
        self.plannerAuthProfiles = plannerAuthProfiles
        self.plannerEndpoints = plannerEndpoints
        self.footprintRoots = footprintRoots
        self.changePrefixes = changePrefixes
        self.executionPrimitive = executionPrimitive
        self.hostBackends = hostBackends
        self.hostModels = hostModels
        self.hostAuthProfiles = hostAuthProfiles
        self.permissionModes = permissionModes
        self.sandboxPolicies = sandboxPolicies
        self.approvalPolicies = approvalPolicies
        self.executionEndpoints = executionEndpoints
        self.toolRules = toolRules
        self.mcpServers = mcpServers
        self.pluginPolicy = pluginPolicy
        self.backgroundHookPolicy = backgroundHookPolicy
        self.maximumStepCount = maximumStepCount
        self.maximumDependencyDepth = maximumDependencyDepth
        self.maximumParallelSteps = maximumParallelSteps
        self.perStepTokenCeiling = perStepTokenCeiling
        self.runTokenCeiling = runTokenCeiling
        self.perStepBudgetMicrosUSD = perStepBudgetMicrosUSD
        self.runBudgetMicrosUSD = runBudgetMicrosUSD
        self.stepSoftDeadlineSeconds = stepSoftDeadlineSeconds
        self.runSoftDeadlineSeconds = runSoftDeadlineSeconds
        self.dynamicInputLanes = dynamicInputLanes
        self.requiredTransferMode = requiredTransferMode
        self.networkBackendsPermitted = networkBackendsPermitted
        self.expiry = expiry
        self.provenance = provenance
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schema
        case workspaceRoot = "workspace_root"
        case discoveryReadPrefixes = "discovery_read_prefixes"
        case plannerEgressPrefixes = "planner_egress_prefixes"
        case plannerEgressByteCeiling = "planner_egress_byte_ceiling"
        case plannerProviders = "planner_providers"
        case plannerModels = "planner_models"
        case plannerAuthProfiles = "planner_auth_profiles"
        case plannerEndpoints = "planner_endpoints"
        case footprintRoots = "footprint_roots"
        case changePrefixes = "change_prefixes"
        case executionPrimitive = "execution_primitive"
        case hostBackends = "host_backends"
        case hostModels = "host_models"
        case hostAuthProfiles = "host_auth_profiles"
        case permissionModes = "permission_modes"
        case sandboxPolicies = "sandbox_policies"
        case approvalPolicies = "approval_policies"
        case executionEndpoints = "execution_endpoints"
        case toolRules = "tool_rules"
        case mcpServers = "mcp_servers"
        case pluginPolicy = "plugin_policy"
        case backgroundHookPolicy = "background_hook_policy"
        case maximumStepCount = "maximum_step_count"
        case maximumDependencyDepth = "maximum_dependency_depth"
        case maximumParallelSteps = "maximum_parallel_steps"
        case perStepTokenCeiling = "per_step_token_ceiling"
        case runTokenCeiling = "run_token_ceiling"
        case perStepBudgetMicrosUSD = "per_step_budget_micros_usd"
        case runBudgetMicrosUSD = "run_budget_micros_usd"
        case stepSoftDeadlineSeconds = "step_soft_deadline_seconds"
        case runSoftDeadlineSeconds = "run_soft_deadline_seconds"
        case dynamicInputLanes = "dynamic_input_lanes"
        case requiredTransferMode = "required_transfer_mode"
        case networkBackendsPermitted = "network_backends_permitted"
        case expiry
        case provenance
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownEnvelopeKeys(
            decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schema = try values.decode(String.self, forKey: .schema)
        workspaceRoot = try values.decode(String.self, forKey: .workspaceRoot)
        discoveryReadPrefixes = try values.decode(
            [String].self,
            forKey: .discoveryReadPrefixes
        )
        plannerEgressPrefixes = try values.decode(
            [String].self,
            forKey: .plannerEgressPrefixes
        )
        plannerEgressByteCeiling = try values.decode(
            Int.self,
            forKey: .plannerEgressByteCeiling
        )
        plannerProviders = try values.decode(
            [String].self,
            forKey: .plannerProviders
        )
        plannerModels = try values.decode([String].self, forKey: .plannerModels)
        plannerAuthProfiles = try values.decode(
            [String].self,
            forKey: .plannerAuthProfiles
        )
        plannerEndpoints = try values.decode(
            [String].self,
            forKey: .plannerEndpoints
        )
        footprintRoots = try values.decode(
            [String].self,
            forKey: .footprintRoots
        )
        changePrefixes = try values.decode(
            [String].self,
            forKey: .changePrefixes
        )
        executionPrimitive = try values.decode(
            String.self,
            forKey: .executionPrimitive
        )
        hostBackends = try values.decode([String].self, forKey: .hostBackends)
        hostModels = try values.decode([String].self, forKey: .hostModels)
        hostAuthProfiles = try values.decode(
            [String].self,
            forKey: .hostAuthProfiles
        )
        permissionModes = try values.decode(
            [String].self,
            forKey: .permissionModes
        )
        sandboxPolicies = try values.decode(
            [String].self,
            forKey: .sandboxPolicies
        )
        approvalPolicies = try values.decode(
            [String].self,
            forKey: .approvalPolicies
        )
        executionEndpoints = try values.decode(
            [String].self,
            forKey: .executionEndpoints
        )
        toolRules = try values.decode(
            [CandidateToolRule].self,
            forKey: .toolRules
        )
        mcpServers = try values.decode([String].self, forKey: .mcpServers)
        pluginPolicy = try values.decode(String.self, forKey: .pluginPolicy)
        backgroundHookPolicy = try values.decode(
            String.self,
            forKey: .backgroundHookPolicy
        )
        maximumStepCount = try values.decode(
            Int.self,
            forKey: .maximumStepCount
        )
        maximumDependencyDepth = try values.decode(
            Int.self,
            forKey: .maximumDependencyDepth
        )
        maximumParallelSteps = try values.decode(
            Int.self,
            forKey: .maximumParallelSteps
        )
        perStepTokenCeiling = try values.decode(
            Int.self,
            forKey: .perStepTokenCeiling
        )
        runTokenCeiling = try values.decode(Int.self, forKey: .runTokenCeiling)
        perStepBudgetMicrosUSD = try values.decode(
            Int64.self,
            forKey: .perStepBudgetMicrosUSD
        )
        runBudgetMicrosUSD = try values.decode(
            Int64.self,
            forKey: .runBudgetMicrosUSD
        )
        stepSoftDeadlineSeconds = try values.decode(
            Int.self,
            forKey: .stepSoftDeadlineSeconds
        )
        runSoftDeadlineSeconds = try values.decode(
            Int.self,
            forKey: .runSoftDeadlineSeconds
        )
        dynamicInputLanes = try values.decode(
            [String].self,
            forKey: .dynamicInputLanes
        )
        requiredTransferMode = try values.decode(
            String.self,
            forKey: .requiredTransferMode
        )
        networkBackendsPermitted = try values.decode(
            Bool.self,
            forKey: .networkBackendsPermitted
        )
        expiry = try values.decodeIfPresent(String.self, forKey: .expiry)
        provenance = try values.decode(String.self, forKey: .provenance)
    }
}

public struct QualificationCheck:
    Codable, Sendable, Equatable, Hashable
{
    public let id: String
    public let passed: Bool
    public let detail: String
    public let enforcing: Bool

    public init(
        id: String,
        passed: Bool,
        detail: String,
        enforcing: Bool = true
    ) {
        self.id = id
        self.passed = passed
        self.detail = detail
        self.enforcing = enforcing
    }
}

/// Trusted identity and complete ordered check inventory for a qualification
/// profile.
///
/// This value is deliberately supplied independently at validation and
/// admission time. A report can authenticate its own bytes, but it cannot
/// choose the profile contract against which those bytes are judged.
public struct ExecutionGraphQualificationProfileDescriptor:
    Codable, Sendable, Equatable, Hashable
{
    public let profileID: String
    public let expectedCheckIDs: [String]

    public init(profileID: String, expectedCheckIDs: [String]) {
        self.profileID = profileID
        self.expectedCheckIDs = expectedCheckIDs
    }
}

public struct QualificationReport: Codable, Sendable, Equatable {
    public static let currentSchema =
        "mentu.execution-qualification-report.v1"

    public let schema: String
    public let linterChecks: [QualificationCheck]
    public let envelopeChecks: [QualificationCheck]
    public let resolvedFootprints: [String]
    public let qualificationStateDigest: String
    public let bundleHash: String
    public let envelopeHash: String
    public let dependencyReportHash: String
    /// Digest of the externally supplied profile descriptor.
    ///
    /// Optional only so frozen v1 reports can still decode and round-trip.
    /// Every newly qualified execution writes it, and current admission
    /// refuses reports that do not carry it.
    public let profileCheckInventoryHash: String?
    public let reportHash: String

    public init(
        schema: String = QualificationReport.currentSchema,
        linterChecks: [QualificationCheck],
        envelopeChecks: [QualificationCheck],
        resolvedFootprints: [String],
        qualificationStateDigest: String,
        bundleHash: String,
        envelopeHash: String,
        dependencyReportHash: String,
        profileCheckInventoryHash: String? = nil,
        reportHash: String
    ) {
        self.schema = schema
        self.linterChecks = linterChecks
        self.envelopeChecks = envelopeChecks
        self.resolvedFootprints = resolvedFootprints
        self.qualificationStateDigest = qualificationStateDigest
        self.bundleHash = bundleHash
        self.envelopeHash = envelopeHash
        self.dependencyReportHash = dependencyReportHash
        self.profileCheckInventoryHash = profileCheckInventoryHash
        self.reportHash = reportHash
    }
}

/// Host-captured qualification facts that must remain bound into the report.
///
/// Git state and dependency resolution are deliberately values here. Core
/// neither inspects Git nor invokes a resolver.
public struct QualificationCapturedFacts:
    Codable, Sendable, Equatable, Hashable
{
    public let qualificationStateDigest: String
    public let dependencyReportHash: String
    public let requiredSandboxesAvailable: Bool

    public init(
        qualificationStateDigest: String,
        dependencyReportHash: String,
        requiredSandboxesAvailable: Bool = true
    ) {
        self.qualificationStateDigest = qualificationStateDigest
        self.dependencyReportHash = dependencyReportHash
        self.requiredSandboxesAvailable = requiredSandboxesAvailable
    }
}

public struct QualifiedExecution: Sendable, Equatable {
    public let bundle: ExecutionArtifactBundle
    public let envelope: ExecutionAuthorityEnvelope
    public let effectivePolicy: EffectiveExecutionPolicy
    public let qualification: QualificationReport

    public init(
        bundle: ExecutionArtifactBundle,
        envelope: ExecutionAuthorityEnvelope,
        effectivePolicy: EffectiveExecutionPolicy,
        qualification: QualificationReport
    ) {
        self.bundle = bundle
        self.envelope = envelope
        self.effectivePolicy = effectivePolicy
        self.qualification = qualification
    }
}

/// Mentu-owned mechanical qualification over an already lowered definition.
public protocol ExecutionGraphQualificationProfile: Sendable {
    /// Stable profile identity and complete ordered inventory this profile is
    /// expected to emit.
    ///
    /// Qualification refuses missing, extra, duplicate, or reordered IDs
    /// before the descriptor digest is persisted.
    var descriptor: ExecutionGraphQualificationProfileDescriptor { get }

    func qualify(
        definition: ExecutionGraphDefinition,
        bundle: ExecutionArtifactBundle,
        envelope: ExecutionAuthorityEnvelope
    ) async throws -> [QualificationCheck]
}

public struct NoopExecutionGraphQualificationProfile:
    ExecutionGraphQualificationProfile
{
    public init() {}

    public var descriptor: ExecutionGraphQualificationProfileDescriptor {
        ExecutionGraphQualificationProfileDescriptor(
            profileID: "mentu.core.noop.v1",
            expectedCheckIDs: ["profile.noop"]
        )
    }

    public func qualify(
        definition: ExecutionGraphDefinition,
        bundle: ExecutionArtifactBundle,
        envelope: ExecutionAuthorityEnvelope
    ) async throws -> [QualificationCheck] {
        [
            QualificationCheck(
                id: "profile.noop",
                passed: true,
                detail: "no host-specific qualification checks configured",
                enforcing: false
            ),
        ]
    }
}

/// Deterministic core qualification over values captured by a host.
public enum ExecutionGraphQualification: Sendable {
    public static func qualify(
        definition: ExecutionGraphDefinition,
        bundle: ExecutionArtifactBundle,
        envelope: ExecutionAuthorityEnvelope,
        effectivePolicy policy: EffectiveExecutionPolicy,
        capturedFacts: QualificationCapturedFacts,
        profile: any ExecutionGraphQualificationProfile,
        clock: any ExecutionGraphClock
    ) async throws -> QualifiedExecution {
        let instant = clock.now()
        try validateEnvelopeHeader(
            envelope,
            policy: policy,
            at: instant
        )
        try validateDefinition(definition)
        guard definition == bundle.definition else {
            throw ExecutionGraphViolation(
                id: "qualification.definition",
                detail: "profile definition does not equal the bundled definition"
            )
        }
        try validateBundle(bundle, policy: policy)

        let envelopeChecks = try authoritySubsetChecks(
            bundle: bundle,
            envelope: envelope,
            effectivePolicy: policy,
            requiredSandboxesAvailable:
                capturedFacts.requiredSandboxesAvailable
        )
        if let failed = envelopeChecks.first(where: {
            $0.enforcing && !$0.passed
        }) {
            throw ExecutionGraphViolation(id: failed.id, detail: failed.detail)
        }

        guard !capturedFacts.qualificationStateDigest.isEmpty,
              !capturedFacts.dependencyReportHash.isEmpty
        else {
            throw ExecutionGraphViolation(
                id: "qualification.captured-facts",
                detail: "qualification state and dependency report digests are required"
            )
        }

        let profileChecks: [QualificationCheck]
        do {
            profileChecks = try await profile.qualify(
                definition: definition,
                bundle: bundle,
                envelope: envelope
            )
        } catch let violation as ExecutionGraphViolation {
            throw violation
        } catch {
            throw ExecutionGraphViolation(
                id: "qualification.profile",
                detail: "qualification profile failed without a typed violation"
            )
        }
        let linterChecks = try validatedProfileChecks(profileChecks)
        let trustedProfile = try validatedProfileDescriptor(
            profile.descriptor
        )
        let expectedProfileCheckIDs = trustedProfile.expectedCheckIDs
        guard linterChecks.map(\.id) == expectedProfileCheckIDs else {
            throw ExecutionGraphViolation(
                id: "qualification.check-inventory",
                detail:
                    "profile checks do not match the declared complete inventory"
            )
        }
        let profileCheckInventoryHash =
            try ExecutionGraphCanonicalizer.hash(trustedProfile)
        if let failed = linterChecks.first(where: {
            $0.enforcing && !$0.passed
        }) {
            throw ExecutionGraphViolation(id: failed.id, detail: failed.detail)
        }

        let footprints = Array(
            Set(bundle.contracts.flatMap(\.footprint))
        ).sorted()
        let envelopeHash = try ExecutionGraphCanonicalizer.hash(envelope)
        let payload = QualificationReportPayload(
            linterChecks: linterChecks,
            envelopeChecks: envelopeChecks,
            resolvedFootprints: footprints,
            qualificationStateDigest:
                capturedFacts.qualificationStateDigest,
            bundleHash: bundle.executableHash,
            envelopeHash: envelopeHash,
            dependencyReportHash: capturedFacts.dependencyReportHash,
            profileCheckInventoryHash: profileCheckInventoryHash
        )
        let report = QualificationReport(
            linterChecks: payload.linterChecks,
            envelopeChecks: payload.envelopeChecks,
            resolvedFootprints: payload.resolvedFootprints,
            qualificationStateDigest:
                payload.qualificationStateDigest,
            bundleHash: payload.bundleHash,
            envelopeHash: payload.envelopeHash,
            dependencyReportHash: payload.dependencyReportHash,
            profileCheckInventoryHash:
                payload.profileCheckInventoryHash,
            reportHash: try ExecutionGraphCanonicalizer.hash(payload)
        )
        return QualifiedExecution(
            bundle: bundle,
            envelope: envelope,
            effectivePolicy: policy,
            qualification: report
        )
    }

    /// Revalidates every qualification identity and replays the trusted host
    /// profile against the qualified inputs.
    ///
    /// A descriptor authenticates only the profile identity and check
    /// inventory. Admission must also compare the complete trusted outcomes
    /// so report-controlled `passed`, `enforcing`, or `detail` values cannot
    /// become authority by rehashing the report.
    public static func validateQualifiedExecution(
        _ qualified: QualifiedExecution,
        trustedProfile: any ExecutionGraphQualificationProfile,
        at instant: Date
    ) async throws {
        let trustedDescriptor = try validatedProfileDescriptor(
            trustedProfile.descriptor
        )
        try validateEnvelopeHeader(
            qualified.envelope,
            policy: qualified.effectivePolicy,
            at: instant
        )
        try validateDefinition(qualified.bundle.definition)
        try validateBundle(
            qualified.bundle,
            policy: qualified.effectivePolicy
        )
        try validateReport(
            qualified.qualification,
            trustedProfile: trustedDescriptor
        )

        let expectedProfileChecks = try validatedProfileChecks(
            await trustedProfile.qualify(
                definition: qualified.bundle.definition,
                bundle: qualified.bundle,
                envelope: qualified.envelope
            )
        )
        guard expectedProfileChecks.map(\.id)
                == trustedDescriptor.expectedCheckIDs
        else {
            throw ExecutionGraphViolation(
                id: "qualification.trusted-profile-inventory",
                detail:
                    "trusted profile outcomes do not match its declared inventory"
            )
        }
        guard qualified.qualification.linterChecks
                == expectedProfileChecks
        else {
            throw ExecutionGraphViolation(
                id: "qualification.profile-outcome-drift",
                detail:
                    "persisted profile outcomes differ from trusted verification"
            )
        }

        let expectedEnvelopeChecks = try authoritySubsetChecks(
            bundle: qualified.bundle,
            envelope: qualified.envelope,
            effectivePolicy: qualified.effectivePolicy
        )
        if let failed = expectedEnvelopeChecks.first(where: {
            $0.enforcing && !$0.passed
        }) {
            throw ExecutionGraphViolation(
                id: failed.id,
                detail: failed.detail
            )
        }
        let validatedProfileChecks = try validatedProfileChecks(
            qualified.qualification.linterChecks
        )
        let persistedProfileCheckIDs = validatedProfileChecks.map(\.id)
        let persistedProfileCheckInventoryHash =
            try ExecutionGraphCanonicalizer.hash(trustedDescriptor)
        let normalizedStoredEnvelopeChecks = try sortedChecks(
            qualified.qualification.envelopeChecks,
            surface: "stored envelope"
        )
        let expectedFootprints = Array(
            Set(qualified.bundle.contracts.flatMap(\.footprint))
        ).sorted()
        guard qualified.qualification.linterChecks
                == validatedProfileChecks,
              qualified.qualification.envelopeChecks
                == normalizedStoredEnvelopeChecks,
              qualified.qualification.envelopeChecks
                == expectedEnvelopeChecks,
              qualified.qualification.envelopeChecks.allSatisfy({
                  $0.id.hasPrefix("envelope.")
              }),
              qualified.qualification.profileCheckInventoryHash
                == persistedProfileCheckInventoryHash,
              persistedProfileCheckIDs
                == trustedDescriptor.expectedCheckIDs,
              qualified.qualification.resolvedFootprints
                == expectedFootprints,
              qualified.qualification.bundleHash
                == qualified.bundle.executableHash,
              qualified.qualification.envelopeHash
                == (try ExecutionGraphCanonicalizer.hash(
                    qualified.envelope
                )),
              !qualified.qualification.qualificationStateDigest.isEmpty,
              !qualified.qualification.dependencyReportHash.isEmpty
        else {
            throw ExecutionGraphViolation(
                id: "qualification.identity-drift",
                detail: "qualified execution no longer matches its bound values"
            )
        }
    }

    /// Validates that a decoded value is a closed, mechanical admitted graph.
    public static func validateDefinition(
        _ definition: ExecutionGraphDefinition
    ) throws {
        guard !definition.name.isEmpty,
              !definition.workspace.isEmpty,
              !definition.steps.isEmpty
        else {
            throw ExecutionGraphViolation(
                id: "graph.definition.empty",
                detail: "name, workspace, and at least one step are required"
            )
        }
        guard definition.transferMode == "worktree",
              definition.stepContract == "enforce",
              !definition.canary
        else {
            throw ExecutionGraphViolation(
                id: "graph.definition.closed-shape",
                detail: "admitted v1 requires worktree, enforced contracts, and canary disabled"
            )
        }

        let labels = definition.steps.map(\.label)
        guard labels.allSatisfy({ !$0.isEmpty }),
              Set(labels).count == labels.count
        else {
            throw ExecutionGraphViolation(
                id: "graph.definition.duplicate-step",
                detail: "step labels must be nonempty and unique"
            )
        }
        let known = Set(labels)
        for step in definition.steps {
            guard step.maxRetries == 0,
                  step.isolation == "worktree",
                  step.shared == step.concurrentSafe
            else {
                throw ExecutionGraphViolation(
                    id: "graph.definition.closed-step-shape",
                    detail: "step \(step.label) widens the admitted host-only shape"
                )
            }
            guard !step.dependsOn.contains(step.label) else {
                throw ExecutionGraphViolation(
                    id: "graph.definition.self-dependency",
                    detail: "step \(step.label) depends on itself"
                )
            }
            if let unknown = step.dependsOn.first(where: {
                !known.contains($0)
            }) {
                throw ExecutionGraphViolation(
                    id: "graph.definition.unknown-dependency",
                    detail: "step \(step.label) depends on unknown step \(unknown)"
                )
            }
            guard Set(step.dependsOn).count == step.dependsOn.count else {
                throw ExecutionGraphViolation(
                    id: "graph.definition.duplicate-dependency",
                    detail: "step \(step.label) repeats a dependency"
                )
            }
        }

        do {
            _ = try ExecutionDAG(
                nodes: definition.steps.map {
                    ExecutionDAG.Node(
                        id: $0.label,
                        dependencies: $0.dependsOn,
                        dispatchMode: $0.concurrentSafe
                            ? .parallelSafe
                            : .exclusive
                    )
                }
            ).validatedFrontiers()
        } catch let violation as ExecutionGraphViolation {
            if violation.id == GraphSchedulerReasonID.cycle {
                throw ExecutionGraphViolation(
                    id: "graph.definition.cycle",
                    detail: violation.detail
                )
            }
            throw violation
        }
    }

    /// Returns the pure authority-subset checks in stable ID order.
    public static func authoritySubsetChecks(
        bundle: ExecutionArtifactBundle,
        envelope: ExecutionAuthorityEnvelope,
        effectivePolicy policy: EffectiveExecutionPolicy,
        requiredSandboxesAvailable: Bool = true
    ) throws -> [QualificationCheck] {
        let root = standardizedAbsolutePath(policy.logicalWorkspaceRoot)
        var checks: [QualificationCheck] = []
        func add(_ id: String, _ passed: Bool, _ detail: String) {
            checks.append(
                QualificationCheck(
                    id: id,
                    passed: passed,
                    detail: detail
                )
            )
        }

        let authorizedFootprints = Set(
            envelope.footprintRoots.map(standardizedAbsolutePath)
        )
        let footprints = bundle.contracts.flatMap(\.footprint)
        add(
            "envelope.footprints",
            !footprints.isEmpty
                && footprints.allSatisfy {
                    let path = standardizedAbsolutePath($0)
                    return path == root && authorizedFootprints.contains(path)
                },
            "every footprint must be the authorized logical workspace root"
        )
        add(
            "envelope.execution-primitive",
            envelope.executionPrimitive == "host-loop.v1",
            "execution primitive must be host-loop.v1"
        )
        add(
            "envelope.transfer-mode",
            envelope.requiredTransferMode == "worktree"
                && policy.transferMode == "worktree"
                && bundle.definition.transferMode == "worktree",
            "admitted v1 requires worktree transfer"
        )
        add(
            "envelope.backend",
            envelope.hostBackends.contains(policy.fixedBackend)
                && bundle.definition.steps.allSatisfy {
                    $0.backend == policy.fixedBackend
                },
            "fixed backend is outside the envelope"
        )
        add(
            "envelope.model",
            envelope.hostModels.contains(policy.fixedModel)
                && bundle.definition.steps.allSatisfy {
                    $0.model == policy.fixedModel
                },
            "fixed model is outside the envelope"
        )
        let fallbackProfileIDs =
            policy.authFallbackChain.map(\.profileId)
        let authBindingsAreClosed =
            !policy.authFallbackChain.isEmpty
            && Set(fallbackProfileIDs).count == fallbackProfileIDs.count
            && fallbackProfileIDs.filter {
                $0 == policy.initialAuthProfile
            }.count == 1
            && policy.authFallbackChain.allSatisfy {
                !$0.profileId.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty
                    && !$0.configDigest.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
            }
        add(
            "envelope.auth",
            authBindingsAreClosed
                && envelope.hostAuthProfiles.contains(
                    policy.initialAuthProfile
                )
                && policy.authFallbackChain.allSatisfy {
                    envelope.hostAuthProfiles.contains($0.profileId)
                }
                && bundle.definition.auth == policy.initialAuthProfile
                && bundle.definition.steps.allSatisfy {
                    $0.auth == policy.initialAuthProfile
                },
            "initial or fallback auth profile is outside the envelope"
        )
        add(
            "envelope.endpoint",
            envelope.executionEndpoints.contains(policy.configuredEndpoint),
            "configured initial execution endpoint is outside the envelope"
        )
        add(
            "envelope.network",
            envelope.networkBackendsPermitted,
            "network-capable host backend was not explicitly authorized"
        )
        add(
            "envelope.closed-extensions",
            envelope.pluginPolicy == "disabled"
                && envelope.backgroundHookPolicy == "disabled"
                && policy.pluginPolicy == "disabled"
                && policy.backgroundHookPolicy == "disabled"
                && policy.outerCallEvidencePolicy == "required",
            "plugins, background hooks, and call-evidence posture must be closed"
        )

        let stepCount = bundle.definition.steps.count
        let frontiers = try ExecutionDAG(
            nodes: bundle.definition.steps.map {
                ExecutionDAG.Node(
                    id: $0.label,
                    dependencies: $0.dependsOn,
                    dispatchMode: $0.concurrentSafe
                        ? .parallelSafe
                        : .exclusive
                )
            }
        ).validatedFrontiers()
        let depth = frontiers.count
        let width = frontiers.map(\.count).max() ?? 0
        add(
            "envelope.graph-limits",
            stepCount > 0
                && stepCount <= envelope.maximumStepCount
                && depth <= envelope.maximumDependencyDepth
                && width <= envelope.maximumParallelSteps
                && policy.maximumParallelSteps > 0
                && policy.maximumParallelSteps
                    <= envelope.maximumParallelSteps,
            "graph size, depth, or parallelism exceeds the envelope"
        )

        let allowedChanges = try ExecutionGraphCanonicalizer
            .normalizeSetPaths(envelope.changePrefixes)
        let changesValid = bundle.contracts
            .flatMap(\.expectedChanges)
            .allSatisfy { pattern in
                guard let prefix = staticPrefix(pattern) else {
                    return false
                }
                return allowedChanges.contains {
                    prefix == $0 || prefix.hasPrefix($0 + "/")
                }
            }
        add(
            "envelope.change-prefixes",
            changesValid,
            "an expected-change prefix is outside the envelope"
        )

        let allowedTools = Set(envelope.toolRules.map(toolKey))
        add(
            "envelope.tools",
            bundle.contracts.flatMap(\.toolRules).allSatisfy {
                allowedTools.contains(toolKey($0))
            },
            "a requested tool rule is outside the envelope"
        )
        add(
            "envelope.mcp",
            bundle.contracts.flatMap(\.mcpServers).allSatisfy {
                envelope.mcpServers.contains($0)
            },
            "a requested MCP server is outside the envelope"
        )

        let permissionsValid = bundle.contracts.allSatisfy {
            $0.permissionMode != "bypassPermissions"
                && envelope.permissionModes.contains($0.permissionMode)
        } && envelope.permissionModes.contains(policy.defaultPermissionMode)
            && bundle.definition.steps.allSatisfy {
                envelope.permissionModes.contains($0.permissionMode)
            }
        add(
            "envelope.permissions",
            permissionsValid,
            "permission mode is forbidden or outside the envelope"
        )

        let approvalsValid = bundle.contracts.allSatisfy {
            $0.approvalPolicy == "never"
                && envelope.approvalPolicies.contains($0.approvalPolicy)
        } && policy.defaultApprovalPolicy == "never"
            && bundle.definition.approvalPolicy == "never"
            && bundle.definition.steps.allSatisfy {
                $0.approvalPolicy == "never"
            }
        add(
            "envelope.approvals",
            approvalsValid,
            "approval policy may widen authority after admission"
        )

        let sandboxMembershipValid = bundle.contracts.allSatisfy {
            envelope.sandboxPolicies.contains($0.sandboxPolicy)
        } && envelope.sandboxPolicies.contains(policy.defaultSandboxPolicy)
            && bundle.definition.sandboxPolicy
                == policy.defaultSandboxPolicy
            && bundle.definition.steps.allSatisfy {
                envelope.sandboxPolicies.contains($0.sandboxPolicy)
            }
        add(
            "envelope.sandbox",
            sandboxMembershipValid && requiredSandboxesAvailable,
            "required sandbox is unavailable or outside the envelope"
        )

        let perStepBudgetsValid = bundle.contracts.allSatisfy {
            $0.tokenLimit > 0
                && $0.budgetMicrosUSD >= 0
                && $0.timeoutSeconds > 0
                && $0.tokenLimit <= envelope.perStepTokenCeiling
                && $0.tokenLimit <= policy.perStepTokenCeiling
                && $0.budgetMicrosUSD
                    <= envelope.perStepBudgetMicrosUSD
                && $0.budgetMicrosUSD
                    <= policy.perStepBudgetMicrosUSD
                && $0.timeoutSeconds
                    <= envelope.stepSoftDeadlineSeconds
                && $0.timeoutSeconds
                    <= policy.stepSoftDeadlineSeconds
        }
        var runTokens = 0
        var runBudget: Int64 = 0
        for contract in bundle.contracts {
            let tokenTotal = runTokens.addingReportingOverflow(
                contract.tokenLimit
            )
            let budgetTotal = runBudget.addingReportingOverflow(
                contract.budgetMicrosUSD
            )
            guard !tokenTotal.overflow, !budgetTotal.overflow else {
                throw ExecutionGraphViolation(
                    id: "envelope.budgets",
                    detail: "token, cost, or soft-deadline budget exceeds the envelope"
                )
            }
            runTokens = tokenTotal.partialValue
            runBudget = budgetTotal.partialValue
        }
        let policyWithinEnvelope =
            policy.runTokenCeiling <= envelope.runTokenCeiling
            && policy.perStepTokenCeiling
                <= envelope.perStepTokenCeiling
            && policy.runBudgetMicrosUSD
                <= envelope.runBudgetMicrosUSD
            && policy.perStepBudgetMicrosUSD
                <= envelope.perStepBudgetMicrosUSD
            && policy.runSoftDeadlineSeconds
                <= envelope.runSoftDeadlineSeconds
            && policy.stepSoftDeadlineSeconds
                <= envelope.stepSoftDeadlineSeconds
        add(
            "envelope.budgets",
            perStepBudgetsValid
                && runTokens <= envelope.runTokenCeiling
                && runTokens <= policy.runTokenCeiling
                && runBudget <= envelope.runBudgetMicrosUSD
                && runBudget <= policy.runBudgetMicrosUSD
                && policyWithinEnvelope,
            "token, cost, or soft-deadline budget exceeds the envelope"
        )

        add(
            "envelope.closed-step-shape",
            bundle.definition.steps.allSatisfy {
                $0.maxRetries == 0
                    && $0.isolation == "worktree"
                    && $0.shared == $0.concurrentSafe
            },
            "step requests a non-host, semantic, retry, wave, or hard-timeout path"
        )
        return checks.sorted { $0.id < $1.id }
    }

    /// Checks report self-consistency and the trusted descriptor inventory.
    ///
    /// This deliberately does not grant admission authority: a descriptor
    /// cannot authenticate outcome values. Admission uses
    /// `validateQualifiedExecution(_:trustedProfile:at:)`, which replays the
    /// trusted profile and compares every complete check.
    public static func validateReport(
        _ report: QualificationReport,
        trustedProfile: ExecutionGraphQualificationProfileDescriptor
    ) throws {
        let trustedProfile = try validatedProfileDescriptor(trustedProfile)
        guard report.schema == QualificationReport.currentSchema else {
            throw ExecutionGraphViolation(
                id: "qualification.report-schema",
                detail: "unsupported qualification report schema"
            )
        }
        let payload = QualificationReportPayload(
            linterChecks: report.linterChecks,
            envelopeChecks: report.envelopeChecks,
            resolvedFootprints: report.resolvedFootprints,
            qualificationStateDigest: report.qualificationStateDigest,
            bundleHash: report.bundleHash,
            envelopeHash: report.envelopeHash,
            dependencyReportHash: report.dependencyReportHash,
            profileCheckInventoryHash:
                report.profileCheckInventoryHash
        )
        guard try ExecutionGraphCanonicalizer.hash(payload)
            == report.reportHash
        else {
            throw ExecutionGraphViolation(
                id: "qualification.report-hash",
                detail: "qualification report hash mismatch"
            )
        }
        let checks = try validatedProfileChecks(report.linterChecks)
        guard report.profileCheckInventoryHash
                == (try ExecutionGraphCanonicalizer.hash(trustedProfile)),
              checks.map(\.id) == trustedProfile.expectedCheckIDs
        else {
            throw ExecutionGraphViolation(
                id: "qualification.check-inventory",
                detail:
                    "persisted profile checks do not match the trusted profile descriptor"
            )
        }
        if let failed = (
            report.linterChecks + report.envelopeChecks
        ).first(where: { $0.enforcing && !$0.passed }) {
            throw ExecutionGraphViolation(
                id: failed.id,
                detail: failed.detail
            )
        }
    }

    private static func validateEnvelopeHeader(
        _ envelope: ExecutionAuthorityEnvelope,
        policy: EffectiveExecutionPolicy,
        at instant: Date
    ) throws {
        guard envelope.schema == ExecutionAuthorityEnvelope.currentSchema else {
            throw ExecutionGraphViolation(
                id: "envelope.schema",
                detail: "unsupported authority schema"
            )
        }
        if let expiry = envelope.expiry {
            guard let expiryDate = parseTimestamp(expiry),
                  expiryDate > instant
            else {
                throw ExecutionGraphViolation(
                    id: "envelope.expired",
                    detail: "authority envelope is expired or malformed"
                )
            }
        }
        let policyRoot = standardizedAbsolutePath(
            policy.logicalWorkspaceRoot
        )
        let envelopeRoot = standardizedAbsolutePath(envelope.workspaceRoot)
        guard policyRoot == envelopeRoot else {
            throw ExecutionGraphViolation(
                id: "envelope.workspace",
                detail: "effective workspace does not match authority workspace"
            )
        }
    }

    private static func validateBundle(
        _ bundle: ExecutionArtifactBundle,
        policy: EffectiveExecutionPolicy
    ) throws {
        guard bundle.schema == ExecutionArtifactBundle.currentSchema else {
            throw ExecutionGraphViolation(
                id: "bundle.schema",
                detail: "unsupported executable bundle schema"
            )
        }
        guard standardizedAbsolutePath(bundle.definition.workspace)
                == standardizedAbsolutePath(policy.logicalWorkspaceRoot),
              standardizedAbsolutePath(bundle.discovery.workspaceRoot)
                == standardizedAbsolutePath(policy.logicalWorkspaceRoot)
        else {
            throw ExecutionGraphViolation(
                id: "discovery.workspace",
                detail: "definition or discovery workspace mismatch"
            )
        }

        let labels = bundle.definition.steps.map(\.label)
        let promptLabels = bundle.prompts.map(\.stepLabel)
        let contractLabels = bundle.contracts.map(\.stepLabel)
        guard Set(labels).count == labels.count,
              Set(promptLabels).count == promptLabels.count,
              Set(contractLabels).count == contractLabels.count,
              Set(labels) == Set(promptLabels),
              Set(labels) == Set(contractLabels)
        else {
            throw ExecutionGraphViolation(
                id: "qualification.artifact-count",
                detail: "definition, prompt, and contract labels must match exactly"
            )
        }

        for prompt in bundle.prompts {
            guard ExecutionGraphDigest.sha256(prompt.body) == prompt.sha256
            else {
                throw ExecutionGraphViolation(
                    id: "qualification.prompt-hash",
                    detail: "sealed prompt hash mismatch for \(prompt.stepLabel)"
                )
            }
        }

        let contractByLabel = Dictionary(
            uniqueKeysWithValues: bundle.contracts.map {
                ($0.stepLabel, $0)
            }
        )
        for step in bundle.definition.steps {
            guard let contract = contractByLabel[step.label],
                  contract.expectedChanges == step.expectedChanges,
                  contract.footprint == step.footprint,
                  contract.verifyRequirements == step.verifyRequirements,
                  contract.concurrencySafe == step.concurrentSafe,
                  contract.timeoutSeconds == step.timeout,
                  contract.maxPhases == step.maxPhases,
                  contract.permissionMode == step.permissionMode,
                  contract.sandboxPolicy == step.sandboxPolicy,
                  contract.approvalPolicy == step.approvalPolicy,
                  contract.toolRules == step.permissions,
                  contract.mcpServers == step.mcpServers,
                  contract.tokenLimit == step.taskBudget,
                  contract.timeoutSeconds
                    == step.limits.maxDurationSeconds,
                  costLimitMatches(
                    maxCostUSD: step.limits.maxCostUSD,
                    budgetMicrosUSD: contract.budgetMicrosUSD
                  )
            else {
                throw ExecutionGraphViolation(
                    id: "qualification.contract-drift",
                    detail: "contract manifest drifted for \(step.label)"
                )
            }
        }

        do {
            try ExecutionGraphLowerer.validateIdentity(
                bundle: bundle,
                policy: policy
            )
        } catch let violation as ExecutionGraphViolation {
            throw violation.id == "graph.lowering.hash-drift"
                ? ExecutionGraphViolation(
                    id: "bundle.hash",
                    detail: "executable bundle identity mismatch"
                )
                : violation
        }
    }

    private static func validatedProfileChecks(
        _ checks: [QualificationCheck]
    ) throws -> [QualificationCheck] {
        let validated = try validatedChecksPreservingOrder(
            checks,
            surface: "profile"
        )
        guard !validated.isEmpty else {
            throw ExecutionGraphViolation(
                id: "qualification.check",
                detail: "profile must return at least one persisted check"
            )
        }
        return validated
    }

    private static func validatedExpectedProfileCheckIDs(
        _ ids: [String]
    ) throws -> [String] {
        guard !ids.isEmpty,
              ids.allSatisfy({
                  !$0.trimmingCharacters(
                      in: .whitespacesAndNewlines
                  ).isEmpty
              })
        else {
            throw ExecutionGraphViolation(
                id: "qualification.check-inventory",
                detail:
                    "profile must declare a complete nonempty check-ID inventory"
            )
        }
        guard Set(ids).count == ids.count else {
            throw ExecutionGraphViolation(
                id: "qualification.check-inventory",
                detail: "profile check inventory contains duplicate IDs"
            )
        }
        return ids
    }

    private static func validatedProfileDescriptor(
        _ descriptor: ExecutionGraphQualificationProfileDescriptor
    ) throws -> ExecutionGraphQualificationProfileDescriptor {
        guard !descriptor.profileID.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            throw ExecutionGraphViolation(
                id: "qualification.profile-identity",
                detail: "trusted qualification profile ID is required"
            )
        }
        return ExecutionGraphQualificationProfileDescriptor(
            profileID: descriptor.profileID,
            expectedCheckIDs: try validatedExpectedProfileCheckIDs(
                descriptor.expectedCheckIDs
            )
        )
    }

    /// Profile order is a persisted compatibility input. Mentu's mechanical
    /// linter has a historical 15-check gate order, so validating a profile
    /// must never alphabetize or otherwise rewrite the returned array.
    private static func validatedChecksPreservingOrder(
        _ checks: [QualificationCheck],
        surface: String
    ) throws -> [QualificationCheck] {
        guard checks.allSatisfy({
            !$0.id.isEmpty && !$0.detail.isEmpty
        }) else {
            throw ExecutionGraphViolation(
                id: "qualification.check",
                detail: "\(surface) checks require stable IDs and details"
            )
        }
        guard Set(checks.map(\.id)).count == checks.count else {
            throw ExecutionGraphViolation(
                id: "qualification.check-duplicate",
                detail: "\(surface) returned duplicate check IDs"
            )
        }
        return checks
    }

    private static func sortedChecks(
        _ checks: [QualificationCheck],
        surface: String
    ) throws -> [QualificationCheck] {
        let validated = try validatedChecksPreservingOrder(
            checks,
            surface: surface
        )
        return validated.sorted { lhs, rhs in
            if lhs.id != rhs.id { return lhs.id < rhs.id }
            if lhs.enforcing != rhs.enforcing {
                return lhs.enforcing && !rhs.enforcing
            }
            return lhs.detail < rhs.detail
        }
    }

    private static func costLimitMatches(
        maxCostUSD: Double,
        budgetMicrosUSD: Int64
    ) -> Bool {
        guard maxCostUSD.isFinite else {
            return false
        }
        let roundedMicros = (maxCostUSD * 1_000_000.0).rounded()
        return roundedMicros.isFinite
            && roundedMicros == Double(budgetMicrosUSD)
    }

    private static func staticPrefix(_ pattern: String) -> String? {
        let wildcard = pattern.firstIndex {
            "*?[".contains($0)
        }
        let raw = wildcard.map {
            String(pattern[..<$0])
        } ?? pattern
        let prefix = raw.trimmingCharacters(
            in: CharacterSet(charactersIn: "/")
        )
        return prefix.isEmpty ? nil : prefix
    }

    private static func toolKey(_ rule: CandidateToolRule) -> String {
        "\(rule.tool)\u{0}\(rule.behavior)\u{0}\(rule.pattern ?? "")"
    }

    static func standardizedAbsolutePath(_ path: String) -> String {
        URL(filePath: path).standardizedFileURL.path
    }

    static func parseTimestamp(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds,
        ]
        if let date = fractional.date(from: value) {
            return date
        }
        let ordinary = ISO8601DateFormatter()
        ordinary.formatOptions = [.withInternetDateTime]
        return ordinary.date(from: value)
    }

    private struct QualificationReportPayload: Encodable {
        let schema = QualificationReport.currentSchema
        let linterChecks: [QualificationCheck]
        let envelopeChecks: [QualificationCheck]
        let resolvedFootprints: [String]
        let qualificationStateDigest: String
        let bundleHash: String
        let envelopeHash: String
        let dependencyReportHash: String
        let profileCheckInventoryHash: String?
    }
}

private struct EnvelopeCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}

private func rejectUnknownEnvelopeKeys(
    _ decoder: Decoder,
    allowed: Set<String>
) throws {
    let container = try decoder.container(
        keyedBy: EnvelopeCodingKey.self
    )
    let unknown = container.allKeys
        .map(\.stringValue)
        .filter { !allowed.contains($0) }
        .sorted()
    guard unknown.isEmpty else {
        throw ExecutionGraphViolation(
            id: "graph.contract.unknown-key",
            detail: "unknown field(s): \(unknown.joined(separator: ", "))"
        )
    }
}
