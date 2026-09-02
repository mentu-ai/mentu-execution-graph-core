import Testing
import MentuExecutionGraphCore

@Suite("MentuExecutionGraphCore module isolation")
struct MentuExecutionGraphCoreTests {
    @Test("module is independently importable")
    func moduleIdentity() {
        #expect(MentuExecutionGraphCoreModule.version == "1.0.0")
    }
}
