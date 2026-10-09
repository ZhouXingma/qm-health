//
//  DiseaseInfo.swift
//  QmHealth
//  疾病信息数据模型
//
//  Created by 周荥马 on 2025/10/2.
//

import Foundation

/// 疾病信息模型
class DiseaseInfo: Codable {
    var id: String?
    var userId: String?
    var name: String?                    // 疾病名称
    var firstVisitTime: String?         // 首诊时间
    var severity: Int64?                // 疾病严重程度
    var status: Int64?                  // 当前状态
    var doctor: String?                 // 主治医生
    var hospital: String?               // 就诊医院
    var followupVisitTime: String?      // 复诊时间
    var treatment: String?                // 治疗计划
    var remarks: String?                   // 备注信息
    var gmtCreated: String?                 // 创建时间
    var gmtModified: String?                 // 更新时间
    
    init(id: String? = nil, userId: String? = nil, name: String? = nil, firstVisitTime: String? = nil, severity: Int64? = nil, status: Int64? = nil, doctor: String? = nil, hospital: String? = nil, followupVisitTime: String? = nil, treatment: String? = nil, remarks: String? = nil, gmtCreated: String? = nil, gmtModified: String? = nil) {
        self.id = id
        self.userId = userId
        self.name = name
        self.firstVisitTime = firstVisitTime
        self.severity = severity
        self.status = status
        self.doctor = doctor
        self.hospital = hospital
        self.followupVisitTime = followupVisitTime
        self.treatment = treatment
        self.remarks = remarks
        self.gmtCreated = gmtCreated
        self.gmtModified = gmtModified
    }
}

class DiseaseEditorInfo: ObservableObject {
    @Published var id: String?
    @Published var name: String = ""                    // 疾病名称
    @Published var firstVisitTime: String? = nil         // 首诊时间
    @Published var severity: DiseaseSeverity = DiseaseSeverity.mild;                // 疾病严重程度
    @Published var status: DiseaseStatus = DiseaseStatus.stable                 // 当前状态
    @Published var doctor: String = ""               // 主治医生
    @Published var hospital: String = ""          // 就诊医院
    @Published var followupVisitTime: String? = nil   // 复诊时间
    @Published var treatment: String = ""           // 治疗计划
    @Published var remarks: String = ""                // 备注信息
    
}



class DiseaseInfoTransform {
    public static func trans2EditorInfo(info:DiseaseInfo) -> DiseaseEditorInfo {
        let editorInfo = DiseaseEditorInfo();
        editorInfo.id = info.id;
        editorInfo.name = StringUtils.emptyStr2NotNilStr(info.name, notNilStr: "");
        editorInfo.firstVisitTime = info.firstVisitTime;
        if let severity = info.severity {
            let diseaseSeverity = DiseaseSeverity.getByCode(code: severity);
            editorInfo.severity = diseaseSeverity ?? DiseaseSeverity.mild;
        }
        if let status = info.status {
            let diseaseStatus = DiseaseStatus.getByCode(code: status);
            editorInfo.status = diseaseStatus ?? DiseaseStatus.stable;
        }
        editorInfo.doctor = StringUtils.emptyStr2NotNilStr(info.doctor, notNilStr: "");
        editorInfo.hospital = StringUtils.emptyStr2NotNilStr(info.hospital, notNilStr: "");
        editorInfo.followupVisitTime = info.followupVisitTime;
        editorInfo.treatment = StringUtils.emptyStr2NotNilStr(info.treatment, notNilStr: "");
        editorInfo.remarks = StringUtils.emptyStr2NotNilStr(info.remarks, notNilStr: "");
        return editorInfo;
    }
    
    public static func trans2Info(editorInfo:DiseaseEditorInfo) -> DiseaseInfo {
        let info = DiseaseInfo();
        info.id = editorInfo.id
        info.name = StringUtils.emptyStr2DefaultStr(editorInfo.name, defaultValue: nil);
        info.firstVisitTime = StringUtils.emptyStr2DefaultStr(editorInfo.firstVisitTime, defaultValue: nil);
        info.severity = editorInfo.severity.rawValue;
        info.status = editorInfo.status.rawValue;
        info.doctor = StringUtils.emptyStr2DefaultStr(editorInfo.doctor, defaultValue: nil);
        info.hospital = StringUtils.emptyStr2DefaultStr(editorInfo.hospital, defaultValue: nil);
        info.followupVisitTime = StringUtils.emptyStr2DefaultStr(editorInfo.followupVisitTime , defaultValue: nil);
        info.treatment = StringUtils.emptyStr2DefaultStr(editorInfo.treatment, defaultValue: nil);
        info.remarks = StringUtils.emptyStr2DefaultStr(editorInfo.remarks, defaultValue: nil);
        return info;
    }
}


// MARK: - 疾病分页查询参数
/// 用于分页查询疾病信息
struct DiseasePageParam: Codable {
    /// 页码（必填）
    var pageNumber: Int
    
    /// 每页大小（必填）
    var pageSize: Int
    
    /// 疾病严重程度数组（可选，支持多选）
    var severities: [Int64]?
    
    /// 疾病状态数组（可选，支持多选）
    var statuses: [Int64]?
    
    /// 疾病名称（可选）
    var name: String?
    
    enum CodingKeys: String, CodingKey {
        case pageNumber
        case pageSize
        case severities
        case statuses
        case name
    }
}
