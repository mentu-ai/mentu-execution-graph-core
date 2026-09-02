import Foundation
import Testing
@testable import MentuExecutionGraphCore

@Suite("Pure execution graph lowering")
struct LowererTests {
    private func baseline() throws
        -> (CandidateExecutionGraph, EffectiveExecutionPolicy)
    {
        let candidate = try JSONDecoder().decode(
            CandidateExecutionGraph.self,
            from: Data(
                contentsOf: executionGraphBaselineFixture(
                    "candidate-graph.json"
                )
            )
        )
        let policy = try JSONDecoder().decode(
            EffectiveExecutionPolicy.self,
            from: Data(
                contentsOf: executionGraphBaselineFixture(
                    "effective-policy.json"
                )
            )
        )
        return (candidate, policy)
    }

    @Test("frozen definition, bundle bytes, and identities remain exact")
    func frozenParity() throws {
        let (candidate, policy) = try baseline()
        let bundle = try ExecutionGraphLowerer.buildBundle(
            candidate: candidate,
            executionPolicy: policy
        )
        let expectedBundle = try Data(
            contentsOf: executionGraphBaselineFixture("artifact-bundle.json")
        )
        let expectedDefinition = try Data(
            contentsOf: executionGraphBaselineFixture(
                "lowered-definition.json"
            )
        )
        #expect(
            try ExecutionGraphCanonicalizer.data(bundle.definition)
                == expectedDefinition
        )
        #expect(try ExecutionGraphCanonicalizer.data(bundle) == expectedBundle)
        #expect(
            bundle.sourceHash
                == "a1418879a3df88b68c10c9acd976db72026db37e9393e38b63a977f71e6d9c54"
        )
        #expect(
            bundle.executableHash
                == "15b112193913f69c58e7427d434176a31b4c803bf7167833843765463c2a3656"
        )
        try ExecutionGraphLowerer.validateIdentity(
            bundle: bundle,
            policy: policy
        )
    }

    @Test("input and dependency order normalize deterministically")
    func deterministicOrdering() throws {
        let (candidate, policy) = try baseline()
        let reordered = CandidateExecutionGraph(
            objective: candidate.objective,
            source: candidate.source,
            discovery: candidate.discovery,
            planningConstraintsHash: candidate.planningConstraintsHash,
            nodes: candidate.nodes.reversed()
        )
        let first = try ExecutionGraphLowerer.buildBundle(
            candidate: candidate,
            executionPolicy: policy
        )
        let second = try ExecutionGraphLowerer.buildBundle(
            candidate: reordered,
            executionPolicy: policy
        )
        #expect(first == second)
        #expect(first.definition.steps.map(\.label)
            == ["recon", "implement", "final-verify"])
    }

    @Test("topology, prompt, path, and contract failures have stable IDs")
    func typedRefusals() throws {
        let (base, policy) = try baseline()
        let node = base.nodes[0]

        let duplicate = replacingNodes(base, [node, node])
        #expect(
            violationID {
                try ExecutionGraphLowerer.lower(
                    duplicate,
                    executionPolicy: policy
                )
            } == "graph.dag.duplicate-node"
        )

        let unknownNode = CandidateGraphNode(
            id: node.id,
            title: node.title,
            description: node.description,
            dependsOn: ["missing"],
            promptBody: node.promptBody,
            contract: node.contract
        )
        #expect(
            violationID {
                try ExecutionGraphLowerer.lower(
                    replacingNodes(base, [unknownNode]),
                    executionPolicy: policy
                )
            } == "graph.dag.unknown-dependency"
        )

        let first = CandidateGraphNode(
            id: "first",
            title: "first",
            dependsOn: ["second"],
            promptBody: "first",
            contract: node.contract
        )
        let second = CandidateGraphNode(
            id: "second",
            title: "second",
            dependsOn: ["first"],
            promptBody: "second",
            contract: node.contract
        )
        #expect(
            violationID {
                try ExecutionGraphLowerer.lower(
                    replacingNodes(base, [first, second]),
                    executionPolicy: policy
                )
            } == "graph.dag.cycle"
        )

        let emptyPrompt = CandidateGraphNode(
            id: node.id,
            title: node.title,
            description: node.description,
            dependsOn: [],
            promptBody: " \n",
            contract: node.contract
        )
        #expect(
            violationID {
                try ExecutionGraphLowerer.lower(
                    replacingNodes(base, [emptyPrompt]),
                    executionPolicy: policy
                )
            } == "graph.lowering.missing-prompt"
        )

        let unsafeContract = CandidateStepContract(
            expectedChanges: ["../escape"],
            footprint: node.contract.footprint,
            verifyRequirements: node.contract.verifyRequirements,
            concurrencySafe: node.contract.concurrencySafe,
            timeoutSeconds: node.contract.timeoutSeconds,
            maxPhases: node.contract.maxPhases,
            permissionMode: node.contract.permissionMode,
            sandboxPolicy: node.contract.sandboxPolicy,
            approvalPolicy: node.contract.approvalPolicy,
            toolRules: node.contract.toolRules,
            mcpServers: node.contract.mcpServers,
            tokenLimit: node.contract.tokenLimit,
            budgetMicrosUSD: node.contract.budgetMicrosUSD
        )
        let unsafe = CandidateGraphNode(
            id: node.id,
            title: node.title,
            dependsOn: [],
            promptBody: node.promptBody,
            contract: unsafeContract
        )
        #expect(
            violationID {
                try ExecutionGraphLowerer.lower(
                    replacingNodes(base, [unsafe]),
                    executionPolicy: policy
                )
            } == "graph.lowering.unsafe-path"
        )
    }

    @Test("hash drift is refused before dispatch")
    func hashDrift() throws {
        let (candidate, policy) = try baseline()
        let bundle = try ExecutionGraphLowerer.buildBundle(
            candidate: candidate,
            executionPolicy: policy
        )
        var prompts = bundle.prompts
        let first = prompts[0]
        prompts[0] = .init(
            stepLabel: first.stepLabel,
            body: first.body + "\ndrift",
            sha256: first.sha256
        )
        let drifted = ExecutionArtifactBundle(
            lowererVersion: bundle.lowererVersion,
            definition: bundle.definition,
            prompts: prompts,
            effectiveStaticVariables: bundle.effectiveStaticVariables,
            contracts: bundle.contracts,
            discovery: bundle.discovery,
            source: bundle.source,
            planningConstraintsHash: bundle.planningConstraintsHash,
            sourceHash: bundle.sourceHash,
            executableHash: bundle.executableHash
        )
        #expect(
            violationID {
                try ExecutionGraphLowerer.validateIdentity(
                    bundle: drifted,
                    policy: policy
                )
            } == "graph.lowering.hash-drift"
        )
    }

    @Test("persistent builder refuses unsafe contract paths")
    func persistentUnsafePathRefusal() throws {
        let (candidate, policy) = try baseline()
        let bundle = try ExecutionGraphLowerer.buildBundle(
            candidate: candidate,
            executionPolicy: policy
        )
        let original = bundle.contracts[0]
        var contracts = bundle.contracts
        contracts[0] = StepContractManifest(
            stepLabel: original.stepLabel,
            expectedChanges: [
                "Sources/**/../../etc/passwd",
            ],
            footprint: original.footprint,
            verifyRequirements: original.verifyRequirements,
            concurrencySafe: original.concurrencySafe,
            timeoutSeconds: original.timeoutSeconds,
            maxPhases: original.maxPhases,
            permissionMode: original.permissionMode,
            sandboxPolicy: original.sandboxPolicy,
            approvalPolicy: original.approvalPolicy,
            toolRules: original.toolRules,
            mcpServers: original.mcpServers,
            tokenLimit: original.tokenLimit,
            budgetMicrosUSD: original.budgetMicrosUSD
        )
        #expect(
            violationID {
                try ExecutionGraphLowerer.buildBundle(
                    definition: bundle.definition,
                    prompts: bundle.prompts,
                    effectiveStaticVariables:
                        bundle.effectiveStaticVariables,
                    contracts: contracts,
                    discovery: bundle.discovery,
                    source: bundle.source,
                    planningConstraintsHash:
                        bundle.planningConstraintsHash,
                    executionPolicy: policy
                )
            } == "graph.lowering.unsafe-path"
        )
    }

    @Test("pure lowering does not create or mutate its target workspace")
    func noWorkspaceWrite() throws {
        let (base, policy) = try baseline()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "mentu-core-pure-\(UUID().uuidString)",
                isDirectory: true
            )
        #expect(!FileManager.default.fileExists(atPath: root.path))
        let discovery = RepositoryDiscoveryReference(
            workspaceRoot: root.path,
            gitHead: base.discovery.gitHead,
            snapshotHash: base.discovery.snapshotHash
        )
        let candidate = CandidateExecutionGraph(
            objective: base.objective,
            source: base.source,
            discovery: discovery,
            planningConstraintsHash: base.planningConstraintsHash,
            nodes: base.nodes.map { node in
                CandidateGraphNode(
                    id: node.id,
                    title: node.title,
                    description: node.description,
                    dependsOn: node.dependsOn,
                    promptBody: node.promptBody,
                    contract: CandidateStepContract(
                        expectedChanges: node.contract.expectedChanges,
                        footprint: [root.path],
                        verifyRequirements: node.contract.verifyRequirements,
                        concurrencySafe: node.contract.concurrencySafe,
                        timeoutSeconds: node.contract.timeoutSeconds,
                        maxPhases: node.contract.maxPhases,
                        permissionMode: node.contract.permissionMode,
                        sandboxPolicy: node.contract.sandboxPolicy,
                        approvalPolicy: node.contract.approvalPolicy,
                        toolRules: node.contract.toolRules,
                        mcpServers: node.contract.mcpServers,
                        tokenLimit: node.contract.tokenLimit,
                        budgetMicrosUSD: node.contract.budgetMicrosUSD
                    )
                )
            }
        )
        let selectedPolicy = EffectiveExecutionPolicy(
            logicalWorkspaceRoot: root.path,
            fixedBackend: policy.fixedBackend,
            fixedModel: policy.fixedModel,
            initialAuthProfile: policy.initialAuthProfile,
            configuredEndpoint: policy.configuredEndpoint,
            endpointConfigDigest: policy.endpointConfigDigest,
            transferMode: policy.transferMode,
            maximumParallelSteps: policy.maximumParallelSteps,
            defaultPermissionMode: policy.defaultPermissionMode,
            defaultSandboxPolicy: policy.defaultSandboxPolicy,
            defaultApprovalPolicy: policy.defaultApprovalPolicy,
            runTokenCeiling: policy.runTokenCeiling,
            perStepTokenCeiling: policy.perStepTokenCeiling,
            runBudgetMicrosUSD: policy.runBudgetMicrosUSD,
            perStepBudgetMicrosUSD: policy.perStepBudgetMicrosUSD,
            runSoftDeadlineSeconds: policy.runSoftDeadlineSeconds,
            stepSoftDeadlineSeconds: policy.stepSoftDeadlineSeconds,
            authFallbackChain: policy.authFallbackChain,
            pluginPolicy: policy.pluginPolicy,
            backgroundHookPolicy: policy.backgroundHookPolicy,
            outerCallEvidencePolicy: policy.outerCallEvidencePolicy,
            toolPolicyDigest: policy.toolPolicyDigest,
            mcpPolicyDigest: policy.mcpPolicyDigest
        )
        _ = try ExecutionGraphLowerer.buildBundle(
            candidate: candidate,
            executionPolicy: selectedPolicy
        )
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }

    private func replacingNodes(
        _ value: CandidateExecutionGraph,
        _ nodes: [CandidateGraphNode]
    ) -> CandidateExecutionGraph {
        .init(
            objective: value.objective,
            source: value.source,
            discovery: value.discovery,
            planningConstraintsHash: value.planningConstraintsHash,
            nodes: nodes
        )
    }

    private func violationID<T>(
        _ operation: () throws -> T
    ) -> String? {
        do {
            _ = try operation()
            return nil
        } catch let violation as ExecutionGraphViolation {
            return violation.id
        } catch {
            return nil
        }
    }
}
