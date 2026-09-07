import CryptoKit
import Foundation

enum ContentDigest {
    private static let digits: [UInt8] = Array("0123456789abcdef".utf8)

    static func sha256(_ data: Data) -> String {
        hexadecimal(SHA256.hash(data: data))
    }

    /// SHA-256 storage keys stay byte-for-byte compatible with the original
    /// lowercase formatter, without creating a formatted String for each byte.
    static func hexadecimal(_ bytes: some Sequence<UInt8>) -> String {
        var output: [UInt8] = []
        output.reserveCapacity(64)
        for byte in bytes {
            output.append(digits[Int(byte >> 4)])
            output.append(digits[Int(byte & 15)])
        }
        return String(decoding: output, as: UTF8.self)
    }
}
