//
//  Medicine.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/10/6.
//

import Foundation
import SwiftUI

/// 用药记录（基于 UsersMedicineDTO）
struct MedicineRecord: Identifiable, Codable {
    var _id: String?
    var userId: String?
    var medicineId: String?
    var medicineName: String?
    var dose: String?
    var doseUnit: String?
    var specification: String?
    var specificationUnit: String?
    var remarks: String?
    var takingTime: Date?
    var adverseReactions: String?
    
    /// Identifiable 协议实现：确保 id 不为 nil
    var id: String {
        return _id ?? UUID().uuidString
    }
    
    /// 获取或设置 id（用于编码/解码）
    var idValue: String? {
        get { return _id }
        set { _id = newValue }
    }
    
    /// 默认初始化方法
    init() {
        self._id = UUID().uuidString
        self.userId = nil
        self.medicineId = nil
        self.medicineName = nil
        self.dose = nil
        self.doseUnit = nil
        self.specification = nil
        self.specificationUnit = nil
        self.remarks = nil
        self.takingTime = nil
        self.adverseReactions = nil
    }
    
    /// Codable 编码键（status 不参与编码/解码，仅用于本地显示）
    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case userId
        case medicineId
        case medicineName
        case dose
        case doseUnit
        case specification
        case specificationUnit
        case remarks
        case takingTime
        case adverseReactions
    }
    
    /// 计算属性：规格字符串（如 "50mg"）
    var specificationString: String {
        guard let spec = specification, !spec.isEmpty,
              let unit = specificationUnit, !unit.isEmpty else {
            return ""
        }
        return "\(spec)\(unit)"
    }
    
    /// 计算属性：用量字符串（如 "1片"）
    var doseString: String {
        guard let dose = dose, !dose.isEmpty,
              let unit = doseUnit, !unit.isEmpty else {
            return ""
        }
        return "\(dose)\(unit)"
    }
    
    /// 计算属性：用药时间字符串（如 "08:00"）
    var timeString: String {
        guard let time = takingTime else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: time)
    }
    
    /// 计算属性：日期（用于分组和筛选）
    var date: Date {
        return takingTime ?? Date()
    }
}

/// 用户用药记录 DTO（对应后端 UsersMedicineDTO）
struct UsersMedicineDTO: Codable {
    /// id
    var id: String?
    
    /// 用户id
    var userId: String?
    
    /// 药品id
    var medicineId: String?

    /// 关联的用药计划 ID
    var planId: String?
    
    /// 药品名称
    var medicineName: String?
    
    /// 剂量
    var dose: String?
    
    /// 剂量单位
    var doseUnit: String?
    
    /// 规格
    var specification: String?
    
    /// 规格单位
    var specificationUnit: String?
    
    /// 备注信息
    var remarks: String?
    
    /// 用药时间
    var takingTime: Date?
    
    /// 不良反应
    var adverseReactions: String?
    
    /// 初始化方法
    init(id: String? = nil,
         userId: String? = nil,
         medicineId: String? = nil,
         medicineName: String? = nil,
         dose: String? = nil,
         doseUnit: String? = nil,
         specification: String? = nil,
         specificationUnit: String? = nil,
         remarks: String? = nil,
         takingTime: Date? = nil,
         adverseReactions: String? = nil) {
        self.id = id
        self.userId = userId
        self.medicineId = medicineId
        self.medicineName = medicineName
        self.dose = dose
        self.doseUnit = doseUnit
        self.specification = specification
        self.specificationUnit = specificationUnit
        self.remarks = remarks
        self.takingTime = takingTime
        self.adverseReactions = adverseReactions
    }
}

/// 按日期查询用药记录参数
struct MedicineListByDateParam: Codable {
    var date: String
}

/// 按月份查询有记录的日期参数
struct MedicineListDatesByMonthParam: Codable {
    var yearMonth: String
}

/// 有记录的日期信息
struct MedicineDateInfo: Codable {
    var date: String
    var count: Int
}
