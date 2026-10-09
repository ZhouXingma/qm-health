//
//  CommonModdels.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/9/30.
//

import Foundation

extension Encodable {
    func toDictionary() throws -> [String: any Any & Sendable] {
        return try JSONFormatUtil.defaultInstall.encodeToDictionary(self)
    }
    
    func toJSONString() throws -> String? {
        return try JSONFormatUtil.defaultInstall.encodeToString(self)
    }
}


extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}

/// 公共分页信息
class Page<T:Codable> : Codable {
    public var pageNumber:Int16
    public var pageSize:Int16
    public var total:Int64
    public var datas: [T]
    
    init(pageNumber: Int16, pageSize: Int16, total: Int64, datas: [T]) {
        self.pageNumber = pageNumber
        self.pageSize = pageSize
        self.total = total
        self.datas = datas
    }
}
