import Foundation

/// Wall-clock authority supplied by the host at a boundary.
///
/// Core algorithms never read process-global clock state directly. Production
/// hosts may use ``SystemExecutionGraphClock`` while tests and reproducibility
/// checks inject a fixed clock.
public protocol ExecutionGraphClock: Sendable {
    func now() -> Date
}

public struct SystemExecutionGraphClock: ExecutionGraphClock {
    public init() {}

    public func now() -> Date {
        Date()
    }
}

public struct FixedExecutionGraphClock: ExecutionGraphClock, Sendable {
    public let instant: Date

    public init(_ instant: Date) {
        self.instant = instant
    }

    public func now() -> Date {
        instant
    }
}

/// Monotonic time authority used only for elapsed lifecycle evidence.
public protocol ExecutionGraphMonotonicClock: Sendable {
    func nowNanoseconds() -> UInt64
}

public struct SystemExecutionGraphMonotonicClock: ExecutionGraphMonotonicClock {
    public init() {}

    public func nowNanoseconds() -> UInt64 {
        let nanoseconds = ProcessInfo.processInfo.systemUptime * 1_000_000_000
        guard nanoseconds.isFinite, nanoseconds > 0 else { return 0 }
        return UInt64(min(nanoseconds, Double(UInt64.max)))
    }
}

/// Host-owned repository discovery. Core consumes only the returned value.
public protocol ExecutionGraphDiscoveryProvider: Sendable {
    func discover(
        objective: String,
        permit: PlanningPermit
    ) async throws -> RepositoryDiscoverySnapshot
}

/// Append-only lifecycle projection owned by the host.
public protocol ExecutionGraphEventSink: Sendable {
    func record(_ event: ExecutionGraphLifecycleEvent) async
}

/// Durable activation/outcome projection owned by the host.
public protocol StepActivationSink: Sendable {
    func append(_ activation: StepActivationRecord) async throws
    func append(_ outcome: StepActivationOutcomeRecord) async throws
}

public struct NoopExecutionGraphEventSink: ExecutionGraphEventSink {
    public init() {}

    public func record(_ event: ExecutionGraphLifecycleEvent) async {}
}

public struct NoopStepActivationSink: StepActivationSink {
    public init() {}

    public func append(_ activation: StepActivationRecord) async throws {}
    public func append(_ outcome: StepActivationOutcomeRecord) async throws {}
}

/// Concurrency-safe in-memory lifecycle sink for embedders and tests.
public actor InMemoryExecutionGraphEventSink: ExecutionGraphEventSink {
    private var storage: [ExecutionGraphLifecycleEvent]

    public init(events: [ExecutionGraphLifecycleEvent] = []) {
        storage = events
    }

    public func record(_ event: ExecutionGraphLifecycleEvent) async {
        storage.append(event)
    }

    public func events() -> [ExecutionGraphLifecycleEvent] {
        storage
    }

    public func removeAll() {
        storage.removeAll(keepingCapacity: false)
    }
}

/// Concurrency-safe in-memory activation ledger for embedders and tests.
public actor InMemoryStepActivationSink: StepActivationSink {
    private var activationStorage: [StepActivationRecord]
    private var outcomeStorage: [StepActivationOutcomeRecord]

    public init(
        activations: [StepActivationRecord] = [],
        outcomes: [StepActivationOutcomeRecord] = []
    ) {
        activationStorage = activations
        outcomeStorage = outcomes
    }

    public func append(_ activation: StepActivationRecord) async throws {
        activationStorage.append(activation)
    }

    public func append(_ outcome: StepActivationOutcomeRecord) async throws {
        outcomeStorage.append(outcome)
    }

    public func activations() -> [StepActivationRecord] {
        activationStorage
    }

    public func outcomes() -> [StepActivationOutcomeRecord] {
        outcomeStorage
    }

    public func removeAll() {
        activationStorage.removeAll(keepingCapacity: false)
        outcomeStorage.removeAll(keepingCapacity: false)
    }
}
