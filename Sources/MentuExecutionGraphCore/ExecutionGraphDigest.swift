import CryptoKit
import Foundation

/// Digest helpers used by graph artifact identities.
public enum ExecutionGraphDigest: Sendable {
    public static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func sha256(_ string: String) -> String {
        sha256(Data(string.utf8))
    }
}
