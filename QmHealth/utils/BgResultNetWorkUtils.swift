//
//  BgResultNetWorkUtils.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/6/2.
//
import Alamofire
import Foundation

// MARK: - 默认的处理方法
class BgResultNetWorkDefaultHandle {
    // 状态不是200的处理方法
    static func defaultNot200Handle<R:Codable>(_ r:BgResult<R>, error:BgResultNetWorkError, errorHandle:((BgResult<R>?, BgResultNetWorkError) -> Void)? = nil, popNamager:PopManager) {
        if r.code == 401 {
            popNamager.showSimplePop(title: "认证异常", description: "登录已失效，请登录重新操作")
            DispatchQueue.main.async {
                GlobalModel.shared.reset()
            }
            TokenUtils.deleteToken()
            return
        }
        if let handle = errorHandle {
            handle(r, error)
        } else {
            popNamager.showSimplePop(title: "失败！", description: r.message ?? "操作失败！请稍后重试")
        }
    }
    // 没有获取结果提示
    static func defaultErrorHandle(_ error:BgResultNetWorkError, popNamager:PopManager) {
        var description = "操作失败！请稍后重试"
        switch error {
        case .timeout(_, let message) : description = message;
        case .network(_, let message) : description = message;
        case .parameter(_, let message) : description = message;
        case .parsing(_, let message) : description = message;
        case .http(_, let message) : description = message;
        case .validation(_, let message) : description = message;
        case .requestError(_, let message) : description = message;
        case .unknown(_, _) : description = "操作失败！请稍后重试";
        }
        popNamager.showSimplePop(title: "失败！", description: description)
    }
    // 组件所有的请求头
    static func buildHeader() -> [String:String] {
        // 获取token
        let token = TokenUtils.getToken();
        let header = [HEAD_ACCEPT:ACCEPT_VALUE,
                  HEAD_ACCEPT_ENCODING: ACCEPT_ENCODING_VALUE,
                            HEAD_TOKEN: token]
        return header;
    }
    // 组件所有的请求头
    static func buildHeaderOnlyToken() -> [String:String] {
        // 获取token
        let token = TokenUtils.getToken();
        let header = [HEAD_TOKEN: token]
        return header;
    }
}
// MARK: - 网络请求失败类型，自己包装的失败类型
enum BgResultNetWorkError : Error {
    case timeout(Int?, String)
    case network(Int?, String)
    case parameter(Int?, String)
    case parsing(Int?, String)
    case http(Int?, String)
    case validation(Int?, String)
    case requestError(Int?, String)
    case unknown(Int?, String)
}


// 1. 定义 Empty 类型（代替 Void）
public struct Empty: Codable, Equatable {
    public init() {}
}

// MARK: - 网络请求对象，自己包装的AF
class BgResultNetWork<P, R> where P: Encodable, R: Codable {
    // 请求的地址
    private var urlStr: String
    // 请求方法
    private var method: HTTPMethod
    // 请求参数
    private var params: P?
    // 编码策略
    private var encoder: ParameterEncoder
    // 解码策略
    private var decoder: DataDecoder
    // 请求头
    private var headers:[String:String] = [:]
    // 失败处理方法
    private var errorHandleFunc: ((BgResult<R>?, BgResultNetWorkError) -> Void)? = nil
    // 成功完成处理方法
    private var complicationHandleFunc: ((R?) -> Void)? = nil
    // 最后结束处理方法
    private var finalyHandleFunc: ((BgResult<R>?) -> Void)? = nil
    // 进度信息
    private var progressHandleFunc: ((Progress) -> Void)? = nil
    // 超时时间
    private var timeOutForRequest : Double
    // 保存session
    private var session: Session? = nil
    // 弹窗管理器
    private var popManager: PopManager
    
    
    init(_ urlStr:String,
         method: HTTPMethod = .get,
         params: P? = nil,
         encoder: ParameterEncoder? = nil,
         decoder: DataDecoder? = nil,
         headers:[String:String] = BgResultNetWorkDefaultHandle.buildHeader(),
         timeOutForRequest: Double = 5,
         popManager:PopManager = PopManager.shared) {
        self.urlStr = urlStr
        self.method = method
        self.headers = headers
        self.params = params
        self.timeOutForRequest = timeOutForRequest
        self.popManager = popManager
        if let e = encoder {
            self.encoder = e
        } else {
            // 自动选择
            self.encoder = (method == .get ? URLEncodedFormParameterEncoder.default : JSONParameterEncoder(encoder: JSONFormatUtil.defaultInstall.encoder))
        }
        if method == .post {
            self.headers[HEAD_APPLICATION] = APPLICATION_JSON
        }
        if let d = decoder {
            self.decoder = d
        } else {
            self.decoder = JSONFormatUtil.defaultInstall.decoder
        }
        
    }
    // get请求
    static func get<T:Codable>(_ urlStr:String, popManager:PopManager = PopManager.shared) -> BgResultNetWork<Empty?, T> {
        return BgResultNetWork<Empty?,T>(urlStr, popManager: popManager)
    }
    // post请求
    static func post<T:Codable>(_ urlStr:String, encoder: ParameterEncoder = JSONParameterEncoder(encoder: JSONFormatUtil.defaultInstall.encoder), params: P? = nil, timeOutForRequest: Double = 5, popManager:PopManager = PopManager.shared) -> BgResultNetWork<P,T> {
        return BgResultNetWork<P,T>(urlStr, method: .post, params: params, encoder: encoder, timeOutForRequest: timeOutForRequest, popManager: popManager)
    }
    
    // 上传请求
    static func upload<T:Codable>(_ urlStr:String, params: P?, popManager:PopManager = PopManager.shared)  -> BgResultNetWork<P,T> {
        //return BgResultNetWork<P,T>(urlStr, method: .post, params: params, encodeing: URLEncoding.default)
        return BgResultNetWork<P,T>(urlStr, method: .post, params: params, encoder: URLEncodedFormParameterEncoder.default, popManager: popManager)
    }
    /**
     * 设置失败的处理方法
     */
    func errorHandle(_ funcHandle: @escaping ((BgResult<R>?, BgResultNetWorkError) -> Void)) -> BgResultNetWork<P,R> {
        self.errorHandleFunc = funcHandle;
        return self
    }
    /**
     * 设置成功的处理方法
     */
    func complicationHand(_ funcHandle: @escaping (R?) -> Void) -> BgResultNetWork<P,R> {
        self.complicationHandleFunc = funcHandle;
        return self
    }
    /**
     * 设置所有处理结束后的处理方法
     */
    func finalHandleFunc(_ funcHandle: @escaping ((BgResult<R>?) -> Void)) -> BgResultNetWork<P,R> {
        self.finalyHandleFunc = funcHandle;
        return self
    }
    /**
     * 设置进度处理方法
     */
    func progressHandleFunc(_ funcHandle: @escaping ((Progress) -> Void)) -> BgResultNetWork<P,R> {
        self.progressHandleFunc = funcHandle;
        return self
    }
    
    
    /**
     * 上传文件
     */
    func upload(fileInfos: [FileUploadInfo]) {
        let multipartFormData = MultipartFormData()
        for fileInfo in fileInfos {
            if fileInfo.isData() {
                multipartFormData.append(fileInfo.data!, withName: "files", fileName: fileInfo.fileName, mimeType: fileInfo.mimeType);
            }
            if fileInfo.isUrl() {
                multipartFormData.append(fileInfo.url!, withName: "files", fileName: fileInfo.fileName, mimeType: fileInfo.mimeType);
            }
        }
        var dicParam:[String: any Any & Sendable] = [:]
        do {
            dicParam = try self.params?.toDictionary() ?? [:];
        } catch {
            
        }
        for (key,value) in dicParam {
            // 处理不同类型的值
            if let stringValue = value as? String {
                // 字符串类型直接处理
                multipartFormData.append(stringValue.data(using: .utf8)!,
                                       withName: key)
            } else if let intValue = value as? Int {
                // 整数类型
                multipartFormData.append("\(intValue)".data(using: .utf8)!,
                                       withName: key)
            } else if let doubleValue = value as? Double {
                // 浮点数类型
                multipartFormData.append("\(doubleValue)".data(using: .utf8)!,
                                       withName: key)
            } else if let boolValue = value as? Bool {
                // 布尔类型
                multipartFormData.append("\(boolValue)".data(using: .utf8)!,
                                       withName: key)
            } else if let arrayValue = value as? [Any] {
                // 数组类型（重要！特殊处理）
                for (_, item) in arrayValue.enumerated() {
                    let arrayKey = "\(key)[]"
                    if let itemStr = item as? String {
                        multipartFormData.append(itemStr.data(using: .utf8)!,
                                               withName: arrayKey)
                    } else {
                        multipartFormData.append("\(item)".data(using: .utf8)!,
                                               withName: arrayKey)
                    }
                }
            } else if let dictValue = value as? [String: Any] {
                // 字典类型（转换为JSON字符串）
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: dictValue, options: [])
                    multipartFormData.append(jsonData,
                                            withName: key,
                                            fileName: "\(key).json",
                                            mimeType: "application/json")
                } catch {
                    print("字典转换失败: \(key) - \(error)")
                    // 可选：作为普通字符串上传
                    multipartFormData.append("\(dictValue)".data(using: .utf8)!,
                                           withName: key)
                }
            } else {
                // 通用回退处理（适用于其他类型）
                multipartFormData.append("\(value)".data(using: .utf8)!,
                                       withName: key)
            }
        }
        AF.upload(multipartFormData: multipartFormData, to: self.urlStr, headers: HTTPHeaders(self.headers))
            .validate() // 👈 关键：让 4xx/5xx 进入 .failure
            .uploadProgress { progress in
                print("总体进度: \(String(format: "%.1f", progress.fractionCompleted * 100))%")
                self.progressHandleFunc?(progress)
            }
            .responseDecodable(of: BgResult<R>.self, decoder: decoder) { response in
                self.handleBgResultResponse(response: response)
            }
    }
    
    // 开始请求，自己解析结果，一些需要自己解析的可以使用这个
    func response() {
        let customSession: Session = {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = self.timeOutForRequest  // ⏱ 请求超时时间（默认 60 秒）
            // 资源超时是整个请求的总超时上限，必须 >= 请求超时，否则会提前掐断长请求；保底 60 秒不影响其它默认请求
            configuration.timeoutIntervalForResource = max(self.timeOutForRequest, 60)
            configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData // 🚫 禁用请求级缓存，避免读取到旧数据
            configuration.urlCache = nil // 🚫 不使用 URLCache，杜绝任何本地响应缓存
            return Session(configuration: configuration)
        }()
        self.session = customSession;
        self.session!.request(urlStr,
                   method: self.method,
                   parameters: self.params,
                   encoder: self.encoder,
                   headers: HTTPHeaders(self.headers),
                   interceptor: nil, requestModifier: nil)
        .validate() // 👈 关键：让 4xx/5xx 进入 .failure
        .response{ response in
            self.handleResponse(response: response)
        }
    }
    // 解析成标准的BgResult<R>结构的请求
    func responseDecodable() {
        let customSession: Session = {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = self.timeOutForRequest  // ⏱ 请求超时时间（默认 60 秒）
            // 资源超时是整个请求的总超时上限，必须 >= 请求超时，否则会提前掐断长请求；保底 60 秒不影响其它默认请求
            configuration.timeoutIntervalForResource = max(self.timeOutForRequest, 60)
            configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData // 🚫 禁用请求级缓存，避免读取到旧数据
            configuration.urlCache = nil // 🚫 不使用 URLCache，杜绝任何本地响应缓存
            return Session(configuration: configuration)
        }()
        self.session = customSession;
        self.session!.request(urlStr,
                   method: self.method,
                   parameters: self.params,
                   encoder: self.encoder,
                   headers: HTTPHeaders(self.headers))
        .validate() // 👈 关键：让 4xx/5xx 进入 .failure
        .responseDecodable(of: BgResult<R>.self, decoder: decoder) { response in
            self.handleBgResultResponse(response: response)
        }
    }
    // 自定义标砖的响应
    private func handleBgResultResponse(response: AFDataResponse<BgResult<R>>) {
        let statusCode = response.response?.statusCode
        switch response.result {
        case .failure(_):
            if let data = response.data {
                self.showLog(data, statusCode);
                // 额外输出一份醒目日志，特别是 “数据解析失败” 这种 silent 错误
                let rawJsonStr = String(data: data, encoding: .utf8) ?? "<非 UTF-8>"
                print("🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥")
                print("🔥【响应解析失败诊断】期望响应类型: \(R.self)")
                print("🔥【请求地址】: \(self.urlStr)")
                print("🔥【请求方法】: \(self.method.rawValue.uppercased())")
                print("🔥【状态码】: \(statusCode.map { String($0) } ?? "未知")")
                print("🔥【AFError】: \(String(describing: response.error))")
                print("🔥【响应原文】:\n\(rawJsonStr)")
                print("🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥")
            }
            let errorInfo = response.error;
            self.handleOfError(statusCode, errorInfo)
        case .success(let ro):
            // 调试日志：成功路径也输出原始响应，方便排查“数据解析失败”这类 silent 错误
            let rawData = response.data ?? Data()
            let rawJsonStr = String(data: rawData, encoding: .utf8) ?? "<非 UTF-8>"
            let roDataJson = (try? JSONFormatUtil.defaultInstall.encodeToString(ro.data)) ?? "nil"
            if ro.code != 200 {
                // 业务失败仍是 HTTP 200，原先不会进入 .failure，因此这里补充输出日志。
                if let data = try? JSONFormatUtil.defaultInstall.encode(ro) {
                    self.showLog(data, statusCode)
                } else {
                    print("网络请求业务失败：code=\(ro.code)，message=\(ro.message ?? "无")")
                }
                BgResultNetWorkDefaultHandle.defaultNot200Handle(ro, error: .requestError(statusCode, ro.message ?? ""), errorHandle: self.errorHandleFunc, popNamager: popManager)
            } else {
                self.complicationHandleFunc?(ro.data)
            }
            self.finalyHandleFunc?(ro)
        }
    }
    // 自定义处理响应
    private func handleResponse(response:AFDataResponse<Data?>) {
        let statusCode = response.response?.statusCode
        switch response.result {
        case .failure(_):
            if let data = response.data {
                self.showLog(data, statusCode);
            }
            let errorInfo = response.error;
            self.handleOfError(statusCode, errorInfo)
        case .success(let ro):
            if let ros = ro {
                do {
                    let rs = try JSONDecoder().decode(BgResult<R>.self, from: ros);
                    let bg = BgResult<R>(code: rs.code, message: rs.message ?? "未知系统异常", data: nil)
                    if bg.code != 200 {
                        BgResultNetWorkDefaultHandle.defaultNot200Handle(bg , error: .requestError(statusCode, bg.message ?? ""), errorHandle: self.errorHandleFunc,popNamager: popManager)
                    } else {
                        self.complicationHandleFunc?(bg.data)
                    }
                } catch(_) {
                    let r = ros as? R;
                    if nil == r {
                        self.handleOfError(statusCode, .responseSerializationFailed(reason: .decodingFailed(error: BgResultNetWorkError.http(statusCode, "返回的数据解析数据异常"))))
                    } else {
                        self.complicationHandleFunc?(r)
                    }
                    
                }
            } else {
                self.complicationHandleFunc?(nil)
            }
            self.finalyHandleFunc?(nil)
        }
    }
    
    // 公共错误处理
    private func handleOfError(_ statusCode: Int?, _ errorInfo: AFError?) {
        // 🔍 区分错误类型
        var bgResultNetWorkError:BgResultNetWorkError = .unknown(statusCode, "未知系统错误")
        if let error = errorInfo,let afError = error.asAFError {
           switch afError {
           case .sessionTaskFailed(let taskError):
               let nsError = taskError as NSError
               if nsError.domain == NSURLErrorDomain {
                   switch nsError.code {
                   case NSURLErrorTimedOut:
                       bgResultNetWorkError = .timeout(statusCode, "请求超时")
                   case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                       bgResultNetWorkError = .network(statusCode, "网络连接异常")
                   default:
                       bgResultNetWorkError = .network(statusCode, "网络异常")
                   }
               }
           case .parameterEncodingFailed, .parameterEncoderFailed:
               bgResultNetWorkError = .parameter(statusCode, "请求参数异常")
               
           case .responseValidationFailed(let reason):
               if case .unacceptableStatusCode(let code) = reason {
                   bgResultNetWorkError = .parameter(statusCode, "HTTP错误: 状态码 \(code)")
               } else {
                   bgResultNetWorkError = .validation(statusCode, "响应验证失败")
               }
           case .createUploadableFailed(_):
               bgResultNetWorkError = .unknown(statusCode, "创建文件上传失败")
           case .responseSerializationFailed:
               bgResultNetWorkError = .parsing(statusCode, "数据解析失败")
           default:
               bgResultNetWorkError = .unknown(statusCode, "未知系统错误")
           }
       }

        if let errorHandle = self.errorHandleFunc {
            errorHandle(nil, bgResultNetWorkError)
        } else {
            BgResultNetWorkDefaultHandle.defaultErrorHandle(bgResultNetWorkError, popNamager: popManager)
        }
        self.finalyHandleFunc?(nil)
    }
    
    private func showLog(_ data:Data, _ statusCode:Int?) {
        var statusCodeStr = "未知";
        if let statusCodeR = statusCode {
            statusCodeStr = String(statusCodeR)
        }
        // 请求方法
        let methodStr = self.method.rawValue.uppercased()
        // 请求头（优先JSON格式化）
        let headersStr: String = {
            var sanitizedHeaders = self.headers
            if sanitizedHeaders[HEAD_TOKEN] != nil {
                sanitizedHeaders[HEAD_TOKEN] = "******"
            }
            if let jsonData = try? JSONSerialization.data(withJSONObject: sanitizedHeaders, options: [.prettyPrinted]),
               let jsonStr = String(data: jsonData, encoding: .utf8) {
                return jsonStr
            }
            return "\(sanitizedHeaders)"
        }()
        // 请求参数（优先JSON格式化，失败则回退为描述字符串）
        let paramsStr: String? = try?JSONFormatUtil.defaultInstall.encodeToString(self.params) ;
        print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>网络请求日志>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
        print("网络请求发生错误：\(statusCodeStr)")
        print("[请求地址]：\(self.urlStr)")
        print("[请求方法]：\(methodStr)")
        print("[请求头]：\(headersStr)")
        print("[请求参数]：\(paramsStr ?? "无法解析参数")")
        print("[错误信息]：\(String(data: data, encoding: .utf8) ?? "无")")
        print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
    }
    
    
}

// 上传文件信息
struct FileUploadInfo {
    var data: Data?
    var url: URL?
    var fileName: String
    var mimeType: String
    
    public func isData() -> Bool {
        return self.data != nil
    }
    public func isUrl() -> Bool {
        return self.url != nil
    }
}
