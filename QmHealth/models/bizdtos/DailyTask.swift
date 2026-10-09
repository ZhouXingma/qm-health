//
//  DailyTask.swift
//  QmHealth
//
//  Created on 2026/6/26.
//

import Foundation
import SwiftUI

/// 每日任务查询参数
struct DailyTaskQueryParam: Codable {
    /// 任务日期，格式：yyyy-MM-dd
    var taskDate: String?
    /// 开始时间（可选）格式：yyyy-MM-dd HH:mm:ss
    var startDate: String?
    /// 结束时间（可选）格式：yyyy-MM-dd HH:mm:ss
    var endDate: String?
    /// 任务类型（可选）
    var taskType: Int16?
    /// 完成状态（可选）
    var status: Int16?
}

/// 每日任务 DTO
class DailyTaskDTO: Codable, Identifiable {
    /// id
    var id: String?
    /// 用户id
    var userId: String?
    /// 任务类型
    var taskType: Int16?
    /// 任务描述
    var taskDesc: String?
    /// 目标值
    var targetValue: String?
    /// 当前完成值
    var currentValue: String?
    /// 任务所属日期
    var taskDate: String?
    /// 计划开始时间
    var planStartTime: String?
    /// 计划结束时间
    var planEndTime: String?
    /// 完成时间
    var completedTime: String?
    /// 完成状态：0未开始 1进行中 2已完成 3已取消
    var status: Int16?
    /// 优先级：1高 2中 3低
    var priority: Int16?
    /// 扩展信息(JSON)
    var extJson: String?
    /// 任务来源
    var taskSource: String?
    /// 创建时间
    var gmtCreated: String?
    /// 修改时间
    var gmtModified: String?
    /// 删除时间
    var gmtDeleted: String?
    /// 是否删除，0否，1是
    var isDeleted: Int16?
}

// MARK: - 任务类型枚举
enum TaskTypeEnum: Int16 {
    case diet = 1              // 饮食
    case exercise = 2          // 运动
    case water = 3             // 饮水
    case medical = 4           // 就诊
    case measureIndicator = 5  // 指标测量
    case other = 99            // 其他

    /// 任务类型中文名
    var displayName: String {
        switch self {
        case .diet: return "饮食"
        case .exercise: return "运动"
        case .water: return "饮水"
        case .medical: return "就诊"
        case .measureIndicator: return "指标测量"
        case .other: return "其他"
        }
    }

    /// SF Symbol 图标名
    var iconName: String {
        switch self {
        case .diet: return "fork.knife"
        case .exercise: return "figure.run"
        case .water: return "drop.fill"
        case .medical: return "cross.case.fill"
        case .measureIndicator: return "heart.text.square.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    /// 主题色
    var color: Color {
        switch self {
        case .diet: return Color.theme(.primary)
        case .exercise: return .green
        case .water: return .blue
        case .medical: return .purple
        case .measureIndicator: return Color.theme(.chart1)
        case .other: return Color("text_secondary")
        }
    }
}

// MARK: - 任务状态枚举
enum DailyTaskStatus: Int16 {
    case notStarted = 0  // 未开始
    case inProgress = 1  // 进行中
    case completed = 2   // 已完成
    case cancelled = 3   // 已取消

    /// 状态中文名
    var displayName: String {
        switch self {
        case .notStarted: return "未开始"
        case .inProgress: return "进行中"
        case .completed: return "已完成"
        case .cancelled: return "已取消"
        }
    }

    /// SF Symbol 图标名
    var iconName: String {
        switch self {
        case .notStarted: return "circle"
        case .inProgress: return "circle.dotted"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle"
        }
    }

    /// 状态颜色（Asset 颜色名）
    var colorName: String {
        switch self {
        case .notStarted: return "text_secondary"
        case .inProgress: return "mainPrimary"
        case .completed: return "color1"
        case .cancelled: return "text_secondary"
        }
    }
}

// MARK: - 优先级枚举
enum DailyTaskPriority: Int16 {
    case high = 1    // 高
    case medium = 2  // 中
    case low = 3     // 低

    /// 优先级中文名
    var displayName: String {
        switch self {
        case .high: return "高"
        case .medium: return "中"
        case .low: return "低"
        }
    }
}

// MARK: - 年度统计

/// 年度统计查询参数
struct YearlyStatsQueryParam: Codable {
    var year: Int
}

/// 月度统计查询参数
struct MonthlyStatsQueryParam: Codable {
    var year: Int
    var month: Int
}

/// 状态数量
struct StatusCountDTO: Codable {
    var status: Int?
    var statusName: String?
    var count: Int?
}

/// 任务类型状态汇总
struct TypeStatusSummaryDTO: Codable {
    var taskType: Int?
    var taskTypeName: String?
    var statusCounts: [StatusCountDTO]?
}

/// 月度状态汇总
struct MonthStatusSummaryDTO: Codable {
    var period: Int?
    var periodName: String?
    var statusCounts: [StatusCountDTO]?
}

/// 年度统计响应
struct YearlyStatsDTO: Codable {
    var statusSummary: [StatusCountDTO]?
    var typeStatusSummary: [TypeStatusSummaryDTO]?
    var monthlyStatusSummary: [MonthStatusSummaryDTO]?
}

/// 月度统计响应（结构与年度一致，只是 monthlyStatusSummary → dailyStatusSummary）
struct MonthlyStatsDTO: Codable {
    var statusSummary: [StatusCountDTO]?
    var typeStatusSummary: [TypeStatusSummaryDTO]?
    var dailyStatusSummary: [MonthStatusSummaryDTO]?
}
