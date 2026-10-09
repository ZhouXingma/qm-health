//
//  WaterIntake.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/11/19.
//
import Foundation

// 获取饮水记录参数
struct UsersWaterIntakeRecordQueryDTO: Codable {
    // 日期
    var date: String
}

/// 用户饮水记录 DTO
class UsersWaterIntakeRecordDTO: Codable {
    /// id
    var id: String?
    
    /// 用户id
    var userId: String?
    
    /// 饮水数量（毫升）
    var intakeMl: Int?
    
    /// 数据来源
    var dataSource: String?
    
    /// 业务发生来源
    var bizLabel: Int16?
    
    /// 创建时间
    var gmtCreated: Date?
    
    /// 修改时间
    var gmtModified: Date?
    
    /// 删除时间
    var gmtDeleted: Date?
    
    /// 是否删除，0否，1是
    var isDeleted: Int16?
    
    /// 初始化方法
    init(id: String? = nil, userId: String? = nil, intakeMl: Int? = nil, dataSource: String? = nil, bizLabel: Int16? = nil, gmtCreated: Date? = nil, gmtModified: Date? = nil, gmtDeleted: Date? = nil, isDeleted: Int16? = nil) {
        self.id = id
        self.userId = userId
        self.intakeMl = intakeMl
        self.dataSource = dataSource
        self.bizLabel = bizLabel
        self.gmtCreated = gmtCreated
        self.gmtModified = gmtModified
        self.gmtDeleted = gmtDeleted
        self.isDeleted = isDeleted
    }
}
