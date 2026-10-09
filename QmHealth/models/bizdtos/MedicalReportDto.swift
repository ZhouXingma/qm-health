//
//  MedicalReportDto.swift
//  QmHealth
//

import Foundation

// MARK: - 就诊报告分页参数
struct MedicalReportPageParam: Codable {
    var pageNumber: Int
    var pageSize: Int

    enum CodingKeys: String, CodingKey {
        case pageNumber
        case pageSize
    }
}

// MARK: - 就诊报告响应（关联就诊信息）
struct MedicalReportVisitResponse: Codable, Identifiable {
    /// 就诊时间字符串（用 visitDate 作为唯一标识）
    var visitDate: String?

    var hospital: String?
    var doctorName: String?
    var department: String?
    var diagnosis: String?

    /// 报告类型：如 血常规、CT、MRI 等
    var reportType: String?

    /// 报告文件 URL
    var fileUrl: String?

    enum CodingKeys: String, CodingKey {
        case visitDate
        case hospital
        case doctorName
        case department
        case diagnosis
        case reportType
        case fileUrl
    }

    /// 唯一 ID（visitDate + reportType + hospital 拼接，避免同一天多份报告冲突）
    var id: String {
        "\(visitDate ?? "")_\(reportType ?? "")_\(hospital ?? "")"
    }

    /// 年份分组（yyyy年）
    var year: String {
        guard let date = parseDate() else { return "未知" }
        let calendar = Calendar.current
        return "\(calendar.component(.year, from: date))年"
    }

    /// 月份（如 11月）
    var month: String {
        guard let date = parseDate() else { return "--月" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月"
        return formatter.string(from: date)
    }

    /// 日（如 15）
    var day: String {
        guard let date = parseDate() else { return "--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        return formatter.string(from: date)
    }

    /// 星期（如 周一）
    var weekday: String {
        guard let date = parseDate() else { return "周--" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let calendar = Calendar.current
        let weekdayIndex = calendar.component(.weekday, from: date)
        let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return weekdays[weekdayIndex - 1]
    }

    /// HH:mm
    var timeText: String {
        guard let date = parseDate() else { return "--:--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func parseDate() -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let str = visitDate, let date = formatter.date(from: str) {
            return date
        }
        return nil
    }
}
