//
//  BizCommonFunctions.swift
//  QmHealth
//  业务通用函数
//
//  Created by 周荥马 on 2025/9/15.
//

import Foundation
import SwiftUI

class BizCommonFunctions {

    // MARK: - 健康指标时间标签
    
    /// 根据当前时间获取默认的时间标签
    /// 规则：
    /// - <8:00 空腹
    /// - <10:00 早餐后
    /// - <11:30 午餐前
    /// - <14:00 午餐后
    /// - <17:00 晚餐前
    /// - <20:00 晚餐后
    /// - <22:00 睡前
    /// - >=22:00 睡前
    /// - Parameter date: 指定日期，默认为当前时间
    /// - Returns: 对应的时间标签
    static func getDefaultHealthIndicatorTimeLabel(for date: Date = Date()) -> HealthIndicatorTimeLabel {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        
        guard let hour = components.hour, let minute = components.minute else {
            return .fasting
        }
        
        let totalMinutes = hour * 60 + minute
        
        // 8:00 = 480分钟
        if totalMinutes < 480 {
            return .fasting
        }
        
        // 10:00 = 600分钟
        if totalMinutes < 600 {
            return .afterBreakfast
        }
        
        // 11:30 = 690分钟
        if totalMinutes < 690 {
            return .beforeLunch
        }
        
        // 14:00 = 840分钟
        if totalMinutes < 840 {
            return .afterLunch
        }
        
        // 17:00 = 1020分钟
        if totalMinutes < 1020 {
            return .beforeDinner
        }
        
        // 20:00 = 1200分钟
        if totalMinutes < 1200 {
            return .afterDinner
        }
        
        // 22:00 = 1320分钟
        if totalMinutes < 1320 {
            return .beforeSleep
        }
        
        // >= 22:00
        return .beforeSleep
    }

    // MARK: - 档案完整度计算

    /// 计算用户档案完整度
    /// - Parameter user: 用户信息
    /// - Returns: 完整度百分比 (0-100)
    static func calculateProfileCompleteness(user: UserDTO?) -> Int {
        guard let user = user else { return 0 }
        
        var completedFields = 0

        // 基本信息字段检查
        if user.name != nil && !user.name!.isEmpty { completedFields += 1 }
        if user.gender != nil { completedFields += 1 }
        if user.birthday != nil && !user.birthday!.isEmpty { completedFields += 1 }
        if user.city != nil && !user.city!.isEmpty { completedFields += 1 }
        if user.job != nil && !user.job!.isEmpty { completedFields += 1 }
        if user.blood != nil { completedFields += 1 }
        if user.bloodRh != nil { completedFields += 1 }
        if user.nationality != nil { completedFields += 1 }
        if user.maritalStatus != nil { completedFields += 1 }
        if user.certification != nil { completedFields += 1 }
        if user.headerImg != nil && !user.headerImg!.isEmpty { completedFields += 1 }
        if user.nickname != nil && !user.nickname!.isEmpty { completedFields += 1 }

        // 调整总字段数为实际可用字段
        let actualTotalFields = 12
        
        return Int((Double(completedFields) / Double(actualTotalFields)) * 100)
    }
    
    // MARK: - 日期格式化
    
    /// 格式化相对时间
    /// - Parameter date: 日期
    /// - Returns: 相对时间描述
    static func formatRelativeTime(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        // 检查是否是今天
        if calendar.isDate(date, inSameDayAs: now) {
            return "今天"
        }
        
        // 检查是否是昨天
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "昨天"
        }
        
        // 检查是否是明天
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "明天"
        }
        
        // 计算天数差
        let components = calendar.dateComponents([.day], from: now, to: date)
        if let days = components.day {
            if days > 0 {
                return "\(days)天后"
            } else if days < 0 {
                return "\(-days)天前"
            }
        }
        
        // 默认格式化
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日"
        return formatter.string(from: date)
    }
}
