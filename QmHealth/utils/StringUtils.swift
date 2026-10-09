//
//  StringUtils.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/2/24.
//

public class StringUtils {
    // 空
    class func trim(_ str:String) -> String {
        return str.trimmingCharacters(in: .whitespacesAndNewlines);
    }
    // 是否为空
    class func isBlank(_ str:String) -> Bool {
        let a = trim(str);
        return a.count == 0;
    }
    // 空字符串转化为默认字符串
    class func emptyStr2DefaultStr(_ value:String?, defaultValue: String?) -> String? {
        if let v = value {
            let k = StringUtils.trim(v);
            if k != "" {
                return k;
            }
        }
        return defaultValue;
    }
    // 空字符串转化为默认字符串
    class func emptyStr2NotNilStr(_ value:String?, notNilStr: String) -> String {
        if let v = value {
            let k = StringUtils.trim(v);
            if k != "" {
                return k;
            }
        }
        return notNilStr;
    }
    /// 字符串转换为数值
    class func trans2Double(_ value: String?) -> Double? {
        guard let value_str = value else {
            return nil;
        }
        return Double(value_str) ?? nil
    }
    /// 字符串转换为数值
    class func trans2Int(_ value: String?) -> Int? {
        guard let value_str = value else {
            return nil;
        }
        return Int(value_str) ?? nil
    }
}
