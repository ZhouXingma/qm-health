//
//  HealthCurve.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/10/26.
//

import Foundation
/// 用户健康曲线计划数据传输对象（DTO）
///
/// 用于在客户端与服务端之间传递用户的健康计划信息。
/// 所有字段均为可选，以适应部分数据缺失或未设置的场景。
public class HealthCurveManagePlanDTO: Codable {
    /// 计划唯一标识 ID
    let id: String?
    
    /// 所属用户 ID
    let userId: String?
    
    /// 计划开始时的身高（单位通常由业务约定，如厘米）
    let startHeight: String?
    
    /// 计划开始时的体重（单位通常为千克）
    let startWeight: String?
    
    /// 目标体重（单位通常为千克）
    let targetWeight: String?
    
    /// 计划执行的总周数（例如：8 表示为期 8 周的计划）
    let planDuration: Int16?
    
    /// 计划方案类型
    let planType: Int16?
    
    /// 日常活动水平（如：卧床、久坐、轻体力、中体力、重体力）
    let activityLevel: String?
    
    /// 计划方案的具体内容（通常为 JSON 字符串或结构化文本）
    let plan: String?
    
    /// 计划的备注或描述信息
    let planDesc: String?
    
    /// AI生成的健康计划内容（HTML格式）
    /// 存储由AI制定的专属健康计划报告，使用HTML格式以便在WebView中渲染显示
    var aiPlanContent: String?
    
    /// AI对话的会话ID
    /// 用于关联AI生成计划时的对话会话，支持继续对话或追溯历史记录
    var conversationId: String?
    
    /// AI消息ID
    /// 标识AI回复的具体消息，用于精确定位计划生成时的消息内容
    var messageId: String?
    
    /// 计划当前状态码（例如：0=未开始, 1=进行中, 2=已完成, 3=已取消）
    let statusCode: Int16?
    
    /// 计划实际开始时间
    let startDate: Date?
    
    /// 计划预计或实际结束时间
    let endDate: Date?
    
    /// 记录创建时间（服务端生成）
    let gmtCreated: Date?
    
    /// 记录最后修改时间（服务端维护）
    let gmtModified: Date?
    
    /// 记录逻辑删除时间（若支持软删除）
    let gmtDeleted: Date?
    
    /// 逻辑删除标记：0 表示未删除，1 表示已删除
    let isDeleted: Int16?
    
    /// 初始化方法
    /// 创建健康曲线计划对象，所有参数均为可选
    init(id: String? = nil,
         userId: String? = nil,
         startHeight: String? = nil,
         startWeight: String? = nil,
         targetWeight: String? = nil,
         planDuration: Int16? = nil,
         planType: Int16? = nil,
         activityLevel: String? = nil,
         plan: String? = nil,
         planDesc: String? = nil,
         aiPlanContent: String? = nil,
         conversationId: String? = nil,
         messageId: String? = nil,
         statusCode: Int16? = nil,
         startDate: Date? = nil,
         endDate: Date? = nil,
         gmtCreated: Date? = nil,
         gmtModified: Date? = nil,
         gmtDeleted: Date? = nil,
         isDeleted: Int16? = nil) {
        self.id = id
        self.userId = userId
        self.startHeight = startHeight
        self.startWeight = startWeight
        self.targetWeight = targetWeight
        self.planDuration = planDuration
        self.planType = planType
        self.activityLevel = activityLevel
        self.plan = plan
        self.planDesc = planDesc
        self.aiPlanContent = aiPlanContent
        self.conversationId = conversationId
        self.messageId = messageId
        self.statusCode = statusCode
        self.startDate = startDate
        self.endDate = endDate
        self.gmtCreated = gmtCreated
        self.gmtModified = gmtModified
        self.gmtDeleted = gmtDeleted
        self.isDeleted = isDeleted
    }
}
