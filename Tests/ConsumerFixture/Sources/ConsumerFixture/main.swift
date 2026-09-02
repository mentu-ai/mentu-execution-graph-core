import MentuExecutionGraphCore

private struct ConsumerQualificationProfile:
    ExecutionGraphQualificationProfile
{
    let descriptor = ExecutionGraphQualificationProfileDescriptor(
        profileID: "mentu.consumer-fixture.v1",
        expectedCheckIDs: ["consumer.in-memory-contract"]
    )

    func qualify(
        definition: ExecutionGraphDefinition,
        bundle: ExecutionArtifactBundle,
        envelope: ExecutionAuthorityEnvelope
    ) async throws -> [QualificationCheck] {
        [
            QualificationCheck(
                id: "consumer.in-memory-contract",
                passed: definition == bundle.definition,
                detail: "consumer checked the in-memory lowered definition"
            ),
        ]
    }
}

private actor ConsumerSchedulerEvidence: GraphSchedulerEventSink {
    private var storage: [GraphSchedulerEvent] = []

    func record(_ event: GraphSchedulerEvent) async {
        storage.append(event)
    }

    func events() -> [GraphSchedulerEvent] {
        storage
    }
}

@main
private struct ConsumerFixture {
    private static let root = "/consumer/workspace"
    private static let executionRoot =
        "/consumer/workspace/.worktrees/consumer-run"
    private static let endpoint = "https://consumer.invalid/v1/messages"
    private static let gitHead =
        "0123456789abcdef0123456789abcdef01234567"
    private static let expectedCandidateHash =
        "9b11259126cab0b26dfab194b20465dff21920afaa23399cafaf12c6b764afa2"
    private static let expectedSourceHash =
        "92b3dc342c70cf70c2b2f15e19d31d0fcad1808aadcb408bd8a07bedf2872140"
    private static let expectedExecutableHash =
        "344bb431c1a0287abd1f868806fde83cb9ead63788d009ec2a00b29451395559"
    private static let expectedQualificationHash =
        "84c113e6494bbdc40cf84ee369e9dbd86c4d99271027e1dac83f46b864df7914"
    private static let expectedReceiptID =
        "rcpt_0550b831090c2b651b6317a7"
    private static let expectedReceiptHash =
        "545ac7c09017ac768fbf5ef3729b8459b1aa31d7f703ee4470fb95ada30718bc"
    private static let expectedEventOrder = [
        "1:scheduleStarted:-:-",
        "2:frontierStarted:1:-",
        "3:nodeDispatched:1:discover",
        "4:nodeCompleted:1:discover",
        "5:frontierCompleted:1:-",
        "6:frontierStarted:2:-",
        "7:nodeDispatched:2:prepare",
        "8:nodeDispatched:2:verify",
        "9:nodeCompleted:2:prepare",
        "10:nodeCompleted:2:verify",
        "11:frontierCompleted:2:-",
        "12:scheduleCompleted:-:-",
    ]

    static func main() async throws {
        let policy = try executionPolicy()
        let nodes = try [
            node("discover", dependencies: [], concurrencySafe: false),
            node(
                "prepare",
                dependencies: ["discover"],
                concurrencySafe: true
            ),
            node(
                "verify",
                dependencies: ["discover"],
                concurrencySafe: true
            ),
        ]
        let proposal = PlannerGraphProposal(nodes: nodes)
        let source = CandidateGraphSource(
            authorKind: "consumer-fixture",
            authorId: "consumer",
            plannerModel: "fixture-planner",
            plannerSystemPromptHash:
                ExecutionGraphDigest.sha256("fixture-system-prompt"),
            endpointConfigDigest: policy.endpointConfigDigest,
            rawProposalHash:
                try ExecutionGraphCanonicalizer.hash(proposal),
            emitterVersion: "consumer-fixture.v1"
        )
        let candidate = CandidateExecutionGraph(
            objective: "Prove a standalone three-node consumer.",
            source: source,
            discovery: RepositoryDiscoveryReference(
                workspaceRoot: root,
                gitHead: gitHead,
                snapshotHash:
                    ExecutionGraphDigest.sha256("consumer-read-set")
            ),
            planningConstraintsHash:
                ExecutionGraphDigest.sha256("consumer-constraints"),
            nodes: nodes
        )

        let lowered = try ExecutionGraphLowerer.lower(
            candidate,
            executionPolicy: policy
        )
        let bundle = try ExecutionGraphLowerer.buildBundle(
            candidate: candidate,
            executionPolicy: policy
        )
        guard lowered.report.executableHash == bundle.executableHash else {
            throw ExecutionGraphViolation(
                id: "consumer.lowering-drift",
                detail: "lowered graph and bundle identities differ"
            )
        }

        let envelope = authorityEnvelope()
        let clock = FixedExecutionGraphClock(
            .init(timeIntervalSince1970: 1_700_000_000)
        )
        let qualified = try await ExecutionGraphQualification.qualify(
            definition: bundle.definition,
            bundle: bundle,
            envelope: envelope,
            effectivePolicy: policy,
            capturedFacts: QualificationCapturedFacts(
                qualificationStateDigest:
                    ExecutionGraphDigest.sha256("consumer-clean-state"),
                dependencyReportHash:
                    ExecutionGraphDigest.sha256("consumer-dependencies")
            ),
            profile: ConsumerQualificationProfile(),
            clock: clock
        )
        let runtime = try runtimeContext(qualified)
        let admitted = try await ExecutionGraphAdmission.admit(
            qualified: qualified,
            runtime: runtime,
            trustedProfile: ConsumerQualificationProfile(),
            clock: clock
        )
        guard admitted.receipt.executableHash == bundle.executableHash else {
            throw ExecutionGraphViolation(
                id: "consumer.admission-drift",
                detail: "admission receipt does not bind the executable"
            )
        }

        let dag = ExecutionDAG(
            nodes: admitted.bundle.definition.steps.map {
                ExecutionDAG.Node(
                    id: $0.label,
                    dependencies: $0.dependsOn,
                    dispatchMode: $0.concurrentSafe
                        ? .parallelSafe
                        : .exclusive
                )
            }
        )
        let evidence = ConsumerSchedulerEvidence()
        let scheduled = try await ExecutionGraphScheduler().run(
            dag: dag,
            initialStates: [:],
            maximumParallelism: 2,
            failurePolicy: .continueIndependentBranches,
            eventSink: evidence
        ) {
            GraphStepOutcome(nodeId: $0.nodeId, state: .succeeded)
        }
        let events = await evidence.events()
        guard scheduled.outcomes.count == 3,
              scheduled.outcomes.allSatisfy({ $0.state == .succeeded }),
              !events.isEmpty
        else {
            throw ExecutionGraphViolation(
                id: "consumer.scheduler-proof",
                detail: "three-node in-memory schedule did not complete"
            )
        }

        let candidateHash = try ExecutionGraphCanonicalizer.hash(candidate)
        guard candidateHash == expectedCandidateHash,
              bundle.sourceHash == expectedSourceHash,
              bundle.executableHash == expectedExecutableHash,
              qualified.qualification.reportHash
                == expectedQualificationHash,
              admitted.receipt.receiptId == expectedReceiptID,
              admitted.receipt.receiptHash == expectedReceiptHash
        else {
            throw ExecutionGraphViolation(
                id: "consumer.identity-drift",
                detail:
                    "candidate=\(candidateHash) "
                    + "source=\(bundle.sourceHash) "
                    + "executable=\(bundle.executableHash) "
                    + "qualification="
                    + "\(qualified.qualification.reportHash) "
                    + "receiptId=\(admitted.receipt.receiptId) "
                    + "receiptHash=\(admitted.receipt.receiptHash)"
            )
        }
        let eventOrder = events.map {
            "\($0.sequence):\($0.kind.rawValue):"
                + "\($0.frontier.map(String.init) ?? "-"):"
                + "\($0.nodeId ?? "-")"
        }
        guard scheduled.dispatchOrder == ["discover", "prepare", "verify"],
              eventOrder == expectedEventOrder
        else {
            throw ExecutionGraphViolation(
                id: "consumer.event-order-drift",
                detail: "standalone consumer scheduler evidence changed"
            )
        }
        print(
            "consumer-fixture: admitted=\(admitted.receipt.receiptId) "
                + "receiptHash=\(admitted.receipt.receiptHash) "
                + "nodes=\(scheduled.outcomes.count) "
                + "events=\(events.count)"
        )
    }

    private static func node(
        _ id: String,
        dependencies: [String],
        concurrencySafe: Bool
    ) throws -> CandidateGraphNode {
        CandidateGraphNode(
            id: id,
            title: id,
            dependsOn: dependencies,
            promptBody: "Complete the in-memory \(id) node.",
            contract: CandidateStepContract(
                expectedChanges: [],
                footprint: [root],
                verifyRequirements:
                    try MechanicalVerificationContract(),
                concurrencySafe: concurrencySafe,
                timeoutSeconds: 60,
                maxPhases: 1,
                permissionMode: "default",
                sandboxPolicy: "workspace-write",
                approvalPolicy: "never",
                toolRules: [],
                mcpServers: [],
                tokenLimit: 1_000,
                budgetMicrosUSD: 100_000
            )
        )
    }

    private static func executionPolicy()
        throws -> EffectiveExecutionPolicy
    {
        let endpointDigest = ExecutionGraphDigest.sha256(
            ["fixture", "model", endpoint].joined(separator: "\u{0}")
        )
        return EffectiveExecutionPolicy(
            logicalWorkspaceRoot: root,
            fixedBackend: "fixture",
            fixedModel: "model",
            initialAuthProfile: "in-memory",
            configuredEndpoint: endpoint,
            endpointConfigDigest: endpointDigest,
            maximumParallelSteps: 2,
            defaultPermissionMode: "default",
            defaultSandboxPolicy: "workspace-write",
            defaultApprovalPolicy: "never",
            runTokenCeiling: 10_000,
            perStepTokenCeiling: 4_000,
            runBudgetMicrosUSD: 1_000_000,
            perStepBudgetMicrosUSD: 500_000,
            runSoftDeadlineSeconds: 600,
            stepSoftDeadlineSeconds: 120,
            authFallbackChain: [
                AuthFallbackBinding(
                    profileId: "in-memory",
                    configDigest:
                        ExecutionGraphDigest.sha256("in-memory")
                ),
            ],
            toolPolicyDigest:
                try ExecutionGraphCanonicalizer.hash(
                    [CandidateToolRule]()
                ),
            mcpPolicyDigest:
                try ExecutionGraphCanonicalizer.hash([String]())
        )
    }

    private static func authorityEnvelope()
        -> ExecutionAuthorityEnvelope
    {
        ExecutionAuthorityEnvelope(
            workspaceRoot: root,
            discoveryReadPrefixes: [],
            plannerEgressPrefixes: [],
            plannerEgressByteCeiling: 0,
            plannerProviders: ["fixture"],
            plannerModels: ["fixture-planner"],
            plannerAuthProfiles: ["in-memory"],
            plannerEndpoints: [endpoint],
            footprintRoots: [root],
            changePrefixes: [],
            hostBackends: ["fixture"],
            hostModels: ["model"],
            hostAuthProfiles: ["in-memory"],
            permissionModes: ["default"],
            sandboxPolicies: ["workspace-write"],
            approvalPolicies: ["never"],
            executionEndpoints: [endpoint],
            toolRules: [],
            mcpServers: [],
            maximumStepCount: 3,
            maximumDependencyDepth: 2,
            maximumParallelSteps: 2,
            perStepTokenCeiling: 4_000,
            runTokenCeiling: 10_000,
            perStepBudgetMicrosUSD: 500_000,
            runBudgetMicrosUSD: 1_000_000,
            stepSoftDeadlineSeconds: 120,
            runSoftDeadlineSeconds: 600,
            dynamicInputLanes: [],
            networkBackendsPermitted: true,
            provenance: "consumer-fixture"
        )
    }

    private static func runtimeContext(
        _ qualified: QualifiedExecution
    ) throws -> AdmissionRuntimeContext {
        AdmissionRuntimeContext(
            runId: "consumer-run",
            logicalWorkspaceRoot: root,
            executionRoot: executionRoot,
            transferMode: "worktree",
            acquiredLockRoots: [executionRoot],
            baselineDigests: [
                executionRoot:
                    ExecutionGraphDigest.sha256("consumer-baseline"),
            ],
            finalGitHead: qualified.bundle.discovery.gitHead,
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
            effectiveBackend: qualified.effectivePolicy.fixedBackend,
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
                ExecutionGraphDigest.sha256("in-memory-adapter"),
            engineVersion: "consumer-fixture.v1",
            qualificationSourceStateDigest:
                qualified.qualification.qualificationStateDigest,
            runtimeStateDigest:
                qualified.qualification.qualificationStateDigest,
            admittedOuterCallEvidence: true,
            gateRecordOverrideUsed: false
        )
    }
}
