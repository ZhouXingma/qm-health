//
//  FamilyHistory.swift
//  QmHealth
//  家族史数据模型
//
//  Created by Kiro on 2025/1/28.
//

import Foundation

// 家族史信息（用于前端展示）
struct FamilyHistory: Codable, Identifiable, Hashable {
    var id: String?
    var userId: String?
    var relationship: Int64? // 亲属关系
    var relationshipName: String? // 亲属关系名称
    var diseaseName: String? // 疾病名称
    var diagnosisAge: Int? // 诊断年龄
    var notes: String? // 备注
    var gmtCreate: String?
    var gmtModified: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case relationship
        case relationshipName = "relationship_name"
        case diseaseName = "disease_name"
        case diagnosisAge = "diagnosis_age"
        case notes
        case gmtCreate = "gmt_create"
        case gmtModified = "gmt_modified"
    }
}

// 家族史简化模型（用于保存到后端）
struct FamilyHistoryItem: Codable {
    var role: String        // 角色（亲属关系代码）
    var disease: String     // 疾病名称
    var desc: String?       // 描述/备注
    var age: Int?           // 诊断年龄
    
    init(role: String, disease: String, desc: String? = nil, age: Int? = nil) {
        self.role = role
        self.disease = disease
        self.desc = desc
        self.age = age
    }
}

// 家族史保存参数
struct FamilyHistorySaveParam {
    var metadataCode: String = "家族史"
    var metadataValue: String
    var bizLabel: Int16 = 2
    
    // 从家族史列表转换为保存参数
    static func from(histories: [FamilyHistory]) -> FamilyHistorySaveParam? {
        let items = histories.map { history in
            FamilyHistoryItem(
                role: "\(history.relationship ?? 1)",
                disease: history.diseaseName ?? "",
                desc: history.notes,
                age: history.diagnosisAge
            )
        }
        
        guard let jsonData = try? JSONEncoder().encode(items),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }
        
        return FamilyHistorySaveParam(metadataValue: jsonString)
    }
    
    // 转换为MetaDataAddParam
    func toMetaDataAddParam() -> MetaDataAddParam {
        return MetaDataAddParam(
            metadataCode: metadataCode,
            metadataValue: metadataValue,
            occurredAt: Date(),
            bizLabel: bizLabel
        )
    }
}

// 家族史加载响应（从后端解析）
struct FamilyHistoryLoadResponse {
    var histories: [FamilyHistory]
    
    // 从元数据记录解析家族史列表
    static func from(metadataRecord: UsersMetadataRecordDTO?) -> FamilyHistoryLoadResponse {
        guard let record = metadataRecord,
              let valueString = record.metadataValue,
              let jsonData = valueString.data(using: .utf8),
              let items = try? JSONDecoder().decode([FamilyHistoryItem].self, from: jsonData) else {
            return FamilyHistoryLoadResponse(histories: [])
        }
        
        let histories = items.enumerated().map { index, item in
            let relationshipCode = Int64(item.role) ?? 1
            let relationship = FamilyRelationship.getByCode(code: relationshipCode)
            
            return FamilyHistory(
                id: "\(record.id ?? "")-\(index)",  // 使用记录ID和索引组合作为唯一ID
                userId: record.userId,
                relationship: relationshipCode,
                relationshipName: relationship?.displayName ?? "未知",
                diseaseName: item.disease,
                diagnosisAge: item.age,
                notes: item.desc,
                gmtCreate: record.gmtCreated != nil ? DateUtils.formatDate(record.gmtCreated!, format: DateUtils.DateFormat.ymdhms) : nil,
                gmtModified: record.gmtModified != nil ? DateUtils.formatDate(record.gmtModified!, format: DateUtils.DateFormat.ymdhms) : nil
            )
        }
        
        return FamilyHistoryLoadResponse(histories: histories)
    }
}

// 亲属关系枚举
enum FamilyRelationship: Int64, CaseIterable, Codable {
    case father = 1
    case mother = 2
    case grandfather = 3
    case grandmother = 4
    case maternalGrandfather = 5
    case maternalGrandmother = 6
    case brother = 7
    case sister = 8
    case paternalUncle = 9      // 叔伯
    case maternalUncle = 10     // 舅舅
    case paternalAunt = 11      // 姑姑
    case maternalAunt = 12      // 姨妈
    
    var displayName: String {
        switch self {
        case .father: return "父亲"
        case .mother: return "母亲"
        case .grandfather: return "祖父"
        case .grandmother: return "祖母"
        case .maternalGrandfather: return "外祖父"
        case .maternalGrandmother: return "外祖母"
        case .brother: return "兄弟"
        case .sister: return "姐妹"
        case .paternalUncle: return "叔伯"
        case .maternalUncle: return "舅舅"
        case .paternalAunt: return "姑姑"
        case .maternalAunt: return "姨妈"
        }
    }
    
    var icon: String {
        switch self {
        case .father: return "dad_parent"
        case .mother: return "mom"
        case .grandfather: return "grandfather"
        case .grandmother: return "grandmother"
        case .maternalGrandfather: return "grandfather"
        case .maternalGrandmother: return "grandmother"
        case .brother: return "brother"
        case .sister: return "sister"
        case .paternalUncle: return "uncle_male"
        case .maternalUncle: return "uncle_male"
        case .paternalAunt: return "aunt"
        case .maternalAunt: return "aunt"
        }
    }
    
    var group: FamilyGroup {
        switch self {
        case .father, .mother:
            return .parents
        case .grandfather, .grandmother, .maternalGrandfather, .maternalGrandmother:
            return .grandparents
        case .brother, .sister:
            return .siblings
        case .paternalUncle, .maternalUncle, .paternalAunt, .maternalAunt:
            return .extended
        }
    }
    
    static func getByCode(code: Int64) -> FamilyRelationship? {
        return FamilyRelationship(rawValue: code)
    }
}

// 家族成员分组
enum FamilyGroup: String, CaseIterable {
    case parents = "父母"
    case grandparents = "祖父母/外祖父母"
    case siblings = "兄弟姐妹"
    case extended = "其他亲属"
    
    var displayName: String {
        return self.rawValue
    }
    
    var icon: String {
        switch self {
        case .parents: return "person.2.fill"
        case .grandparents: return "figure.2.and.child.holdinghands"
        case .siblings: return "person.3.fill"
        case .extended: return "person.2.wave.2.fill"
        }
    }
    
    var color: String {
        switch self {
        case .parents: return "color1"
        case .grandparents: return "color2"
        case .siblings: return "color3"
        case .extended: return "color4"
        }
    }
}
