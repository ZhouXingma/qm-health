//
//  SseApi.swift
//  QmHealth
//
//  Created by 周荥马 on 2026/2/11.
//

import Foundation

class SseApi {
    static func postResponse(_ url:String, param:Encodable?, headers:[String:String]?,
                             dataHandle: ((String) -> Void)?,
                             errorHandle:((Error) -> Void)?,
                             stateChangeHandle:((ConnectionState) -> Void)?,
                             sendSuccessHanle:(() -> Void)?,
                             sendFailureHandler:((Error) -> Void)?) -> SSEClient {
        // 1. 创建带参数的 POST 请求
        let paramDic = try? param?.toDictionary();
        let paramRel = paramDic ?? [:]
        let headersRel = headers ?? [:]
        
        // ========== 参数转换日志 ==========
        print("========== SseApi 参数信息 ==========")
        print("URL: \(url)")
        print("请求头数量: \(headersRel.count)")
        for (key, value) in headersRel {
            if key.lowercased().contains("token") || key.lowercased().contains("authorization") {
                print("  \(key): [已隐藏]")
            } else {
                print("  \(key): \(value)")
            }
        }
        print("参数数量: \(paramRel.count)")
        if !paramRel.isEmpty {
            print("参数内容: \(paramRel)")
        }
        print("====================================")
        
        let client = SSEClient(
            urlString: url,
            configuration: SSEConfiguration.jsonBody(paramRel, headers: headersRel)
        )!
        // 3. 设置事件处理器
        client.onEvent = { event in
//            print("========== Sse 数据信息 ==========")
//            print("事件类型: \(event.event)")
//            print("数据: \(event.data)")
//            print("================================")
            switch event.event {
            case "data" :
                dataHandle?(event.data)
            default:
                print("未知事件类型：\(event.event),数据: \(event.data)")
            }
        }
        client.onError = { error in
            print("========== SSE 错误详情 ==========")
            print("错误: \(error)")
            if let sseError = error as? SSEError {
                switch sseError {
                case .invalidURL:
                    print("错误类型: 无效的 URL")
                case .invalidResponse:
                    print("错误类型: 无效的响应")
                case .connectionFailed(let reason):
                    print("错误类型: 连接失败")
                    print("原因: \(reason)")
                case .parsingError:
                    print("错误类型: 解析错误")
                case .disconnected:
                    print("错误类型: 连接已断开")
                case .requestBodyError(let err):
                    print("错误类型: 请求体错误")
                    print("详情: \(err.localizedDescription)")
                }
            } else {
                let nsError = error as NSError
                print("错误域: \(nsError.domain)")
                print("错误码: \(nsError.code)")
                print("错误描述: \(nsError.localizedDescription)")
            }
            print("====================================")
            errorHandle?(error)
        }
        client.onStateChange = { connectionState in
            stateChangeHandle?(connectionState)
        }
        client.onSendSuccess = {
            sendSuccessHanle?()
        }
        client.onSendFailure = { error in
            print("========== SSE 发送失败 ==========")
            print("错误: \(error)")
            print("====================================")
            sendFailureHandler?(error)
        }
        // 4. 连接
        do {
            try client.connect()
        } catch {
            print("连接失败: \(error)")
        }
        return client;
    }
    
    static  func postResponseDecode<R>(_ url:String, param:Encodable?, headers:[String:String]?,
                             dataHandle: ((R) -> Void)?,
                             errorHandle:((Error) -> Void)?,
                               stateChangeHandle:((ConnectionState) -> Void)?,
                               sendSuccessHanle:(() -> Void)?,
                               sendFailureHandler:((Error) -> Void)?) -> SSEClient where R:Decodable{
                             
        return SseApi.postResponse(url, param: param, headers: headers) { data in
            do {
                let a =  try JSONFormatUtil.defaultInstall.decodeFromString(data, as: R.self);
                dataHandle?(a)
            } catch {
                print("解析返回的数据，json解析出错！data:\(data)")
            }
            
        } errorHandle: { error in
            errorHandle?(error)
        } stateChangeHandle: { state in
            stateChangeHandle?(state)
        } sendSuccessHanle: {
            sendSuccessHanle?()
        } sendFailureHandler: { error in
            sendFailureHandler?(error)
        }

        
    }
}
