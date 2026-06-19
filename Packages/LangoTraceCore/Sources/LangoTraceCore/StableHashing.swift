import CryptoKit
import Foundation

/// Single source of truth for stable, content-derived hashing used across
/// artifact keys, configuration fingerprints, and cache lookups. Consolidates
/// the previously duplicated SHA-256 hex helpers (7 copies across Core / Data /
/// UI) and the FNV-1a endpoint-fingerprint hasher (1 copy). Output is
/// byte-for-byte identical to the prior copies, so existing keys and
/// fingerprints stay stable.
public enum StableHashing {
    /// Lowercase hex SHA-256 of the UTF-8 bytes of `value`.
    public static func sha256Hex(_ value: String) -> String {
        sha256Hex(Data(value.utf8))
    }

    /// Lowercase hex SHA-256 of `data`.
    public static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// 64-bit FNV-1a of the UTF-8 bytes of `value`, as zero-padded lowercase hex.
    public static func fnv1a64Hex(_ value: String) -> String {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0100_0000_01B3
        }
        return String(format: "%016llx", hash)
    }
}
