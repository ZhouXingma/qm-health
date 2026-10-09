//
//  MedicalVisitDto.swift
//  QmHealth
//
//  Created on 2025/1/14.
//

import Foundation

// MARK: - 就诊记录用药提交参数
/// 仅保留就诊记录接口需要的用药字段，避免将详情响应中的用户与审计字段回传给服务端。
struct MedicalVisitMedicineParam: Codable {
    /// 已保存的就诊用药记录 ID；新建药品不传该字段。
    var id: String?
    /// 关联药品/用药计划 ID；已有药品需要随更新请求回传。
    var medicineId: String?
    var medicineName: String?
    var medicineForm: String?
    var specification: String?
    var specificationUnit: String?
    var frequencyType: Int16?
    var takingInfo: TakingInfoRaw?
    var startDate: String?
    var endDate: String?
    var sourceType: Int16?
    var medicalAdvice: String?

    init(plan: UsersMedicinePlanDTO) {
        id = plan.id
        medicineId = plan.medicineId
        medicineName = plan.medicineName
        medicineForm = plan.medicineForm
        specification = plan.specification
        specificationUnit = plan.specificationUnit
        frequencyType = plan.frequencyType
        takingInfo = plan.takingInfo
        startDate = plan.startDate
        endDate = plan.endDate
        sourceType = plan.sourceType
        medicalAdvice = plan.medicalAdvice
    }
}

// MARK: - 就诊记录用药详情响应
/// 就诊详情接口使用 medicineId，而独立用药计划模块使用 id；在此完成边界转换。
struct MedicalVisitMedicineResponse: Codable {
    /// 就诊用药关联记录 ID。
    var id: String?
    /// 关联药品/用药计划 ID。
    var medicineId: String?
    var medicineName: String?
    var medicineForm: String?
    var specification: String?
    var specificationUnit: String?
    var frequencyType: Int16?
    var takingInfo: TakingInfoRaw?
    var startDate: String?
    var endDate: String?
    var sourceType: Int16?
    var medicalAdvice: String?

    func asMedicinePlan() -> UsersMedicinePlanDTO {
        UsersMedicinePlanDTO(
            id: id,
            medicineId: medicineId,
            medicineName: medicineName,
            medicineForm: medicineForm,
            specification: specification,
            specificationUnit: specificationUnit,
            frequencyType: frequencyType,
            takingInfo: takingInfo,
            startDate: startDate,
            endDate: endDate,
            sourceType: sourceType,
            medicalAdvice: medicalAdvice
        )
    }
}

// MARK: - 就诊记录添加参数
/// 用于创建新的就诊记录
struct MedicalVisitAddParam: Codable {
    /// 医院名称（必填）
    var hospital: String
    
    /// 科室（必填）
    var department: String
    
    /// 医生姓名（必填）
    var doctorName: String
    
    /// 就诊/预约日期时间（必填）
    /// 格式：yyyy-MM-dd HH:mm:ss
    var visitDate: String
    
    /// 诊断结果（可选）
    /// 预约时可能为空，就诊后填写
    var diagnosis: String?
    
    /// 就诊状态（必填）
    /// 0 = 预约中，1 = 已就诊
    var status: Int
    
    /// 备注/医嘱（可选）
    var remarks: String?
    
    /// 症状描述（可选）
    var symptomDescription: String?
    
    /// 关联的医疗报告列表（可选）
    var reports: [MedicalReportAddParam]?
    
    /// 关联的疾病列表（可选）
    /// 格式：[{"diseaseId":"疾病的id","name":"疾病的名称","severity":"严重程度","status":"状态"}]
    var diseases: [MedicalVisitDiseaseParam]?

    /// 本次就诊开具的用药计划；没有 ID 的计划将由服务端同时创建
    var medicines: [MedicalVisitMedicineParam]?
    
    enum CodingKeys: String, CodingKey {
        case hospital
        case department
        case doctorName
        case visitDate
        case diagnosis
        case status
        case remarks
        case symptomDescription
        case reports
        case diseases
        case medicines
    }
}

// MARK: - 医疗报告添加参数
/// 用于添加医疗报告（检查报告、化验单等）
struct MedicalReportAddParam: Codable {
    /// 关联的就诊记录ID（必填）
    var visitId: String
    
    /// 报告类型（必填）
    /// 如：血常规、尿常规、CT、MRI、X光片等
    var reportType: String
    
    /// 报告文件的存储路径/文件ID（必填）
    /// 通过文件上传接口获得
    var fileUrl: String
    
    /// 原始文件名（必填）
    var fileName: String
    
    /// 报告简要描述（可选）
    var description: String?
    
    var isImage : Int32
    
    enum CodingKeys: String, CodingKey {
        case visitId
        case reportType
        case fileUrl
        case fileName
        case description
        case isImage
    }
}

// MARK: - 就诊状态枚举
/// 就诊记录的状态
enum MedicalVisitStatus: Int {
    case appointment = 0  // 预约中
    case visited = 1      // 已就诊
    
    var description: String {
        switch self {
        case .appointment:
            return "预约中"
        case .visited:
            return "已就诊"
        }
    }
}

// MARK: - 分页查询就诊记录参数
/// 用于分页查询就诊记录
struct MedicalVisitPageParam: Codable {
    /// 开始就诊日期（可选）
    /// 格式：yyyy-MM-dd HH:mm:ss
    var startVisitDate: String?
    
    /// 结束就诊日期（可选）
    /// 格式：yyyy-MM-dd HH:mm:ss
    var endVisitDate: String?
    
    /// 就诊状态筛选（可选）
    /// 0 = 预约中，1 = 已就诊
    var status: Int?
    
    /// 页码（必填）
    var pageNumber: Int
    
    /// 每页大小（必填）
    var pageSize: Int
    
    enum CodingKeys: String, CodingKey {
        case startVisitDate
        case endVisitDate
        case status
        case pageNumber
        case pageSize
    }
}

// MARK: - 更新就诊状态参数
/// 用于更新就诊记录的状态（仅修改状态）
struct MedicalVisitUpdateStatusParam: Codable {
    /// 就诊记录ID
    var id: String
    
    /// 就诊状态：0=预约中，1=已就诊
    var status: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case status
    }
}

// MARK: - 更新就诊记录参数
/// 用于更新就诊记录的完整信息
struct MedicalVisitUpdateParam: Codable {
    /// 就诊记录ID（必填）
    var id: String
    
    /// 医院名称（必填）
    var hospital: String
    
    /// 科室（必填）
    var department: String
    
    /// 医生姓名（必填）
    var doctorName: String
    
    /// 就诊/预约日期时间（必填）
    /// 格式：yyyy-MM-dd HH:mm:ss
    var visitDate: String
    
    /// 诊断结果（可选）
    var diagnosis: String?
    
    /// 就诊状态（必填）
    /// 0 = 预约中，1 = 已就诊
    var status: Int
    
    /// 备注/医嘱（可选）
    var remarks: String?
    
    /// 症状描述（可选）
    var symptomDescription: String?
    
    /// 关联的医疗报告列表（可选）
    var reports: [MedicalReportAddParam]?
    
    /// 关联的疾病列表（可选）
    /// 格式：[{"diseaseId":"疾病的id","name":"疾病的名称","severity":"严重程度","status":"状态"}]
    var diseases: [MedicalVisitDiseaseParam]?

    /// 本次就诊开具的用药计划；没有 ID 的计划将由服务端同时创建
    var medicines: [MedicalVisitMedicineParam]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case hospital
        case department
        case doctorName
        case visitDate
        case diagnosis
        case status
        case remarks
        case symptomDescription
        case reports
        case diseases
        case medicines
    }
}

// MARK: - 就诊记录详情查询参数
/// 用于查询单个就诊记录的详细信息
struct MedicalVisitDetailParam: Codable {
    /// 就诊记录ID
    var id: String
    
    enum CodingKeys: String, CodingKey {
        case id
    }
}

// MARK: - 就诊记录详情响应
/// 就诊记录的详细信息（包含报告等）
struct MedicalVisitDetailResponse: Codable {
    /// 就诊记录信息
    var visit: MedicalVisitInfo
    
    /// 关联的医疗报告列表
    var reports: [MedicalReportResponse]?
    
    /// 关联的疾病列表
    var diseases: [MedicalVisitDiseaseParam]?

    /// 本次就诊开具的用药计划
    var medicines: [MedicalVisitMedicineResponse]?
    
    enum CodingKeys: String, CodingKey {
        case visit
        case reports
        case diseases
        case medicines
    }
}

// MARK: - 就诊记录信息
/// 就诊记录的基本信息
struct MedicalVisitInfo: Codable {
    /// 记录ID
    var id: String
    
    /// 医院名称
    var hospital: String
    
    /// 科室
    var department: String
    
    /// 医生姓名
    var doctorName: String
    
    /// 就诊日期时间
    var visitDate: String
    
    /// 诊断结果
    var diagnosis: String?
    
    /// 就诊状态
    var status: Int
    
    /// 备注/医嘱
    var remarks: String?
    
    /// 症状描述
    var symptomDescription: String?
    
    /// 创建时间
    var gmtCreated: String
    
    /// 修改时间
    var gmtModified: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case hospital
        case department
        case doctorName
        case visitDate
        case diagnosis
        case status
        case remarks
        case symptomDescription
        case gmtCreated
        case gmtModified
    }
}

// MARK: - 医疗报告响应
/// 医疗报告的详细信息
struct MedicalReportResponse: Codable, Identifiable {
    /// 报告ID
    var id: String
    
    /// 报告类型
    var reportType: String
    
    /// 报告文件URL/文件ID
    var fileUrl: String
    
    /// 文件名
    var fileName: String
    
    /// 报告描述
    var description: String?
    
    /// 是否是图片 0:否，1:是
    var isImage: Int32
    
    /// 创建时间
    var gmtCreated: String
    
    /// 修改时间
    var gmtModified: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case reportType
        case fileUrl
        case fileName
        case description
        case gmtCreated
        case gmtModified
        case isImage
    }
}

// MARK: - 就诊记录响应数据
/// 从API返回的就诊记录数据
struct MedicalVisitResponse: Codable, Identifiable {
    /// 记录ID
    var id: String
    
    /// 医院名称
    var hospital: String
    
    /// 科室
    var department: String
    
    /// 医生姓名
    var doctorName: String
    
    /// 就诊日期时间
    /// 格式：yyyy-MM-dd HH:mm:ss
    var visitDate: String
    
    /// 诊断结果（可选）
    var diagnosis: String?
    
    /// 就诊状态
    /// 0 = 预约中，1 = 已就诊
    var status: Int
    
    /// 备注/医嘱（可选）
    var remarks: String?
    
    /// 症状描述（可选）
    var symptomDescription: String?
    
    /// 创建时间
    var gmtCreated: String
    
    /// 修改时间
    var gmtModified: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case hospital
        case department
        case doctorName
        case visitDate
        case diagnosis
        case status
        case remarks
        case symptomDescription
        case gmtCreated
        case gmtModified
    }
    
    /// 获取年份（用于分组）
    var year: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = dateFormatter.date(from: visitDate) {
            let calendar = Calendar.current
            return "\(calendar.component(.year, from: date))年"
        }
        return "未知"
    }
    
    /// 格式化的日期显示
    var formattedDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = dateFormatter.date(from: visitDate) {
            dateFormatter.dateFormat = "MM月dd日"
            return dateFormatter.string(from: date)
        }
        return visitDate
    }
    
    /// 月份显示（如：01月）
    var month: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = dateFormatter.date(from: visitDate) {
            dateFormatter.dateFormat = "MM"
            return dateFormatter.string(from: date)
        }
        return "--月"
    }
    
    /// 日期显示（如：14）
    var day: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = dateFormatter.date(from: visitDate) {
            dateFormatter.dateFormat = "dd"
            return dateFormatter.string(from: date)
        }
        return "--"
    }
    
    /// 月日显示（如：01/14）
    var monthDay: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = dateFormatter.date(from: visitDate) {
            dateFormatter.dateFormat = "MM/dd"
            return dateFormatter.string(from: date)
        }
        return "--/--"
    }
    
    /// 星期显示（如：周一）
    var weekday: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.locale = Locale(identifier: "zh_CN")
        if let date = dateFormatter.date(from: visitDate) {
            let calendar = Calendar.current
            let weekdayIndex = calendar.component(.weekday, from: date)
            let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
            return weekdays[weekdayIndex - 1]
        }
        return "周--"
    }
}

// MARK: - 就诊记录分页响应
/// 分页查询就诊记录的响应数据
struct MedicalVisitPageResponse: Codable {
    /// 就诊记录列表
    var datas: [MedicalVisitResponse]
    
    /// 当前页码
    var pageNumber: Int
    
    /// 每页大小
    var pageSize: Int
    
    /// 总记录数
    var total: Int
    
    enum CodingKeys: String, CodingKey {
        case datas
        case pageNumber
        case pageSize
        case total
    }
}

// MARK: - 通用API响应包装
/// 通用的API响应包装类
struct ApiResponse<T: Codable>: Codable {
    /// 响应码
    var code: Int
    
    /// 响应消息
    var message: String
    
    /// 响应数据
    var data: T?
    
    enum CodingKeys: String, CodingKey {
        case code
        case message
        case data
    }
}

// MARK: - 按疾病分页查询就诊记录参数
/// 用于按疾病ID分页查询就诊记录
struct MedicalVisitPageByDiseaseParam: Codable {
    /// 疾病ID（必填）
    var diseaseId: String
    
    /// 页码（必填）
    var pageNumber: Int16
    
    /// 每页大小（必填）
    var pageSize: Int16
    
    enum CodingKeys: String, CodingKey {
        case diseaseId
        case pageNumber
        case pageSize
    }
}
