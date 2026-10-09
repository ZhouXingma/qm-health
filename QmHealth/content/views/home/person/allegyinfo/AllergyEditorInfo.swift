//
//  AllergyEditorInfo.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/10/12.
//

import Foundation

class AllergyEditorInfo: ObservableObject {
    @Published var id: String = ""
    @Published var name: String = ""
    @Published var severity: Int64 = 1
    @Published var treatment: String = ""
    @Published var remarks: String = ""
}
