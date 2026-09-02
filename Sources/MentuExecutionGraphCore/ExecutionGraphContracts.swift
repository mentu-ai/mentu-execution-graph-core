import Foundation

public struct ExecutionGraphViolation:
    Error, LocalizedError, Codable, Sendable, Equatable
{
    public let id: String
    public let detail: String

    public init(id: String, detail: String) {
        self.id = id
        self.detail = detail
    }

    public var errorDescription: String? {
        "\(id): \(detail)"
    }
}

// MARK: - Immutable step-start values

public struct StepSnapshotIdentity:
    Codable, Hashable, Sendable, Equatable
{
    public let runId: String
    public let stepLabel: String
    public let canonicalTarget: String

    public init(runId: String, stepLabel: String, canonicalTarget: String) {
        self.runId = runId
        self.stepLabel = stepLabel
        self.canonicalTarget = canonicalTarget
    }
}

public struct StepStartInput:
    Codable, Hashable, Sendable, Equatable
{
    public let lane: String
    public let source: String
    public let content: String

    public init(lane: String, source: String, content: String) {
        self.lane = lane
        self.source = source
        self.content = content
    }
}

public struct StepStartContext:
    Codable, Hashable, Sendable, Equatable
{
    public static let currentSchema = "mentu.step-start-context.v1"
    public static let schema = currentSchema

    public let schema: String
    public let runId: String
    public let stepLabel: String
    public let logicalAttempt: Int
    public let workspaceSnapshot: StepSnapshotIdentity
    public let dataSnapshots: [StepSnapshotIdentity]
    public let inputs: [StepStartInput]
    public let effectiveBackend: String?
    public let effectiveModel: String?
    public let effectiveAuthProfile: String?
    public let effectivePermissionMode: String?

    public init(
        runId: String,
        stepLabel: String,
        logicalAttempt: Int = 1,
        workspaceSnapshot: StepSnapshotIdentity,
        dataSnapshots: [StepSnapshotIdentity],
        inputs: [StepStartInput],
        effectiveBackend: String?,
        effectiveModel: String?,
        effectiveAuthProfile: String?,
        effectivePermissionMode: String?,
        schema: String = Self.currentSchema
    ) {
        self.schema = schema
        self.runId = runId
        self.stepLabel = stepLabel
        self.logicalAttempt = logicalAttempt
        self.workspaceSnapshot = workspaceSnapshot
        self.dataSnapshots = dataSnapshots
        self.inputs = inputs
        self.effectiveBackend = effectiveBackend
        self.effectiveModel = effectiveModel
        self.effectiveAuthProfile = effectiveAuthProfile
        self.effectivePermissionMode = effectivePermissionMode
    }
}

// MARK: - Candidate graph

public struct CandidateGraphSource:
    Codable, Sendable, Equatable, Hashable
{
    public let authorKind: String
    public let authorId: String
    public let plannerModel: String
    public let plannerSystemPromptHash: String
    public let endpointConfigDigest: String
    public let rawProposalHash: String
    public let emitterVersion: String

    public init(
        authorKind: String,
        authorId: String,
        plannerModel: String,
        plannerSystemPromptHash: String,
        endpointConfigDigest: String,
        rawProposalHash: String,
        emitterVersion: String
    ) {
        self.authorKind = authorKind
        self.authorId = authorId
        self.plannerModel = plannerModel
        self.plannerSystemPromptHash = plannerSystemPromptHash
        self.endpointConfigDigest = endpointConfigDigest
        self.rawProposalHash = rawProposalHash
        self.emitterVersion = emitterVersion
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case authorKind, authorId, plannerModel, plannerSystemPromptHash
        case endpointConfigDigest, rawProposalHash, emitterVersion
    }

    public init(from decoder: Decoder) throws {
        try _rejectUnknownKeys(
            decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        authorKind = try c.decode(String.self, forKey: .authorKind)
        authorId = try c.decode(String.self, forKey: .authorId)
        plannerModel = try c.decode(String.self, forKey: .plannerModel)
        plannerSystemPromptHash = try c.decode(
            String.self,
            forKey: .plannerSystemPromptHash
        )
        endpointConfigDigest = try c.decode(
            String.self,
            forKey: .endpointConfigDigest
        )
        rawProposalHash = try c.decode(String.self, forKey: .rawProposalHash)
        emitterVersion = try c.decode(String.self, forKey: .emitterVersion)
    }
}

public struct RepositoryDiscoveryReference:
    Codable, Sendable, Equatable, Hashable
{
    public static let currentSchema =
        "mentu.repository-discovery-reference.v1"

    public let schema: String
    public let workspaceRoot: String
    public let gitHead: String
    public let snapshotHash: String

    public init(
        workspaceRoot: String,
        gitHead: String,
        snapshotHash: String,
        schema: String = Self.currentSchema
    ) {
        self.schema = schema
        self.workspaceRoot = workspaceRoot
        self.gitHead = gitHead
        self.snapshotHash = snapshotHash
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schema, workspaceRoot, gitHead, snapshotHash
    }

    public init(from decoder: Decoder) throws {
        try _rejectUnknownKeys(
            decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schema = try c.decode(String.self, forKey: .schema)
        workspaceRoot = try c.decode(String.self, forKey: .workspaceRoot)
        gitHead = try c.decode(String.self, forKey: .gitHead)
        snapshotHash = try c.decode(String.self, forKey: .snapshotHash)
    }
}

public struct CandidateToolRule:
    Codable, Sendable, Equatable, Hashable
{
    public let tool: String
    public let behavior: String
    public let pattern: String?

    public init(tool: String, behavior: String, pattern: String? = nil) {
        self.tool = tool
        self.behavior = behavior
        self.pattern = pattern
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case tool, behavior, pattern
    }

    public init(from decoder: Decoder) throws {
        try _rejectUnknownKeys(
            decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tool = try c.decode(String.self, forKey: .tool)
        behavior = try c.decode(String.self, forKey: .behavior)
        pattern = try c.decodeIfPresent(String.self, forKey: .pattern)
    }
}

public struct CandidateStepContract:
    Codable, Sendable, Equatable, Hashable
{
    public let expectedChanges: [String]
    public let footprint: [String]
    public let verifyRequirements: MechanicalVerificationContract
    public let concurrencySafe: Bool
    public let timeoutSeconds: Int
    public let maxPhases: Int
    public let permissionMode: String
    public let sandboxPolicy: String
    public let approvalPolicy: String
    public let toolRules: [CandidateToolRule]
    public let mcpServers: [String]
    public let tokenLimit: Int
    public let budgetMicrosUSD: Int64

    public init(
        expectedChanges: [String],
        footprint: [String],
        verifyRequirements: MechanicalVerificationContract,
        concurrencySafe: Bool,
        timeoutSeconds: Int,
        maxPhases: Int,
        permissionMode: String,
        sandboxPolicy: String,
        approvalPolicy: String,
        toolRules: [CandidateToolRule],
        mcpServers: [String],
        tokenLimit: Int,
        budgetMicrosUSD: Int64
    ) {
        self.expectedChanges = expectedChanges
        self.footprint = footprint
        self.verifyRequirements = verifyRequirements
        self.concurrencySafe = concurrencySafe
        self.timeoutSeconds = timeoutSeconds
        self.maxPhases = maxPhases
        self.permissionMode = permissionMode
        self.sandboxPolicy = sandboxPolicy
        self.approvalPolicy = approvalPolicy
        self.toolRules = toolRules
        self.mcpServers = mcpServers
        self.tokenLimit = tokenLimit
        self.budgetMicrosUSD = budgetMicrosUSD
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case expectedChanges = "expected_changes"
        case footprint
        case verifyRequirements = "verify_requirements"
        case concurrencySafe = "concurrency_safe"
        case timeoutSeconds = "timeout_seconds"
        case maxPhases = "max_phases"
        case permissionMode = "permission_mode"
        case sandboxPolicy = "sandbox_policy"
        case approvalPolicy = "approval_policy"
        case toolRules = "tool_rules"
        case mcpServers = "mcp_servers"
        case tokenLimit = "token_limit"
        case budgetMicrosUSD = "budget_micros_usd"
    }

    public init(from decoder: Decoder) throws {
        try _rejectUnknownKeys(
            decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        expectedChanges = try c.decode(
            [String].self,
            forKey: .expectedChanges
        )
        footprint = try c.decode([String].self, forKey: .footprint)
        verifyRequirements = try c.decode(
            MechanicalVerificationContract.self,
            forKey: .verifyRequirements
        )
        concurrencySafe = try c.decode(Bool.self, forKey: .concurrencySafe)
        timeoutSeconds = try c.decode(Int.self, forKey: .timeoutSeconds)
        maxPhases = try c.decode(Int.self, forKey: .maxPhases)
        permissionMode = try c.decode(String.self, forKey: .permissionMode)
        sandboxPolicy = try c.decode(String.self, forKey: .sandboxPolicy)
        approvalPolicy = try c.decode(String.self, forKey: .approvalPolicy)
        toolRules = try c.decode([CandidateToolRule].self, forKey: .toolRules)
        mcpServers = try c.decode([String].self, forKey: .mcpServers)
        tokenLimit = try c.decode(Int.self, forKey: .tokenLimit)
        budgetMicrosUSD = try c.decode(Int64.self, forKey: .budgetMicrosUSD)
    }
}

public struct CandidateGraphNode:
    Codable, Sendable, Equatable, Hashable
{
    public let id: String
    public let title: String
    public let description: String?
    public let dependsOn: [String]
    public let promptBody: String
    public let contract: CandidateStepContract

    public init(
        id: String,
        title: String,
        description: String? = nil,
        dependsOn: [String],
        promptBody: String,
        contract: CandidateStepContract
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.dependsOn = dependsOn
        self.promptBody = promptBody
        self.contract = contract
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id, title, description, contract
        case dependsOn = "depends_on"
        case promptBody = "prompt_body"
    }

    public init(from decoder: Decoder) throws {
        try _rejectUnknownKeys(
            decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        dependsOn = try c.decode([String].self, forKey: .dependsOn)
        promptBody = try c.decode(String.self, forKey: .promptBody)
        contract = try c.decode(CandidateStepContract.self, forKey: .contract)
    }
}

public struct PlannerGraphProposal:
    Codable, Sendable, Equatable
{
    public let nodes: [CandidateGraphNode]

    public init(nodes: [CandidateGraphNode]) {
        self.nodes = nodes
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case nodes
    }

    public init(from decoder: Decoder) throws {
        try _rejectUnknownKeys(decoder, allowed: ["nodes"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nodes = try c.decode([CandidateGraphNode].self, forKey: .nodes)
    }
}

public struct CandidateExecutionGraph:
    Codable, Sendable, Equatable
{
    public static let currentSchema = "mentu.execution-graph.candidate.v1"

    public let schema: String
    public let objective: String
    public let source: CandidateGraphSource
    public let discovery: RepositoryDiscoveryReference
    public let planningConstraintsHash: String
    public let nodes: [CandidateGraphNode]

    public init(
        objective: String,
        source: CandidateGraphSource,
        discovery: RepositoryDiscoveryReference,
        planningConstraintsHash: String,
        nodes: [CandidateGraphNode],
        schema: String = Self.currentSchema
    ) {
        self.schema = schema
        self.objective = objective
        self.source = source
        self.discovery = discovery
        self.planningConstraintsHash = planningConstraintsHash
        self.nodes = nodes
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schema, objective, source, discovery, planningConstraintsHash
        case nodes
    }

    public init(from decoder: Decoder) throws {
        try _rejectUnknownKeys(
            decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schema = try c.decode(String.self, forKey: .schema)
        objective = try c.decode(String.self, forKey: .objective)
        source = try c.decode(CandidateGraphSource.self, forKey: .source)
        discovery = try c.decode(
            RepositoryDiscoveryReference.self,
            forKey: .discovery
        )
        planningConstraintsHash = try c.decode(
            String.self,
            forKey: .planningConstraintsHash
        )
        nodes = try c.decode([CandidateGraphNode].self, forKey: .nodes)
    }
}

// MARK: - Effective policy

public struct AuthFallbackBinding:
    Codable, Sendable, Equatable, Hashable
{
    public let profileId: String
    public let configDigest: String

    public init(profileId: String, configDigest: String) {
        self.profileId = profileId
        self.configDigest = configDigest
    }
}

public struct EffectiveExecutionPolicy:
    Codable, Sendable, Equatable
{
    public static let currentSchema = "mentu.effective-execution-policy.v1"

    public let schema: String
    public let logicalWorkspaceRoot: String
    public let fixedBackend: String
    public let fixedModel: String
    public let initialAuthProfile: String
    public let configuredEndpoint: String
    public let endpointConfigDigest: String
    public let transferMode: String
    public let maximumParallelSteps: Int
    public let defaultPermissionMode: String
    public let defaultSandboxPolicy: String
    public let defaultApprovalPolicy: String
    public let runTokenCeiling: Int
    public let perStepTokenCeiling: Int
    public let runBudgetMicrosUSD: Int64
    public let perStepBudgetMicrosUSD: Int64
    public let runSoftDeadlineSeconds: Int
    public let stepSoftDeadlineSeconds: Int
    public let authFallbackChain: [AuthFallbackBinding]
    public let pluginPolicy: String
    public let backgroundHookPolicy: String
    public let outerCallEvidencePolicy: String
    public let toolPolicyDigest: String
    public let mcpPolicyDigest: String

    public init(
        logicalWorkspaceRoot: String,
        fixedBackend: String,
        fixedModel: String,
        initialAuthProfile: String,
        configuredEndpoint: String,
        endpointConfigDigest: String,
        transferMode: String = "worktree",
        maximumParallelSteps: Int,
        defaultPermissionMode: String,
        defaultSandboxPolicy: String,
        defaultApprovalPolicy: String,
        runTokenCeiling: Int,
        perStepTokenCeiling: Int,
        runBudgetMicrosUSD: Int64,
        perStepBudgetMicrosUSD: Int64,
        runSoftDeadlineSeconds: Int,
        stepSoftDeadlineSeconds: Int,
        authFallbackChain: [AuthFallbackBinding],
        pluginPolicy: String = "disabled",
        backgroundHookPolicy: String = "disabled",
        outerCallEvidencePolicy: String = "required",
        toolPolicyDigest: String,
        mcpPolicyDigest: String,
        schema: String = Self.currentSchema
    ) {
        self.schema = schema
        self.logicalWorkspaceRoot = logicalWorkspaceRoot
        self.fixedBackend = fixedBackend
        self.fixedModel = fixedModel
        self.initialAuthProfile = initialAuthProfile
        self.configuredEndpoint = configuredEndpoint
        self.endpointConfigDigest = endpointConfigDigest
        self.transferMode = transferMode
        self.maximumParallelSteps = maximumParallelSteps
        self.defaultPermissionMode = defaultPermissionMode
        self.defaultSandboxPolicy = defaultSandboxPolicy
        self.defaultApprovalPolicy = defaultApprovalPolicy
        self.runTokenCeiling = runTokenCeiling
        self.perStepTokenCeiling = perStepTokenCeiling
        self.runBudgetMicrosUSD = runBudgetMicrosUSD
        self.perStepBudgetMicrosUSD = perStepBudgetMicrosUSD
        self.runSoftDeadlineSeconds = runSoftDeadlineSeconds
        self.stepSoftDeadlineSeconds = stepSoftDeadlineSeconds
        self.authFallbackChain = authFallbackChain
        self.pluginPolicy = pluginPolicy
        self.backgroundHookPolicy = backgroundHookPolicy
        self.outerCallEvidencePolicy = outerCallEvidencePolicy
        self.toolPolicyDigest = toolPolicyDigest
        self.mcpPolicyDigest = mcpPolicyDigest
    }
}

// MARK: - Planning authority and deterministic discovery

public struct PlanningSelections:
    Codable, Sendable, Equatable, Hashable
{
    public let provider: String
    public let model: String
    public let authProfile: String
    public let endpoint: String

    public init(
        provider: String,
        model: String,
        authProfile: String,
        endpoint: String
    ) {
        self.provider = provider
        self.model = model
        self.authProfile = authProfile
        self.endpoint = endpoint
    }
}

public struct PlanningConstraintView:
    Codable, Sendable, Equatable
{
    public static let currentSchema =
        "mentu.planning-constraint-view.v1"

    public let schema: String
    public let changePrefixes: [String]
    public let maximumStepCount: Int
    public let maximumDependencyDepth: Int
    public let maximumParallelSteps: Int
    public let hostBackends: [String]
    public let hostModels: [String]
    public let permissionModes: [String]
    public let sandboxPolicies: [String]
    public let approvalPolicies: [String]
    public let toolRules: [CandidateToolRule]
    public let mcpServers: [String]
    public let perStepTokenCeiling: Int
    public let runTokenCeiling: Int
    public let perStepBudgetMicrosUSD: Int64
    public let runBudgetMicrosUSD: Int64
    public let stepSoftDeadlineSeconds: Int
    public let runSoftDeadlineSeconds: Int

    public init(
        changePrefixes: [String],
        maximumStepCount: Int,
        maximumDependencyDepth: Int,
        maximumParallelSteps: Int,
        hostBackends: [String],
        hostModels: [String],
        permissionModes: [String],
        sandboxPolicies: [String],
        approvalPolicies: [String],
        toolRules: [CandidateToolRule],
        mcpServers: [String],
        perStepTokenCeiling: Int,
        runTokenCeiling: Int,
        perStepBudgetMicrosUSD: Int64,
        runBudgetMicrosUSD: Int64,
        stepSoftDeadlineSeconds: Int,
        runSoftDeadlineSeconds: Int,
        schema: String = Self.currentSchema
    ) {
        self.schema = schema
        self.changePrefixes = changePrefixes
        self.maximumStepCount = maximumStepCount
        self.maximumDependencyDepth = maximumDependencyDepth
        self.maximumParallelSteps = maximumParallelSteps
        self.hostBackends = hostBackends
        self.hostModels = hostModels
        self.permissionModes = permissionModes
        self.sandboxPolicies = sandboxPolicies
        self.approvalPolicies = approvalPolicies
        self.toolRules = toolRules
        self.mcpServers = mcpServers
        self.perStepTokenCeiling = perStepTokenCeiling
        self.runTokenCeiling = runTokenCeiling
        self.perStepBudgetMicrosUSD = perStepBudgetMicrosUSD
        self.runBudgetMicrosUSD = runBudgetMicrosUSD
        self.stepSoftDeadlineSeconds = stepSoftDeadlineSeconds
        self.runSoftDeadlineSeconds = runSoftDeadlineSeconds
    }

    public init(envelope: ExecutionAuthorityEnvelope) {
        self.init(
            changePrefixes: envelope.changePrefixes.sorted(),
            maximumStepCount: envelope.maximumStepCount,
            maximumDependencyDepth: envelope.maximumDependencyDepth,
            maximumParallelSteps: envelope.maximumParallelSteps,
            hostBackends: envelope.hostBackends.sorted(),
            hostModels: envelope.hostModels.sorted(),
            permissionModes: envelope.permissionModes.sorted(),
            sandboxPolicies: envelope.sandboxPolicies.sorted(),
            approvalPolicies: envelope.approvalPolicies.sorted(),
            toolRules: envelope.toolRules,
            mcpServers: envelope.mcpServers.sorted(),
            perStepTokenCeiling: envelope.perStepTokenCeiling,
            runTokenCeiling: envelope.runTokenCeiling,
            perStepBudgetMicrosUSD: envelope.perStepBudgetMicrosUSD,
            runBudgetMicrosUSD: envelope.runBudgetMicrosUSD,
            stepSoftDeadlineSeconds: envelope.stepSoftDeadlineSeconds,
            runSoftDeadlineSeconds: envelope.runSoftDeadlineSeconds
        )
    }
}

public struct PlanningPermit: Codable, Sendable, Equatable {
    public static let currentSchema = "mentu.planning-permit.v1"

    public let schema: String
    public let workspaceRoot: String
    public let discoveryReadPrefixes: [String]
    public let plannerEgressPrefixes: [String]
    public let plannerEgressByteCeiling: Int
    public let provider: String
    public let model: String
    public let authProfile: String
    public let sealedRequestEndpoint: String
    public let endpointConfigDigest: String
    public let constraintView: PlanningConstraintView
    public let constraintViewHash: String
    public let permitHash: String

    public init(
        workspaceRoot: String,
        discoveryReadPrefixes: [String],
        plannerEgressPrefixes: [String],
        plannerEgressByteCeiling: Int,
        provider: String,
        model: String,
        authProfile: String,
        sealedRequestEndpoint: String,
        endpointConfigDigest: String,
        constraintView: PlanningConstraintView,
        constraintViewHash: String,
        permitHash: String,
        schema: String = Self.currentSchema
    ) {
        self.schema = schema
        self.workspaceRoot = workspaceRoot
        self.discoveryReadPrefixes = discoveryReadPrefixes
        self.plannerEgressPrefixes = plannerEgressPrefixes
        self.plannerEgressByteCeiling = plannerEgressByteCeiling
        self.provider = provider
        self.model = model
        self.authProfile = authProfile
        self.sealedRequestEndpoint = sealedRequestEndpoint
        self.endpointConfigDigest = endpointConfigDigest
        self.constraintView = constraintView
        self.constraintViewHash = constraintViewHash
        self.permitHash = permitHash
    }
}

public struct RepositoryDiscoveryStatusSummary:
    Codable, Sendable, Equatable, Hashable
{
    public let relativePath: String
    public let state: String

    public init(relativePath: String, state: String) {
        self.relativePath = relativePath
        self.state = state
    }
}

public struct RepositoryDiscoveryExclusion:
    Codable, Sendable, Equatable, Hashable
{
    public let ruleId: String
    public let count: Int

    public init(ruleId: String, count: Int) {
        self.ruleId = ruleId
        self.count = count
    }
}

public struct RepositoryDiscoveryFileEntry:
    Codable, Sendable, Equatable, Hashable
{
    public let relativePath: String
    public let sha256: String
    public let byteCount: Int
    public let truncated: Bool
    public let contentEncoding: String
    public let content: String?

    public init(
        relativePath: String,
        sha256: String,
        byteCount: Int,
        truncated: Bool,
        contentEncoding: String,
        content: String?
    ) {
        self.relativePath = relativePath
        self.sha256 = sha256
        self.byteCount = byteCount
        self.truncated = truncated
        self.contentEncoding = contentEncoding
        self.content = content
    }
}

public struct RepositoryDiscoverySnapshot:
    Codable, Sendable, Equatable
{
    public static let currentSchema = "mentu.repository-discovery.v1"

    public let schema: String
    public let workspaceRoot: String
    public let gitHead: String
    public let statusEntries: [RepositoryDiscoveryStatusSummary]
    public let statusDigest: String
    public let exclusions: [RepositoryDiscoveryExclusion]
    public let headTree: [String]
    public let selectedFiles: [RepositoryDiscoveryFileEntry]
    public let omittedFileCount: Int
    public let selectionAlgorithm: String
    public let totalByteCap: Int
    public let sentPaths: [String]
    public let sentByteCount: Int
    public let snapshotHash: String

    public init(
        workspaceRoot: String,
        gitHead: String,
        statusEntries: [RepositoryDiscoveryStatusSummary],
        statusDigest: String,
        exclusions: [RepositoryDiscoveryExclusion],
        headTree: [String],
        selectedFiles: [RepositoryDiscoveryFileEntry],
        omittedFileCount: Int,
        selectionAlgorithm: String,
        totalByteCap: Int,
        sentPaths: [String],
        sentByteCount: Int,
        snapshotHash: String,
        schema: String = Self.currentSchema
    ) {
        self.schema = schema
        self.workspaceRoot = workspaceRoot
        self.gitHead = gitHead
        self.statusEntries = statusEntries
        self.statusDigest = statusDigest
        self.exclusions = exclusions
        self.headTree = headTree
        self.selectedFiles = selectedFiles
        self.omittedFileCount = omittedFileCount
        self.selectionAlgorithm = selectionAlgorithm
        self.totalByteCap = totalByteCap
        self.sentPaths = sentPaths
        self.sentByteCount = sentByteCount
        self.snapshotHash = snapshotHash
    }

    public var reference: RepositoryDiscoveryReference {
        .init(
            workspaceRoot: workspaceRoot,
            gitHead: gitHead,
            snapshotHash: snapshotHash
        )
    }
}

// MARK: - Sealed executable artifact

public struct SealedExecutionPrompt:
    Codable, Sendable, Equatable, Hashable
{
    public let stepLabel: String
    public let body: String
    public let sha256: String

    public init(stepLabel: String, body: String, sha256: String) {
        self.stepLabel = stepLabel
        self.body = body
        self.sha256 = sha256
    }
}

public struct StepContractManifest:
    Codable, Sendable, Equatable, Hashable
{
    public let stepLabel: String
    public let expectedChanges: [String]
    public let footprint: [String]
    public let verifyRequirements: MechanicalVerificationContract
    public let concurrencySafe: Bool
    public let timeoutSeconds: Int
    public let maxPhases: Int
    public let permissionMode: String
    public let sandboxPolicy: String
    public let approvalPolicy: String
    public let toolRules: [CandidateToolRule]
    public let mcpServers: [String]
    public let tokenLimit: Int
    public let budgetMicrosUSD: Int64

    public init(
        stepLabel: String,
        expectedChanges: [String],
        footprint: [String],
        verifyRequirements: MechanicalVerificationContract,
        concurrencySafe: Bool,
        timeoutSeconds: Int,
        maxPhases: Int,
        permissionMode: String,
        sandboxPolicy: String,
        approvalPolicy: String,
        toolRules: [CandidateToolRule],
        mcpServers: [String],
        tokenLimit: Int,
        budgetMicrosUSD: Int64
    ) {
        self.stepLabel = stepLabel
        self.expectedChanges = expectedChanges
        self.footprint = footprint
        self.verifyRequirements = verifyRequirements
        self.concurrencySafe = concurrencySafe
        self.timeoutSeconds = timeoutSeconds
        self.maxPhases = maxPhases
        self.permissionMode = permissionMode
        self.sandboxPolicy = sandboxPolicy
        self.approvalPolicy = approvalPolicy
        self.toolRules = toolRules
        self.mcpServers = mcpServers
        self.tokenLimit = tokenLimit
        self.budgetMicrosUSD = budgetMicrosUSD
    }
}

public struct ExecutionArtifactBundle:
    Codable, Sendable, Equatable
{
    public static let currentSchema = "mentu.execution-artifact-bundle.v1"

    public let schema: String
    public let lowererVersion: String
    public let definition: ExecutionGraphDefinition
    public let prompts: [SealedExecutionPrompt]
    public let effectiveStaticVariables: [String: String]
    public let contracts: [StepContractManifest]
    public let discovery: RepositoryDiscoveryReference
    public let source: CandidateGraphSource
    public let planningConstraintsHash: String
    public let sourceHash: String
    public let executableHash: String

    public init(
        schema: String = Self.currentSchema,
        lowererVersion: String,
        definition: ExecutionGraphDefinition,
        prompts: [SealedExecutionPrompt],
        effectiveStaticVariables: [String: String],
        contracts: [StepContractManifest],
        discovery: RepositoryDiscoveryReference,
        source: CandidateGraphSource,
        planningConstraintsHash: String,
        sourceHash: String,
        executableHash: String
    ) {
        self.schema = schema
        self.lowererVersion = lowererVersion
        self.definition = definition
        self.prompts = prompts
        self.effectiveStaticVariables = effectiveStaticVariables
        self.contracts = contracts
        self.discovery = discovery
        self.source = source
        self.planningConstraintsHash = planningConstraintsHash
        self.sourceHash = sourceHash
        self.executableHash = executableHash
    }
}

public struct ExecutionGraphLoweringReport:
    Codable, Sendable, Equatable
{
    public static let currentSchema = "mentu.execution-graph-lowering-report.v1"

    public let schema: String
    public let lowererVersion: String
    public let nodeOrder: [String]
    public let promptHashes: [String: String]
    public let sourceHash: String
    public let executableHash: String

    public init(
        lowererVersion: String,
        nodeOrder: [String],
        promptHashes: [String: String],
        sourceHash: String,
        executableHash: String,
        schema: String = Self.currentSchema
    ) {
        self.schema = schema
        self.lowererVersion = lowererVersion
        self.nodeOrder = nodeOrder
        self.promptHashes = promptHashes
        self.sourceHash = sourceHash
        self.executableHash = executableHash
    }
}

public struct LoweredExecutionGraph: Sendable, Equatable {
    public let definition: ExecutionGraphDefinition
    public let prompts: [SealedExecutionPrompt]
    public let contracts: [StepContractManifest]
    public let report: ExecutionGraphLoweringReport

    public init(
        definition: ExecutionGraphDefinition,
        prompts: [SealedExecutionPrompt],
        contracts: [StepContractManifest],
        report: ExecutionGraphLoweringReport
    ) {
        self.definition = definition
        self.prompts = prompts
        self.contracts = contracts
        self.report = report
    }
}
