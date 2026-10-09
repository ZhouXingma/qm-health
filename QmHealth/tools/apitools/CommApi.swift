//
//  CommApi.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/11/12.
//
import Foundation
// 获取值域
func getValueScopes(codes:[String]) -> [String: ValueScopeInfo] {
    let params = ValueScopeGetParamDTO(codes: codes)
    // 使用信号量实现同步等待
    let semaphore = DispatchSemaphore(value: 0)
    var result: [String: ValueScopeInfo] = [:]
    BgResultNetWork<ValueScopeGetParamDTO, [String: ValueScopeInfo]>.post(apiUrl(VALUE_SCOPE_LIST), params: params)
        .complicationHand { (dic:[String: ValueScopeInfo]?) in
            if let data = dic {
                result = data
            }
        }
        .finalHandleFunc { _ in
            semaphore.signal() // 网络请求完成后释放信号量
        }
        .responseDecodable()
    // 等待网络请求完成
    semaphore.wait()
    return result
}
