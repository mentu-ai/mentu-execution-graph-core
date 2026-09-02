import Foundation

/// The fixed CIR policy admitted by execution-graph v1.
public struct ExecutionGraphCIRPolicy:
    Codable, Sendable, Equatable, Hashable
{
    public let readBeforeAct: Bool
    public let writeAfterStep: Bool
    public let embed: Bool
    public let detectPatternsOnComplete: Bool
    public let defaultContextBudget: Int

    public init(
        readBeforeAct: Bool,
        writeAfterStep: Bool,
        embed: Bool,
        detectPatternsOnComplete: Bool,
        defaultContextBudget: Int
    ) {
        self.readBeforeAct = readBeforeAct
        self.writeAfterStep = writeAfterStep
        self.embed = embed
        self.detectPatternsOnComplete = detectPatternsOnComplete
        self.defaultContextBudget = defaultContextBudget
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case readBeforeAct = "read_before_act"
        case writeAfterStep = "write_after_step"
        case embed
        case detectPatternsOnComplete = "detect_patterns_on_complete"
        case defaultContextBudget = "default_context_budget"
    }

    public init(from decoder: Decoder) throws {
        try _rejectUnknownKeys(
            decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        readBeforeAct = try container.decode(Bool.self, forKey: .readBeforeAct)
        writeAfterStep = try container.decode(Bool.self, forKey: .writeAfterStep)
        embed = try container.decode(Bool.self, forKey: .embed)
        detectPatternsOnComplete = try container.decode(
            Bool.self,
            forKey: .detectPatternsOnComplete
        )
        defaultContextBudget = try container.decode(
            Int.self,
            forKey: .defaultContextBudget
        )
    }
}

public struct ExecutionGraphStepLimits:
    Codable, Sendable, Equatable, Hashable
{
    public let maxDurationSeconds: Int
    public let maxCostUSD: Double

    public init(maxDurationSeconds: Int, maxCostUSD: Double) {
        self.maxDurationSeconds = maxDurationSeconds
        self.maxCostUSD = maxCostUSD
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case maxDurationSeconds = "max_duration_seconds"
        case maxCostUSD = "max_cost_usd"
    }

    public init(from decoder: Decoder) throws {
        try _rejectUnknownKeys(
            decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        maxDurationSeconds = try container.decode(
            Int.self,
            forKey: .maxDurationSeconds
        )
        maxCostUSD = try container.decode(Double.self, forKey: .maxCostUSD)
    }
}

/// Strict admitted-only post-step verification object.
///
/// Values are deliberately kept as canonical JSON rather than importing any
/// host linter types. The object encodes directly as `verify_requirements`.
public struct MechanicalVerificationContract:
    Codable, Sendable, Equatable, Hashable
{
    public static let allowedKeys: Set<String> = [
        "grep_present",
        "grep_absent",
        "ordering",
        "file_absent",
        "git_clean_outside",
        "json_schema",
        "entity_footprint",
        "arity_clean",
        "tests_cover_impact",
        "data_contract",
        "data_footprint",
        "observe",
        "okf_conformance",
    ]

    public let values: [String: CanonicalJSONValue]

    public init(_ values: [String: CanonicalJSONValue] = [:]) throws {
        let unknown = values.keys.filter {
            !Self.allowedKeys.contains($0)
        }.sorted()
        guard unknown.isEmpty else {
            throw ExecutionGraphViolation(
                id: unknown.contains("semantic_assertion")
                    ? "graph.contract.semantic-verification"
                    : "graph.contract.unknown-verification-key",
                detail: "unsupported verify_requirements key(s): "
                    + unknown.joined(separator: ", ")
            )
        }
        self.values = values
    }

    public var isEmpty: Bool {
        values.isEmpty
    }

    public subscript(key: String) -> CanonicalJSONValue? {
        values[key]
    }

    /// Mechanical file claims used by the lowering coverage gate.
    public var grepPresentFiles: [String] {
        guard case .array(let rules)? = values["grep_present"] else {
            return []
        }
        return rules.compactMap { rule in
            guard case .object(let fields) = rule,
                  case .string(let file)? = fields["file"]
            else {
                return nil
            }
            return file
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: _ExecutionGraphCodingKey.self
        )
        let keys = Set(container.allKeys.map(\.stringValue))
        let unknown = keys.subtracting(Self.allowedKeys).sorted()
        guard unknown.isEmpty else {
            throw ExecutionGraphViolation(
                id: unknown.contains("semantic_assertion")
                    ? "graph.contract.semantic-verification"
                    : "graph.contract.unknown-verification-key",
                detail: "unsupported verify_requirements key(s): "
                    + unknown.joined(separator: ", ")
            )
        }
        var decoded: [String: CanonicalJSONValue] = [:]
        for key in container.allKeys {
            decoded[key.stringValue] = try container.decode(
                CanonicalJSONValue.self,
                forKey: key
            )
        }
        values = decoded
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(
            keyedBy: _ExecutionGraphCodingKey.self
        )
        for key in values.keys.sorted(
            by: ExecutionGraphCanonicalizer.utf16Less
        ) {
            try container.encode(values[key], forKey: .init(key))
        }
    }

    public func hash(into hasher: inout Hasher) {
        for key in values.keys.sorted(
            by: ExecutionGraphCanonicalizer.utf16Less
        ) {
            hasher.combine(key)
            hasher.combine(values[key])
        }
    }
}

/// One fully admitted executable step. Every field is explicit; no engine
/// defaults or general-recipe extensions cross this boundary.
public struct ExecutionGraphStep:
    Codable, Sendable, Equatable, Hashable
{
    public let label: String
    public let auth: String
    public let args: [String]
    public let model: String
    public let backend: String
    public let timeout: Int
    public let completionKeyword: String
    public let maxPhases: Int
    public let taskBudget: Int
    public let maxRetries: Int
    public let dependsOn: [String]
    public let mcpServers: [String]
    public let permissionMode: String
    public let permissions: [CandidateToolRule]
    public let concurrentSafe: Bool
    public let shared: Bool
    public let verifyRequirements: MechanicalVerificationContract
    public let expectedChanges: [String]
    public let footprint: [String]
    public let limits: ExecutionGraphStepLimits
    public let isolation: String
    public let sandboxPolicy: String
    public let approvalPolicy: String

    public init(
        label: String,
        auth: String,
        args: [String],
        model: String,
        backend: String,
        timeout: Int,
        completionKeyword: String,
        maxPhases: Int,
        taskBudget: Int,
        maxRetries: Int,
        dependsOn: [String],
        mcpServers: [String],
        permissionMode: String,
        permissions: [CandidateToolRule],
        concurrentSafe: Bool,
        shared: Bool,
        verifyRequirements: MechanicalVerificationContract,
        expectedChanges: [String],
        footprint: [String],
        limits: ExecutionGraphStepLimits,
        isolation: String,
        sandboxPolicy: String,
        approvalPolicy: String
    ) {
        self.label = label
        self.auth = auth
        self.args = args
        self.model = model
        self.backend = backend
        self.timeout = timeout
        self.completionKeyword = completionKeyword
        self.maxPhases = maxPhases
        self.taskBudget = taskBudget
        self.maxRetries = maxRetries
        self.dependsOn = dependsOn
        self.mcpServers = mcpServers
        self.permissionMode = permissionMode
        self.permissions = permissions
        self.concurrentSafe = concurrentSafe
        self.shared = shared
        self.verifyRequirements = verifyRequirements
        self.expectedChanges = expectedChanges
        self.footprint = footprint
        self.limits = limits
        self.isolation = isolation
        self.sandboxPolicy = sandboxPolicy
        self.approvalPolicy = approvalPolicy
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case label, auth, args, model, backend, timeout
        case completionKeyword = "completion_keyword"
        case maxPhases = "max_phases"
        case taskBudget = "task_budget"
        case maxRetries = "max_retries"
        case dependsOn = "depends_on"
        case mcpServers = "mcp_servers"
        case permissionMode = "permission_mode"
        case permissions
        case concurrentSafe = "concurrent_safe"
        case shared
        case verifyRequirements = "verify_requirements"
        case expectedChanges = "expected_changes"
        case footprint, limits, isolation
        case sandboxPolicy = "sandbox_policy"
        case approvalPolicy = "approval_policy"
    }

    public init(from decoder: Decoder) throws {
        try _rejectUnknownKeys(
            decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = try container.decode(String.self, forKey: .label)
        auth = try container.decode(String.self, forKey: .auth)
        args = try container.decode([String].self, forKey: .args)
        model = try container.decode(String.self, forKey: .model)
        backend = try container.decode(String.self, forKey: .backend)
        timeout = try container.decode(Int.self, forKey: .timeout)
        completionKeyword = try container.decode(
            String.self,
            forKey: .completionKeyword
        )
        maxPhases = try container.decode(Int.self, forKey: .maxPhases)
        taskBudget = try container.decode(Int.self, forKey: .taskBudget)
        maxRetries = try container.decode(Int.self, forKey: .maxRetries)
        dependsOn = try container.decode([String].self, forKey: .dependsOn)
        mcpServers = try container.decode([String].self, forKey: .mcpServers)
        permissionMode = try container.decode(
            String.self,
            forKey: .permissionMode
        )
        permissions = try container.decode(
            [CandidateToolRule].self,
            forKey: .permissions
        )
        concurrentSafe = try container.decode(
            Bool.self,
            forKey: .concurrentSafe
        )
        shared = try container.decode(Bool.self, forKey: .shared)
        verifyRequirements = try container.decode(
            MechanicalVerificationContract.self,
            forKey: .verifyRequirements
        )
        expectedChanges = try container.decode(
            [String].self,
            forKey: .expectedChanges
        )
        footprint = try container.decode([String].self, forKey: .footprint)
        limits = try container.decode(
            ExecutionGraphStepLimits.self,
            forKey: .limits
        )
        isolation = try container.decode(String.self, forKey: .isolation)
        sandboxPolicy = try container.decode(
            String.self,
            forKey: .sandboxPolicy
        )
        approvalPolicy = try container.decode(
            String.self,
            forKey: .approvalPolicy
        )
    }
}

/// The compact executable schema accepted by the admitted host runner.
public struct ExecutionGraphDefinition:
    Codable, Sendable, Equatable
{
    public let name: String
    public let description: String?
    public let workspace: String
    public let steps: [ExecutionGraphStep]
    public let cir: ExecutionGraphCIRPolicy
    public let canary: Bool
    public let transferMode: String
    public let auth: String
    public let stepContract: String
    public let sandboxPolicy: String
    public let approvalPolicy: String

    public init(
        name: String,
        description: String?,
        workspace: String,
        steps: [ExecutionGraphStep],
        cir: ExecutionGraphCIRPolicy,
        canary: Bool,
        transferMode: String,
        auth: String,
        stepContract: String,
        sandboxPolicy: String,
        approvalPolicy: String
    ) {
        self.name = name
        self.description = description
        self.workspace = workspace
        self.steps = steps
        self.cir = cir
        self.canary = canary
        self.transferMode = transferMode
        self.auth = auth
        self.stepContract = stepContract
        self.sandboxPolicy = sandboxPolicy
        self.approvalPolicy = approvalPolicy
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case name, description, workspace, steps, cir, canary, auth
        case transferMode = "transfer_mode"
        case stepContract = "step_contract"
        case sandboxPolicy = "sandbox_policy"
        case approvalPolicy = "approval_policy"
    }

    public init(from decoder: Decoder) throws {
        try _rejectUnknownKeys(
            decoder,
            allowed: Set(CodingKeys.allCases.map(\.rawValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(
            String.self,
            forKey: .description
        )
        workspace = try container.decode(String.self, forKey: .workspace)
        steps = try container.decode([ExecutionGraphStep].self, forKey: .steps)
        cir = try container.decode(ExecutionGraphCIRPolicy.self, forKey: .cir)
        canary = try container.decode(Bool.self, forKey: .canary)
        transferMode = try container.decode(String.self, forKey: .transferMode)
        auth = try container.decode(String.self, forKey: .auth)
        stepContract = try container.decode(String.self, forKey: .stepContract)
        sandboxPolicy = try container.decode(
            String.self,
            forKey: .sandboxPolicy
        )
        approvalPolicy = try container.decode(
            String.self,
            forKey: .approvalPolicy
        )
    }
}
