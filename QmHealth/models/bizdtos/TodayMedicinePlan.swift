import Foundation

// MARK: - 今日用药计划 DTO
/// 今日每个应服时间点对应一条计划数据，不能作为实际用药记录使用。
struct TodayMedicinePlanDTO: Codable, Identifiable {
    /// 用药计划 ID。
    var planId: String
    /// 药品名称。
    var medicineName: String
    /// 剂型。
    var medicineForm: String?
    /// 规格数值。
    var specification: String?
    /// 规格单位。
    var specificationUnit: String?
    /// 频次模式：1-每天，2-循环定时，3-每周特定日，4-每隔 N 天。
    var frequencyType: Int
    /// 今日应服时间，格式为 H:mm 或 HH:mm。
    var time: String
    /// 本次服药剂量单位。
    var doseUnit: String
    /// 本次服药剂量。
    var doseAmount: Double
    /// 今日该时间点是否已服用。
    var isTaken: Bool
    /// 匹配到的今日实际服药记录 ID。
    var takingRecordId: String?
    /// 匹配到的今日实际服药时间。
    var takingTime: String?
    /// 医嘱或备注。
    var medicalAdvice: String?
    /// 最近一次实际服药时间。
    var lastTakingTime: String?

    var id: String {
        "\(planId)-\(time)"
    }

    var specificationText: String {
        guard let specification, !specification.isEmpty else { return "" }
        return "\(specification)\(specificationUnit ?? "")"
    }

    var doseText: String {
        let amountText: String
        if doseAmount == doseAmount.rounded() {
            amountText = String(Int(doseAmount))
        } else {
            amountText = String(doseAmount)
        }
        return "\(amountText)\(doseUnit)"
    }
}
