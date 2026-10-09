//
//  AllergyRecordResponse.swift
//  QmHealth
//
//  Created by 周荥马 on 2026/3/27.
//

import Foundation

struct AllergyRecordResponse: Codable, Identifiable {
    let pkId: Int64?
    let id: String
    let userId: String?
    let allergyId: String?
    let allergyName: String?
    let onsetTime: String?
    let symptoms: String?
    let severity: Int64?
    let treatmentMethod: String?
    let remarks: String?
    let isDeleted: Int32?
    let gmtCreated: String?
    let gmtModified: String?
    let gmtDeleted: String?
    
    var year: String {
        guard let onsetTime = onsetTime else { return "未知" }
        let components = onsetTime.split(separator: "-")
        return String(components.first ?? "未知")
    }
}

struct AllergyRecordPageParam: Codable {
    let allergyId: String
    let pageNumber: Int16
    let pageSize: Int16
}

struct AllergyRecordDeleteParam: Codable {
    let id: String
}
