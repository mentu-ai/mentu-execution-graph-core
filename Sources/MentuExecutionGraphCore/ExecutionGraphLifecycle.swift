import Foundation

public enum ExecutionGraphLifecyclePhase:
    String, Codable, Sendable, Equatable, Hashable, CaseIterable
{
    case loadPlan
    case authorize
    case discover
    case author
    case lower
    case qualify
    case reproduce
    case requalify
    case prepareExecution
    case admit
    case execute
    case evidence
}

public enum ExecutionGraphLifecycleState:
    String, Codable, Sendable, Equatable, Hashable
{
    case started
    case completed
    case failed
}

public struct ExecutionGraphLifecycleDetail:
    Codable, Sendable, Equatable, Hashable
{
    public var message: String?
    public var schema: String?
    public var hash: String?
    public var secondaryHash: String?
    public var profile: String?
    public var path: String?
    public var runId: String?
    public var selectedCount: Int?
    public var sentBytes: Int?
    public var omittedCount: Int?
    public var nodeCount: Int?
    public var dispatchCount: Int?
    public var inputTokens: Int?
    public var outputTokens: Int?
    public var promptCount: Int?
    public var contractCount: Int?
    public var passedCount: Int?
    public var totalCount: Int?
    public var okCount: Int?
    public var warnCount: Int?
    public var totalCost: Double?
    public var exact: Bool?
    public var success: Bool?

    public init(
        message: String? = nil,
        schema: String? = nil,
        hash: String? = nil,
        secondaryHash: String? = nil,
        profile: String? = nil,
        path: String? = nil,
        runId: String? = nil,
        selectedCount: Int? = nil,
        sentBytes: Int? = nil,
        omittedCount: Int? = nil,
        nodeCount: Int? = nil,
        dispatchCount: Int? = nil,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        promptCount: Int? = nil,
        contractCount: Int? = nil,
        passedCount: Int? = nil,
        totalCount: Int? = nil,
        okCount: Int? = nil,
        warnCount: Int? = nil,
        totalCost: Double? = nil,
        exact: Bool? = nil,
        success: Bool? = nil
    ) {
        self.message = message
        self.schema = schema
        self.hash = hash
        self.secondaryHash = secondaryHash
        self.profile = profile
        self.path = path
        self.runId = runId
        self.selectedCount = selectedCount
        self.sentBytes = sentBytes
        self.omittedCount = omittedCount
        self.nodeCount = nodeCount
        self.dispatchCount = dispatchCount
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.promptCount = promptCount
        self.contractCount = contractCount
        self.passedCount = passedCount
        self.totalCount = totalCount
        self.okCount = okCount
        self.warnCount = warnCount
        self.totalCost = totalCost
        self.exact = exact
        self.success = success
    }

    public static let empty = ExecutionGraphLifecycleDetail()
}

public struct ExecutionGraphLifecycleEvent:
    Codable, Sendable, Equatable, Hashable
{
    public static let currentSchema = "mentu.graph.lifecycle-event.v1"

    public let schema: String
    public let phase: ExecutionGraphLifecyclePhase
    public let state: ExecutionGraphLifecycleState
    public let elapsedMilliseconds: UInt64
    public let detail: ExecutionGraphLifecycleDetail
    public let reasonId: String?

    public init(
        phase: ExecutionGraphLifecyclePhase,
        state: ExecutionGraphLifecycleState,
        elapsedMilliseconds: UInt64,
        detail: ExecutionGraphLifecycleDetail = .empty,
        reasonId: String? = nil,
        schema: String = ExecutionGraphLifecycleEvent.currentSchema
    ) {
        self.schema = schema
        self.phase = phase
        self.state = state
        self.elapsedMilliseconds = elapsedMilliseconds
        self.detail = detail
        self.reasonId = reasonId
    }
}

public struct ExecutionGraphLifecycleSpan: Sendable, Equatable, Hashable {
    public let phase: ExecutionGraphLifecyclePhase
    public let startedAtNanoseconds: UInt64

    public init(
        phase: ExecutionGraphLifecyclePhase,
        startedAtNanoseconds: UInt64
    ) {
        self.phase = phase
        self.startedAtNanoseconds = startedAtNanoseconds
    }
}

/// Emits typed lifecycle events without deciding their persistence surface.
public struct ExecutionGraphLifecycleReporter: Sendable {
    private let sink: any ExecutionGraphEventSink
    private let clock: any ExecutionGraphMonotonicClock

    public init(
        sink: any ExecutionGraphEventSink,
        clock: any ExecutionGraphMonotonicClock
    ) {
        self.sink = sink
        self.clock = clock
    }

    public static let noop = ExecutionGraphLifecycleReporter(
        sink: NoopExecutionGraphEventSink(),
        clock: SystemExecutionGraphMonotonicClock()
    )

    @discardableResult
    public func start(
        _ phase: ExecutionGraphLifecyclePhase,
        detail: ExecutionGraphLifecycleDetail = .empty
    ) async -> ExecutionGraphLifecycleSpan {
        let now = clock.nowNanoseconds()
        await sink.record(
            ExecutionGraphLifecycleEvent(
                phase: phase,
                state: .started,
                elapsedMilliseconds: 0,
                detail: detail
            )
        )
        return ExecutionGraphLifecycleSpan(
            phase: phase,
            startedAtNanoseconds: now
        )
    }

    public func complete(
        _ span: ExecutionGraphLifecycleSpan,
        detail: ExecutionGraphLifecycleDetail = .empty
    ) async {
        await sink.record(
            ExecutionGraphLifecycleEvent(
                phase: span.phase,
                state: .completed,
                elapsedMilliseconds: elapsedMilliseconds(
                    since: span.startedAtNanoseconds
                ),
                detail: detail
            )
        )
    }

    public func fail(
        _ span: ExecutionGraphLifecycleSpan,
        violation: ExecutionGraphViolation,
        detail: ExecutionGraphLifecycleDetail = .empty
    ) async {
        await sink.record(
            ExecutionGraphLifecycleEvent(
                phase: span.phase,
                state: .failed,
                elapsedMilliseconds: elapsedMilliseconds(
                    since: span.startedAtNanoseconds
                ),
                detail: detail,
                reasonId: violation.id
            )
        )
    }

    private func elapsedMilliseconds(since start: UInt64) -> UInt64 {
        let end = clock.nowNanoseconds()
        guard end >= start else { return 0 }
        return (end - start) / 1_000_000
    }
}
