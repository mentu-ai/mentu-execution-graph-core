import Foundation
import Testing
@testable import MentuExecutionGraphCore

@Suite("Canonical JSON and digest")
struct CanonicalJSONTests {
    @Test("Mentu v1 number and literal reference vector is byte exact")
    func referenceVector() throws {
        let input = Data(
            #"{"numbers":[333333333.33333329,1E30,4.50,2e-3,0.000000000000000000000000001],"literals":[null,true,false]}"#
                .utf8
        )
        let expected =
            #"{"literals":[null,true,false],"numbers":[333333333.3333333,1e+30,4.5,0.002,1e-27]}"#
        #expect(
            String(
                data: try ExecutionGraphCanonicalizer.canonicalize(input),
                encoding: .utf8
            ) == expected
        )
        #expect(
            ExecutionGraphCanonicalizer.schemeIdentifier
                == "mentu.canonical-json.v1"
        )
    }

    @Test("Mentu v1 thresholds, escaping, ordering, and NFC are stable")
    func edgeFormatting() throws {
        let input = Data(
            #"{"z":-0.0,"small":1e-7,"decimal":1e-6,"largeDecimal":1e20,"escape":"\b\t\n\f\r\u000f\/\\\"","😀":1,"€":2,"nfc":"e\u0301"}"#
                .utf8
        )
        let text = try #require(
            String(
                data: ExecutionGraphCanonicalizer.canonicalize(input),
                encoding: .utf8
            )
        )
        #expect(text.contains(#""z":0"#))
        #expect(text.contains(#""small":1e-7"#))
        #expect(text.contains(#""decimal":0.000001"#))
        #expect(text.contains(#""largeDecimal":100000000000000000000"#))
        #expect(text.contains(#""escape":"\b\t\n\f\r\u000f/\\\"""#))
        #expect(text.contains(#""nfc":"é""#))
        #expect(try ExecutionGraphCanonicalizer.canonicalize(Data(text.utf8))
            == Data(text.utf8))
    }

    @Test("duplicate keys and malformed input are refused")
    func invalidInput() {
        for input in [
            #"{"a":1,"a":2}"#,
            #"{"e\u0301":1,"é":2}"#,
            #"{"a":01}"#,
            #"{"a":1e400}"#,
        ] {
            #expect(throws: Error.self) {
                try ExecutionGraphCanonicalizer.canonicalize(
                    Data(input.utf8)
                )
            }
        }
        #expect(throws: Error.self) {
            try ExecutionGraphCanonicalizer.canonicalize(Data([0xff, 0xfe]))
        }
    }

    @Test("CanonicalJSONNumber accepts only finite JSON number lexemes")
    func numberLexemes() throws {
        #expect(try CanonicalJSONNumber(jsonLexeme: "-0").jsonLexeme == "0")
        #expect(
            try CanonicalJSONNumber(jsonLexeme: "1E30").jsonLexeme == "1e+30"
        )
        #expect(
            try CanonicalJSONNumber(jsonLexeme: "1e-6").jsonLexeme
                == "0.000001"
        )
        for invalid in [
            "", " 1", "1 ", "+1", "01", "1.", ".1", "NaN", "Infinity",
            "--1",
        ] {
            #expect(throws: Error.self) {
                try CanonicalJSONNumber(jsonLexeme: invalid)
            }
        }
    }

    @Test("CanonicalJSONValue encodes without case wrappers")
    func valueEncoding() throws {
        let value = CanonicalJSONValue.object([
            "z": .null,
            "a": .array([
                .bool(true),
                .number(try .init(jsonLexeme: "4.50")),
                .string("value"),
            ]),
        ])
        #expect(
            try ExecutionGraphCanonicalizer.string(value)
                == #"{"a":[true,4.5,"value"],"z":null}"#
        )
        let decoded = try JSONDecoder().decode(
            CanonicalJSONValue.self,
            from: ExecutionGraphCanonicalizer.data(value)
        )
        #expect(decoded == value)
    }

    @Test("path normalization is lexical, stable, and collision aware")
    func pathNormalization() throws {
        #expect(
            try ExecutionGraphCanonicalizer.normalizePath("Sources/A.swift")
                == "Sources/A.swift"
        )
        for path in ["", "../escape", "/absolute", "a//b", "a/./b", #"a\b"#] {
            #expect(throws: Error.self) {
                try ExecutionGraphCanonicalizer.normalizePath(path)
            }
        }
        #expect(throws: Error.self) {
            try ExecutionGraphCanonicalizer.normalizeSetPaths([
                "caf\u{65}\u{301}/x",
                "café/x",
            ])
        }
    }

    @Test("SHA-256 helpers have stable lowercase output")
    func digest() {
        let expected =
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        #expect(ExecutionGraphDigest.sha256("abc") == expected)
        #expect(ExecutionGraphDigest.sha256(Data("abc".utf8)) == expected)
    }
}
