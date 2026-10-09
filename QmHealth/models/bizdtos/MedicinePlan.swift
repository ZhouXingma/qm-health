//
//  MedicinePlan.swift
//  QmHealth
//  用药计划相关数据模型
//
//  Created by 周荥马 on 2025/12/8.
//

import SwiftUI

// MARK: - 用药计划列表查询参数
/// medicineName 为空时查询全部计划；填写时由服务端执行药品名称模糊匹配。
struct MedicinePlanListParam: Codable {
    var medicineName: String
}

// MARK: - 用药计划详情查询参数
struct MedicinePlanDetailParam: Codable {
    var id: String
}

// MARK: - 用药计划分页查询参数
/// 用于添加用药记录时，按药品名称模糊匹配用药计划中的药品。
struct MedicinePlanPageParam: Codable {
    var medicineName: String
    var pageNumber: Int
    var pageSize: Int
}

// MARK: - 服药时间点（taking_info 中 times 数组的元素）
struct DoseTime: Codable, Hashable {
    var time: String        // "08:00"
    var doseUnit: String    // "颗"
    var doseAmount: Double   // 1 / 0.5

    init(time: String, doseUnit: String, doseAmount: Double) {
        self.time = time
        self.doseUnit = doseUnit
        self.doseAmount = doseAmount
    }
}

// MARK: - 服药详情原始结构（taking_info）
/// 用一个包含全部可能字段的 Codable 结构承载 5 种频次的 JSON，
/// 每种频次只使用其中的一部分字段，避免使用 AnyCodable（其解码在新运行时会崩溃）。
///
/// - 每天：times
/// - 循环定时：cycleUnit + times + cycleUseTimes + cycleStopTimes
/// - 每周特定日：sun/mon/tue/wed/thu/fri/sat
/// - 每隔N天：intervalDays + times
/// - 按需：无字段
struct TakingInfoRaw: Codable, Hashable {
    // 通用时间点列表（每天 / 循环定时 / 每隔N天）
    var times: [DoseTime]?

    // 循环定时
    var cycleUnit: Int?         // 1-天, 2-周
    var cycleUseTimes: Int?
    var cycleStopTimes: Int?

    // 每隔N天
    var intervalDays: Int?

    // 每周特定日
    var sun: [DoseTime]?
    var mon: [DoseTime]?
    var tue: [DoseTime]?
    var wed: [DoseTime]?
    var thu: [DoseTime]?
    var fri: [DoseTime]?
    var sat: [DoseTime]?

    init(times: [DoseTime]? = nil,
         cycleUnit: Int? = nil,
         cycleUseTimes: Int? = nil,
         cycleStopTimes: Int? = nil,
         intervalDays: Int? = nil,
         sun: [DoseTime]? = nil,
         mon: [DoseTime]? = nil,
         tue: [DoseTime]? = nil,
         wed: [DoseTime]? = nil,
         thu: [DoseTime]? = nil,
         fri: [DoseTime]? = nil,
         sat: [DoseTime]? = nil) {
        self.times = times
        self.cycleUnit = cycleUnit
        self.cycleUseTimes = cycleUseTimes
        self.cycleStopTimes = cycleStopTimes
        self.intervalDays = intervalDays
        self.sun = sun
        self.mon = mon
        self.tue = tue
        self.wed = wed
        self.thu = thu
        self.fri = fri
        self.sat = sat
    }

    /// 每周特定日：按周一到周日的顺序返回有安排的日期（key + 中文标签 + 时间点）
    var weeklyDays: [(key: String, label: String, times: [DoseTime])] {
        let mapping: [(key: String, label: String, times: [DoseTime]?)] = [
            ("mon", "周一", mon), ("tue", "周二", tue), ("wed", "周三", wed),
            ("thu", "周四", thu), ("fri", "周五", fri), ("sat", "周六", sat),
            ("sun", "周日", sun)
        ]
        return mapping.compactMap { item in
            guard let times = item.times, !times.isEmpty else { return nil }
            return (key: item.key, label: item.label, times: times)
        }
    }
}

// MARK: - 用药计划 DTO（对应后端 UsersMedicinePlanDTO）
/// 【说明】
/// - 新增时 id 为空，服务端自动生成
/// - 更新时 id 必填，其余字段选填（未提供的字段不会被更新）
/// - takingInfo 结构由 frequencyType 决定，具体解读见 `TakingInfoRaw`
struct UsersMedicinePlanDTO: Codable, Identifiable {
    /// id（更新时必填）
    var id: String?
    /// 用户id（由服务端根据登录信息自动填充）
    var userId: String?
    /// 关联药品/用药计划 ID；就诊记录详情返回时与当前就诊用药记录 id 分开保存。
    var medicineId: String?
    /// 药品名称
    var medicineName: String?
    /// 剂型（对应值域 medicineForm）
    var medicineForm: String?
    /// 规格数值
    var specification: String?
    /// 规格单位（对应值域 medicineSpecificationUnit）
    var specificationUnit: String?
    /// 频次模式：1-每天, 2-循环定时, 3-每周特定日, 4-每隔N天, 5-按需（对应值域 medicineFrequencyType）
    var frequencyType: Int16?
    /// 服药详情（结构随 frequencyType 变化）
    var takingInfo: TakingInfoRaw?
    /// 计划开始日期（格式：yyyy-MM-dd）
    var startDate: String?
    /// 计划结束日期（为空表示长期服药）
    var endDate: String?
    /// 来源类型：1-医院处方, 2-药店购买, 3-自行添加
    var sourceType: Int16?
    /// 医嘱/备注
    var medicalAdvice: String?
    /// 创建时间
    var gmtCreated: String?
    /// 修改时间
    var gmtModified: String?

    init(id: String? = nil,
         userId: String? = nil,
         medicineId: String? = nil,
         medicineName: String? = nil,
         medicineForm: String? = nil,
         specification: String? = nil,
         specificationUnit: String? = nil,
         frequencyType: Int16? = nil,
         takingInfo: TakingInfoRaw? = nil,
         startDate: String? = nil,
         endDate: String? = nil,
         sourceType: Int16? = nil,
         medicalAdvice: String? = nil,
         gmtCreated: String? = nil,
         gmtModified: String? = nil) {
        self.id = id
        self.userId = userId
        self.medicineId = medicineId
        self.medicineName = medicineName
        self.medicineForm = medicineForm
        self.specification = specification
        self.specificationUnit = specificationUnit
        self.frequencyType = frequencyType
        self.takingInfo = takingInfo
        self.startDate = startDate
        self.endDate = endDate
        self.sourceType = sourceType
        self.medicalAdvice = medicalAdvice
        self.gmtCreated = gmtCreated
        self.gmtModified = gmtModified
    }

    /// 频次类型枚举（客户端渲染逻辑依据，不依赖值域接口）
    var frequencyTypeEnum: MedicineFrequencyType? {
        guard let frequencyType = frequencyType else { return nil }
        return MedicineFrequencyType(rawValue: frequencyType)
    }

    /// 来源类型枚举
    var sourceTypeEnum: MedicineSourceType? {
        guard let sourceType = sourceType else { return nil }
        return MedicineSourceType(rawValue: sourceType)
    }

    /// 规格字符串（如 "0.25g"）
    var specificationString: String {
        guard let spec = specification, !spec.isEmpty else { return "" }
        return "\(spec)\(specificationUnit ?? "")"
    }
}

// MARK: - 用药计划来源：1-医院处方, 2-药店购买, 3-自行添加
enum MedicineSourceType: Int16, CaseIterable, Codable {
    case hospitalPrescription = 1
    case pharmacyPurchase = 2
    case selfAdded = 3

    var displayName: String {
        switch self {
        case .hospitalPrescription: return "医院处方"
        case .pharmacyPurchase: return "药店购买"
        case .selfAdded: return "自行添加"
        }
    }
}

// MARK: - 频次模式：1-每天, 2-循环定时, 3-每周特定日, 4-每隔N天, 5-按需
/// 该枚举决定 taking_info 的结构以及卡片摘要的渲染方式，为客户端固定逻辑。
/// 展示文案（如"每天"）统一从 medicineFrequencyType 值域接口获取，不在此硬编码。
enum MedicineFrequencyType: Int16, CaseIterable {
    case daily = 1
    case cyclic = 2
    case weekly = 3
    case interval = 4
    case asNeeded = 5

    var icon: String {
        switch self {
        case .daily: return "repeat"
        case .cyclic: return "arrow.triangle.2.circlepath"
        case .weekly: return "calendar"
        case .interval: return "calendar.badge.clock"
        case .asNeeded: return "hand.raised"
        }
    }
}

// MARK: - 用药剂型图标
/// 根据值域接口返回的剂型中文描述选择 SF Symbol。
/// 同类剂型可共享图标；未知、空或新增加的剂型使用默认药品图标。
enum MedicineFormIcon {
    static let defaultSystemName = "pills.fill"

    static func systemName(for form: String?) -> String {
        let normalizedForm = form?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "（", with: "(")
            .replacingOccurrences(of: "）", with: ")")
            ?? ""

        switch normalizedForm {
        // 口服固体
        case "胶囊":
            return "capsule.fill"
        case "药片", "片剂":
            return "circle.fill"
        case "锭剂":
            return "rectangle.fill"
        case "颗粒", "颗粒剂", "散剂", "粉末":
            return "pills.fill"
        case "丸剂", "丸剂(大蜜丸)", "丸剂(水丸/浓缩丸)", "丹剂":
            return "circle.fill"

        // 液体、滴剂和浸膏
        case "液体", "液剂", "滴剂", "露剂", "酊剂", "流浸膏", "浸膏剂":
            return "drop.fill"
        case "汤剂", "茶剂":
            return "cup.and.saucer.fill"
        case "药酒", "药酒(酒剂)", "酒剂":
            return "wineglass.fill"

        // 外用制剂
        case "外用", "乳液", "乳霜", "乳膏", "凝胶", "泡沫", "软膏", "膏方", "膏方(膏滋)", "煎膏", "煎膏剂":
            return "cross.case.fill"
        case "贴剂", "膜剂":
            return "bandage.fill"

        // 特殊给药方式或器械
        case "吸入剂":
            return "lungs.fill"
        case "喷剂":
            // SF Symbols 未提供 spray；使用已验证的滴剂图标，避免 Image(systemName:) 显示为空。
            return "drop.fill"
        case "注射", "注射剂":
            return "syringe.fill"
        case "栓剂":
            return "pills.fill"
        case "设备":
            return "cross.case.fill"

        default:
            return defaultSystemName
        }
    }
}
