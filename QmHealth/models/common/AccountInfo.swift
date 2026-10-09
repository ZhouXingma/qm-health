//
//  AccountInfo.swift
//  QmHealth
//
//  Created by 周荥马 on 2026/1/23.
//

import Foundation

// 账号信息模型
struct AccountInfo: Codable, Identifiable {
    var id: String { userId }
    let account: String      // 账号（手机号/邮箱）
    let userId: String       // 用户ID
    var userName: String?    // 用户名
    var nickname: String?    // 昵称
    var headerImg: String?   // 头像
    var lastLoginTime: Date  // 最后登录时间
    
    init(account: String, userId: String, userName: String? = nil, nickname:String? = nil, headerImg: String? = nil, lastLoginTime: Date = Date()) {
        self.account = account
        self.userId = userId
        self.userName = userName
        self.nickname = nickname
        self.headerImg = headerImg
        self.lastLoginTime = lastLoginTime
    }
}

// 多账号管理
class AccountManager {
    static let shared = AccountManager()
    
    private let accountsKey = "saved_accounts"
    private let currentAccountKey = "current_account"
    
    private init() {}
    
    // MARK: - 获取所有账号
    func getAllAccounts() -> [AccountInfo] {
        guard let data = UserDefaults.standard.data(forKey: accountsKey),
              let accounts = try? JSONDecoder().decode([AccountInfo].self, from: data) else {
            return []
        }
        return accounts.sorted { $0.lastLoginTime > $1.lastLoginTime }
    }
    
    // MARK: - 获取当前账号
    func getCurrentAccount() -> String? {
        return UserDefaults.standard.string(forKey: currentAccountKey)
    }
    
    // MARK: - 保存账号信息
    func saveAccount(_ accountInfo: AccountInfo) {
        var accounts = getAllAccounts()
        
        // 移除已存在的相同账号
        accounts.removeAll { $0.account == accountInfo.account }
        
        // 添加新账号
        accounts.append(accountInfo)
        
        // 保存到UserDefaults
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: accountsKey)
        }
    }
    
    // MARK: - 设置当前账号
    func setCurrentAccount(_ account: String) {
        UserDefaults.standard.set(account, forKey: currentAccountKey)
        
        // 更新该账号的最后登录时间
        var accounts = getAllAccounts()
        if let index = accounts.firstIndex(where: { $0.account == account }) {
            accounts[index].lastLoginTime = Date()
            if let data = try? JSONEncoder().encode(accounts) {
                UserDefaults.standard.set(data, forKey: accountsKey)
            }
        }
    }
    
    // MARK: - 删除账号
    func deleteAccount(_ account: String) {
        var accounts = getAllAccounts()
        accounts.removeAll { $0.account == account }
        
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: accountsKey)
        }
        
        // 删除token
        KeychainUtils.shared.deleteToken(account: account)
        
        // 如果删除的是当前账号，清除当前账号标记
        if getCurrentAccount() == account {
            UserDefaults.standard.removeObject(forKey: currentAccountKey)
        }
    }
    
    // MARK: - 更新账号信息
    func updateAccount(_ account: String, userName: String?, headerImg: String?) {
        var accounts = getAllAccounts()
        if let index = accounts.firstIndex(where: { $0.account == account }) {
            if let userName = userName {
                accounts[index].userName = userName
            }
            if let headerImg = headerImg {
                accounts[index].headerImg = headerImg
            }
            
            if let data = try? JSONEncoder().encode(accounts) {
                UserDefaults.standard.set(data, forKey: accountsKey)
            }
        }
    }
    
    // MARK: - 获取指定账号信息
    func getAccount(_ account: String) -> AccountInfo? {
        return getAllAccounts().first { $0.account == account }
    }
    
    // MARK: - 清除所有账号
    func clearAllAccounts() {
        let accounts = getAllAccounts()
        for account in accounts {
            KeychainUtils.shared.deleteToken(account: account.account)
        }
        UserDefaults.standard.removeObject(forKey: accountsKey)
        UserDefaults.standard.removeObject(forKey: currentAccountKey)
    }
}
