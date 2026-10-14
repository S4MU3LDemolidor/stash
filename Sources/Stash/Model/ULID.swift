import Foundation

/// Universally Unique Lexicographically Sortable Identifier: 48-bit millisecond timestamp
/// plus 80 random bits, in Crockford base32 (26 characters). IDs sort by creation time.
enum ULID {
    private static let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    static func generate(date: Date = Date()) -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        let milliseconds = UInt64(max(0, date.timeIntervalSince1970 * 1000))
        for i in 0..<6 {
            bytes[i] = UInt8(truncatingIfNeeded: milliseconds >> (8 * UInt64(5 - i)))
        }
        for i in 6..<16 {
            bytes[i] = UInt8.random(in: .min ... .max)
        }
        return encode(bytes)
    }

    /// 128 bits → 26 base32 characters (the first character carries 2 leading zero bits).
    private static func encode(_ bytes: [UInt8]) -> String {
        var result = ""
        result.reserveCapacity(26)
        var buffer: UInt32 = 0
        var bitCount = 2
        for byte in bytes {
            buffer = (buffer << 8) | UInt32(byte)
            bitCount += 8
            while bitCount >= 5 {
                bitCount -= 5
                result.append(alphabet[Int((buffer >> UInt32(bitCount)) & 0x1F)])
            }
        }
        return result
    }

    static func isValid(_ string: String) -> Bool {
        string.count == 26 && string.uppercased().allSatisfy(alphabet.contains)
    }
}
