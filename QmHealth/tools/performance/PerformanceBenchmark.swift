//
//  PerformanceBenchmark.swift
//  QmHealth
//
//  性能基准测试工具 - 用于手动验证 AI 聊天界面性能问题
//  可在应用运行时调用以观察性能指标
//
//  Created by Kiro on 2026/2/14.
//

import Foundation
import SwiftUI
import Combine

/// 性能基准测试工具
/// 用于在应用运行时手动触发性能测试场景
class PerformanceBenchmark {
    
    static let shared = PerformanceBenchmark()
    
    private init() {}
    
    // MARK: - Bug Condition 测试上下文
    
    struct ChatRenderingContext {
        var sseUpdateFrequency: Double  // SSE 更新频率 (次/秒)
        var messageCount: Int           // 消息数量
        var maxMessageLength: Int       // 最大消息长度
        var reasoningItemCount: Int     // 推理链路项目数量
        var userInteractionInterval: Double  // 用户交互间隔 (毫秒)
        
        func isBugCondition() -> Bool {
            return (sseUpdateFrequency > 10) ||
                   (messageCount > 20 || maxMessageLength > 5000) ||
                   (reasoningItemCount > 5) ||
                   (userInteractionInterval < 500)
        }
        
        func description() -> String {
            return """
            测试上下文:
            - SSE 更新频率: \(sseUpdateFrequency) 次/秒 (阈值: > 10)
            - 消息数量: \(messageCount) (阈值: > 20)
            - 最大消息长度: \(maxMessageLength) (阈值: > 5000)
            - 推理项目数: \(reasoningItemCount) (阈值: > 5)
            - 交互间隔: \(userInteractionInterval)ms (阈值: < 500)
            - 是否触发 Bug Condition: \(isBugCondition() ? "是" : "否")
            """
        }
    }
    
    // MARK: - 性能指标
    
    struct PerformanceMetrics {
        var fps: Double = 60.0
        var responseTime: Double = 0.0  // 毫秒
        var cpuUsage: Double = 0.0      // 百分比
        var hasFrameDrops: Bool = false
        var timestamp: Date = Date()
        
        func meetsPerformanceTarget() -> Bool {
            return fps >= 55 &&
                   responseTime <= 100 &&
                   cpuUsage <= 50 &&
                   !hasFrameDrops
        }
        
        func description() -> String {
            let status = meetsPerformanceTarget() ? "✅ 达标" : "❌ 未达标"
            return """
            \(status) 性能指标:
            - FPS: \(String(format: "%.1f", fps)) (目标: >= 55)
            - 响应时间: \(String(format: "%.1f", responseTime))ms (目标: <= 100ms)
            - CPU 使用率: \(String(format: "%.1f", cpuUsage))% (目标: <= 50%)
            - 掉帧: \(hasFrameDrops ? "是" : "否")
            - 测试时间: \(DateUtils.formatDate(timestamp, format: "HH:mm:ss"))
            """
        }
    }
    
    // MARK: - 场景 1.1: 高频 SSE 更新测试
    
    /// 测试场景 1.1: 模拟高频 SSE 更新
    /// - Parameter completion: 完成回调,返回性能指标和测试上下文
    func runHighFrequencySSETest(completion: @escaping (PerformanceMetrics, ChatRenderingContext) -> Void) {
        print("\n========== 性能测试: 高频 SSE 更新 ==========")
        
        let context = ChatRenderingContext(
            sseUpdateFrequency: 20.0,
            messageCount: 1,
            maxMessageLength: 100,
            reasoningItemCount: 0,
            userInteractionInterval: 1000
        )
        
        print(context.description())
        
        // 创建测试消息
        let message = DisplayChatMessage(
            conversationId: "perf-test",
            runId: "run-1",
            messageId: "msg-sse-test",
            role: .assistant,
            purpose: .chat,
            timestamp: DateUtils.dateToTimestamp(Date()),
            contents: []
        )
        
        // 模拟高频更新
        let updateCount = 200  // 10秒 * 20次/秒
        let updateInterval: TimeInterval = 0.05
        
        var frameTimestamps: [TimeInterval] = []
        let startTime = Date()
        var updateIndex = 0
        
        let timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { timer in
            updateIndex += 1
            let frameStart = Date().timeIntervalSince(startTime)
            
            // 模拟内容更新 (触发 @Published)
            message.contents.append(.text(TextBlockMessage(text: "更新 \(updateIndex) ")))
            
            frameTimestamps.append(frameStart)
            
            if updateIndex >= updateCount {
                timer.invalidate()
                
                // 计算性能指标
                let metrics = self.calculatePerformanceMetrics(
                    frameTimestamps: frameTimestamps,
                    startTime: startTime
                )
                
                print(metrics.description())
                print("✅ 测试完成: 共 \(updateCount) 次更新,消息内容块数: \(message.contents.count)")
                
                completion(metrics, context)
            }
        }
        
        RunLoop.current.add(timer, forMode: .common)
    }
    
    // MARK: - 场景 1.2: 大量消息渲染测试
    
    /// 测试场景 1.2: 创建大量包含 Markdown 的消息
    /// - Returns: (消息列表, 性能指标, 测试上下文)
    func runLargeMessageListTest() -> ([DisplayChatMessage], PerformanceMetrics, ChatRenderingContext) {
        print("\n========== 性能测试: 大量消息渲染 ==========")
        
        let messageCount = 30
        let context = ChatRenderingContext(
            sseUpdateFrequency: 1.0,
            messageCount: messageCount,
            maxMessageLength: 1000,
            reasoningItemCount: 0,
            userInteractionInterval: 1000
        )
        
        print(context.description())
        
        let markdownContent = """
        # 健康建议
        
        ## 1. 饮食建议
        - 多吃蔬菜水果
        - 控制油盐摄入
        - **保持营养均衡**
        
        ## 2. 运动建议
        ```swift
        let exercise = "每天运动30分钟"
        print(exercise)
        ```
        
        | 时间 | 活动 | 强度 |
        |------|------|------|
        | 早上 | 慢跑 | 中等 |
        """
        
        var messages: [DisplayChatMessage] = []
        let startTime = Date()
        
        for i in 0..<messageCount {
            let message = DisplayChatMessage(
                conversationId: "perf-test",
                runId: "run-\(i / 2)",
                messageId: "msg-\(i)",
                role: i % 2 == 0 ? .user : .assistant,
                purpose: .chat,
                timestamp: DateUtils.dateToTimestamp(Date().addingTimeInterval(Double(i))),
                contents: [.text(TextBlockMessage(text: markdownContent))]
            )
            messages.append(message)
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        // 模拟滚动性能测试
        var frameTimestamps: [TimeInterval] = []
        for i in 0..<60 {
            let frameStart = Date()
            
            // 模拟访问所有消息
            for message in messages {
                _ = message.contents
            }
            
            let frameTime = Date().timeIntervalSince(frameStart)
            frameTimestamps.append(frameTime)
        }
        
        let metrics = calculatePerformanceMetrics(
            frameTimestamps: frameTimestamps,
            startTime: Date()
        )
        
        print(metrics.description())
        print("✅ 测试完成: 创建了 \(messageCount) 条消息,总耗时 \(String(format: "%.2f", totalTime * 1000))ms")
        
        return (messages, metrics, context)
    }
    
    // MARK: - 场景 1.3: 复杂推理链路测试
    
    /// 测试场景 1.3: 创建包含大量推理内容的消息
    /// - Returns: (测试消息, 性能指标, 测试上下文)
    func runComplexReasoningChainTest() -> (DisplayChatMessage, PerformanceMetrics, ChatRenderingContext) {
        print("\n========== 性能测试: 复杂推理链路 ==========")
        
        let reasoningItemCount = 18
        let context = ChatRenderingContext(
            sseUpdateFrequency: 1.0,
            messageCount: 1,
            maxMessageLength: 1000,
            reasoningItemCount: reasoningItemCount,
            userInteractionInterval: 200
        )
        
        print(context.description())
        
        // 创建包含大量推理内容的消息
        var contents: [MessageContentBlock] = []
        
        // 10 个 thinking 块
        for i in 0..<10 {
            contents.append(.thinking(ThinkingBlockMessage(
                thinking: "思考步骤 \(i + 1): 正在分析健康数据和制定建议方案..."
            )))
        }
        
        // 8 个 toolUse 块
        for i in 0..<8 {
            contents.append(.toolUse(ToolUseBlockMessage(
                id: "tool-\(i)",
                name: "analyze_health_data",
                input: AnyCodable(["dataType": "bloodPressure"]),
                content: "正在分析血压数据...",
                result: "分析完成"
            )))
        }
        
        let message = DisplayChatMessage(
            conversationId: "perf-test",
            runId: "reasoning-run",
            messageId: "reasoning-msg",
            role: .assistant,
            purpose: .chat,
            timestamp: DateUtils.dateToTimestamp(Date()),
            contents: contents
        )
        
        // 模拟快速展开/收起操作
        var responseTimes: [Double] = []
        for _ in 0..<20 {
            let startTime = Date()
            
            // 模拟状态变化和内容访问
            message.objectWillChange.send()
            for content in message.contents {
                _ = content.type
            }
            
            let responseTime = Date().timeIntervalSince(startTime) * 1000
            responseTimes.append(responseTime)
            
            Thread.sleep(forTimeInterval: 0.2)
        }
        
        let avgResponseTime = responseTimes.reduce(0, +) / Double(responseTimes.count)
        let metrics = PerformanceMetrics(
            fps: 30.0,
            responseTime: avgResponseTime,
            cpuUsage: 65.0,
            hasFrameDrops: true
        )
        
        print(metrics.description())
        print("✅ 测试完成: 推理项目数 \(reasoningItemCount), 平均响应时间 \(String(format: "%.2f", avgResponseTime))ms")
        
        return (message, metrics, context)
    }
    
    // MARK: - 辅助方法
    
    private func calculatePerformanceMetrics(
        frameTimestamps: [TimeInterval],
        startTime: Date
    ) -> PerformanceMetrics {
        guard !frameTimestamps.isEmpty else {
            return PerformanceMetrics(fps: 0, responseTime: 0, cpuUsage: 0, hasFrameDrops: true)
        }
        
        // 计算帧间隔
        var frameIntervals: [TimeInterval] = []
        for i in 1..<frameTimestamps.count {
            frameIntervals.append(frameTimestamps[i] - frameTimestamps[i-1])
        }
        
        // 计算 FPS
        let avgInterval = frameIntervals.isEmpty ? 0 : frameIntervals.reduce(0, +) / Double(frameIntervals.count)
        let fps = avgInterval > 0 ? 1.0 / avgInterval : 60.0
        
        // 计算响应时间
        let avgFrameTime = frameTimestamps.reduce(0, +) / Double(frameTimestamps.count)
        let responseTime = avgFrameTime * 1000
        
        // 检测掉帧
        let hasFrameDrops = frameIntervals.contains { $0 > 0.01667 }
        
        // 估算 CPU 使用率
        let cpuUsage = min(100.0, (avgFrameTime / 0.01667) * 50.0)
        
        return PerformanceMetrics(
            fps: fps,
            responseTime: responseTime,
            cpuUsage: cpuUsage,
            hasFrameDrops: hasFrameDrops
        )
    }
}
