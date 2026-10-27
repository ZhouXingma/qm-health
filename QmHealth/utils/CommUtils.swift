//
//  CommUtils.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/3/16.
//
import SwiftUI

/// 通用工具类
/// 提供项目中常用的工具方法
struct CommUtils {
    /// 计算年龄
    /// - Parameter birthday: 生日字符串，格式必须为："yyyy-MM-dd"
    /// - Returns: 返回计算出的年龄，如果日期格式错误则返回nil
    /// - Note: 使用系统日历组件计算年龄，会自动处理闰年等特殊情况
    static func computerAge(_ birthday: String?) -> Int? {
        ageComponents(birthday)?.year
    }

    /// 生日到指定时间的年月日差值
    /// - Parameters:
    ///   - birthday: 生日字符串，格式为 "yyyy-MM-dd"
    ///   - now: 参照时间，默认当前时间
    /// - Returns: 年月日差值；生日为空、格式错误或晚于参照时间时返回 nil
    static func ageComponents(_ birthday: String?, now: Date = Date()) -> DateComponents? {
        guard let birthday = birthday, !birthday.isEmpty else { return nil }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        guard let birthdayDate = dateFormatter.date(from: birthday), birthdayDate <= now else { return nil }
        return Calendar.current.dateComponents([.year, .month, .day], from: birthdayDate, to: now)
    }

    /// 年龄文案
    /// 满 1 岁显示「N岁」；不足 1 岁显示「N个月N天」；不足 1 个月显示「N天」
    /// - Returns: 年龄文案；生日无效时返回 nil
    static func ageText(_ birthday: String?, now: Date = Date()) -> String? {
        guard let components = ageComponents(birthday, now: now) else { return nil }
        let year = components.year ?? 0
        if year > 0 {
            return "\(year)岁"
        }
        let month = components.month ?? 0
        let day = components.day ?? 0
        if month > 0 {
            return day > 0 ? "\(month)个月\(day)天" : "\(month)个月"
        }
        return "\(day)天"
    }

    /// 年龄单位：周岁 / 月龄 / 日龄
    static func ageUnit(_ birthday: String?, now: Date = Date()) -> String? {
        guard let components = ageComponents(birthday, now: now) else { return nil }
        if (components.year ?? 0) > 0 {
            return "周岁"
        }
        return (components.month ?? 0) > 0 ? "月龄" : "日龄"
    }
    
    /// 获取性别枚举值
    /// - Parameter sexValue: 性别值（1:男 2:女）
    /// - Returns: 返回性别枚举，如果值不正确则返回nil
    static func getSex(_ sexValue: Int64?) -> Sex? {
        guard let value = sexValue else { return nil }
        return Sex(rawValue: value)
    }
}
