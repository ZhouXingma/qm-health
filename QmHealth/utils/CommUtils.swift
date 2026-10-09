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
        guard let birthday = birthday else { return nil }
        // 创建日期格式化器
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // 将生日字符串转换为日期对象
        if let birthdayDate = dateFormatter.date(from: birthday) {
            // 获取系统日历
            let calendar = Calendar.current
            // 获取当前时间
            let now = Date()
            // 计算生日日期到现在的年份差值
            let ageComponents = calendar.dateComponents([.year], from: birthdayDate, to: now)
            
            // 返回计算出的年龄
            if let age = ageComponents.year {
                return age
            }
        }
        return nil;
    }
    
    /// 获取性别枚举值
    /// - Parameter sexValue: 性别值（1:男 2:女）
    /// - Returns: 返回性别枚举，如果值不正确则返回nil
    static func getSex(_ sexValue: Int64?) -> Sex? {
        guard let value = sexValue else { return nil }
        return Sex(rawValue: value)
    }
}
