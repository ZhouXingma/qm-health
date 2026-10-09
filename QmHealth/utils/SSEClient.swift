import Foundation

// MARK: - SSE 事件模型
public struct SSEEvent {
    public let id: String?
    public let event: String
    public let data: String
    public let retry: Int?
    
    public init(id: String?, event: String, data: String, retry: Int? = nil) {
        self.id = id
        self.event = event
        self.data = data
        self.retry = retry
    }
}

// MARK: - HTTP 方法枚举
public enum SseHTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

// MARK: - 请求参数类型
public enum RequestBody {
    case json(Any)
    case form([String: String])
    case raw(String)
    case data(Data)
    
    var contentType: String {
        switch self {
        case .json:
            return "application/json"
        case .form:
            return "application/x-www-form-urlencoded"
        case .raw, .data:
            return "text/plain"
        }
    }
    
    func bodyData() throws -> Data? {
        switch self {
        case .json(let jsonObject):
            return try JSONSerialization.data(withJSONObject: jsonObject, options: [])
            
        case .form(let parameters):
            var components = URLComponents()
            components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
            return components.query?.data(using: .utf8)
            
        case .raw(let string):
            return string.data(using: .utf8)
            
        case .data(let data):
            return data
        }
    }
}

// MARK: - SSE 配置
public struct SSEConfiguration {
    public var method: SseHTTPMethod
    public var body: RequestBody?
    public var headers: [String: String]
    public var queryParameters: [String: String]?
    public var autoReconnect: Bool
    public var maxReconnectAttempts: Int
    public var reconnectDelay: TimeInterval
    public var timeoutInterval: TimeInterval
    
    public init(
        method: SseHTTPMethod = .get,
        body: RequestBody? = nil,
        headers: [String: String] = [:],
        queryParameters: [String: String]? = nil,
        autoReconnect: Bool = true,
        maxReconnectAttempts: Int = 5,
        reconnectDelay: TimeInterval = 1.0,
        timeoutInterval: TimeInterval = TimeInterval(INT_MAX)
    ) {
        self.method = method
        self.body = body
        self.headers = headers
        self.queryParameters = queryParameters
        self.autoReconnect = autoReconnect
        self.maxReconnectAttempts = maxReconnectAttempts
        self.reconnectDelay = reconnectDelay
        self.timeoutInterval = timeoutInterval
    }
}

// MARK: - SSE 错误类型
public enum SSEError: Error {
    case invalidURL
    case invalidResponse
    case connectionFailed(String)
    case parsingError
    case disconnected
    case requestBodyError(Error)
}

// MARK: - 连接状态
public enum ConnectionState {
    case connecting
    case connected
    case disconnected
    case reconnecting
}

// MARK: - SSE 客户端主类
public class SSEClient: NSObject {
    
    // MARK: - 类型别名
    public typealias EventHandler = (SSEEvent) -> Void
    public typealias ErrorHandler = (Error) -> Void
    public typealias SendSuccessHandler = () -> Void
    public typealias SendFailureHandler = (Error) -> Void
    public typealias StateHandler = (ConnectionState) -> Void
    
    // MARK: - 属性
    private let baseURL: URL
    private var configuration: SSEConfiguration
    private var urlSession: URLSession?
    private var dataTask: URLSessionDataTask?
    private var buffer = ""
    private var currentEvent: [String: String] = [:]
    private var lastEventId: String?
    private var incompleteUTF8Buffer = Data() // 用于处理不完整的UTF-8字符
    
    // MARK: - 重连相关
    private var reconnectAttempts = 0
    private var reconnectTimer: Timer?
    
    // MARK: - 回调
    public var onEvent: EventHandler?
    public var onError: ErrorHandler?
    public var onStateChange: StateHandler?
    public var onSendSuccess: SendSuccessHandler?
    public var onSendFailure: SendFailureHandler?
    
    // MARK: - 状态
    public private(set) var isConnected = false
    public private(set) var connectionState: ConnectionState = .disconnected {
        didSet {
            DispatchQueue.main.async {
                self.onStateChange?(self.connectionState)
            }
        }
    }
    
    // MARK: - 初始化
    public init(url: URL, configuration: SSEConfiguration = SSEConfiguration()) {
        self.baseURL = url
        self.configuration = configuration
        super.init()
        setupSession()
    }
    
    public convenience init?(urlString: String, configuration: SSEConfiguration = SSEConfiguration()) {
        guard let url = URL(string: urlString) else { return nil }
        self.init(url: url, configuration: configuration)
    }
    
    deinit {
        disconnect()
    }
    
    // MARK: - 配置方法
    public func updateConfiguration(_ configuration: SSEConfiguration) {
        self.configuration = configuration
    }
    
    public func setHeaders(_ headers: [String: String]) {
        configuration.headers = headers
    }
    
    public func addHeader(key: String, value: String) {
        configuration.headers[key] = value
    }
    
    public func setRequestBody(_ body: RequestBody?) {
        configuration.body = body
    }
    
    // MARK: - 连接管理
    public func connect() throws {
        guard connectionState != .connecting && connectionState != .connected else {
            print("SSE: Already connecting or connected")
            return
        }
        
        // 如果 session 已经失效，重新创建
        if urlSession == nil {
            setupSession()
        }
        
        connectionState = .connecting
        reconnectAttempts = 0
        cancelReconnectTimer()
        
        // 构建完整 URL（包含查询参数）
        let url = buildURLWithQueryParameters()
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = configuration.method.rawValue
        request.timeoutInterval = configuration.timeoutInterval
        
        // 设置默认头部
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        
        // 添加上次事件ID（用于断线重连）
        if let lastEventId = lastEventId {
            request.setValue(lastEventId, forHTTPHeaderField: "Last-Event-ID")
        }
        
        // 设置请求体（如果是 POST/PUT 等）
        if let body = configuration.body {
            do {
                request.httpBody = try body.bodyData()
                request.setValue(body.contentType, forHTTPHeaderField: "Content-Type")
            } catch {
                throw SSEError.requestBodyError(error)
            }
        }
        
        // 添加自定义头部
        for (key, value) in configuration.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // ========== 详细的请求日志 ==========
        print("========== SSE 请求详情 ==========")
        print("URL: \(url.absoluteString)")
        print("方法: \(configuration.method.rawValue)")
        print("超时时间: \(configuration.timeoutInterval)s")
        
        // 打印所有请求头
        print("请求头:")
        if let allHeaders = request.allHTTPHeaderFields {
            for (key, value) in allHeaders {
                // 隐藏敏感信息
                if key.lowercased().contains("token") || key.lowercased().contains("authorization") {
                    print("  \(key): [已隐藏]")
                } else {
                    print("  \(key): \(value)")
                }
            }
        }
        
        // 打印请求体
        if let body = request.httpBody {
            if let bodyString = String(data: body, encoding: .utf8) {
                print("请求体: \(bodyString)")
            } else {
                print("请求体: [二进制数据，大小: \(body.count) bytes]")
            }
        } else {
            print("请求体: 无")
        }
        print("====================================")
        
        // 创建数据任务
        dataTask = urlSession?.dataTask(with: request)
        dataTask?.resume()
        
        print("SSE: Request sent successfully")
    }
    
    public func disconnect() {
        // 先保存状态，避免在回调中访问已释放的对象
        guard connectionState != .disconnected else {
            print("SSE: Already disconnected")
            return
        }
        
        print("SSE: Disconnecting...")
        
        // 立即更新状态，防止重复调用
        connectionState = .disconnected
        isConnected = false
        
        // 取消重连定时器
        cancelReconnectTimer()
        
        // 先取消任务
        dataTask?.cancel()
        dataTask = nil
        
        // 清理缓冲区
        buffer = ""
        currentEvent.removeAll()
        incompleteUTF8Buffer.removeAll()
        
        // 使用 invalidateAndCancel 而不是 finishTasksAndInvalidate
        // invalidateAndCancel 会立即取消所有任务并使 session 无效
        // 这样可以避免在 session 失效后还有回调被触发
        urlSession?.invalidateAndCancel()
        urlSession = nil
        
        print("SSE: Disconnected")
    }
    
    // MARK: - 私有方法
    private func setupSession() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = TimeInterval(INT_MAX)
        configuration.timeoutIntervalForResource = TimeInterval(INT_MAX)
        configuration.httpAdditionalHeaders = ["Accept": "text/event-stream"]
        
        urlSession = URLSession(configuration: configuration,
                               delegate: self,
                               delegateQueue: .main)
    }
    
    private func buildURLWithQueryParameters() -> URL {
        guard let queryParameters = configuration.queryParameters,
              !queryParameters.isEmpty,
              var urlComponents = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return baseURL
        }
        
        var queryItems = urlComponents.queryItems ?? []
        for (key, value) in queryParameters {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        urlComponents.queryItems = queryItems
        
        return urlComponents.url ?? baseURL
    }
    
    private func processBuffer() {
        // 安全地处理 buffer 分割
        while !buffer.isEmpty {
            // 找到第一个换行符
            if let newlineRange = buffer.range(of: "\n") {
                // 提取一行（不包括换行符）
                let line = String(buffer[buffer.startIndex..<newlineRange.lowerBound])
                
                // 安全地移除处理过的行（包括换行符）
                buffer.removeSubrange(buffer.startIndex..<newlineRange.upperBound)
                
                processLine(line)
            } else {
                // 没有找到换行符，保留剩余内容在 buffer 中
                break
            }
        }
    }
    
    private func processLine(_ line: String) {
        // 空行表示事件结束
        if line.isEmpty {
            dispatchEventIfReady()
            return
        }
        
        // 注释行，跳过
        if line.hasPrefix(":") { return }
        
        // 解析字段（格式：field: value）
        let colonIndex = line.firstIndex(of: ":")
        guard let colonIndex = colonIndex else { return }
        
        let field = String(line[line.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
        let valueStartIndex = line.index(after: colonIndex)
        var value = String(line[valueStartIndex..<line.endIndex]).trimmingCharacters(in: .whitespaces)
        
        // 如果value以空格开头，去掉第一个空格
        if value.hasPrefix(" ") {
            value = String(value.dropFirst())
        }
        
        switch field {
        case "event":
            currentEvent["event"] = value
        case "data":
            if let existingData = currentEvent["data"] {
                currentEvent["data"] = existingData + "\n" + value
            } else {
                currentEvent["data"] = value
            }
        case "id":
            currentEvent["id"] = value
            lastEventId = value
        case "retry":
            // 服务器可以建议重连时间
            if let retryInt = Int(value) {
                currentEvent["retry"] = value
                configuration.reconnectDelay = TimeInterval(retryInt) / 1000.0 // 转换为秒
            }
        default:
            // 忽略未知字段
            break
        }
    }
    
    private func dispatchEventIfReady() {
        guard let data = currentEvent["data"] else {
            currentEvent.removeAll()
            return
        }
        
        let retry: Int? = currentEvent["retry"].flatMap { Int($0) }
        let event = SSEEvent(
            id: currentEvent["id"],
            event: currentEvent["event"] ?? "message",
            data: data,
            retry: retry
        )
        
        // 回调事件
        DispatchQueue.main.async { [weak self] in
            self?.onEvent?(event)
        }
        
        // 重置当前事件
        currentEvent.removeAll()
    }
    
    private func handleError(_ error: Error) {
        // 调用发送失败回调
        DispatchQueue.main.async { [weak self] in
            self?.onSendFailure?(error)
            self?.onError?(error)
        }
        
        if configuration.autoReconnect && isConnected {
            scheduleReconnect()
        }
    }
    
    private func scheduleReconnect() {
        guard configuration.autoReconnect,
              reconnectAttempts < configuration.maxReconnectAttempts else {
            print("SSE: Max reconnection attempts reached or auto reconnect disabled")
            return
        }
        
        reconnectAttempts += 1
        connectionState = .reconnecting
        
        // 指数退避算法
        let delay = configuration.reconnectDelay * pow(2.0, Double(reconnectAttempts - 1))
        print("SSE: Reconnecting in \(delay) seconds (attempt \(reconnectAttempts)/\(configuration.maxReconnectAttempts))")
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self, self.connectionState == .reconnecting else { return }
            
            do {
                try self.connect()
            } catch {
                self.handleError(error)
            }
        }
    }
    
    private func cancelReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
}

// MARK: - URLSessionDataDelegate
extension SSEClient: URLSessionDataDelegate {
    
    public func urlSession(_ session: URLSession,
                         dataTask: URLSessionDataTask,
                         didReceive response: URLResponse,
                         completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        
        // 检查是否已经断开连接
        guard connectionState != .disconnected else {
            print("SSE: Ignoring response - already disconnected")
            completionHandler(.cancel)
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            handleError(SSEError.invalidResponse)
            return
        }
        
        print("========== SSE 响应详情 ==========")
        print("状态码: \(httpResponse.statusCode)")
        print("URL: \(httpResponse.url?.absoluteString ?? "未知")")
        
        // 打印响应头
        print("响应头:")
        for (key, value) in httpResponse.allHeaderFields {
            print("  \(key): \(value)")
        }
        print("====================================")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let error = SSEError.connectionFailed("HTTP \(httpResponse.statusCode)")
            print("SSE: HTTP 错误 - \(httpResponse.statusCode)")
            completionHandler(.cancel)
            
            // 调用发送失败回调
            DispatchQueue.main.async { [weak self] in
                self?.onSendFailure?(error)
            }
            
            handleError(error)
            return
        }
        
        // 检查Content-Type
        if let contentType = httpResponse.allHeaderFields["Content-Type"] as? String,
           !contentType.contains("text/event-stream") && !contentType.contains("text/event-stream;") {
            print("SSE: Warning - Content-Type is not text/event-stream: \(contentType)")
        }
        
        connectionState = .connected
        isConnected = true
        reconnectAttempts = 0
        
        print("SSE: Connected successfully")
        
        // 调用发送成功回调
        DispatchQueue.main.async { [weak self] in
            self?.onSendSuccess?()
        }
        
        completionHandler(.allow)
    }
    
    public func urlSession(_ session: URLSession,
                         dataTask: URLSessionDataTask,
                         didReceive data: Data) {
        // 检查是否已经断开连接
        guard connectionState != .disconnected else {
            print("SSE: Ignoring data - already disconnected")
            return
        }
        
        // 将新数据追加到不完整的UTF-8缓冲区
        incompleteUTF8Buffer.append(data)
        
        // 如果缓冲区为空，直接返回
        guard !incompleteUTF8Buffer.isEmpty else {
            return
        }
        
        // 尝试解码缓冲区中的数据
        var decodedString = ""
        var validDataLength = 0
        
        // 先尝试解码整个缓冲区（最常见的情况）
        if let fullString = String(data: incompleteUTF8Buffer, encoding: .utf8) {
            // 成功解码整个缓冲区
            decodedString = fullString
            validDataLength = incompleteUTF8Buffer.count
        } else {
            // 整个缓冲区无法解码，从后往前查找最后一个完整的UTF-8字符边界
            let bufferCount = incompleteUTF8Buffer.count
            
            // 从 count - 1 开始递减到 1（至少保留1个字节用于下次）
            if bufferCount > 1 {
                for length in stride(from: bufferCount - 1, through: 1, by: -1) {
                    let testData = incompleteUTF8Buffer.prefix(length)
                    if let testString = String(data: testData, encoding: .utf8) {
                        decodedString = testString
                        validDataLength = length
                        break
                    }
                }
            }
        }
        
        // 如果仍然无法解码任何数据，可能是数据太小或编码问题
        if decodedString.isEmpty && validDataLength == 0 {
            // 如果缓冲区很大但仍无法解码，可能是编码问题
            if incompleteUTF8Buffer.count > 1024 {
                print("SSE: Warning - Large buffer cannot be decoded as UTF-8, size: \(incompleteUTF8Buffer.count)")
                print("SSE: Buffer hex: \(incompleteUTF8Buffer.prefix(100).map { String(format: "%02X", $0) }.joined(separator: " "))")
                
                // 尝试使用 latin1 编码作为降级方案
                if let latinString = String(data: incompleteUTF8Buffer, encoding: .isoLatin1) {
                    print("SSE: Fallback to ISO-8859-1 encoding")
                    decodedString = latinString
                    validDataLength = incompleteUTF8Buffer.count
                } else {
                    print("SSE: Failed to decode data with any encoding")
                    // 清空缓冲区，避免无限累积
                    incompleteUTF8Buffer.removeAll()
                    handleError(SSEError.parsingError)
                    return
                }
            } else {
                // 缓冲区较小（<=1024字节），可能是多字节字符被分割，继续等待更多数据
                print("SSE: Waiting for more data, buffer size: \(incompleteUTF8Buffer.count)")
                return
            }
        }
        
        // 移除已解码的数据
        if validDataLength > 0 && validDataLength <= incompleteUTF8Buffer.count {
            incompleteUTF8Buffer.removeFirst(validDataLength)
        }
        
        // 将解码的字符串追加到处理缓冲区
        if !decodedString.isEmpty {
            buffer += decodedString
            processBuffer()
        }
    }
    
    public func urlSession(_ session: URLSession,
                         task: URLSessionTask,
                         didCompleteWithError error: Error?) {
        // 检查是否已经断开连接，避免重复处理
        guard connectionState != .disconnected else {
            print("SSE: Ignoring completion - already disconnected")
            return
        }
        
        connectionState = .disconnected
        isConnected = false
        
        if let error = error as NSError? {
            // 忽略取消错误
            if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                print("SSE: Connection cancelled")
                return
            }
            
            // 详细的错误日志
            print("SSE: Connection closed with error: \(error)")
            print("SSE: Error domain: \(error.domain), code: \(error.code)")
            
            // 网络错误的详细处理
            if error.domain == NSURLErrorDomain {
                switch error.code {
                case NSURLErrorNotConnectedToInternet:
                    print("SSE: No internet connection")
                case NSURLErrorTimedOut:
                    print("SSE: Request timed out")
                case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost:
                    print("SSE: Cannot connect to host")
                case NSURLErrorNetworkConnectionLost:
                    print("SSE: Network connection lost")
                case NSURLErrorSecureConnectionFailed:
                    print("SSE: Secure connection failed")
                case NSURLErrorServerCertificateUntrusted:
                    print("SSE: Server certificate untrusted")
                default:
                    print("SSE: Network error code: \(error.code)")
                }
            }
            
            handleError(error)
        } else {
            print("SSE: Connection closed normally")
            
            // 正常关闭时也调用状态变更回调
            DispatchQueue.main.async { [weak self] in
                self?.onStateChange?(.disconnected)
            }
        }
        
        // 只在异常断开时自动重连
        if error != nil && configuration.autoReconnect {
            scheduleReconnect()
        }
    }
}

// MARK: - 便捷扩展
public extension SSEClient {
    
    /// 快速连接方法（POST 请求示例）
    static func connect(
        to urlString: String,
        method: SseHTTPMethod = .post,
        parameters: [String: Any]? = nil,
        headers: [String: String] = [:],
        onEvent: @escaping EventHandler,
        onError: ErrorHandler? = nil
    ) -> SSEClient? {
        
        guard let url = URL(string: urlString) else {
            onError?(SSEError.invalidURL)
            return nil
        }
        
        // 配置请求
        var configuration = SSEConfiguration()
        configuration.method = method
        configuration.headers = headers
        
        // 如果有参数，设置为 JSON 请求体
        if let parameters = parameters {
            configuration.body = .json(parameters)
        }
        
        let client = SSEClient(url: url, configuration: configuration)
        client.onEvent = onEvent
        client.onError = onError ?? { error in
            print("SSE Error: \(error)")
        }
        
        do {
            try client.connect()
        } catch {
            onError?(error)
            return nil
        }
        
        return client
    }
    
    /// 设置 Bearer Token 认证
    func setBearerToken(_ token: String) {
        addHeader(key: "Authorization", value: "Bearer \(token)")
    }
    
    /// 设置基础认证
    func setBasicAuth(username: String, password: String) {
        let credentials = "\(username):\(password)"
        if let data = credentials.data(using: .utf8) {
            let base64 = data.base64EncodedString()
            addHeader(key: "Authorization", value: "Basic \(base64)")
        }
    }
}

// MARK: - 便捷构造器扩展
public extension SSEConfiguration {
    
    /// 创建带 JSON 请求体的配置
    static func jsonBody(_ json: [String: Any], headers: [String: String] = [:]) -> SSEConfiguration {
        var config = SSEConfiguration(method: .post, headers: headers)
        config.body = .json(json)
        return config
    }
    
    /// 创建带表单数据的配置
    static func formBody(_ parameters: [String: String], headers: [String: String] = [:]) -> SSEConfiguration {
        var config = SSEConfiguration(method: .post, headers: headers)
        config.body = .form(parameters)
        return config
    }
    
    /// 创建带查询参数的配置
    static func withQueryParameters(_ parameters: [String: String], headers: [String: String] = [:]) -> SSEConfiguration {
        var config = SSEConfiguration(headers: headers)
        config.queryParameters = parameters
        return config
    }
}
