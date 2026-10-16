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

    /// 历史记录条数上限
    static let maxHistoryCount = 10

    /// 一次保存过的地址对：业务 API + 智能体 API，两个地址成对出现
    struct EndpointPair: Codable, Equatable, Identifiable {
        let basicUrl: String
        let aiUrl: String

        var id: String { "\(basicUrl)|\(aiUrl)" }
    }

    private enum Keys {
        static let basicUrl = "apiConfig.basicUrl"
        static let aiUrl = "apiConfig.aiUrl"
        /// 历史记录旧版存放位置，仅用于迁移到 json 文件
        static let legacyHistory = "apiConfig.history"
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
        notifyChanged()
    }

    /// 设置 AI API 地址
    static func setAiUrl(_ url: String) {
        defaults.set(url, forKey: Keys.aiUrl)
        notifyChanged()
    }

    /// 恢复默认地址（清掉 UserDefaults 里的覆盖值）
    static func resetToDefaults() {
        defaults.removeObject(forKey: Keys.basicUrl)
        defaults.removeObject(forKey: Keys.aiUrl)
        notifyChanged()
    }

    /// 地址变更通知：ApiConfig 是静态配置，不是 ObservableObject，
    /// 展示当前地址的页面需订阅此通知才能即时刷新。
    private static func notifyChanged() {
        NotificationCenter.default.post(name: .apiConfigDidChange, object: nil)
    }

    // MARK: - 历史记录（本地 json 文件）

    /// 历史记录文件：Documents/api_endpoints.json（沙盒内，可直接查看/手改）
    static var historyFilePath: String {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("api_endpoints.json").path
    }

    /// 保存过的地址对，最近使用的排在最前
    static var endpointHistory: [EndpointPair] {
        if let data = try? Data(contentsOf: URL(fileURLWithPath: historyFilePath)) {
            return (try? JSONDecoder().decode([EndpointPair].self, from: data)) ?? []
        }
        return migrateLegacyHistory()
    }

    /// 记录一次保存
    /// - 两个地址都一致视为与历史记录重复，去重后提到最前（使用过的放在前面）
    /// - 最多保留 maxHistoryCount 条，超出丢弃最旧的
    static func recordEndpointHistory(basicUrl: String, aiUrl: String) {
        var list = endpointHistory
        list.removeAll { $0.basicUrl == basicUrl && $0.aiUrl == aiUrl }
        list.insert(EndpointPair(basicUrl: basicUrl, aiUrl: aiUrl), at: 0)
        if list.count > maxHistoryCount {
            list = Array(list.prefix(maxHistoryCount))
        }
        writeHistory(list)
    }

    /// 删除一条历史记录
    static func removeEndpointHistory(_ pair: EndpointPair) {
        let list = endpointHistory.filter { $0 != pair }
        writeHistory(list)
    }

    /// 写回 json 文件：输出成可读格式，方便直接打开查看
    private static func writeHistory(_ list: [EndpointPair]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(list) else { return }
        try? data.write(to: URL(fileURLWithPath: historyFilePath), options: .atomic)
    }

    /// 旧版本把历史记录存在 UserDefaults 里，首次读取时迁移到 json 文件
    private static func migrateLegacyHistory() -> [EndpointPair] {
        guard let legacy = defaults.data(forKey: Keys.legacyHistory),
              let list = try? JSONDecoder().decode([EndpointPair].self, from: legacy) else {
            return []
        }
        writeHistory(list)
        defaults.removeObject(forKey: Keys.legacyHistory)
        return list
    }
}

extension Notification.Name {
    /// 请求地址（业务 API / 智能体 API）发生变更
    static let apiConfigDidChange = Notification.Name("apiConfigDidChange")
}
