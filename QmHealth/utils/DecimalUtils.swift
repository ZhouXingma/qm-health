//
//  DecimalUtils.swift
//  QingmuAccount
//
//  Created by 周荥马 on 2022/12/1.
//


import SwiftUI
class DecimalUtils {
    private static let DEFAULT_SPECIFILE:String="%.2f"
    public static func trans2StringOfDefaultSpecifile(_ value:Decimal) -> String {
        let doubleValue = Double(truncating: value as NSNumber)
        return String(format: DEFAULT_SPECIFILE, doubleValue)
    }
    
    public static func trans2StringOfSpecifile(_ value:Decimal, _ specifier:String) -> String {
        let doubleValue = Double(truncating: value as NSNumber)
        return String(format: specifier, doubleValue)
    }
}


extension Decimal {
    var doubleValue:Double {
        return NSDecimalNumber(decimal:self).doubleValue
    }
}
