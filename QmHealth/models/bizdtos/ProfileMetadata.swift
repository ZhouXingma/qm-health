//
//  ProfileMetadata.swift
//  QmHealth
//  档案信息数据模型
//
//  Created by Kiro on 2025/1/30.
//

import Foundation

// MARK: - 档案元数据
class ProfileMetadata: Codable, Identifiable {
    /// 记录ID
    var id: String?
    
    /// 用户ID
    var userId: String?
    
    /// 档案名称（如：吸烟状态、饮食习惯等）
    var name: String?
    
    /// 元数据编码
    var metadataCode: String?
    
    /// 数据类型：single-单值, multiple-多值, record-记录
    var dataType: ProfileDataType = .single
    
    /// 单值数据（当dataType为single时使用）
    var singleValue: String?
    
    /// 多值数据（当dataType为multiple时使用）
    var multipleValues: [String]?
    
    /// 记录数据（当dataType为record时使用）
    var recordValues: [ProfileRecord]?
    
    /// 数据来源
    var dataSource: String?
    
    /// 业务标签
    var bizLabel: Int16?
    
    /// 创建时间
    var gmtCreated: String?
    
    /// 修改时间
    var gmtModified: String?
    
    init() {}
}

// MARK: - 档案记录
struct ProfileRecord: Codable, Identifiable {
    /// 记录ID
    var id: String
    
    /// 记录值
    var value: String
    
    /// 发生时间
    var occurredAt: Date?
    
    init(id: String = ULIDUtils.generate(), value: String, occurredAt: Date? = nil) {
        self.id = id
        self.value = value
        self.occurredAt = occurredAt
    }
}

// MARK: - 数据类型枚举
enum ProfileDataType: String, Codable, CaseIterable {
    case single = "single"      // 单值
    case multiple = "multiple"  // 多值
    case record = "record"      // 记录
    
    var displayName: String {
        switch self {
        case .single:
            return "单值"
        case .multiple:
            return "多值"
        case .record:
            return "记录"
        }
    }
    
    var description: String {
        switch self {
        case .single:
            return "记录单一文本信息"
        case .multiple:
            return "记录多个独立的文本信息"
        case .record:
            return "每条记录包含时间和内容"
        }
    }
    
    var icon: String {
        switch self {
        case .single:
            return "text.quote"
        case .multiple:
            return "list.bullet"
        case .record:
            return "clock.arrow.circlepath"
        }
    }
    
    var color: String {
        switch self {
        case .single:
            return "color1"
        case .multiple:
            return "color2"
        case .record:
            return "color3"
        }
    }
}

// MARK: - 档案信息添加参数
struct ProfileMetadataAddParam: Codable {
    /// 档案名称
    var name: String
    
    /// 元数据编码
    var metadataCode: String
    
    /// 数据类型
    var dataType: ProfileDataType
    
    /// 单值数据
    var singleValue: String?
    
    /// 多值数据
    var multipleValues: [String]?
    
    /// 业务标签
    var bizLabel: Int16?
}

// MARK: - 档案记录添加参数
struct ProfileRecordAddParam: Codable {
    /// 元数据编码
    var metadataCode: String
    
    /// 记录值
    var value: String
    
    /// 发生时间
    var occurredAt: Date
    
    /// 业务标签
    var bizLabel: Int16?
}

// MARK: - 档案信息查询参数
struct ProfileMetadataQueryParam: Codable {
    /// 页码
    var pageNumber: Int16
    
    /// 分页数量
    var pageSize: Int16
    
    /// 数据类型过滤（可选）
    var dataType: ProfileDataType?
}
