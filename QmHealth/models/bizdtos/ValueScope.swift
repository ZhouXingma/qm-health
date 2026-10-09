//
//  ValueScope.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/11/12.
//
import Foundation

// MARK: - 值域项（有序数组格式）
class ValueScopeItem: Codable {
    var value: String
    var desc: String
    
    init(value: String, desc: String) {
        self.value = value
        self.desc = desc
    }
}

// MARK: - 值域信息（支持有序数组）
class ValueScopeInfo: Codable {
    var code: String
    var desc: String
    var valueScope: [ValueScopeItem]
    
    init(code: String, desc: String, valueScope: [ValueScopeItem]) {
        self.code = code
        self.desc = desc
        self.valueScope = valueScope
    }
}

// MARK: - 获取值域的参数
class ValueScopeGetParamDTO: Codable {
    var codes: [String]
    
    init(codes: [String]) {
        self.codes = codes
    }
}

// MARK: - 值域文案查找辅助方法
extension ValueScopeInfo {
    /// 根据 value 查找对应的展示文案（desc），找不到时返回 nil
    func desc(forValue value: String) -> String? {
        return valueScope.first(where: { $0.value == value })?.desc
    }
}
