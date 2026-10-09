//
//  HealthCurveEnums.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/11/15.
//

// MARK: - 计划类型枚举
enum HealthCurvePlanType: Int16, CaseIterable {
    case conservative = 1
    case moderate = 2
    case aggressive = 3
    
    var title: String {
        switch self {
        case .conservative: "保守方案"
        case .moderate: "均衡方案"
        case .aggressive: "激进方案"
        }
    }
    
    var description: String {
        switch self {
        case .conservative: "每周减肥 0.25-0.5 kg，适合初学者"
        case .moderate: "每周减肥 0.5-1.0 kg，推荐方案"
        case .aggressive: "每周减肥 1.0-1.5 kg，需医生指导"
        }
    }
    
    var weeklyLoss: String {
        switch self {
        case .conservative: "0.25-0.5 kg/周"
        case .moderate: "0.5-1.0 kg/周"
        case .aggressive: "1.0-1.5 kg/周"
        }
    }
    // 每周最大减重量（kg）
    var maxWeeklyLoss: Double {
        switch self {
        case .conservative: 0.5
        case .moderate: 1.0
        case .aggressive: 1.5
        }
    }
    // 根据编码获取方案类型
    public static func getByRowValue(_ code:Int16?) -> HealthCurvePlanType? {
        guard let code_value = code else {
            return nil
        }
        var result:HealthCurvePlanType? = nil;
        switch code_value {
            case 1: result = HealthCurvePlanType.conservative
            case 2: result = HealthCurvePlanType.moderate
            case 3: result = HealthCurvePlanType.aggressive
            default: result = nil
        }
        return result;
    }
}
