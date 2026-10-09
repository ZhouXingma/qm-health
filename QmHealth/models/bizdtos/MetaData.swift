//
//  MetaData.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/11/18.
//
import Foundation

// 添加元数据参数
struct MetaDataAddParam:Codable {
    // 元数据编码
    var metadataCode:String
    // 元数据值
    var metadataValue:String
    // 业务发生时间
    var occurredAt: Date?
    // 业务label
    var bizLabel: Int16
}


// 添加元数据参数
struct MetaDataPageParam:Codable {
    // 页码
    var pageNumber: Int16
    // 分页数量
    var pageSize: Int16
    // 元数据编码
    var metadataCode:String
    
}

// 获取元数据记录最新记录的参数
struct MetaDataRecordLatestParam:Codable {
    // 元数据编码
    var metadataCode:String
}

// 根据编码获取元数据的参数
struct MetaDataGetByCodeParam: Codable {
    // 元数据编码
    var metadataCode: String
}




/// 元数据记录返回信息
class UsersMetadataRecordDTO: Codable {
    /// 记录ID
    var id: String?
    
    /// 用户ID
    var userId: String?
    
    /// 元数据键（如 surgery、allergy）
    var metadataCode: String?
    
    /// 元数据值
    var metadataValue: String?
    
    /// 事件发生时间
    var occurredAt: Date?
    
    /// 数据来源
    var dataSource: String?
    
    /// 业务发生来源
    var bizLabel: Int16?
    
    /// 创建时间
    var gmtCreated: Date?
    
    /// 修改时间
    var gmtModified: Date?
    
    /// 初始化方法
    init() {}
}
