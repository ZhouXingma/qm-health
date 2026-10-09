//
//  ApiConfig.swift
//  QmHealth
//
//  业务 API 与 AI API 的基础地址动态配置：
//  - 默认值 127.0.0.1，可由用户在"通用设置 → 请求地址"里修改
//  - 持久化在 UserDefaults，App 重启后保留
//  - 修改后无需重启进程，立即生效（所有后续请求都走 ApiConfig.currentBasicUrl/currentAiUrl）
//

import Foundation

enum ApiConfig {
    /// 业务 API 默认地址（保持与原 BASIC_URL 同协议同端口）
    static let defaultBasicUrl = "http://127.0.0.1:8080"
    /// AI API 默认地址
    static let defaultAiUrl = "http://127.0.0.1:8082"

    private enum Keys {
        static let basicUrl = "apiConfig.basicUrl"
        static let aiUrl = "apiConfig.aiUrl"
    }

    private static let defaults = UserDefaults.standard

    /// 当前业务 API 地址（未设置时返回默认值）
    static var currentBasicUrl: String {
        defaults.string(forKey: Keys.basicUrl).flatMap { $0.isEmpty ? nil : $0 } ?? defaultBasicUrl
    }

    /// 当前 AI API 地址
    static var currentAiUrl: String {
        defaults.string(forKey: Keys.aiUrl).flatMap { $0.isEmpty ? nil : $0 } ?? defaultAiUrl
    }

    /// 设置业务 API 地址
    static func setBasicUrl(_ url: String) {
        defaults.set(url, forKey: Keys.basicUrl)
    }

    /// 设置 AI API 地址
    static func setAiUrl(_ url: String) {
        defaults.set(url, forKey: Keys.aiUrl)
    }

    /// 恢复默认地址（清掉 UserDefaults 里的覆盖值）
    static func resetToDefaults() {
        defaults.removeObject(forKey: Keys.basicUrl)
        defaults.removeObject(forKey: Keys.aiUrl)
    }
}
