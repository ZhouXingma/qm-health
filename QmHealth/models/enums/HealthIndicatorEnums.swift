//
//  HealthIndicatorEnums.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/10/26.
//

import SwiftUI

// 趋势：升高/降低/平稳（仅图标展示）
enum Trend: Int64, CaseIterable, Codable  {
    case down = -1
    case flat = 0
    case up = 1
    var color: Color {
        switch self {
            case .down: return .blue
            case .flat: return Color("text_secondary")
            case .up: return .orange
        }
    }
    var icon: String {
        switch self {
            case .down: return "arrow.down.right"
            case .flat: return "arrow.right"
            case .up: return "arrow.up.right"
        }
    }
    var displayName: String {
        switch self {
            case .down: return "下降"
            case .flat: return "平稳"
            case .up: return "上升"
        }
    }
    
    static func getByCode(code:Int64?) -> Trend? {
        if let codeValue = code {
            if codeValue == 0 {
                return .flat
            }
            if codeValue > 0 {
                return .up
            }
            return .down
        }
        return nil;
       
    }
}

// 指标的图标
func getHealthIndicatorIcon(_ code: String) -> (iconName: String, color: Color) {
    switch code.lowercased() {
    // 已定义的指标
    case "height": // 身高
        return ("arrow.up.and.down", .blue)
    case "weight": // 体重
        return ("scalemass", .orange)
    case "waist": // 腰围
        return ("arrow.left.and.right", .green)
    case "hip": // 臀围
        return ("figure", .purple)
    case "blood_pressure","systolic","diastolic":
        return ("heart.fill", .red)
    case "pulse_rate": // 心率
        return ("waveform.path.ecg", .pink)
    case "blood_sugar": // 血糖
        return ("drop.fill", Color.theme(.primary))
    case "temperature": // 体温
        return ("thermometer.variable", .red)
    case "steps":
        return ("figure.walk", .green)
    case "sleep":
        return ("bed.double.fill", .blue)
    case "oxygen_saturation":
        return ("o.circle.fill", .blue)
    case "respiratory_rate":
        return ("lungs.fill", .teal)
    case "active_energy":
        return ("flame.fill", .orange)
    case "distance":
        return ("point.topleft.down.curvedto.point.bottomright.up", .cyan)
    case "vo2max":
        return ("waveform.path.ecg", .indigo)
    case "body_fat", "fat_percentage":
        return ("percent", .gray)
    case "muscle_mass":
        return ("figure.strengthtraining.functional", .brown)
    case "water_intake", "hydration":
        return ("drop.circle.fill", .blue)
    case "mindfulness", "breathing":
        return ("leaf.fill", .mint)
    case "heart_rate_variability", "hrv":
        return ("waveform.path", .purple)
    case "blood_oxygen":
        return ("o.circle", .red)
        
    default:
        return ("heart.text.square.fill", .gray)
    }
}


// 健康指标状态枚举（rawValue 与后端 IndicatorStatus 编码一致，可直接解码复用）
enum HealthStatus: Int16, CaseIterable, Codable {
    // 未标记/无状态
    case none = 0
    // 正常
    case normal = 1
    // 偏高
    case high = 2
    // 偏低
    case low = 3
    // 异常
    case abnormal = 4
    // 检出
    case detected = 5
    // 未检出
    case notDetected = 6
    
    var color: Color {
        switch self {
        case .none:
            return Color.clear
        case .normal:
            return Color.green
        case .high, .low:
            return Color.red
        case .abnormal, .detected:
            return Color.red
        case .notDetected:
            return Color.gray
        }
    }
    
    var textColor: Color {
        switch self {
        case .none:
            return Color("text_primary")
        case .normal:
            return Color("text_primary")
        case .high, .low:
            return Color.red
        case .abnormal, .detected:
            return Color.red
        case .notDetected:
            return Color("text_primary")
        }
    }
    
    var text: String {
        switch self {
        case .none:
            return ""
        case .normal:
            return "正常"
        case .high:
            return "偏高"
        case .low:
            return "偏低"
        case .abnormal:
            return "异常"
        case .detected:
            return "检出"
        case .notDetected:
            return "未检出"
        }
    }
    
    
    // 根据后端状态编码获取健康状态（nil/未标记/未知编码归为 none）
    static func getHealthStatus(indicatorStatus: Int16?) -> HealthStatus {
        return HealthStatus(rawValue: indicatorStatus ?? 0) ?? .none
    }
}


// 血糖/血压的时间标签枚举
enum HealthIndicatorTimeLabel: Int16, CaseIterable, Codable {
    case fasting = 1           // 空腹
    case afterBreakfast = 2    // 早餐后
    case beforeLunch = 3       // 午餐前
    case afterLunch = 4        // 午餐后
    case beforeDinner = 5      // 晚餐前
    case afterDinner = 6       // 晚餐后
    case beforeSleep = 7       // 睡前
    case other = 99            // 其它
    
    var displayName: String {
        switch self {
        case .fasting: return "空腹"
        case .afterBreakfast: return "早餐后"
        case .beforeLunch: return "午餐前"
        case .afterLunch: return "午餐后"
        case .beforeDinner: return "晚餐前"
        case .afterDinner: return "晚餐后"
        case .beforeSleep: return "睡前"
        case .other: return "其它"
        }
    }
}

// 获取血糖/血压的 otherLabel 文本
func getDataTimeLabel(_ otherLabel: Int?) -> String? {
    guard let label = otherLabel else {
        return nil
    }
    
    if let timeLabel = HealthIndicatorTimeLabel(rawValue: Int16(label)) {
        return timeLabel.displayName
    }
    return nil
}


enum HealthIndicatorResultType:  Int32, Codable{
    case Description = 0 // 描述性，文本描述
    case Qualitative = 1 // 定性，比如：阴性/阳性
    case Quantitative = 2 // 定量，一般情况是数值
}


