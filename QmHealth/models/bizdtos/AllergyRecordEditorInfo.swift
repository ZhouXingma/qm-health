//
//  AllergyRecordEditorInfo.swift
//  QmHealth
//
//  Created by 周荥马 on 2026/3/27.
//

import Foundation

class AllergyRecordEditorInfo: ObservableObject {
    @Published var id: String = ""
    @Published var allergyId: String = ""
    @Published var onsetTime: String = ""
    @Published var symptoms: String = ""
    @Published var severity: Int64 = 1
    @Published var treatmentMethod: String = ""
    @Published var remarks: String = ""
}

struct AllergyRecordSaveParam: Codable {
    let id: String?
    let allergyId: String
    let onsetTime: String
    let symptoms: String
    let severity: Int64
    let treatmentMethod: String
    let remarks: String
}
