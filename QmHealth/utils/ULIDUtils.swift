//
//  ULIDUtils.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/3/12.
//

import Foundation

/// ULID 工具类
/// ULID 是一个 26 字符的字符串，由以下部分组成：
/// - 时间戳（前 10 个字符）：以 Crockford 的 Base32 编码的 48 位时间戳，精确到毫秒
/// - 随机数（后 16 个字符）：随机生成的数据
class ULIDUtils {
    
    /// Base32 字符集
    private static let ENCODING_CHARS = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
    
    /// 生成一个 ULID
    /// - Returns: 26 字符的 ULID 字符串
    static func generate() -> String {
        let timestamp = UInt64(Date().timeIntervalSince1970 * 1000)
        var randomBytes = [UInt8](repeating: 0, count: 10)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        
        return encode(timestamp: timestamp, randomness: randomBytes)
    }
    
    /// 编码时间戳和随机数为 ULID
    private static func encode(timestamp: UInt64, randomness: [UInt8]) -> String {
        var result = ""
        
        // 编码时间戳（10 个字符）
        var remainingTimestamp = timestamp
        for _ in 0..<10 {
            let mod = Int(remainingTimestamp % 32)
            remainingTimestamp /= 32
            result = String(ENCODING_CHARS[mod]) + result
        }
        
        // 编码随机数（16 个字符）
        for byte in randomness {
            let firstChar = ENCODING_CHARS[Int(byte >> 3)]
            let secondChar = ENCODING_CHARS[Int(byte & 0x1F)]
            result += String(firstChar)
            result += String(secondChar)
        }
        
        return result
    }
    
    /// 从 ULID 中提取时间戳
    /// - Parameter ulid: ULID 字符串
    /// - Returns: 时间戳（毫秒）
    static func getTimestamp(from ulid: String) -> Date? {
        guard ulid.count == 26 else { return nil }
        
        let timestampChars = String(ulid.prefix(10))
        var timestamp: UInt64 = 0
        
        for char in timestampChars {
            if let value = ENCODING_CHARS.firstIndex(of: char) {
                timestamp = timestamp * 32 + UInt64(value)
            } else {
                return nil
            }
        }
        
        return Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
    }
    
    /// 验证 ULID 是否有效
    /// - Parameter ulid: 要验证的 ULID 字符串
    /// - Returns: 是否是有效的 ULID
    static func isValid(_ ulid: String) -> Bool {
        guard ulid.count == 26 else { return false }
        
        return ulid.allSatisfy { ENCODING_CHARS.contains($0) }
    }
}