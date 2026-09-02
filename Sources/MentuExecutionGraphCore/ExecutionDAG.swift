import Foundation

/// Stable reason identifiers emitted by DAG validation and scheduler invariants.
public enum GraphSchedulerReasonID: Sendable {
    public static let duplicateNode = "graph.dag.duplicate-node"
    public static let invalidNodeID = "graph.dag.invalid-node-id"
    public static let unknownDependency = "graph.dag.unknown-dependency"
    public static let selfDependency = "graph.dag.self-dependency"
    public static let cycle = "graph.dag.cycle"

    public static let invalidParallelism = "graph.scheduler.invalid-parallelism"
    public static let resumeUnknownNode = "graph.scheduler.resume-unknown-node"
    public static let resumeInconsistent = "graph.scheduler.resume-inconsistent"
    public static let outcomeNodeMismatch = "graph.scheduler.outcome-node-mismatch"
    public static let outcomeNonterminal = "graph.scheduler.outcome-nonterminal"

    public static let dependencyFailed = "graph.scheduler.dependency-failed"
    public static let circuitOpen = "graph.scheduler.circuit-open"
    public static let boundaryStop = "graph.scheduler.boundary-stop"
}

/// A value-only directed acyclic execution graph.
///
/// Dispatch mode is deliberately a single enum rather than independent
/// `exclusive` and `concurrencySafe` flags. Contradictory policy is therefore
/// unrepresentable after the host has constructed a node.
public struct ExecutionDAG: Codable, Sendable, Equatable {
    public struct Node: Codable, Sendable, Equatable, Hashable {
        public enum DispatchMode: String, Codable, Sendable {
            case parallelSafe
            case exclusive
        }

        public let id: String
        public let dependencies: [String]
        public let dispatchMode: DispatchMode

        public init(
            id: String,
            dependencies: [String] = [],
            dispatchMode: DispatchMode = .parallelSafe
        ) {
            self.id = id
            self.dependencies = dependencies
            self.dispatchMode = dispatchMode
        }
    }

    public let nodes: [Node]

    public init(nodes: [Node]) {
        self.nodes = nodes
    }

    /// Validates the graph and returns its stable, one-based scheduler frontiers.
    ///
    /// This is the sole topological planner used by the core scheduler and host
    /// adapters. Nodes within every frontier are sorted by their stable node ID.
    public func validatedFrontiers() throws -> [[Node]] {
        let duplicateIDs = Dictionary(grouping: nodes, by: \.id)
            .filter { $0.value.count > 1 }
            .map(\.key)
            .sorted()
        if let duplicateID = duplicateIDs.first {
            throw ExecutionGraphViolation(
                id: GraphSchedulerReasonID.duplicateNode,
                detail: "duplicate node ID '\(duplicateID)'"
            )
        }

        let sortedNodes = nodes.sorted { $0.id < $1.id }
        for node in sortedNodes where !Self.isSafeNodeID(node.id) {
            throw ExecutionGraphViolation(
                id: GraphSchedulerReasonID.invalidNodeID,
                detail: "node ID '\(node.id)' is empty or unsafe"
            )
        }

        let nodeIDs = Set(sortedNodes.map(\.id))
        for node in sortedNodes {
            let dependencies = Array(Set(node.dependencies)).sorted()
            if dependencies.contains(node.id) {
                throw ExecutionGraphViolation(
                    id: GraphSchedulerReasonID.selfDependency,
                    detail: "node '\(node.id)' depends on itself"
                )
            }
            if let unknown = dependencies.first(where: { !nodeIDs.contains($0) }) {
                throw ExecutionGraphViolation(
                    id: GraphSchedulerReasonID.unknownDependency,
                    detail: "node '\(node.id)' depends on unknown node '\(unknown)'"
                )
            }
        }

        var inDegree = Dictionary(
            uniqueKeysWithValues: sortedNodes.map {
                ($0.id, Set($0.dependencies).count)
            }
        )
        var dependents: [String: Set<String>] = [:]
        for node in sortedNodes {
            for dependency in Set(node.dependencies) {
                dependents[dependency, default: []].insert(node.id)
            }
        }

        let nodesByID = Dictionary(uniqueKeysWithValues: sortedNodes.map { ($0.id, $0) })
        var processed = Set<String>()
        var frontiers: [[Node]] = []

        while processed.count < sortedNodes.count {
            let readyIDs = inDegree
                .filter { !processed.contains($0.key) && $0.value == 0 }
                .map(\.key)
                .sorted()
            guard !readyIDs.isEmpty else {
                let cycleNodes = nodeIDs.subtracting(processed).sorted()
                throw ExecutionGraphViolation(
                    id: GraphSchedulerReasonID.cycle,
                    detail: "cycle contains: \(cycleNodes.joined(separator: ", "))"
                )
            }

            frontiers.append(readyIDs.compactMap { nodesByID[$0] })
            for nodeID in readyIDs {
                processed.insert(nodeID)
                for dependent in (dependents[nodeID] ?? []).sorted() {
                    inDegree[dependent, default: 0] -= 1
                }
            }
        }

        return frontiers
    }

    private static func isSafeNodeID(_ id: String) -> Bool {
        let normalized = id.precomposedStringWithCanonicalMapping
        guard !id.isEmpty,
              id != ".",
              id != "..",
              id.utf8.elementsEqual(normalized.utf8)
        else {
            return false
        }

        let punctuation = CharacterSet(charactersIn: "._-")
        return id.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0) || punctuation.contains($0)
        }
    }
}

public enum GraphNodeState: Sendable, Equatable {
    case pending
    case running
    case succeeded
    case failed(reasonId: String)
    case skipped(reasonId: String, blockedBy: String?)

    public var isTerminal: Bool {
        switch self {
        case .succeeded, .failed, .skipped:
            return true
        case .pending, .running:
            return false
        }
    }

    public var isTerminalSuccessful: Bool {
        self == .succeeded
    }

    public var reasonId: String? {
        switch self {
        case .failed(let reasonId), .skipped(let reasonId, _):
            return reasonId
        case .pending, .running, .succeeded:
            return nil
        }
    }
}

extension GraphNodeState: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case reasonId
        case blockedBy
    }

    private enum Kind: String, Codable {
        case pending
        case running
        case succeeded
        case failed
        case skipped
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .pending:
            self = .pending
        case .running:
            self = .running
        case .succeeded:
            self = .succeeded
        case .failed:
            self = .failed(
                reasonId: try container.decode(String.self, forKey: .reasonId)
            )
        case .skipped:
            self = .skipped(
                reasonId: try container.decode(String.self, forKey: .reasonId),
                blockedBy: try container.decodeIfPresent(String.self, forKey: .blockedBy)
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .pending:
            try container.encode(Kind.pending, forKey: .kind)
        case .running:
            try container.encode(Kind.running, forKey: .kind)
        case .succeeded:
            try container.encode(Kind.succeeded, forKey: .kind)
        case .failed(let reasonId):
            try container.encode(Kind.failed, forKey: .kind)
            try container.encode(reasonId, forKey: .reasonId)
        case .skipped(let reasonId, let blockedBy):
            try container.encode(Kind.skipped, forKey: .kind)
            try container.encode(reasonId, forKey: .reasonId)
            try container.encodeIfPresent(blockedBy, forKey: .blockedBy)
        }
    }
}

public enum GraphFailurePolicy: Sendable, Equatable {
    case continueIndependentBranches
    case stopFutureFrontiers(maximumExecutedFailures: Int)
}

extension GraphFailurePolicy: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case maximumExecutedFailures
    }

    private enum Kind: String, Codable {
        case continueIndependentBranches
        case stopFutureFrontiers
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .continueIndependentBranches:
            self = .continueIndependentBranches
        case .stopFutureFrontiers:
            self = .stopFutureFrontiers(
                maximumExecutedFailures: try container.decode(
                    Int.self,
                    forKey: .maximumExecutedFailures
                )
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .continueIndependentBranches:
            try container.encode(Kind.continueIndependentBranches, forKey: .kind)
        case .stopFutureFrontiers(let maximumExecutedFailures):
            try container.encode(Kind.stopFutureFrontiers, forKey: .kind)
            try container.encode(
                maximumExecutedFailures,
                forKey: .maximumExecutedFailures
            )
        }
    }
}

public struct GraphStepActivation: Codable, Sendable, Equatable {
    public let nodeId: String
    public let ordinal: Int
    public let frontier: Int

    public init(nodeId: String, ordinal: Int, frontier: Int) {
        self.nodeId = nodeId
        self.ordinal = ordinal
        self.frontier = frontier
    }
}

public struct GraphStepOutcome: Codable, Sendable, Equatable {
    public let nodeId: String
    public let state: GraphNodeState

    public init(nodeId: String, state: GraphNodeState) {
        self.nodeId = nodeId
        self.state = state
    }
}

public struct GraphScheduleResult: Codable, Sendable, Equatable {
    public let states: [String: GraphNodeState]
    public let dispatchOrder: [String]
    public let outcomes: [GraphStepOutcome]

    public init(
        states: [String: GraphNodeState],
        dispatchOrder: [String],
        outcomes: [GraphStepOutcome]
    ) {
        self.states = states
        self.dispatchOrder = dispatchOrder
        self.outcomes = outcomes
    }
}

public struct GraphSchedulerEvent: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable {
        case scheduleStarted
        case frontierStarted
        case nodeDispatched
        case nodeCompleted
        case nodeSkipped
        case frontierCompleted
        case circuitOpened
        case scheduleCompleted
    }

    public let sequence: Int
    public let kind: Kind
    public let frontier: Int?
    public let nodeId: String?
    public let state: GraphNodeState?
    public let reasonId: String?

    public init(
        sequence: Int,
        kind: Kind,
        frontier: Int? = nil,
        nodeId: String? = nil,
        state: GraphNodeState? = nil,
        reasonId: String? = nil
    ) {
        self.sequence = sequence
        self.kind = kind
        self.frontier = frontier
        self.nodeId = nodeId
        self.state = state
        self.reasonId = reasonId
    }
}

public protocol GraphSchedulerEventSink: Sendable {
    func record(_ event: GraphSchedulerEvent) async
}

public struct NoOpGraphSchedulerEventSink: GraphSchedulerEventSink {
    public init() {}

    public func record(_ event: GraphSchedulerEvent) async {}
}
