//
//  CommNetworkModel.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/2/25.
//

import Foundation

// 后段请求结恶果
struct BgResult<T: Codable>:Codable{
    var code: Int16
    var message: String?
    var data: T?
}
