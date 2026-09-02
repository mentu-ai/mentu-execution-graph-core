import Foundation

/// A JSON value whose numeric members retain their Mentu Canonical JSON v1
/// representation.
///
/// The enum encodes as the represented JSON value itself; it does not introduce
/// a case discriminator or wrapper object.
public enum CanonicalJSONValue: Codable, Sendable, Equatable, Hashable {
    case null
    case bool(Bool)
    case number(CanonicalJSONNumber)
    case string(String)
    case array([CanonicalJSONValue])
    case object([String: CanonicalJSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .number(try CanonicalJSONNumber(jsonLexeme: String(value)))
        } else if let value = try? container.decode(UInt64.self) {
            self = .number(try CanonicalJSONNumber(jsonLexeme: String(value)))
        } else if let value = try? container.decode(Double.self) {
            guard value.isFinite else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "canonical JSON numbers must be finite"
                )
            }
            self = .number(try CanonicalJSONNumber(jsonLexeme: String(value)))
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([CanonicalJSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: CanonicalJSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "unsupported JSON value"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .number(let value):
            try value.encode(to: encoder)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .null:
            hasher.combine(0)
        case .bool(let value):
            hasher.combine(1)
            hasher.combine(value)
        case .number(let value):
            hasher.combine(2)
            hasher.combine(value)
        case .string(let value):
            hasher.combine(3)
            hasher.combine(value)
        case .array(let value):
            hasher.combine(4)
            hasher.combine(value)
        case .object(let value):
            hasher.combine(5)
            for key in value.keys.sorted(by: ExecutionGraphCanonicalizer.utf16Less) {
                hasher.combine(key)
                hasher.combine(value[key])
            }
        }
    }
}

/// A finite JSON number normalized using Mentu Canonical JSON v1.
public struct CanonicalJSONNumber: Codable, Sendable, Equatable, Hashable {
    /// The canonical JSON number lexeme.
    public let jsonLexeme: String

    public init(jsonLexeme: String) throws {
        self.jsonLexeme = try ExecutionGraphCanonicalizer.canonicalNumberLexeme(jsonLexeme)
    }

    init(canonicalLexeme: String) {
        jsonLexeme = canonicalLexeme
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int64.self) {
            try self.init(jsonLexeme: String(value))
        } else if let value = try? container.decode(UInt64.self) {
            try self.init(jsonLexeme: String(value))
        } else {
            let value = try container.decode(Double.self)
            guard value.isFinite else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "canonical JSON numbers must be finite"
                )
            }
            try self.init(jsonLexeme: String(value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if !jsonLexeme.contains("."), !jsonLexeme.contains("e"),
           let integer = Int64(jsonLexeme) {
            try container.encode(integer)
            return
        }
        guard let value = Double(jsonLexeme), value.isFinite else {
            throw EncodingError.invalidValue(
                jsonLexeme,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "invalid canonical JSON number"
                )
            )
        }
        try container.encode(value)
    }
}

struct _ExecutionGraphCodingKey: CodingKey, Hashable {
    let stringValue: String
    let intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

func _rejectUnknownKeys(
    _ decoder: Decoder,
    allowed: Set<String>
) throws {
    let container = try decoder.container(keyedBy: _ExecutionGraphCodingKey.self)
    let unknown = container.allKeys.map(\.stringValue).filter { !allowed.contains($0) }.sorted()
    guard unknown.isEmpty else {
        let path = decoder.codingPath.map(\.stringValue)
            .joined(separator: ".")
        throw ExecutionGraphViolation(
            id: "graph.contract.unknown-key",
            detail:
                (path.isEmpty ? "" : "\(path): ")
                + "unknown key(s): \(unknown.joined(separator: ", "))"
        )
    }
}
