//
//  HealthCurveUtil.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/11/15.
//

import SwiftUI

// BMI的状态和颜色
func bimStatusAndColor(bmiValue:Double) -> (text: String, color: Color) {
    switch bmiValue {
        case ..<18.5: ("偏瘦", .blue)
        case 18.5..<24.0: ("正常", .green)
        case 24.0..<28.0: ("超重", .orange)
        default: ("肥胖", .red)
    }
}

// 腰臀比的状态和颜色
func whrStatusAndColor(whrValue:Double) -> (text: String,color:Color) {
    if (whrValue == 0) {
        return ("--", .blue)
    }
    return whrValue > 0.9 ? ("偏高",.orange) : ("正常", .green)
}

// 计算bmi
func computerBmiValue(height:Double, weight:Double) -> Double {
    let heightM = max(0.01, height / 100.0)
    return (weight / (heightM * heightM)).rounded(toPlaces: 1);
}

// 获取减肥困难程度
func getLossWeightDifficultyLevel(_ valueOption :Double?) -> (text:String, color:Color)? {
    guard let value = valueOption else {
        return nil;
    }
    switch value {
    case ...0.5: return ("简单",Color.green)
    case 0.5...1.0:return ("中等",Color.blue)
    case 1.0...1.5: return ("略难",Color.red)
        default: return ("略难", Color.red)
    }
}
