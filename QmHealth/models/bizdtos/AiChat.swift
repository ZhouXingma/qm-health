//
//  AiChat.swift
//  QmHealth
//
//  Created by 周荥马 on 2026/2/10.
//

import Foundation

// MARK: - DynamicCodingKeys - 用于动态键名
struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
    }
    
    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = "\(intValue)"
    }
}

// MARK: - MessageContentBlock - 消息内容块枚举（使用类型擦除）
enum MessageContentBlock: Codable {
    case text(TextBlockMessage)
    case thinking(ThinkingBlockMessage)
    case interactiveHandle(InteractiveHandleBlockMessage)
    case system(SystemBlockMessage)
    case toolUse(ToolUseBlockMessage)
    case toolResult(ToolResultBlockMessage)
    case file(FileOfIdMessage)
    
    var type: String {
        switch self {
        case .text: return "text"
        case .thinking: return "thinking"
        case .interactiveHandle: return "interactiveHandle"
        case .system: return "system"
        case .toolUse: return "toolUse"
        case .toolResult: return "toolResult"
        case .file: return "file"
        }
    }
    
    /// 判断两个 MessageContentBlock 是否内容相等
    /// 用于优化更新机制,仅在内容真正变化时触发视图更新
    func isEqual(to other: MessageContentBlock) -> Bool {
        switch (self, other) {
        case (.text(let a), .text(let b)):
            return a.text == b.text
        case (.thinking(let a), .thinking(let b)):
            return a.thinking == b.thinking
        case (.interactiveHandle(let a), .interactiveHandle(let b)):
            return a.messageId == b.messageId && 
                   a.toolCallId == b.toolCallId && 
                   a.messageType == b.messageType
        case (.system(let a), .system(let b)):
            return a.system == b.system
        case (.toolUse(let a), .toolUse(let b)):
            return a.id == b.id && 
                   a.name == b.name && 
                   a.content == b.content && 
                   a.result == b.result
        case (.toolResult(let a), .toolResult(let b)):
            return a.id == b.id && a.name == b.name
        case (.file(let a), .file(let b)):
            return a.fileId == b.fileId && a.fileName == b.fileName && a.fileType == b.fileType
        default:
            return false
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        
        // 获取 type 字段
        guard let typeKey = DynamicCodingKeys(stringValue: "type") else {
            throw DecodingError.dataCorruptedError(forKey: DynamicCodingKeys(stringValue: "type")!, in: container, debugDescription: "Missing type field")
        }
        
        let type = try container.decode(String.self, forKey: typeKey)
        
        switch type {
        case "text":
            self = .text(try TextBlockMessage(from: decoder))
        case "thinking":
            self = .thinking(try ThinkingBlockMessage(from: decoder))
        case "interactiveHandle":
            self = .interactiveHandle(try InteractiveHandleBlockMessage(from: decoder))
        case "system":
            self = .system(try SystemBlockMessage(from: decoder))
        case "toolUse":
            self = .toolUse(try ToolUseBlockMessage(from: decoder))
        case "toolResult":
            self = .toolResult(try ToolResultBlockMessage(from: decoder))
        case "file":
            self = .file(try FileOfIdMessage(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: typeKey, in: container, debugDescription: "Unknown message type: \(type)")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let msg):
            try msg.encode(to: encoder)
        case .thinking(let msg):
            try msg.encode(to: encoder)
        case .interactiveHandle(let msg):
            try msg.encode(to: encoder)
        case .system(let msg):
            try msg.encode(to: encoder)
        case .toolUse(let msg):
            try msg.encode(to: encoder)
        case .toolResult(let msg):
            try msg.encode(to: encoder)
        case .file(let msg):
            try msg.encode(to: encoder)
        }
    }
}

// MARK: - 1. TextBlockMessage - 普通文本
struct TextBlockMessage: Codable {
    let type: String = "text"
    let text: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case text
    }
    
    init(text: String) {
        self.text = text
    }
}

// MARK: - 2. ThinkingBlockMessage - 思考内容
struct ThinkingBlockMessage: Codable {
    let type: String = "thinking"
    let thinking: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case thinking
    }
    
    init(thinking: String) {
        self.thinking = thinking
    }
}

// MARK: - 3. InteractiveHandleBlockMessage - 交互消息处理结果
struct InteractiveHandleBlockMessage: Codable {
    let type: String = "interactiveHandle"
    let messageId: String
    let name: String?
    let toolCallId: String
    let messageType: String
    let value: AnyCodable
    
    enum CodingKeys: String, CodingKey {
        case type
        case messageId
        case name
        case toolCallId
        case messageType
        case value
    }
    
    init(messageId: String, name: String? = nil, toolCallId: String, messageType: String, value: AnyCodable) {
        self.messageId = messageId
        self.name = name
        self.toolCallId = toolCallId
        self.messageType = messageType
        self.value = value
    }
}

// MARK: - 4. SystemBlockMessage - 系统消息
struct SystemBlockMessage: Codable {
    let type: String = "system"
    let system: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case system
    }
    
    init(system: String) {
        self.system = system
    }
}

// MARK: - 5. ToolUseBlockMessage - 工具调用消息
struct ToolUseBlockMessage: Codable {
    let type: String = "toolUse"
    let id: String
    let name: String  // 调用方法名称
    let input: AnyCodable  // 调用参数，任意对象
    let content: String?  // 调用过程中的内容（流式更新）
    let result: String?  // 调用结果
    let metadata: [String: AnyCodable]?
    
    enum CodingKeys: String, CodingKey {
        case type
        case id
        case name
        case input
        case content
        case result
        case metadata
    }
    
    init(id: String, name: String, input: AnyCodable, content: String? = nil, result: String? = nil, metadata: [String: AnyCodable]? = nil) {
        self.id = id
        self.name = name
        self.input = input
        self.content = content
        self.result = result
        self.metadata = metadata
    }
}

// MARK: - 6. ToolResultBlockMessage - 工具调用结果消息
struct ToolResultBlockMessage: Codable {
    let type: String = "toolResult"
    let id: String
    let name: String  // 调用方法名称
    let result: AnyCodable  // 工具调用结果
    let metadata: [String: AnyCodable]?
    
    enum CodingKeys: String, CodingKey {
        case type
        case id
        case name
        case result
        case metadata
    }
    
    init(id: String, name: String, result: AnyCodable, metadata: [String: AnyCodable]? = nil) {
        self.id = id
        self.name = name
        self.result = result
        self.metadata = metadata
    }
}

// MARK: - ChatFileType - 文件类型枚举
enum ChatFileType: String, Codable {
    case image = "image"
    case pdf = "pdf"
    case doc = "doc"
    case md = "md"
    case other = "other"
}

// MARK: - ChatFileInfo - 发送文件时携带的信息
struct ChatFileInfo {
    let fileId: String
    let fileName: String?
    let fileType: ChatFileType
}

// MARK: - 7. FileOfIdMessage - 文件id的消息
struct FileOfIdMessage: Codable {
    let type: String = "file"
    let fileId: String
    let fileName: String?
    let fileType: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case fileId
        case fileName
        case fileType
    }
    
    init(fileId: String, fileName: String?, fileType: ChatFileType) {
        self.fileId = fileId
        self.fileName = fileName
        self.fileType = fileType.rawValue
    }
}

// MARK: - ChatRequest - 聊天请求
struct ChatRequest: Codable {
    let conversationId: String?
    let messageId: String?
    let contents: [MessageContentBlock]
    let metadata: [String: AnyCodable]?
    
    enum CodingKeys: String, CodingKey {
        case conversationId
        case messageId
        case contents
        case metadata
    }
    
    init(conversationId: String? = nil, messageId: String? = nil, contents: [MessageContentBlock], metadata: [String: AnyCodable]? = nil) {
        self.conversationId = conversationId
        self.messageId = messageId
        self.contents = contents
        self.metadata = metadata
    }
}

// MARK: - ChatResumeRequest - 恢复会话请求
/// 点击历史会话进入时调用 /ai/chat/completions/v1，body 只携带 conversationId。
/// startSeq 默认 0（从最新位置开始续读），后端契约中可不传，故请求体里不包含该字段。
/// 返回的流与正常聊天一致（可能为空流 / 仅 RUN_FINISHED 的已完成流，此时无需渲染）。
struct ChatResumeRequest: Codable {
    let conversationId: String
}

// MARK: - AnyCodable - 用于处理任意类型的数据
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let int64Value as Int64:
            try container.encode(int64Value)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        // 具体类型优先匹配，避免被 [Any]/[String: Any] 吞掉
        case let anyCodableDict as [String: AnyCodable]:
            try container.encode(anyCodableDict)
        case let anyCodableArray as [AnyCodable]:
            try container.encode(anyCodableArray)
        case let stringArray as [String]:
            try container.encode(stringArray)
        case let intArray as [Int]:
            try container.encode(intArray)
        case let doubleArray as [Double]:
            try container.encode(doubleArray)
        case let arrayValue as [Any]:
            let encodableArray = arrayValue.map { AnyCodable($0) }
            try container.encode(encodableArray)
        case let dictValue as [String: Any]:
            let encodableDict = dictValue.mapValues { AnyCodable($0) }
            try container.encode(encodableDict)
        case is NSNull:
            try container.encodeNil()
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported type: \(type(of: value))"))
        }
    }
    
    var stringValue: String? {
        return value as? String
    }
    
    var intValue: Int? {
        return value as? Int
    }
    
    var doubleValue: Double? {
        return value as? Double
    }
    
    var int64Value: Int64? {
        return value as? Int64
    }
    
    var arrayValue: [Any]? {
        return value as? [Any]
    }
    
    var dictValue: [String: Any]? {
        return value as? [String: Any]
    }
}

// MARK: - ChatMessage - AI 聊天响应（对应 Java ChatMessage）
class ChatMessage: NSObject, Codable, ObservableObject {
    /// 会话id
    var conversationId: String
    /// 单次会话id
    var runId: String
    /// 消息id
    var messageId: String
    /// 角色（assistant、user 等）
    var role: String
    /// 用途（chat、interactive、generateTitle、ocrImage 等）
    var purpose: String
    /// 时间戳
    var timestamp: Int64
    /// 模型
    var model: String?
    /// 一条消息可能包含多个块
    @Published var contents: [MessageContentBlock]
    /// 扩展字段
    var metadata: [String: AnyCodable]?
    
    init(
        conversationId: String,
        runId: String,
        messageId: String,
        role: String,
        purpose: String,
        timestamp: Int64,
        model: String? = nil,
        contents: [MessageContentBlock] = [],
        metadata: [String: AnyCodable]? = nil
    ) {
        self.conversationId = conversationId
        self.runId = runId
        self.messageId = messageId
        self.role = role
        self.purpose = purpose
        self.timestamp = timestamp
        self.model = model
        self.contents = contents
        self.metadata = metadata
        super.init()
    }
    
    enum CodingKeys: String, CodingKey {
        case conversationId
        case runId
        case messageId
        case role
        case purpose
        case timestamp
        case model
        case contents
        case metadata
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        conversationId = try container.decode(String.self, forKey: .conversationId)
        runId = try container.decode(String.self, forKey: .runId)
        messageId = try container.decode(String.self, forKey: .messageId) 
        role = try container.decode(String.self, forKey: .role)
        purpose = try container.decode(String.self, forKey: .purpose)
        timestamp = try container.decode(Int64.self, forKey: .timestamp)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        contents = try container.decode([MessageContentBlock].self, forKey: .contents)
        metadata = try container.decodeIfPresent([String: AnyCodable].self, forKey: .metadata)
        super.init()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(conversationId, forKey: .conversationId)
        try container.encodeIfPresent(runId, forKey: .runId)
        try container.encodeIfPresent(messageId, forKey: .messageId)
        try container.encode(role, forKey: .role)
        try container.encode(purpose, forKey: .purpose)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(model, forKey: .model)
        try container.encode(contents, forKey: .contents)
        try container.encodeIfPresent(metadata, forKey: .metadata)
    }
}

extension ChatMessage {
    /// 是否是权限确认（机制 A：Permission ASK）的回执消息。
    /// 用户点击授权条"允许/拒绝"后，服务端会在历史记录中插入一条
    /// role=user、metadata 携带 agentscope_confirm_results 的消息
    /// （通常 contents 是"用户已确认工具调用"这种占位文本），
    /// 这只是内部流程记录，不属于真实对话内容，历史详情加载时应过滤掉。
    var isConfirmResultMessage: Bool {
        return metadata?["agentscope_confirm_results"] != nil
    }
}

class ContentObject: Decodable {
    var type: String
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    init(type: String) {
        self.type = type
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
    }
}

// MARK: - MessageStatus - 消息状态
enum MessageStatus {
    case sending
    case success
    case failed
    case response
}

// MARK: - MessagePurpose - 消息用途
enum MessagePurpose {
    case chat
    case interactive
    case generateTitle
    case response
    
    func code() -> String {
        switch(self) {
        case .chat:
            return "chat"
        case .interactive:
            return "interactive"
        case .generateTitle:
            return "generateTitle"
        case .response:
            return "response"
        }
    }
}

// MARK: - MessageRole - 消息角色
enum MessageRole {
    case user
    case assistant
    case system
    case tool
    
    func code() -> String {
        switch(self) {
        case .user:
            return "user"
        case .assistant:
            return "assistant"
        case .system:
            return "system"
        case .tool:
            return "tool"
        }
    }
}

/// 将字符串角色转换为 MessageRole 枚举
func getMessageRole(_ role: String) -> MessageRole {
    switch role {
    case "user":
        return .user
    case "assistant":
        return .assistant
    case "system":
        return .system
    case "tool":
        return .tool
    default:
        return .system
    }
}

/// 将字符串用途转换为 MessagePurpose 枚举
func getMessagePurpose(_ purpose: String) -> MessagePurpose {
    switch purpose {
    case "chat":
        return .chat
    case "interactive":
        return .interactive
    case "generateTitle":
        return .generateTitle
    case "response":
        return .response
    default:
        return .chat
    }
}

// MARK: - MessageDisplayState - 消息的 UI 显示状态
/// 统一管理消息的所有 UI 状态
enum MessageDisplayState: Equatable {
    /// 成功状态
    case success
    /// 发送中
    case sending
    /// 处理中（等待 AI 响应）
    case processing
    /// 响应中（接收流式响应）
    case responding
    /// 失败状态，包含错误信息
    case failed(error: String)
    
    /// 是否处于加载状态（发送、处理、响应中）
    var isLoading: Bool {
        switch self {
        case .sending, .processing, .responding:
            return true
        default:
            return false
        }
    }
    
    /// 是否处于错误状态
    var isFailed: Bool {
        if case .failed = self {
            return true
        }
        return false
    }
    
    /// 获取错误信息
    var errorMessage: String? {
        if case .failed(let error) = self {
            return error
        }
        return nil
    }
    
    /// 实现 Equatable 协议
    static func == (lhs: MessageDisplayState, rhs: MessageDisplayState) -> Bool {
        switch (lhs, rhs) {
        case (.success, .success):
            return true
        case (.sending, .sending):
            return true
        case (.processing, .processing):
            return true
        case (.responding, .responding):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}

// MARK: - DisplayChatMessage - 用于 UI 显示的消息
/// 包含 ChatMessage 的所有字段，加上 UI 状态
/// 可以从 ChatMessage 转换而来
class DisplayChatMessage: NSObject, ObservableObject, Identifiable {
    var id: String { messageId }
    /// 会话id
    var conversationId: String?
    /// 单次会话id
    var runId: String?
    /// 消息id
    var messageId: String
    /// 角色（assistant、user 等）
    var role: MessageRole
    /// 用途（chat、interactive、generateTitle、ocrImage 等）
    var purpose: MessagePurpose
    /// 时间戳
    var timestamp: Int64
    /// 模型
    var model: String?
    /// 一条消息可能包含多个块
    @Published var contents: [MessageContentBlock]
    /// 扩展字段
    var metadata: [String: AnyCodable]?
    
    /// UI 显示状态
    @Published var displayState: MessageDisplayState = .success
    
    /// 消息是否被选中（用于多选操作）
    @Published var isSelected: Bool = false
    
    /// 内容版本号,用于快速判断是否有实际变化
    private var contentsVersion: Int = 0
    
    init(
        conversationId: String?,
        runId: String?,
        messageId: String,
        role: MessageRole,
        purpose: MessagePurpose,
        timestamp: Int64,
        model: String? = nil,
        contents: [MessageContentBlock] = [],
        metadata: [String: AnyCodable]? = nil,
        displayState: MessageDisplayState = .success
    ) {
        self.conversationId = conversationId
        self.runId = runId
        self.messageId = messageId
        self.role = role
        self.purpose = purpose
        self.timestamp = timestamp
        self.model = model
        self.contents = contents
        self.metadata = metadata
        self.displayState = displayState
        super.init()
    }
    
    /// 从 ChatMessage 转换
    convenience init(from chatMessage: ChatMessage, displayState: MessageDisplayState = .success) {
        self.init(
            conversationId: chatMessage.conversationId,
            runId: chatMessage.runId,
            messageId: chatMessage.messageId,
            role: getMessageRole(chatMessage.role),
            purpose: getMessagePurpose(chatMessage.purpose),
            timestamp: chatMessage.timestamp,
            model: chatMessage.model,
            contents: chatMessage.contents,
            metadata: chatMessage.metadata,
            displayState: displayState
        )
    }
    
    /// 获取消息的文本内容（如果存在）
    var textContent: String? {
        for content in contents {
            if case .text(let textBlock) = content {
                return textBlock.text
            }
        }
        return nil
    }
    
    /// 获取消息的所有文本内容（合并多个文本块）
    var allTextContent: String {
        var result = ""
        for content in contents {
            if case .text(let textBlock) = content {
                if !result.isEmpty {
                    result += "\n"
                }
                result += textBlock.text
            }
        }
        return result
    }
    
    /// 检查消息是否是用户消息
    var isUserMessage: Bool {
        return role == .user
    }
    
    /// 检查消息是否是助手消息
    var isAssistantMessage: Bool {
        return role == .assistant
    }
    
    /// 检查消息是否是系统消息
    var isSystemMessage: Bool {
        return role == .system
    }
    
    /// 检查消息是否是工具消息
    var isToolMessage: Bool {
        return role == .tool
    }

    /// 是否被用户中断：服务端在消息 metadata 中写入 interruptedByUser = true
    var isInterrupted: Bool {
        guard let value = metadata?["interruptedByUser"]?.value as? Bool else { return false }
        return value
    }

    /// 模型/运行异常信息（metadata.runError），无则为 nil
    var runErrorReason: String? {
        guard let str = metadata?["runError"]?.value as? String else { return nil }
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 节点崩溃、由 HA 补偿终止的原因（metadata.runAborted），无则为 nil
    var runAbortReason: String? {
        guard let str = metadata?["runAborted"]?.value as? String else { return nil }
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    

    /// 标记为发送中
    func markAsSending() {
        displayState = .sending
    }
    
    /// 标记为处理中
    func markAsProcessing() {
        displayState = .processing
    }
    
    /// 标记为响应中
    func markAsResponding() {
        displayState = .responding
    }
    
    /// 标记为成功
    func markAsSuccess() {
        displayState = .success
    }
    
    /// 标记为失败
    func markAsFailed(error: String? = nil) {
        displayState = .failed(error: error ?? "Unknown error")
    }
    
    /// 重置 UI 状态
    func resetUIState() {
        displayState = .success
        isSelected = false
    }
    
    /// 优化的内容更新方法
    /// 只有内容真正变化时才更新,避免无效的观察者通知
    func updateContents(_ newContents: [MessageContentBlock]) {
        // 快速路径:如果数组长度不同,肯定有变化
        if self.contents.count != newContents.count {
            self.contents = newContents
            self.contentsVersion += 1
            return
        }
        
        // 逐个比较内容块是否相等
        var hasChanged = false
        for (index, newContent) in newContents.enumerated() {
            if !self.contents[index].isEqual(to: newContent) {
                hasChanged = true
                break
            }
        }
        
        // 只有内容真正变化时才更新
        if hasChanged {
            self.contents = newContents
            self.contentsVersion += 1
        }
    }
}
