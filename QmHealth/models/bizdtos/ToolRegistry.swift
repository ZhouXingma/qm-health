//
//  ToolRegistry.swift
//  QmHealth
//
//  Created by 周荥马 on 2026/2/10.
//

import Foundation

// MARK: - ToolRegistry - 工具注册表，用于管理特殊工具的处理
/// 这是一个扩展框架，允许为不同的工具添加特殊处理逻辑
/// 当需要支持新的工具时，只需在这里添加相应的处理器即可
class ToolRegistry {
    static let shared = ToolRegistry()
    
    private var toolHandlers: [String: ToolHandler] = [:]
    
    private init() {
        registerDefaultTools()
    }
    
    /// 注册默认的工具处理器
    private func registerDefaultTools() {
        // 注册 ask_user 工具处理器
        register(AskUserToolHandler())
        
        // 可以在这里添加其他工具处理器
        // register(SomeOtherToolHandler())
    }
    
    /// 注册工具处理器
    func register(_ handler: ToolHandler) {
        toolHandlers[handler.toolName] = handler
    }
    
    /// 获取工具处理器
    func getHandler(for toolName: String) -> ToolHandler? {
        return toolHandlers[toolName]
    }
    
    /// 检查是否有特殊处理器
    func hasSpecialHandler(for toolName: String) -> Bool {
        return toolHandlers[toolName] != nil
    }
    
    /// 获取所有已注册的工具名称
    func registeredToolNames() -> [String] {
        return Array(toolHandlers.keys)
    }
}

// MARK: - ToolHandler - 工具处理器协议
/// 所有特殊工具处理器都应该遵循这个协议
protocol ToolHandler {
    /// 工具名称
    var toolName: String { get }
    
    /// 工具描述
    var description: String { get }
    
    /// 验证工具输入是否有效
    func validateInput(_ input: AnyCodable) -> Bool
    
    /// 解析工具输入
    func parseInput(_ input: AnyCodable) -> Any?
}

// MARK: - AskUserToolHandler - ask_user 工具处理器
struct AskUserToolHandler: ToolHandler {
    let toolName: String = "ask_user"
    let description: String = "向用户发起追问，支持多种交互形式（文本、选择、日期时间等）"
    
    func validateInput(_ input: AnyCodable) -> Bool {
        // 检查是否包含必需的 question 字段
        if let dictValue = input.dictValue,
           let question = dictValue["question"] as? String,
           !question.isEmpty {
            return true
        }
        return false
    }
    
    func parseInput(_ input: AnyCodable) -> Any? {
        do {
            if let dictValue = input.dictValue {
                let jsonData = try JSONSerialization.data(withJSONObject: dictValue)
                let decoder = JSONDecoder()
                return try decoder.decode(AskUserToolInput.self, from: jsonData)
            }
            return nil
        } catch {
            print("Failed to parse ask_user input: \(error)")
            return nil
        }
    }
}

// MARK: - 示例：如何添加新的工具处理器
/*
 
 // 1. 创建新的工具数据模型（例如 SomeToolInput.swift）
 struct SomeToolInput: Codable {
     let param1: String
     let param2: Int?
     // ... 其他字段
 }
 
 // 2. 创建工具处理器
 struct SomeToolHandler: ToolHandler {
     let toolName: String = "some_tool"
     let description: String = "Some tool description"
     
     func validateInput(_ input: AnyCodable) -> Bool {
         if let dictValue = input.dictValue,
            let param1 = dictValue["param1"] as? String,
            !param1.isEmpty {
             return true
         }
         return false
     }
     
     func parseInput(_ input: AnyCodable) -> Any? {
         do {
             if let dictValue = input.dictValue {
                 let jsonData = try JSONSerialization.data(withJSONObject: dictValue)
                 let decoder = JSONDecoder()
                 return try decoder.decode(SomeToolInput.self, from: jsonData)
             }
             return nil
         } catch {
             print("Failed to parse some_tool input: \(error)")
             return nil
         }
     }
 }
 
 // 3. 在 ToolRegistry 中注册
 private func registerDefaultTools() {
     register(AskUserToolHandler())
     register(SomeToolHandler())  // 添加新的处理器
 }
 
 // 4. 创建对应的 UI 组件（例如 AISomeToolMessageView.swift）
 struct AISomeToolMessageView: View {
     let toolUse: ToolUseBlockMessage
     // ... UI 实现
 }
 
 // 5. 在 AIMessageView 中添加处理
 case .toolUse(let toolUseBlock):
     if toolUseBlock.isAskUserTool {
         AIAskUserMessageView(toolUse: toolUseBlock)
     } else if toolUseBlock.name == "some_tool" {
         AISomeToolMessageView(toolUse: toolUseBlock)
     } else {
         AIToolUseMessageView(toolUse: toolUseBlock)
     }
 
 */
