//
//  KeychainManager.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/2/28.
//
import Foundation
import Security

class KeychainUtils {
    
    static let shared = KeychainUtils()
    
    private init() {}
    
    private let service = KEYCHAIN_SERVICE  // 使用你的服务标识

    
    // 存储 Token 到 Keychain
    func saveToken(token: String, account: String) -> Bool {
        guard let tokenData = token.data(using: .utf8) else {
            print("Token 数据无效")
            return false
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
        ]
        // 删除现有的 Token（如果存在）
        let deleteStatus = SecItemDelete(query as CFDictionary)
        
        // 检查删除是否成功，如果没有数据可以删除，直接跳过
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            print("删除旧数据失败: \(deleteStatus)")
            return false
        }
        
        // 添加 Token 到 Keychain
        let addStatus = SecItemAdd([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: tokenData
        ] as CFDictionary, nil)
        
        return addStatus == errSecSuccess
    }
    
    // 从 Keychain 读取 Token
    func readToken(account: String) -> String? {
        var result: AnyObject?
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data, let token = String(data: data, encoding: .utf8) {
            return token
        } else {
            print("读取 Token 失败，错误码：\(status)")
            return nil
        }
    }
    
    // 更新 Keychain 中的 Token
    func updateToken(token: String, account: String) -> Bool {
        guard let tokenData = token.data(using: .utf8) else {
            print("Token 数据无效")
            return false
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
        ]
        
        // 更新数据
        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: tokenData
        ]
        
        let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        
        return updateStatus == errSecSuccess
    }
    
    // 删除 Keychain 中的 Token
    func deleteToken(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
        ]
        // 先查询是否存在
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            print("没有找到要删除的 Token")
            return true  // 没有找到数据可以直接返回成功
        }
        
        // 删除数据
        let deleteStatus = SecItemDelete(query as CFDictionary)
        
        if deleteStatus == errSecSuccess {
            print("Token 删除成功")
            return true
        } else {
            print("删除 Token 失败，错误码：\(deleteStatus)")
            return false
        }
    }
}
