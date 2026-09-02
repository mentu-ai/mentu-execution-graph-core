import Foundation
import Testing
import MentuExecutionGraphCore

@Suite("Execution graph host protocols")
struct ProtocolTests {
    @Test("in-memory event sink is append-only and resettable")
    func eventSink() async {
        let sink = InMemoryExecutionGraphEventSink()
        let first = ExecutionGraphLifecycleEvent(
            phase: .lower,
            state: .started,
            elapsedMilliseconds: 0
        )
        let second = ExecutionGraphLifecycleEvent(
            phase: .lower,
            state: .completed,
            elapsedMilliseconds: 3
        )
        await sink.record(first)
        await sink.record(second)
        let events = await sink.events()
        #expect(events == [first, second])

        await sink.removeAll()
        let empty = await sink.events()
        #expect(empty.isEmpty)
    }

    @Test("in-memory activation sink retains typed records")
    func activationSink() async throws {
        let activation = try JSONDecoder().decode(
            StepActivationRecord.self,
            from: QualificationTestSupport.fixtureData("activation.json")
        )
        let outcome = try JSONDecoder().decode(
            StepActivationOutcomeRecord.self,
            from: QualificationTestSupport.fixtureData(
                "activation-outcome.json"
            )
        )
        let sink = InMemoryStepActivationSink()
        try await sink.append(activation)
        try await sink.append(outcome)

        let activations = await sink.activations()
        let outcomes = await sink.outcomes()
        #expect(activations == [activation])
        #expect(outcomes == [outcome])
    }

    @Test("no-op sinks accept evidence without side effects")
    func noOpSinks() async throws {
        let eventSink = NoopExecutionGraphEventSink()
        await eventSink.record(
            ExecutionGraphLifecycleEvent(
                phase: .evidence,
                state: .completed,
                elapsedMilliseconds: 0
            )
        )

        let activation = try JSONDecoder().decode(
            StepActivationRecord.self,
            from: QualificationTestSupport.fixtureData("activation.json")
        )
        let outcome = try JSONDecoder().decode(
            StepActivationOutcomeRecord.self,
            from: QualificationTestSupport.fixtureData(
                "activation-outcome.json"
            )
        )
        let activationSink = NoopStepActivationSink()
        try await activationSink.append(activation)
        try await activationSink.append(outcome)
    }

    @Test("fixed clock returns the injected instant")
    func fixedClock() {
        let instant = Date(timeIntervalSince1970: 42)
        let clock = FixedExecutionGraphClock(instant)
        #expect(clock.now() == instant)
    }
}
