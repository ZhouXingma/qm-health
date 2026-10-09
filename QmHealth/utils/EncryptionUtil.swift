//
//  EncryptionUtil.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/2/27.
//

import Foundation
import CommonCrypto

class EncryptionUtil {
    // SHA-256加密
    static func sha256(_ string: String) -> String {
        let messageData = Data(string.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        
        _ = messageData.withUnsafeBytes {
            CC_SHA256($0.baseAddress, CC_LONG(messageData.count), &hash)
        }
        
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    // SHA-224加密（如果你想要224位输出）
    static func sha224(_ string: String) -> String {
        let messageData = Data(string.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA224_DIGEST_LENGTH))
        
        _ = messageData.withUnsafeBytes {
            CC_SHA224($0.baseAddress, CC_LONG(messageData.count), &hash)
        }
        
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    // MD5加密（128位输出）
    static func md5(_ string: String) -> String {
        let messageData = Data(string.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        
        _ = messageData.withUnsafeBytes {
            CC_MD5($0.baseAddress, CC_LONG(messageData.count), &hash)
        }
        
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    // SHA-256截取前32位（4字节）
    static func sha256Truncated32(_ string: String) -> String {
        let fullHash = sha256(string)
        let endIndex = fullHash.index(fullHash.startIndex, offsetBy: 8) // 32位 = 8个十六进制字符
        return String(fullHash[..<endIndex])
    }
    
    // SHA-1加密（已不推荐用于安全目的，但仍可能需要兼容性）
    static func sha1(_ string: String) -> String {
        let messageData = Data(string.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        
        _ = messageData.withUnsafeBytes {
            CC_SHA1($0.baseAddress, CC_LONG(messageData.count), &hash)
        }
        
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    // SHA-384加密
    static func sha384(_ string: String) -> String {
        let messageData = Data(string.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA384_DIGEST_LENGTH))
        
        _ = messageData.withUnsafeBytes {
            CC_SHA384($0.baseAddress, CC_LONG(messageData.count), &hash)
        }
        
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    // SHA-512加密
    static func sha512(_ string: String) -> String {
        let messageData = Data(string.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA512_DIGEST_LENGTH))
        
        _ = messageData.withUnsafeBytes {
            CC_SHA512($0.baseAddress, CC_LONG(messageData.count), &hash)
        }
        
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    // HMAC-SHA256加密
    static func hmacSHA256(_ string: String, key: String) -> String {
        let keyData = Data(key.utf8)
        let messageData = Data(string.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        
        keyData.withUnsafeBytes { keyBytes in
            messageData.withUnsafeBytes { messageBytes in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256),
                       keyBytes.baseAddress, keyData.count,
                       messageBytes.baseAddress, messageData.count,
                       &hash)
            }
        }
        
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    // Base64编码
    static func base64Encode(_ string: String) -> String {
        let data = Data(string.utf8)
        return data.base64EncodedString()
    }
    
    // Base64解码
    static func base64Decode(_ string: String) -> String? {
        guard let data = Data(base64Encoded: string) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - 使用示例
extension EncryptionUtil {
    static func examples() {
        let testString = "Hello, World!"
        
        print("原始字符串: \(testString)")
        print("SHA-256: \(sha256(testString))")
        print("SHA-224: \(sha224(testString))")
        print("MD5: \(md5(testString))")
        print("SHA-256截取32位: \(sha256Truncated32(testString))")
        print("SHA-1: \(sha1(testString))")
        print("SHA-384: \(sha384(testString))")
        print("SHA-512: \(sha512(testString))")
        print("HMAC-SHA256: \(hmacSHA256(testString, key: "secretkey"))")
        print("Base64编码: \(base64Encode(testString))")
        print("Base64解码: \(base64Decode(base64Encode(testString)) ?? "解码失败")")
    }
}
