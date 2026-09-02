import Foundation

/// Mentu Canonical JSON v1 encoder used by graph identities.
///
/// Unlike `JSONEncoder.sortedKeys`, this parser rejects duplicate keys before
/// typed decoding, sorts object names by UTF-16 code units, normalizes strings
/// to NFC, and emits the current Mentu ECMAScript-compatible number form. NFC
/// normalization is an intentional persisted compatibility rule, so this
/// scheme is not RFC 8785/JCS. Any strict JCS implementation must use a new,
/// explicitly versioned scheme rather than changing these identity bytes.
public enum ExecutionGraphCanonicalizer: Sendable {
    public static let schemeIdentifier = "mentu.canonical-json.v1"

    public enum CanonicalizationError: Error, LocalizedError, Sendable, Equatable {
        case invalidUTF8
        case invalidJSON(String)
        case duplicateKey(String)
        case nonFiniteNumber
        case invalidPath(String)
        case pathCollision(String)

        public var errorDescription: String? {
            switch self {
            case .invalidUTF8:
                "canonical JSON is not valid UTF-8"
            case .invalidJSON(let detail):
                "invalid canonical JSON: \(detail)"
            case .duplicateKey(let key):
                "duplicate JSON object key after NFC normalization: \(key)"
            case .nonFiniteNumber:
                "non-finite JSON number"
            case .invalidPath(let path):
                "invalid canonical path: \(path)"
            case .pathCollision(let path):
                "path normalization collision: \(path)"
            }
        }
    }

    public static func canonicalize(
        _ data: Data,
        normalizeStrings: Bool = true
    ) throws -> Data {
        guard let text = String(data: data, encoding: .utf8) else {
            throw CanonicalizationError.invalidUTF8
        }
        var parser = Parser(text: text, normalizeStrings: normalizeStrings)
        return Data(render(try parser.parse()).utf8)
    }

    public static func data<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return try canonicalize(encoder.encode(value))
    }

    /// Compatibility spelling retained for Mentu's pre-extraction call sites.
    public static func canonicalData<T: Encodable>(
        _ value: T,
        normalizeStrings: Bool = true
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return try canonicalize(
            encoder.encode(value),
            normalizeStrings: normalizeStrings
        )
    }

    public static func string<T: Encodable>(_ value: T) throws -> String {
        guard let result = String(data: try data(value), encoding: .utf8) else {
            throw CanonicalizationError.invalidUTF8
        }
        return result
    }

    public static func hash<T: Encodable>(_ value: T) throws -> String {
        ExecutionGraphDigest.sha256(try data(value))
    }

    /// Normalizes a workspace-relative artifact path without consulting the
    /// filesystem. Symlink resolution remains a host-adapter responsibility.
    public static func normalizePath(_ input: String) throws -> String {
        let nfc = input.precomposedStringWithCanonicalMapping
        guard !nfc.isEmpty,
              !nfc.hasPrefix("/"),
              !nfc.contains("\\"),
              !nfc.unicodeScalars.contains(where: {
                  CharacterSet.controlCharacters.contains($0)
              })
        else {
            throw CanonicalizationError.invalidPath(input)
        }
        let components = nfc.split(
            separator: "/",
            omittingEmptySubsequences: false
        ).map(String.init)
        guard components.allSatisfy({
            !$0.isEmpty && $0 != "." && $0 != ".."
        }) else {
            throw CanonicalizationError.invalidPath(input)
        }
        return components.joined(separator: "/")
    }

    public static func normalizeSetPaths(_ values: [String]) throws -> [String] {
        var seen: [String: String] = [:]
        for raw in values {
            let normalized = try normalizePath(raw)
            if let previous = seen[normalized],
               Array(previous.unicodeScalars) != Array(raw.unicodeScalars) {
                throw CanonicalizationError.pathCollision(normalized)
            }
            seen[normalized] = raw
        }
        return seen.keys.sorted(by: utf16Less)
    }

    static func canonicalNumberLexeme(_ raw: String) throws -> String {
        guard raw == raw.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else {
            throw CanonicalizationError.invalidJSON(
                "number lexeme contains surrounding whitespace"
            )
        }
        var parser = Parser(text: raw, normalizeStrings: false)
        let parsed = try parser.parse()
        guard case .number(let number) = parsed else {
            throw CanonicalizationError.invalidJSON("expected a JSON number")
        }
        return number.jsonLexeme
    }

    static func utf16Less(_ lhs: String, _ rhs: String) -> Bool {
        Array(lhs.utf16).lexicographicallyPrecedes(Array(rhs.utf16))
    }

    private static func render(_ value: CanonicalJSONValue) -> String {
        switch value {
        case .object(let object):
            "{" + object.keys.sorted(by: utf16Less).map {
                escape($0) + ":" + render(object[$0]!)
            }.joined(separator: ",") + "}"
        case .array(let array):
            "[" + array.map(render).joined(separator: ",") + "]"
        case .string(let string):
            escape(string)
        case .number(let number):
            number.jsonLexeme
        case .bool(let value):
            value ? "true" : "false"
        case .null:
            "null"
        }
    }

    private static func escape(_ value: String) -> String {
        var output = "\""
        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 0x08: output += "\\b"
            case 0x09: output += "\\t"
            case 0x0a: output += "\\n"
            case 0x0c: output += "\\f"
            case 0x0d: output += "\\r"
            case 0x22: output += "\\\""
            case 0x5c: output += "\\\\"
            case 0x00...0x1f:
                output += String(format: "\\u%04x", scalar.value)
            default:
                output.unicodeScalars.append(scalar)
            }
        }
        return output + "\""
    }

    private static func renderNumber(_ value: Double) -> String {
        guard value.isFinite else { return "null" }
        if value == 0 { return "0" }

        let magnitude = abs(value)
        var shortest = String(value).lowercased()
        if shortest.hasSuffix(".0") {
            shortest.removeLast(2)
        }

        if magnitude >= 1e-6 && magnitude < 1e21 {
            return shortest.contains("e") ? expandScientific(shortest) : shortest
        }
        if !shortest.contains("e") {
            shortest = scientificFromDecimal(shortest)
        }
        return normalizeExponent(shortest)
    }

    private static func expandScientific(_ value: String) -> String {
        let parts = value.split(separator: "e", omittingEmptySubsequences: false)
        guard parts.count == 2, let exponent = Int(parts[1]) else { return value }
        let negative = parts[0].hasPrefix("-")
        let mantissa = negative ? String(parts[0].dropFirst()) : String(parts[0])
        let digits = mantissa.replacingOccurrences(of: ".", with: "")
        let point = mantissa.firstIndex(of: ".").map {
            mantissa.distance(from: mantissa.startIndex, to: $0)
        } ?? mantissa.count
        let decimalIndex = point + exponent
        let body: String
        if decimalIndex <= 0 {
            body = "0." + String(repeating: "0", count: -decimalIndex) + digits
        } else if decimalIndex >= digits.count {
            body = digits + String(
                repeating: "0",
                count: decimalIndex - digits.count
            )
        } else {
            let split = digits.index(
                digits.startIndex,
                offsetBy: decimalIndex
            )
            body = String(digits[..<split]) + "." + String(digits[split...])
        }
        return (negative ? "-" : "") + body
    }

    private static func scientificFromDecimal(_ value: String) -> String {
        let negative = value.hasPrefix("-")
        let raw = negative ? String(value.dropFirst()) : value
        let pieces = raw.split(separator: ".", omittingEmptySubsequences: false)
        let integer = String(pieces[0])
        let fraction = pieces.count == 2 ? String(pieces[1]) : ""
        let digits = integer + fraction
        let firstNonZero = digits.firstIndex(where: { $0 != "0" })
            ?? digits.startIndex
        let offset = digits.distance(
            from: digits.startIndex,
            to: firstNonZero
        )
        let exponent = integer == "0"
            ? -(offset - integer.count + 1)
            : integer.count - offset - 1
        let significant = String(digits[firstNonZero...])
        let mantissa = significant.count > 1
            ? String(significant.prefix(1)) + "." + String(significant.dropFirst())
            : significant
        return (negative ? "-" : "") + mantissa + "e"
            + (exponent >= 0 ? "+" : "") + String(exponent)
    }

    private static func normalizeExponent(_ value: String) -> String {
        let parts = value.split(separator: "e", omittingEmptySubsequences: false)
        guard parts.count == 2, let exponent = Int(parts[1]) else { return value }
        return String(parts[0]) + "e"
            + (exponent >= 0 ? "+" : "") + String(exponent)
    }

    private struct Parser {
        let scalars: [UnicodeScalar]
        let normalizeStrings: Bool
        var index = 0

        init(text: String, normalizeStrings: Bool) {
            scalars = Array(text.unicodeScalars)
            self.normalizeStrings = normalizeStrings
        }

        mutating func parse() throws -> CanonicalJSONValue {
            skipWhitespace()
            let value = try parseValue()
            skipWhitespace()
            guard index == scalars.count else {
                throw CanonicalizationError.invalidJSON("trailing content")
            }
            return value
        }

        mutating func parseValue() throws -> CanonicalJSONValue {
            guard let current = peek else {
                throw CanonicalizationError.invalidJSON("unexpected end of input")
            }
            switch current {
            case "{": return try parseObject()
            case "[": return try parseArray()
            case "\"": return .string(try parseString())
            case "t": try consume("true"); return .bool(true)
            case "f": try consume("false"); return .bool(false)
            case "n": try consume("null"); return .null
            default:
                guard current == "-" || isASCIIDigit(current) else {
                    throw CanonicalizationError.invalidJSON(
                        "unexpected token \(current)"
                    )
                }
                return try parseNumber()
            }
        }

        mutating func parseObject() throws -> CanonicalJSONValue {
            try expect("{")
            skipWhitespace()
            var object: [String: CanonicalJSONValue] = [:]
            if take("}") { return .object(object) }
            while true {
                guard peek == "\"" else {
                    throw CanonicalizationError.invalidJSON(
                        "object key must be a string"
                    )
                }
                let key = try parseString()
                guard object[key] == nil else {
                    throw CanonicalizationError.duplicateKey(key)
                }
                skipWhitespace()
                try expect(":")
                skipWhitespace()
                object[key] = try parseValue()
                skipWhitespace()
                if take("}") { break }
                try expect(",")
                skipWhitespace()
            }
            return .object(object)
        }

        mutating func parseArray() throws -> CanonicalJSONValue {
            try expect("[")
            skipWhitespace()
            var array: [CanonicalJSONValue] = []
            if take("]") { return .array(array) }
            while true {
                array.append(try parseValue())
                skipWhitespace()
                if take("]") { break }
                try expect(",")
                skipWhitespace()
            }
            return .array(array)
        }

        mutating func parseString() throws -> String {
            try expect("\"")
            var output = String.UnicodeScalarView()
            while let scalar = peek {
                index += 1
                if scalar == "\"" {
                    let string = String(output)
                    return normalizeStrings
                        ? string.precomposedStringWithCanonicalMapping
                        : string
                }
                if scalar == "\\" {
                    guard let escaped = peek else {
                        throw CanonicalizationError.invalidJSON(
                            "unterminated escape"
                        )
                    }
                    index += 1
                    switch escaped {
                    case "\"", "\\", "/": output.append(escaped)
                    case "b": output.append("\u{08}")
                    case "f": output.append("\u{0c}")
                    case "n": output.append("\n")
                    case "r": output.append("\r")
                    case "t": output.append("\t")
                    case "u":
                        let first = try parseHexQuad()
                        if (0xd800...0xdbff).contains(first) {
                            try expect("\\")
                            try expect("u")
                            let second = try parseHexQuad()
                            guard (0xdc00...0xdfff).contains(second) else {
                                throw CanonicalizationError.invalidJSON(
                                    "invalid surrogate pair"
                                )
                            }
                            let combined = 0x10000
                                + ((first - 0xd800) << 10)
                                + (second - 0xdc00)
                            guard let decoded = UnicodeScalar(combined) else {
                                throw CanonicalizationError.invalidJSON(
                                    "invalid Unicode scalar"
                                )
                            }
                            output.append(decoded)
                        } else if (0xdc00...0xdfff).contains(first) {
                            throw CanonicalizationError.invalidJSON(
                                "unpaired low surrogate"
                            )
                        } else if let decoded = UnicodeScalar(first) {
                            output.append(decoded)
                        }
                    default:
                        throw CanonicalizationError.invalidJSON("invalid escape")
                    }
                } else {
                    guard scalar.value >= 0x20 else {
                        throw CanonicalizationError.invalidJSON(
                            "unescaped control character"
                        )
                    }
                    output.append(scalar)
                }
            }
            throw CanonicalizationError.invalidJSON("unterminated string")
        }

        mutating func parseHexQuad() throws -> UInt32 {
            var value: UInt32 = 0
            for _ in 0..<4 {
                guard let scalar = peek else {
                    throw CanonicalizationError.invalidJSON(
                        "short Unicode escape"
                    )
                }
                index += 1
                let digit: UInt32
                switch scalar.value {
                case 48...57: digit = scalar.value - 48
                case 65...70: digit = scalar.value - 55
                case 97...102: digit = scalar.value - 87
                default:
                    throw CanonicalizationError.invalidJSON(
                        "invalid Unicode escape"
                    )
                }
                value = value * 16 + digit
            }
            return value
        }

        mutating func parseNumber() throws -> CanonicalJSONValue {
            let start = index
            _ = take("-")
            guard let first = peek else {
                throw CanonicalizationError.invalidJSON("incomplete number")
            }
            if first == "0" {
                index += 1
                if let next = peek, isASCIIDigit(next) {
                    throw CanonicalizationError.invalidJSON("leading zero")
                }
            } else {
                guard first.value >= 49, first.value <= 57 else {
                    throw CanonicalizationError.invalidJSON("invalid number")
                }
                while let scalar = peek, isASCIIDigit(scalar) { index += 1 }
            }
            var fractional = false
            if take(".") {
                fractional = true
                guard let scalar = peek, isASCIIDigit(scalar) else {
                    throw CanonicalizationError.invalidJSON("empty fraction")
                }
                while let scalar = peek, isASCIIDigit(scalar) { index += 1 }
            }
            var exponent = false
            if take("e") || take("E") {
                exponent = true
                _ = take("+") || take("-")
                guard let scalar = peek, isASCIIDigit(scalar) else {
                    throw CanonicalizationError.invalidJSON("empty exponent")
                }
                while let scalar = peek, isASCIIDigit(scalar) { index += 1 }
            }
            let raw = String(
                String.UnicodeScalarView(scalars[start..<index])
            )
            let canonical: String
            if !fractional, !exponent, let integer = Int64(raw) {
                canonical = String(integer)
            } else {
                guard let number = Double(raw), number.isFinite else {
                    throw CanonicalizationError.nonFiniteNumber
                }
                canonical = ExecutionGraphCanonicalizer.renderNumber(number)
            }
            return .number(CanonicalJSONNumber(canonicalLexeme: canonical))
        }

        var peek: UnicodeScalar? {
            index < scalars.count ? scalars[index] : nil
        }

        func isASCIIDigit(_ scalar: UnicodeScalar) -> Bool {
            scalar.value >= 48 && scalar.value <= 57
        }

        mutating func skipWhitespace() {
            while let scalar = peek,
                  scalar == " " || scalar == "\n"
                    || scalar == "\r" || scalar == "\t" {
                index += 1
            }
        }

        mutating func expect(_ scalar: UnicodeScalar) throws {
            guard take(scalar) else {
                throw CanonicalizationError.invalidJSON("expected \(scalar)")
            }
        }

        mutating func take(_ scalar: UnicodeScalar) -> Bool {
            guard peek == scalar else { return false }
            index += 1
            return true
        }

        mutating func consume(_ token: String) throws {
            for scalar in token.unicodeScalars {
                try expect(scalar)
            }
        }
    }
}
