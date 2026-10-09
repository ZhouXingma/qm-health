//
//  ChatHistory.swift
//  QmHealth
//
//  Created by Kiro on 2026/2/23.
//

import Foundation

// 聊天历史请求参数
struct ChatHistoryRequest: Codable {
    let pageNumber: Int
    let pageSize: Int
}

// 聊天历史响应
struct ChatHistoryResponse: Codable {
    let pageNumber: Int
    let pageSize: Int
    let totalCount: Int
    let results: [ChatHistoryItem]
}

// 聊天历史项
struct ChatHistoryItem: Codable, Identifiable {
    let id: String
    let title: String
    let gmtModified: String  // 后端返回的时间戳字符串，通常无时区标记，微秒精度
    let running: Bool?  // 会话是否仍在运行中（true 时前端显示闪烁点；可选，兼容旧数据缺失该字段）

    // 计算属性：转换为 Date
    var modifiedDate: Date {
        ChatHistoryDateParser.parse(gmtModified)
    }
    
    // 计算属性：获取日期分组标题
    var dateGroupTitle: String {
        let date = modifiedDate
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "今天"
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date)
        }
    }
}

// 分组后的聊天历史
struct GroupedChatHistory: Identifiable {
    let id = UUID()
    let dateTitle: String
    let items: [ChatHistoryItem]
}

// MARK: - 时间戳解析
///
/// 后端返回的 gmtModified 形如 "2026-07-16T22:08:07.398896"：
/// 不带时区标记，且小数秒位数不固定（曾观察到 6 位微秒）。
///
/// 之前的实现依赖 ISO8601DateFormatter（要求必须带时区，如 "Z"）和
/// DateFormatter 固定小数位模板，两者都无法匹配这种格式，导致解析
/// 几乎全部失败，兜底又用 `Date()`（当前时刻）顶替——相当于所有记录的
/// 排序时间都变成了"解析发生的那一刻"，跟真实修改时间毫无关系，
/// 于是刚发生的会话反而可能被排到列表中间。
///
/// 这里改为手动按字段拆解字符串，不依赖任何格式化器去猜测精度：
/// 1. 优先按本机所在时区（服务端返回的是本地时间，不是 UTC）解析；
/// 2. 兼容带时区标记（Z / +08:00）的情况；
/// 3. 全部解析失败时返回 `Date.distantPast`，让这条记录排到最后，
///    而不是错误地排到最前面。
enum ChatHistoryDateParser {
    /// 缓存 Calendar 实例，避免每次解析都重新创建
    private static var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        return cal
    }()

    static func parse(_ raw: String) -> Date {
        // 1. 优先尝试带时区标记的标准 ISO 8601（如果后端某天改成带时区返回，无需再改代码）
        if let date = parseWithTimeZone(raw) {
            return date
        }

        // 2. 按 "yyyy-MM-dd'T'HH:mm:ss[.fraction]" 手动拆解，时区按设备本地处理
        if let date = parseLocalNaive(raw) {
            return date
        }

        // 3. 彻底解析失败，排到最后而不是最前，避免污染排序
        return Date.distantPast
    }

    private static func parseWithTimeZone(_ raw: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: raw) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: raw)
    }

    private static func parseLocalNaive(_ raw: String) -> Date? {
        // 期望格式: yyyy-MM-ddTHH:mm:ss[.ffffff]
        let parts = raw.split(separator: "T", maxSplits: 1)
        guard parts.count == 2 else { return nil }

        let datePart = parts[0].split(separator: "-")
        guard datePart.count == 3,
              let year = Int(datePart[0]),
              let month = Int(datePart[1]),
              let day = Int(datePart[2]) else {
            return nil
        }

        let timeAndFraction = parts[1].split(separator: ".", maxSplits: 1)
        let timeComponents = timeAndFraction[0].split(separator: ":")
        guard timeComponents.count == 3,
              let hour = Int(timeComponents[0]),
              let minute = Int(timeComponents[1]),
              let second = Int(timeComponents[2]) else {
            return nil
        }

        var nanosecond = 0
        if timeAndFraction.count == 2 {
            // 小数秒位数不固定（可能是 3 位毫秒也可能是 6 位微秒），
            // 统一按"字符串左对齐补齐到 9 位纳秒"处理，避免位数不同导致数值含义错位
            let fractionStr = String(timeAndFraction[1].prefix(9)).padding(toLength: 9, withPad: "0", startingAt: 0)
            nanosecond = Int(fractionStr) ?? 0
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        components.nanosecond = nanosecond

        return calendar.date(from: components)
    }
}
