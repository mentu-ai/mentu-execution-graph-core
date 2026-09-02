import Foundation
import Testing
import MentuExecutionGraphCore

@Suite("Execution graph lifecycle")
struct LifecycleTests {
    @Test("reporter emits deterministic elapsed evidence")
    func lifecycleReporter() async throws {
        let sink = InMemoryExecutionGraphEventSink()
        let reporter = ExecutionGraphLifecycleReporter(
            sink: sink,
            clock: SequenceMonotonicClock([
                1_000_000,
                8_000_000,
            ])
        )

        let span = await reporter.start(
            .qualify,
            detail: ExecutionGraphLifecycleDetail(nodeCount: 3)
        )
        await reporter.complete(
            span,
            detail: ExecutionGraphLifecycleDetail(
                passedCount: 4,
                totalCount: 4,
                success: true
            )
        )

        let events = await sink.events()
        #expect(events.count == 2)
        #expect(events[0].phase == .qualify)
        #expect(events[0].state == .started)
        #expect(events[0].elapsedMilliseconds == 0)
        #expect(events[1].state == .completed)
        #expect(events[1].elapsedMilliseconds == 7)
        #expect(events[1].detail.success == true)
    }

    @Test("failure evidence carries only the stable violation ID")
    func lifecycleFailure() async {
        let sink = InMemoryExecutionGraphEventSink()
        let reporter = ExecutionGraphLifecycleReporter(
            sink: sink,
            clock: SequenceMonotonicClock([20_000_000, 19_000_000])
        )
        let span = await reporter.start(.admit)
        await reporter.fail(
            span,
            violation: ExecutionGraphViolation(
                id: "admission.state-drift",
                detail: "mutable state changed"
            )
        )

        let events = await sink.events()
        #expect(events.count == 2)
        #expect(events[1].state == .failed)
        #expect(events[1].reasonId == "admission.state-drift")
        #expect(events[1].elapsedMilliseconds == 0)
    }

    @Test("frozen lifecycle event remains byte-identical")
    func frozenLifecycleCompatibility() throws {
        let bytes = try QualificationTestSupport.fixtureData(
            "lifecycle-event.json"
        )
        let event = try JSONDecoder().decode(
            ExecutionGraphLifecycleEvent.self,
            from: bytes
        )
        #expect(
            try ExecutionGraphCanonicalizer.data(event) == bytes
        )
        #expect(event.phase == .admit)
        #expect(event.state == .completed)
        #expect(event.reasonId == nil)
    }
}

private final class SequenceMonotonicClock:
    ExecutionGraphMonotonicClock, @unchecked Sendable
{
    private let lock = NSLock()
    private var values: [UInt64]

    init(_ values: [UInt64]) {
        self.values = values
    }

    func nowNanoseconds() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        guard !values.isEmpty else { return 0 }
        return values.removeFirst()
    }
}
