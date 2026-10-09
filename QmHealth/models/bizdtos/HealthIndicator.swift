//
//  HealthIndicator.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/10/15.
//

import Foundation
import SwiftUI

// 获取指标最新状态信息参数
class UsersHealthIndicatorLastedStatusParam : Codable {
    var indicatorCodes: [String]
    
    init(indicatorCodes: [String]) {
        self.indicatorCodes = indicatorCodes
    }
}

// 获取指标最新状态信息
class UsersHealthIndicatorLastedStatusDTO : Codable {
    // 指标编码
    var indicatorCode: String
    // 指标值
    var indicatorValue: String
    // 测量时间
    var measureTime: Date
    // 指标状态
    var indicatorStatus: Int64?
    // 平稳状态
    var stableStatus: Int64?
    
    init(indicatorCode: String, indicatorValue: String, measureTime: Date, indicatorStatus: Int64? = nil, stableStatus: Int64? = nil) {
        self.indicatorCode = indicatorCode
        self.indicatorValue = indicatorValue
        self.measureTime = measureTime
        self.indicatorStatus = indicatorStatus
        self.stableStatus = stableStatus
    }
}

// 用户健康指标配置信息
class UsersHealthIndicatorConfigurationDTO : Codable {
    var indicatorCode: String
    var indicatorName: String?
    var unit: String?
    var resultType: Int32?
    var description: String?
    var config: UsersHealthIndicatorConfigurationInfoDTO?
    
    init(indicatorCode: String, indicatorName: String? = nil, unit: String? = nil, resultType: Int32? = nil, description: String? = nil, config: UsersHealthIndicatorConfigurationInfoDTO) {
        self.indicatorCode = indicatorCode
        self.indicatorName = indicatorName
        self.unit = unit
        self.resultType = resultType
        self.description = description
        self.config = config
    }
    
}

// 健康指标配置信息
class UsersHealthIndicatorConfigurationInfoDTO : Codable  {
    var model: String?
    var addModel: String?
    var dateUnit: Int?
    var minValue: Double?
    var maxValue: Double?
    var valueFormate: String?
    var valueScope: [String]?
    var step:Double?
    
    init(model: String? = nil, addModel: String? = nil, dateUnit: Int? = nil,
         minValue: Double? = nil, maxValue: Double? = nil, valueFormate: String? = nil, valueScope: [String]? = nil, step:Double? = nil) {
        self.model = model
        self.addModel = addModel
        self.dateUnit = dateUnit
        self.minValue = minValue
        self.maxValue = maxValue
        self.valueFormate = valueFormate
        self.valueScope = valueScope
        self.step = step
    }
}

// 用户健康指标配置信息，用于页面交互
class UsersHealthIndicatorConfigurationInfo:ObservableObject {
    @Published var model: String
    @Published var addModel: String
    @Published var dateUnit: Int
    @Published var minValue: Double
    @Published var maxValue: Double
    @Published var valueFormate: String
    @Published var valueScope: [String]
    @Published var step: Double
    
    init(model: String = "normal", addModel: String = "normal",
         dateUnit: Int = 1, minValue: Double = 0, maxValue: Double = 100,
         valueFormate: String = "%0.1f", valueScope:[String] = [], step: Double = 0.1) {
        self.model = model
        self.addModel = addModel
        self.dateUnit = dateUnit
        self.minValue = minValue
        self.maxValue = maxValue
        self.valueFormate = valueFormate
        self.valueScope = valueScope
        self.step = step
    }
    func from(dto: UsersHealthIndicatorConfigurationInfoDTO) {
        self.model = dto.model ?? "normal";
        self.addModel = dto.addModel ?? "normal";
        self.dateUnit = dto.dateUnit ?? 1;
        self.minValue = dto.minValue ?? 0;
        self.maxValue = dto.maxValue ?? 100;
        self.valueFormate = dto.valueFormate ?? "%.1f";
        self.valueScope = dto.valueScope ?? []
        self.step = dto.step ?? 0.1
    }
}

// 健康指标分页参数
class UsersHealthIndicatorPageParam : Codable {
    var pageNumber: Int16
    var pageSize: Int16
    var indicatorCode: String
    var startDate: String?
    var endDate: String?
    
    init(pageNumber: Int16, pageSize: Int16, indicatorCode: String, startDate: String? = nil, endDate: String? = nil) {
        self.pageNumber = pageNumber
        self.pageSize = pageSize
        self.indicatorCode = indicatorCode
        self.startDate = startDate
        self.endDate = endDate
    }
}

/// 健康指标信息
class UsersHealthIndicatorDTO: Codable {
    // 唯一标识符
    var id: String?
    // 用户ID
    var userId: String?
    // 指标编码
    var indicatorCode: String?
    // 指标数值
    var indicatorValue: String?
    // 正常范围描述-原始
    var referenceRange: String?
    // 指标状态
    var indicatorStatus: Int16?
    // 医院名称
    var hospitalName: String?
    // 数据来源
    var dataSource: String?
    // 检测时间
    var measureTime: Date?
    // 文件ID集合
    var fileId: [String]?
    // 标签
    var label: Int16?
    // 其它标签
    var otherLabel: Int16?
    // 其它描述
    var otherDesc: String?
    // 业务ID
    var bizId: String?
    // 创建时间
    var gmtCreated: Date?
    // 修改时间
    var gmtModified: Date?
    // 数据类型
    var resultType: Int16?
}

/// 添加指标的参数
class UsersHealthIndicatorAddParam : Codable {
    // 指标编码
    var indicatorCode: String
    // 指标数值
    var indicatorValue: String
    // 正常范围描述
    var referenceRange: String?
    // 指标状态
    var indicatorStatus: Int16?
    // 医院名称
    var hospitalName: String?
    // 检测时间
    var measureTime: Date
    // 文件ID集合
    var fileId: [String]?
    // 标签
    var label: Int16?
    // 其它标签
    var otherLabel: Int16?
    // 其它描述
    var otherDesc: String?
    // 业务ID
    var bizId: String?

    init(indicatorCode: String, indicatorValue: String, referenceRange: String? = nil, indicatorStatus: Int16? = nil, hospitalName: String? = nil, measureTime: Date, fileId: [String]? = nil, label: Int16? = nil, otherLabel: Int16? = nil, otherDesc: String? = nil, bizId: String? = nil) {
        self.indicatorCode = indicatorCode
        self.indicatorValue = indicatorValue
        self.referenceRange = referenceRange
        self.indicatorStatus = indicatorStatus
        self.hospitalName = hospitalName
        self.measureTime = measureTime
        self.fileId = fileId
        self.label = label
        self.otherLabel = otherLabel
        self.otherDesc = otherDesc
        self.bizId = bizId
    }
}

// MARK: - 获取最新指标数据
/// 获取最新指标数据的参数
class UsersHealthIndicatorLastParam : Codable {
    var indicatorCodes: [String]
    var indicatorCategory: String?
    
    init(indicatorCodes: [String], indicatorCategory: String? = nil) {
        self.indicatorCodes = indicatorCodes
        self.indicatorCategory = indicatorCategory
    }
}

/// 最新指标数据详情
class HealthIndicatorInfoDTO : Codable {
    var id: String?
    var userId: String?
    var indicatorCode: String?
    var indicatorName: String?
    var indicatorValue: String?
    var referenceRange: String?
    var indicatorStatus: Int16?
    var hospitalName: String?
    var dataSource: String?
    var measureTime: String?
    var fileId: [String]?
    var label: Int?
    var otherLabel: Int?
    var otherDesc: String?
    var bizId: String?
    var gmtCreated: String?
    var gmtModified: String?
    var gmtDeleted: String?
    var isDeleted: Int?
    var resultType: Int?
    var categoryCode: String?
    var unit: String?
    var description: String?
    
    init(id: String? = nil, userId: String? = nil, indicatorCode: String? = nil, indicatorName: String? = nil, indicatorValue: String? = nil, referenceRange: String? = nil, indicatorStatus: Int16? = nil, hospitalName: String? = nil, dataSource: String? = nil, measureTime: String? = nil, fileId: [String]? = nil, label: Int? = nil, otherLabel: Int? = nil, otherDesc: String? = nil, bizId: String? = nil, gmtCreated: String? = nil, gmtModified: String? = nil, gmtDeleted: String? = nil, isDeleted: Int? = nil, resultType: Int? = nil, categoryCode: String? = nil, unit: String? = nil, description: String? = nil) {
        self.id = id
        self.userId = userId
        self.indicatorCode = indicatorCode
        self.indicatorName = indicatorName
        self.indicatorValue = indicatorValue
        self.referenceRange = referenceRange
        self.indicatorStatus = indicatorStatus
        self.hospitalName = hospitalName
        self.dataSource = dataSource
        self.measureTime = measureTime
        self.fileId = fileId
        self.label = label
        self.otherLabel = otherLabel
        self.otherDesc = otherDesc
        self.bizId = bizId
        self.gmtCreated = gmtCreated
        self.gmtModified = gmtModified
        self.gmtDeleted = gmtDeleted
        self.isDeleted = isDeleted
        self.resultType = resultType
        self.categoryCode = categoryCode
        self.unit = unit
        self.description = description
    }
}


struct HealthIndicatorMetaGroup: Codable {
    let categoryCode: String
    let categoryName: String
    let indicators: [HealthIndicatorMetaItem]
}

struct HealthIndicatorMetaItem: Codable {
    let indicatorCode: String?
    let indicatorName: String?
    let unit: String?
    let resultType: Int?
    let description: String?
    
    var resultTypeText: String {
        switch resultType {
        case 0: return "描述性"
        case 1: return "定性"
        case 2: return "定量"
        default: return "未知"
        }
    }
    
    var resultTypeColor: Color {
        switch resultType {
        case 0: return Color(red: 0.4, green: 0.6, blue: 1.0)  // 描述性 - 蓝色
        case 1: return Color(red: 1.0, green: 0.6, blue: 0.2)  // 定性 - 橙色
        case 2: return Color(red: 0.2, green: 0.8, blue: 0.4)  // 定量 - 绿色
        default: return Color.theme(.primary)
        }
    }
}
