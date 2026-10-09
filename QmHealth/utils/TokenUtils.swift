//
//  TokenUtils.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/6/2.
//

import Foundation

class TokenUtils {
    // MARK: - 获取当前账号的token
    static func getToken() -> String {
        guard let account = AccountManager.shared.getCurrentAccount() else {
            return ""
        }
        return KeychainUtils.shared.readToken(account: account) ?? ""
    }
    
    // MARK: - 获取指定账号的token
    static func getToken(for account: String) -> String {
        return KeychainUtils.shared.readToken(account: account) ?? ""
    }
    
    // MARK: - 保存或更新token（登录时调用）
    static func saveToken(_ account: String, _ token: String, userId: String, userName: String? = nil, nickname:String? = nil, headerImg: String? = nil) -> Bool {
        // 保存token到Keychain
        let success = KeychainUtils.shared.saveToken(token: token, account: account)
        
        if success {
            // 保存账号信息
            let accountInfo = AccountInfo(
                account: account,
                userId: userId,
                userName: userName,
                nickname: nickname,
                headerImg: headerImg,
                lastLoginTime: Date()
            )
            
            print("保存的账号信息:\(try? JSONFormatUtil.defaultInstall.encodeToString(accountInfo))")
            AccountManager.shared.saveAccount(accountInfo)
            
            // 设置为当前账号
            AccountManager.shared.setCurrentAccount(account)
        }
        
        return success
    }
    
    // MARK: - 切换账号
    static func switchAccount(_ account: String) -> Bool {
        // 检查该账号是否有token
        guard let token = KeychainUtils.shared.readToken(account: account), !token.isEmpty else {
            return false
        }
        
        // 设置为当前账号
        AccountManager.shared.setCurrentAccount(account)
        return true
    }
    
    // MARK: - 删除当前账号的token
    static func deleteToken() {
        guard let account = AccountManager.shared.getCurrentAccount() else {
            return
        }
        AccountManager.shared.deleteAccount(account)
    }
    
    // MARK: - 删除指定账号的token
    static func deleteToken(for account: String) {
        AccountManager.shared.deleteAccount(account)
    }
    
    // MARK: - 更新账号信息
    static func updateAccountInfo(account: String, userName: String?, headerImg: String?) {
        AccountManager.shared.updateAccount(account, userName: userName, headerImg: headerImg)
    }
    
    // MARK: - 获取所有已登录账号
    static func getAllAccounts() -> [AccountInfo] {
        return AccountManager.shared.getAllAccounts()
    }
    
    // MARK: - 获取当前账号
    static func getCurrentAccount() -> String? {
        return AccountManager.shared.getCurrentAccount()
    }
    
    // MARK: - 登出所有账号
    static func logoutAll() {
        AccountManager.shared.clearAllAccounts()
    }
}
