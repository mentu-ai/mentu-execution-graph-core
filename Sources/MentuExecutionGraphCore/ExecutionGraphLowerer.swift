import Foundation

/// Deterministic, in-memory graph lowering and artifact identity.
///
/// This type performs no filesystem, process, network, credential, model,
/// environment, or persistence operation.
public enum ExecutionGraphLowerer: Sendable {
    public static let version =
        "mentu.execution-graph-lowerer.v1+prompt.v1"
    public static let promptTemplateVersion =
        "mentu.execution-graph.prompt.v1"

    public static func lower(
        _ candidate: CandidateExecutionGraph,
        executionPolicy policy: EffectiveExecutionPolicy
    ) throws -> LoweredExecutionGraph {
        guard candidate.schema == CandidateExecutionGraph.currentSchema else {
            throw violation(
                "graph.lowering.candidate-schema",
                "unsupported candidate schema '\(candidate.schema)'"
            )
        }
        guard candidate.discovery.schema
            == RepositoryDiscoveryReference.currentSchema
        else {
            throw violation(
                "graph.lowering.discovery-schema",
                "unsupported discovery schema '\(candidate.discovery.schema)'"
            )
        }
        guard policy.schema == EffectiveExecutionPolicy.currentSchema else {
            throw violation(
                "graph.lowering.policy-schema",
                "unsupported effective policy schema '\(policy.schema)'"
            )
        }
        guard !candidate.objective.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            throw violation(
                "graph.lowering.objective-empty",
                "candidate objective is empty"
            )
        }
        guard !candidate.nodes.isEmpty else {
            throw violation("graph.dag.empty", "candidate graph is empty")
        }
        guard policy.transferMode == "worktree" else {
            throw violation(
                "graph.lowering.transfer-mode",
                "effective transfer mode must be worktree"
            )
        }

        let workspaceRoot = try canonicalWorkspaceRoot(
            policy.logicalWorkspaceRoot
        )
        guard candidate.discovery.workspaceRoot == workspaceRoot else {
            throw violation(
                "graph.lowering.discovery-workspace",
                "discovery root '\(candidate.discovery.workspaceRoot)' "
                    + "does not match policy root '\(workspaceRoot)'"
            )
        }

        var normalizedByID: [String: CandidateGraphNode] = [:]
        for node in candidate.nodes {
            let id = node.id.precomposedStringWithCanonicalMapping
            try validateIdentifier(id, original: node.id)
            guard normalizedByID[id] == nil else {
                throw violation(
                    "graph.dag.duplicate-node",
                    "duplicate node id '\(id)'"
                )
            }
            normalizedByID[id] = CandidateGraphNode(
                id: id,
                title: node.title.precomposedStringWithCanonicalMapping,
                description: node.description?
                    .precomposedStringWithCanonicalMapping,
                dependsOn: Array(Set(node.dependsOn.map {
                    $0.precomposedStringWithCanonicalMapping
                })).sorted(),
                promptBody: node.promptBody,
                contract: node.contract
            )
        }
        for node in normalizedByID.values {
            for dependency in node.dependsOn
            where normalizedByID[dependency] == nil {
                throw violation(
                    "graph.dag.unknown-dependency",
                    "node '\(node.id)' has unknown dependency '\(dependency)'"
                )
            }
            if node.dependsOn.contains(node.id) {
                throw violation(
                    "graph.dag.self-dependency",
                    "node '\(node.id)' depends on itself"
                )
            }
        }
        let nodes = try topologicalOrder(normalizedByID)

        var prompts: [SealedExecutionPrompt] = []
        var manifests: [StepContractManifest] = []
        var steps: [ExecutionGraphStep] = []
        var claims: [(node: String, path: String)] = []

        for node in nodes {
            let contract = try normalizeContract(
                node.contract,
                nodeID: node.id,
                workspaceRoot: workspaceRoot
            )
            guard !node.promptBody.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty else {
                throw violation(
                    "graph.lowering.missing-prompt",
                    "node '\(node.id)' has an empty prompt body"
                )
            }
            let body = renderPrompt(
                candidate: candidate,
                node: node,
                contract: contract
            )
            prompts.append(
                .init(
                    stepLabel: node.id,
                    body: body,
                    sha256: ExecutionGraphDigest.sha256(body)
                )
            )
            manifests.append(manifest(label: node.id, contract: contract))
            claims.append(contentsOf: contract.expectedChanges.map {
                (node.id, $0)
            })
            steps.append(
                ExecutionGraphStep(
                    label: node.id,
                    auth: policy.initialAuthProfile,
                    args: ["-P", logicalPromptReference(stepLabel: node.id)],
                    model: policy.fixedModel,
                    backend: policy.fixedBackend,
                    timeout: contract.timeoutSeconds,
                    completionKeyword: completionKeyword(node.id),
                    maxPhases: contract.maxPhases,
                    taskBudget: contract.tokenLimit,
                    maxRetries: 0,
                    dependsOn: node.dependsOn,
                    mcpServers: contract.mcpServers,
                    permissionMode: contract.permissionMode,
                    permissions: contract.toolRules,
                    concurrentSafe: contract.concurrencySafe,
                    shared: contract.concurrencySafe,
                    verifyRequirements: contract.verifyRequirements,
                    expectedChanges: contract.expectedChanges,
                    footprint: contract.footprint,
                    limits: .init(
                        maxDurationSeconds: contract.timeoutSeconds,
                        maxCostUSD: Double(contract.budgetMicrosUSD)
                            / 1_000_000.0
                    ),
                    isolation: "worktree",
                    sandboxPolicy: contract.sandboxPolicy,
                    approvalPolicy: contract.approvalPolicy
                )
            )
        }

        try validateVerificationCoverage(claims: claims, nodes: nodes)

        let definition = ExecutionGraphDefinition(
            name: "admitted-execution-graph",
            description: "Admitted execution graph",
            workspace: workspaceRoot,
            steps: steps,
            cir: .init(
                readBeforeAct: false,
                writeAfterStep: false,
                embed: false,
                detectPatternsOnComplete: false,
                defaultContextBudget: 0
            ),
            canary: false,
            transferMode: "worktree",
            auth: policy.initialAuthProfile,
            stepContract: "enforce",
            sandboxPolicy: policy.defaultSandboxPolicy,
            approvalPolicy: policy.defaultApprovalPolicy
        )
        let sortedPrompts = prompts.sorted { $0.stepLabel < $1.stepLabel }
        let sortedContracts = manifests.sorted { $0.stepLabel < $1.stepLabel }
        let sourceHash = try hashSource(
            source: candidate.source,
            discovery: candidate.discovery,
            planningConstraintsHash: candidate.planningConstraintsHash
        )
        let executableHash = try hashExecutable(
            definition: definition,
            prompts: sortedPrompts,
            variables: [:],
            contracts: sortedContracts,
            policy: policy,
            lowererVersion: version
        )
        let report = ExecutionGraphLoweringReport(
            lowererVersion: version,
            nodeOrder: nodes.map(\.id),
            promptHashes: Dictionary(
                uniqueKeysWithValues: sortedPrompts.map {
                    ($0.stepLabel, $0.sha256)
                }
            ),
            sourceHash: sourceHash,
            executableHash: executableHash
        )
        return LoweredExecutionGraph(
            definition: definition,
            prompts: sortedPrompts,
            contracts: sortedContracts,
            report: report
        )
    }

    public static func buildBundle(
        candidate: CandidateExecutionGraph,
        executionPolicy policy: EffectiveExecutionPolicy
    ) throws -> ExecutionArtifactBundle {
        let lowered = try lower(candidate, executionPolicy: policy)
        return ExecutionArtifactBundle(
            lowererVersion: version,
            definition: lowered.definition,
            prompts: lowered.prompts,
            effectiveStaticVariables: [:],
            contracts: lowered.contracts,
            discovery: candidate.discovery,
            source: candidate.source,
            planningConstraintsHash: candidate.planningConstraintsHash,
            sourceHash: lowered.report.sourceHash,
            executableHash: lowered.report.executableHash
        )
    }

    /// Compatibility spelling for the current generated-graph builder.
    public static func fromCandidate(
        _ candidate: CandidateExecutionGraph,
        executionPolicy policy: EffectiveExecutionPolicy
    ) throws -> ExecutionArtifactBundle {
        try buildBundle(candidate: candidate, executionPolicy: policy)
    }

    /// Builds identity for an already normalized definition and already sealed
    /// in-memory prompts. Host adapters use this for persistent recipes.
    public static func buildBundle(
        definition: ExecutionGraphDefinition,
        prompts: [SealedExecutionPrompt],
        effectiveStaticVariables: [String: String],
        contracts: [StepContractManifest],
        discovery: RepositoryDiscoveryReference,
        source: CandidateGraphSource,
        planningConstraintsHash: String,
        executionPolicy policy: EffectiveExecutionPolicy,
        lowererVersion: String = Self.version
    ) throws -> ExecutionArtifactBundle {
        let sortedPrompts = prompts.sorted { $0.stepLabel < $1.stepLabel }
        let sortedContracts = contracts.sorted { $0.stepLabel < $1.stepLabel }
        let workspaceRoot = try canonicalWorkspaceRoot(
            policy.logicalWorkspaceRoot
        )
        try validatePersistentContracts(
            definition: definition,
            contracts: sortedContracts,
            discovery: discovery,
            workspaceRoot: workspaceRoot
        )
        try validatePromptBindings(
            definition: definition,
            prompts: sortedPrompts,
            contracts: sortedContracts
        )
        let sourceHash = try hashSource(
            source: source,
            discovery: discovery,
            planningConstraintsHash: planningConstraintsHash
        )
        let executableHash = try hashExecutable(
            definition: definition,
            prompts: sortedPrompts,
            variables: effectiveStaticVariables,
            contracts: sortedContracts,
            policy: policy,
            lowererVersion: lowererVersion
        )
        return ExecutionArtifactBundle(
            lowererVersion: lowererVersion,
            definition: definition,
            prompts: sortedPrompts,
            effectiveStaticVariables: effectiveStaticVariables,
            contracts: sortedContracts,
            discovery: discovery,
            source: source,
            planningConstraintsHash: planningConstraintsHash,
            sourceHash: sourceHash,
            executableHash: executableHash
        )
    }

    public static func recomputeExecutableHash(
        bundle: ExecutionArtifactBundle,
        policy: EffectiveExecutionPolicy
    ) throws -> String {
        try hashExecutable(
            definition: bundle.definition,
            prompts: bundle.prompts,
            variables: bundle.effectiveStaticVariables,
            contracts: bundle.contracts,
            policy: policy,
            lowererVersion: bundle.lowererVersion
        )
    }

    public static func validateIdentity(
        bundle: ExecutionArtifactBundle,
        policy: EffectiveExecutionPolicy
    ) throws {
        guard bundle.schema == ExecutionArtifactBundle.currentSchema else {
            throw violation(
                "graph.lowering.bundle-schema",
                "unsupported artifact bundle schema '\(bundle.schema)'"
            )
        }
        let workspaceRoot = try canonicalWorkspaceRoot(
            policy.logicalWorkspaceRoot
        )
        try validatePersistentContracts(
            definition: bundle.definition,
            contracts: bundle.contracts,
            discovery: bundle.discovery,
            workspaceRoot: workspaceRoot
        )
        try validatePromptBindings(
            definition: bundle.definition,
            prompts: bundle.prompts,
            contracts: bundle.contracts
        )
        let sourceHash = try hashSource(
            source: bundle.source,
            discovery: bundle.discovery,
            planningConstraintsHash: bundle.planningConstraintsHash
        )
        guard sourceHash == bundle.sourceHash else {
            throw violation(
                "graph.lowering.hash-drift",
                "source hash drift: expected \(bundle.sourceHash), got \(sourceHash)"
            )
        }
        let executableHash = try recomputeExecutableHash(
            bundle: bundle,
            policy: policy
        )
        guard executableHash == bundle.executableHash else {
            throw violation(
                "graph.lowering.hash-drift",
                "executable hash drift: expected \(bundle.executableHash), "
                    + "got \(executableHash)"
            )
        }
    }

    public static func logicalPromptReference(stepLabel: String) -> String {
        "mentu://sealed-prompt/\(stepLabel)"
    }

    public static func completionKeyword(_ nodeID: String) -> String {
        "GRAPH_NODE_COMPLETE_" + nodeID.uppercased().map {
            $0.isLetter || $0.isNumber ? String($0) : "_"
        }.joined()
    }

    public static func renderPrompt(
        candidate: CandidateExecutionGraph,
        node: CandidateGraphNode,
        contract: CandidateStepContract
    ) -> String {
        let description = node.description?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let descriptionLine = description.map {
            "\nDescription: \($0)"
        } ?? ""
        let changes = contract.expectedChanges.isEmpty
            ? "(no committed application changes declared)"
            : contract.expectedChanges.joined(separator: ", ")
        let footprint = contract.footprint.joined(separator: ", ")
        return """
        <!-- \(promptTemplateVersion) -->
        # Objective
        \(candidate.objective)

        # Node
        ID: \(node.id)
        Title: \(node.title)\(descriptionLine)

        # Instruction
        \(node.promptBody)

        # Scope and verification
        Expected changes: \(changes)
        Footprint: \(footprint)
        Work only within this declared contract. Satisfy the node's mechanical verification requirements before reporting completion.
        When complete, write exactly: \(completionKeyword(node.id))
        """
    }

    private struct SourcePayload: Encodable {
        let source: CandidateGraphSource
        let discovery: RepositoryDiscoveryReference
        let planningConstraintsHash: String
        let rawProposalHash: String
    }

    private struct PromptBinding: Encodable {
        let stepLabel: String
        let sha256: String
    }

    private struct ExecutablePayload: Encodable {
        let schema = "mentu.execution-artifact.executable.v1"
        let lowererVersion: String
        let definition: ExecutionGraphDefinition
        let prompts: [PromptBinding]
        let variables: [String: String]
        let contracts: [StepContractManifest]
        let policy: EffectiveExecutionPolicy
    }

    private static func hashSource(
        source: CandidateGraphSource,
        discovery: RepositoryDiscoveryReference,
        planningConstraintsHash: String
    ) throws -> String {
        try ExecutionGraphCanonicalizer.hash(
            SourcePayload(
                source: source,
                discovery: discovery,
                planningConstraintsHash: planningConstraintsHash,
                rawProposalHash: source.rawProposalHash
            )
        )
    }

    private static func hashExecutable(
        definition: ExecutionGraphDefinition,
        prompts: [SealedExecutionPrompt],
        variables: [String: String],
        contracts: [StepContractManifest],
        policy: EffectiveExecutionPolicy,
        lowererVersion: String
    ) throws -> String {
        try ExecutionGraphCanonicalizer.hash(
            ExecutablePayload(
                lowererVersion: lowererVersion,
                definition: definition,
                prompts: prompts.map {
                    PromptBinding(
                        stepLabel: $0.stepLabel,
                        sha256: $0.sha256
                    )
                }.sorted { $0.stepLabel < $1.stepLabel },
                variables: variables,
                contracts: contracts.sorted {
                    $0.stepLabel < $1.stepLabel
                },
                policy: policy
            )
        )
    }

    private static func validatePromptBindings(
        definition: ExecutionGraphDefinition,
        prompts: [SealedExecutionPrompt],
        contracts: [StepContractManifest]
    ) throws {
        try validateDefinitionGraph(definition.steps)
        let labels = definition.steps.map(\.label)
        let promptLabels = prompts.map(\.stepLabel)
        let contractLabels = contracts.map(\.stepLabel)
        guard Set(promptLabels) == Set(labels),
              promptLabels.count == labels.count
        else {
            throw violation(
                "graph.lowering.missing-prompt",
                "sealed prompt labels do not match definition labels"
            )
        }
        guard Set(contractLabels) == Set(labels),
              contractLabels.count == labels.count
        else {
            throw violation(
                "graph.lowering.contract-count",
                "contract labels do not match definition labels"
            )
        }
        for prompt in prompts {
            let computed = ExecutionGraphDigest.sha256(prompt.body)
            guard computed == prompt.sha256 else {
                throw violation(
                    "graph.lowering.hash-drift",
                    "prompt hash drift for step '\(prompt.stepLabel)'"
                )
            }
        }
    }

    private static func validateDefinitionGraph(
        _ steps: [ExecutionGraphStep]
    ) throws {
        _ = try ExecutionDAG(
            nodes: steps.map {
                ExecutionDAG.Node(
                    id: $0.label,
                    dependencies: $0.dependsOn,
                    dispatchMode: $0.concurrentSafe
                        ? .parallelSafe
                        : .exclusive
                )
            }
        ).validatedFrontiers()
    }

    /// The persistent entry point receives public value types, so "already
    /// normalized" is a checked precondition rather than caller trust.
    private static func validatePersistentContracts(
        definition: ExecutionGraphDefinition,
        contracts: [StepContractManifest],
        discovery: RepositoryDiscoveryReference,
        workspaceRoot: String
    ) throws {
        guard definition.workspace == workspaceRoot,
              discovery.workspaceRoot == workspaceRoot
        else {
            throw violation(
                "graph.lowering.unsafe-path",
                "definition and discovery roots must equal the canonical "
                    + "logical workspace root"
            )
        }
        var contractsByLabel: [String: StepContractManifest] = [:]
        for contract in contracts {
            guard contractsByLabel.updateValue(
                contract,
                forKey: contract.stepLabel
            ) == nil else {
                throw violation(
                    "graph.lowering.contract-count",
                    "contract labels do not match definition labels"
                )
            }
            let normalized = try normalizeContract(
                CandidateStepContract(
                    expectedChanges: contract.expectedChanges,
                    footprint: contract.footprint,
                    verifyRequirements: contract.verifyRequirements,
                    concurrencySafe: contract.concurrencySafe,
                    timeoutSeconds: contract.timeoutSeconds,
                    maxPhases: contract.maxPhases,
                    permissionMode: contract.permissionMode,
                    sandboxPolicy: contract.sandboxPolicy,
                    approvalPolicy: contract.approvalPolicy,
                    toolRules: contract.toolRules,
                    mcpServers: contract.mcpServers,
                    tokenLimit: contract.tokenLimit,
                    budgetMicrosUSD: contract.budgetMicrosUSD
                ),
                nodeID: contract.stepLabel,
                workspaceRoot: workspaceRoot
            )
            guard manifest(
                label: contract.stepLabel,
                contract: normalized
            ) == contract else {
                throw contractViolation(
                    contract.stepLabel,
                    "persistent contract is not canonical"
                )
            }
        }
        for step in definition.steps {
            guard let contract = contractsByLabel[step.label] else {
                throw violation(
                    "graph.lowering.contract-count",
                    "contract labels do not match definition labels"
                )
            }
            let normalized = try normalizeContract(
                CandidateStepContract(
                    expectedChanges: step.expectedChanges,
                    footprint: step.footprint,
                    verifyRequirements: step.verifyRequirements,
                    concurrencySafe: step.concurrentSafe,
                    timeoutSeconds: step.timeout,
                    maxPhases: step.maxPhases,
                    permissionMode: step.permissionMode,
                    sandboxPolicy: step.sandboxPolicy,
                    approvalPolicy: step.approvalPolicy,
                    toolRules: step.permissions,
                    mcpServers: step.mcpServers,
                    tokenLimit: step.taskBudget,
                    budgetMicrosUSD: contract.budgetMicrosUSD
                ),
                nodeID: step.label,
                workspaceRoot: workspaceRoot
            )
            guard normalized.expectedChanges == step.expectedChanges,
                  normalized.footprint == step.footprint,
                  normalized.toolRules == step.permissions,
                  normalized.mcpServers == step.mcpServers,
                  step.expectedChanges == contract.expectedChanges,
                  step.footprint == contract.footprint,
                  step.verifyRequirements == contract.verifyRequirements,
                  step.concurrentSafe == contract.concurrencySafe,
                  step.timeout == contract.timeoutSeconds,
                  step.maxPhases == contract.maxPhases,
                  step.permissionMode == contract.permissionMode,
                  step.sandboxPolicy == contract.sandboxPolicy,
                  step.approvalPolicy == contract.approvalPolicy,
                  step.permissions == contract.toolRules,
                  step.mcpServers == contract.mcpServers,
                  step.taskBudget == contract.tokenLimit,
                  step.limits.maxDurationSeconds
                    == contract.timeoutSeconds,
                  step.limits.maxCostUSD.isFinite,
                  step.limits.maxCostUSD
                    == Double(contract.budgetMicrosUSD) / 1_000_000.0
            else {
                throw contractViolation(
                    step.label,
                    "definition step and persistent contract differ"
                )
            }
        }
    }

    private static func canonicalWorkspaceRoot(_ input: String) throws -> String {
        let root = input.precomposedStringWithCanonicalMapping
        guard root.hasPrefix("/"),
              !root.contains("\\"),
              !root.unicodeScalars.contains(where: {
                  CharacterSet.controlCharacters.contains($0)
              })
        else {
            throw violation(
                "graph.lowering.unsafe-path",
                "workspace root is not a safe absolute path: '\(input)'"
            )
        }
        let pieces = root.split(
            separator: "/",
            omittingEmptySubsequences: false
        )
        guard pieces.dropFirst().allSatisfy({
            !$0.isEmpty && $0 != "." && $0 != ".."
        }) else {
            throw violation(
                "graph.lowering.unsafe-path",
                "workspace root is not lexically canonical: '\(input)'"
            )
        }
        return root
    }

    private static func validateIdentifier(
        _ id: String,
        original: String
    ) throws {
        let allowed = CharacterSet.alphanumerics.union(
            CharacterSet(charactersIn: "._-")
        )
        guard !id.isEmpty,
              id.unicodeScalars.allSatisfy({ allowed.contains($0) }),
              !id.unicodeScalars.contains(where: {
                  CharacterSet.controlCharacters.contains($0)
              })
        else {
            throw violation(
                "graph.dag.invalid-node-id",
                "invalid normalized node id '\(original)'"
            )
        }
    }

    private static func topologicalOrder(
        _ nodes: [String: CandidateGraphNode]
    ) throws -> [CandidateGraphNode] {
        try ExecutionDAG(
            nodes: nodes.values.map {
                ExecutionDAG.Node(
                    id: $0.id,
                    dependencies: $0.dependsOn,
                    dispatchMode: $0.contract.concurrencySafe
                        ? .parallelSafe
                        : .exclusive
                )
            }
        )
        .validatedFrontiers()
        .flatMap { frontier in
            frontier.compactMap { nodes[$0.id] }
        }
    }

    private static func normalizeContract(
        _ contract: CandidateStepContract,
        nodeID: String,
        workspaceRoot: String
    ) throws -> CandidateStepContract {
        guard contract.timeoutSeconds > 0 else {
            throw contractViolation(
                nodeID,
                "timeout_seconds must be positive"
            )
        }
        guard contract.maxPhases > 0 else {
            throw contractViolation(nodeID, "max_phases must be positive")
        }
        guard contract.tokenLimit > 0, contract.budgetMicrosUSD >= 0 else {
            throw contractViolation(nodeID, "token/cost budget is invalid")
        }
        guard contract.permissionMode != "bypassPermissions" else {
            throw contractViolation(nodeID, "bypassPermissions is forbidden")
        }

        let changes: [String]
        do {
            changes = try ExecutionGraphCanonicalizer.normalizeSetPaths(
                contract.expectedChanges
            )
        } catch {
            throw violation(
                "graph.lowering.unsafe-path",
                "node '\(nodeID)' has invalid expected_changes: "
                    + error.localizedDescription
            )
        }
        for path in changes {
            guard path != "**/*", path != "**",
                  staticPrefix(path) != nil
            else {
                throw violation(
                    "graph.lowering.unsafe-path",
                    "node '\(nodeID)' has root-wide or prefix-free "
                        + "expected_changes '\(path)'"
                )
            }
        }

        let roots = Array(Set(contract.footprint.map {
            $0 == "." ? workspaceRoot
                : $0.precomposedStringWithCanonicalMapping
        })).sorted()
        guard !roots.isEmpty,
              roots.allSatisfy({ $0 == workspaceRoot })
        else {
            throw violation(
                "graph.lowering.unsafe-path",
                "node '\(nodeID)' footprint must equal the canonical "
                    + "logical workspace root"
            )
        }
        for server in contract.mcpServers
        where server.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty {
            throw contractViolation(nodeID, "empty MCP server name")
        }
        for rule in contract.toolRules {
            guard !rule.tool.isEmpty,
                  ["allow", "deny"].contains(rule.behavior)
            else {
                throw contractViolation(nodeID, "invalid tool rule")
            }
        }

        return CandidateStepContract(
            expectedChanges: changes,
            footprint: roots,
            verifyRequirements: contract.verifyRequirements,
            concurrencySafe: contract.concurrencySafe,
            timeoutSeconds: contract.timeoutSeconds,
            maxPhases: contract.maxPhases,
            permissionMode: contract.permissionMode,
            sandboxPolicy: contract.sandboxPolicy,
            approvalPolicy: contract.approvalPolicy,
            toolRules: contract.toolRules.sorted {
                ($0.tool, $0.behavior, $0.pattern ?? "")
                    < ($1.tool, $1.behavior, $1.pattern ?? "")
            },
            mcpServers: Array(Set(contract.mcpServers)).sorted(),
            tokenLimit: contract.tokenLimit,
            budgetMicrosUSD: contract.budgetMicrosUSD
        )
    }

    private static func staticPrefix(_ pattern: String) -> String? {
        let wildcard = pattern.firstIndex(where: { "*?[".contains($0) })
        let raw = wildcard.map { String(pattern[..<$0]) } ?? pattern
        let prefix = raw.trimmingCharacters(
            in: CharacterSet(charactersIn: "/")
        )
        return prefix.isEmpty ? nil : prefix
    }

    private static func validateVerificationCoverage(
        claims: [(node: String, path: String)],
        nodes: [CandidateGraphNode]
    ) throws {
        guard !claims.isEmpty else { return }
        let verifiers = nodes.filter {
            $0.id.hasSuffix("-verify")
                || $0.id.hasSuffix("-verification")
        }
        guard !verifiers.isEmpty else {
            throw violation(
                "graph.lowering.verification-coverage",
                "claimed changes require a terminal *-verify or "
                    + "*-verification node"
            )
        }
        let files = verifiers.flatMap {
            $0.contract.verifyRequirements.grepPresentFiles
        }
        for claim in claims {
            guard let prefix = staticPrefix(claim.path),
                  files.contains(where: {
                      $0 == prefix || $0.hasPrefix(prefix + "/")
                          || prefix.hasPrefix($0 + "/")
                  })
            else {
                throw violation(
                    "graph.lowering.verification-coverage",
                    "node '\(claim.node)' verification does not cover "
                        + "'\(claim.path)'"
                )
            }
        }
    }

    private static func manifest(
        label: String,
        contract: CandidateStepContract
    ) -> StepContractManifest {
        .init(
            stepLabel: label,
            expectedChanges: contract.expectedChanges,
            footprint: contract.footprint,
            verifyRequirements: contract.verifyRequirements,
            concurrencySafe: contract.concurrencySafe,
            timeoutSeconds: contract.timeoutSeconds,
            maxPhases: contract.maxPhases,
            permissionMode: contract.permissionMode,
            sandboxPolicy: contract.sandboxPolicy,
            approvalPolicy: contract.approvalPolicy,
            toolRules: contract.toolRules,
            mcpServers: contract.mcpServers,
            tokenLimit: contract.tokenLimit,
            budgetMicrosUSD: contract.budgetMicrosUSD
        )
    }

    private static func contractViolation(
        _ nodeID: String,
        _ detail: String
    ) -> ExecutionGraphViolation {
        violation(
            "graph.lowering.invalid-contract",
            "node '\(nodeID)': \(detail)"
        )
    }

    private static func violation(
        _ id: String,
        _ detail: String
    ) -> ExecutionGraphViolation {
        .init(id: id, detail: detail)
    }
}
