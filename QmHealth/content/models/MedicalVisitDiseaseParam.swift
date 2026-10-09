import Foundation

// MARK: - 就诊记录疾病参数
struct MedicalVisitDiseaseParam: Codable {
    let diseaseId: String
    let name: String
    let severity: Int64?
    let status: Int64?
    
    enum CodingKeys: String, CodingKey {
        case diseaseId, name, severity, status
    }
}
