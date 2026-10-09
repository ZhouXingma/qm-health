//
// 过敏源
//  Allergy.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/10/12.
//

struct UserAllergy: Codable {
    var id: String?
    var userId: String?
    var name: String?                    // 疾病名称
    var severity: Int64?                // 疾病严重程度
    var treatment: String?                // 治疗/缓解方式
    var remarks: String?                   // 备注信息
    var gmtCreated: String?                 // 创建时间
    var gmtModified: String?                 // 更新时间
}
 
