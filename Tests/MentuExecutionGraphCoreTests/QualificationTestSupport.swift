import Foundation
import MentuExecutionGraphCore

struct QualificationPassingProfile: ExecutionGraphQualificationProfile {
    var checks: [QualificationCheck] = [
        QualificationCheck(
            id: "linter.mechanical",
            passed: true,
            detail: "mechanical verification passed"
        ),
    ]
    var declaredCheckIDs: [String]? = nil

    var descriptor: ExecutionGraphQualificationProfileDescriptor {
        ExecutionGraphQualificationProfileDescriptor(
            profileID: "mentu.core.tests.passing.v1",
            expectedCheckIDs: declaredCheckIDs ?? checks.map(\.id)
        )
    }

    func qualify(
        definition: ExecutionGraphDefinition,
        bundle: ExecutionArtifactBundle,
        envelope: ExecutionAuthorityEnvelope
    ) async throws -> [QualificationCheck] {
        checks
    }
}

enum QualificationTestSupport {
    static let root = "/workspace/project"
    static let executionRoot = root + "/.worktrees/test-run"
    static let endpoint = "https://api.example.test/v1/messages"
    static let instant = Date(timeIntervalSince1970: 1_767_225_600)
    static let trustedProfile = QualificationPassingProfile()
    static let trustedDescriptor = trustedProfile.descriptor

    static func policy(
        backend: String = "claude",
        initialAuthProfile: String = "auth-primary",
        maximumParallelSteps: Int = 2,
        runTokenCeiling: Int = 8_000,
        perStepTokenCeiling: Int = 4_000,
        runBudgetMicrosUSD: Int64 = 1_000_000,
        perStepBudgetMicrosUSD: Int64 = 500_000,
        authFallbackChain: [AuthFallbackBinding]? = nil
    ) throws -> EffectiveExecutionPolicy {
        EffectiveExecutionPolicy(
            logicalWorkspaceRoot: root,
            fixedBackend: backend,
            fixedModel: "model",
            initialAuthProfile: initialAuthProfile,
            configuredEndpoint: endpoint,
            endpointConfigDigest: ExecutionGraphDigest.sha256(
                ["claude", "model", endpoint].joined(separator: "\u{0}")
            ),
            maximumParallelSteps: maximumParallelSteps,
            defaultPermissionMode: "default",
            defaultSandboxPolicy: "workspace-write",
            defaultApprovalPolicy: "never",
            runTokenCeiling: runTokenCeiling,
            perStepTokenCeiling: perStepTokenCeiling,
            runBudgetMicrosUSD: runBudgetMicrosUSD,
            perStepBudgetMicrosUSD: perStepBudgetMicrosUSD,
            runSoftDeadlineSeconds: 1_800,
            stepSoftDeadlineSeconds: 600,
            authFallbackChain:
                authFallbackChain ?? [
                    AuthFallbackBinding(
                        profileId: initialAuthProfile,
                        configDigest:
                            ExecutionGraphDigest.sha256(initialAuthProfile)
                    ),
                ],
            toolPolicyDigest: try ExecutionGraphCanonicalizer.hash([
                CandidateToolRule(tool: "Read", behavior: "allow"),
            ]),
            mcpPolicyDigest: try ExecutionGraphCanonicalizer.hash(
                [String]()
            )
        )
    }

    static func envelope(
        hostBackends: [String] = ["claude"],
        hostAuthProfiles: [String] = ["auth-primary"],
        runTokenCeiling: Int = 8_000,
        perStepTokenCeiling: Int = 4_000,
        runBudgetMicrosUSD: Int64 = 1_000_000,
        perStepBudgetMicrosUSD: Int64 = 500_000,
        expiry: String? = nil
    ) -> ExecutionAuthorityEnvelope {
        ExecutionAuthorityEnvelope(
            workspaceRoot: root,
            discoveryReadPrefixes: ["Sources"],
            plannerEgressPrefixes: ["Sources"],
            plannerEgressByteCeiling: 65_536,
            plannerProviders: ["anthropic"],
            plannerModels: ["planner-model"],
            plannerAuthProfiles: ["planner-auth"],
            plannerEndpoints: [endpoint],
            footprintRoots: [root],
            changePrefixes: ["Sources"],
            hostBackends: hostBackends,
            hostModels: ["model"],
            hostAuthProfiles: hostAuthProfiles,
            permissionModes: ["default"],
            sandboxPolicies: ["read-only", "workspace-write"],
            approvalPolicies: ["never"],
            executionEndpoints: [endpoint],
            toolRules: [
                CandidateToolRule(tool: "Read", behavior: "allow"),
            ],
            mcpServers: [],
            maximumStepCount: 4,
            maximumDependencyDepth: 4,
            maximumParallelSteps: 2,
            perStepTokenCeiling: perStepTokenCeiling,
            runTokenCeiling: runTokenCeiling,
            perStepBudgetMicrosUSD: perStepBudgetMicrosUSD,
            runBudgetMicrosUSD: runBudgetMicrosUSD,
            stepSoftDeadlineSeconds: 600,
            runSoftDeadlineSeconds: 1_800,
            dynamicInputLanes: ["steering", "upstream-output"],
            networkBackendsPermitted: true,
            expiry: expiry,
            provenance: "core-tests"
        )
    }

    static func bundle(
        policy: EffectiveExecutionPolicy? = nil,
        budgetsMicrosUSD: [Int64] = [200_000],
        tokenLimit: Int = 2_000
    ) throws -> ExecutionArtifactBundle {
        let policy = try policy ?? self.policy()
        let verification = try MechanicalVerificationContract()
        let nodes = budgetsMicrosUSD.enumerated().map { index, budget in
            let label = budgetsMicrosUSD.count == 1
                ? "inspect"
                : "inspect-\(index + 1)"
            return CandidateGraphNode(
                id: label,
                title: "Inspect",
                dependsOn: [],
                promptBody: "Inspect the bounded source.",
                contract: CandidateStepContract(
                    expectedChanges: [],
                    footprint: [root],
                    verifyRequirements: verification,
                    concurrencySafe: false,
                    timeoutSeconds: 300,
                    maxPhases: 2,
                    permissionMode: "default",
                    sandboxPolicy: "workspace-write",
                    approvalPolicy: "never",
                    toolRules: [
                        CandidateToolRule(tool: "Read", behavior: "allow"),
                    ],
                    mcpServers: [],
                    tokenLimit: tokenLimit,
                    budgetMicrosUSD: budget
                )
            )
        }
        let proposal = PlannerGraphProposal(nodes: nodes)
        let candidate = CandidateExecutionGraph(
            objective: "Inspect a deterministic source surface.",
            source: CandidateGraphSource(
                authorKind: "planner",
                authorId: "core-tests",
                plannerModel: "planner-model",
                plannerSystemPromptHash:
                    ExecutionGraphDigest.sha256("planner-prompt"),
                endpointConfigDigest: policy.endpointConfigDigest,
                rawProposalHash: try ExecutionGraphCanonicalizer.hash(
                    proposal
                ),
                emitterVersion: "core-tests.v1"
            ),
            discovery: RepositoryDiscoveryReference(
                workspaceRoot: root,
                gitHead: "0123456789abcdef0123456789abcdef01234567",
                snapshotHash:
                    ExecutionGraphDigest.sha256("selected-read-set")
            ),
            planningConstraintsHash:
                ExecutionGraphDigest.sha256("planning-constraints"),
            nodes: nodes
        )
        return try ExecutionGraphLowerer.buildBundle(
            candidate: candidate,
            executionPolicy: policy
        )
    }

    static func qualified(
        envelope: ExecutionAuthorityEnvelope? = nil,
        policy: EffectiveExecutionPolicy? = nil,
        requiredSandboxesAvailable: Bool = true,
        profile: any ExecutionGraphQualificationProfile =
            QualificationPassingProfile()
    ) async throws -> QualifiedExecution {
        let policy = try policy ?? self.policy()
        let bundle = try bundle(policy: policy)
        return try await ExecutionGraphQualification.qualify(
            definition: bundle.definition,
            bundle: bundle,
            envelope: envelope ?? self.envelope(),
            effectivePolicy: policy,
            capturedFacts: QualificationCapturedFacts(
                qualificationStateDigest:
                    ExecutionGraphDigest.sha256("clean-state"),
                dependencyReportHash:
                    ExecutionGraphDigest.sha256("dependencies"),
                requiredSandboxesAvailable:
                    requiredSandboxesAvailable
            ),
            profile: profile,
            clock: FixedExecutionGraphClock(instant)
        )
    }

    static func runtime(
        qualified: QualifiedExecution,
        finalGitHead: String? = nil,
        runtimeStateDigest: String? = nil
    ) throws -> AdmissionRuntimeContext {
        AdmissionRuntimeContext(
            runId: "run_core_tests",
            logicalWorkspaceRoot: root,
            executionRoot: executionRoot,
            transferMode: "worktree",
            acquiredLockRoots: [executionRoot],
            baselineDigests: [
                executionRoot:
                    ExecutionGraphDigest.sha256("workspace-snapshot"),
            ],
            finalGitHead:
                finalGitHead ?? qualified.bundle.discovery.gitHead,
            finalGitStatusDigest:
                ExecutionGraphAdmission.cleanStatusDigest,
            selectedReadSetHash:
                qualified.bundle.discovery.snapshotHash,
            dependencyReportHash:
                qualified.qualification.dependencyReportHash,
            effectiveVariablesHash:
                try ExecutionGraphCanonicalizer.hash(
                    qualified.bundle.effectiveStaticVariables
                ),
            effectiveBackend:
                qualified.effectivePolicy.fixedBackend,
            effectiveModel: qualified.effectivePolicy.fixedModel,
            currentAuthProfile:
                qualified.effectivePolicy.initialAuthProfile,
            endpointConfigDigest:
                qualified.effectivePolicy.endpointConfigDigest,
            permissionMode:
                qualified.effectivePolicy.defaultPermissionMode,
            sandboxPolicy:
                qualified.effectivePolicy.defaultSandboxPolicy,
            approvalPolicy:
                qualified.effectivePolicy.defaultApprovalPolicy,
            mcpConfigurationDigest:
                qualified.effectivePolicy.mcpPolicyDigest,
            primitiveContractHash:
                ExecutionGraphDigest.sha256("host-loop.v1"),
            backendAdapterDigest:
                ExecutionGraphDigest.sha256("host-adapter"),
            engineVersion: "core-tests-engine.v1",
            qualificationSourceStateDigest:
                qualified.qualification.qualificationStateDigest,
            runtimeStateDigest:
                runtimeStateDigest
                    ?? qualified.qualification.qualificationStateDigest,
            admittedOuterCallEvidence: true,
            gateRecordOverrideUsed: false
        )
    }

    static func admitted() async throws -> AdmittedExecution {
        let qualified = try await qualified()
        return try await ExecutionGraphAdmission.admit(
            qualified: qualified,
            runtime: try runtime(qualified: qualified),
            trustedProfile: trustedProfile,
            clock: FixedExecutionGraphClock(instant)
        )
    }

    static func stepStart(
        admitted: AdmittedExecution,
        lane: String = "steering",
        content: String = "preserve the exact boundary"
    ) -> StepStartContext {
        StepStartContext(
            runId: admitted.receipt.runId,
            stepLabel: "inspect",
            workspaceSnapshot: StepSnapshotIdentity(
                runId: admitted.receipt.runId,
                stepLabel: "inspect",
                canonicalTarget: executionRoot
            ),
            dataSnapshots: [],
            inputs: [
                StepStartInput(
                    lane: lane,
                    source: "test",
                    content: content
                ),
            ],
            effectiveBackend:
                admitted.effectivePolicy.fixedBackend,
            effectiveModel: admitted.effectivePolicy.fixedModel,
            effectiveAuthProfile:
                admitted.effectivePolicy.initialAuthProfile,
            effectivePermissionMode:
                admitted.effectivePolicy.defaultPermissionMode
        )
    }

    static func fixtureData(_ name: String) throws -> Data {
        try Data(contentsOf: executionGraphBaselineFixture(name))
    }
}
