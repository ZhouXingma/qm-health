//
//  AIPlanGeneratorView.swift
//  QmHealth
//
//  Created by AI Assistant on 2026/6/8.
//

import SwiftUI
import WebKit

/// 内容类型
enum ContentType {
    case html       // HTML内容
    case markdown   // Markdown内容
    case code       // 代码内容
    case unknown    // 未知类型
}

/// AI制定健康计划页面
/// 包括进度显示、HTML结果渲染、采纳/重新生成功能
struct AIPlanGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - 计划参数
    /// 开始身高（cm）
    let startHeight: String
    /// 开始体重（kg）
    let startWeight: String
    /// 目标体重（kg）
    let targetWeight: String
    /// 计划周期（周数）
    let planDuration: Int16
    /// 减肥方案类型
    let planType: HealthCurvePlanType
    /// 日常活动水平
    let activityLevel: String
    /// 采纳报告回调 - 用于将生成的AI报告传回给父视图
    var onAdoptPlan: ((AIGeneratedReport) -> Void)? = nil
    
    // 状态管理
    @State private var generationState: GenerationState = .idle
    @State private var progressSteps: [ProgressStep] = []
    @State private var currentStepIndex: Int = 0
    @State private var generatedContent: String? = nil
    @State private var contentType: ContentType = .unknown
    @State private var showRegenerateInput: Bool = false
    @State private var regeneratePrompt: String = ""
    @State private var errorMessage: String? = nil
    @State private var sseClient: SSEClient? = nil
    @State private var conversationId: String? = nil
    // 当前流的事件累积器（新版事件协议：RUN_STARTED/THINKING/TOOL_CALL/TEXT/RUN_FINISHED...）
    // 负责把流式事件合并为一条消息，runId 可用于中断请求
    @State private var streamAccumulator: ChatStreamAccumulator? = nil
    // 当前处理的messageId（用于区分不同消息）
    @State private var currentMessageId: String? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                Color("background")
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if generationState == .generating {
                        // 生成中 - 显示进度
                        progressView
                    } else if generationState == .completed {
                        // 完成 - 显示HTML结果和操作按钮
                        resultView
                    } else if generationState == .error {
                        // 错误状态
                        errorView
                    }
                }
            }
            .navigationTitle("AI制定健康计划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        stopClient()
                        dismiss()
                    }
                    .foregroundStyle(Color("text_secondary"))
                }
            }
            .onAppear {
                startGeneration()
            }
            .onDisappear {
                stopClient()
            }
        }
    }
    

    
    // MARK: - 清理内容
    private func cleanContent(_ content: String, type: ContentType) -> String {
        var cleaned = content
        
        // 如果是HTML类型，需要去除可能的markdown代码块标记
        if type == .html {
            // 去除开头的 ```html 或 ```HTML
            let htmlCodeBlockPattern = "^```html\\s*\\n"
            if let range = cleaned.range(of: htmlCodeBlockPattern, options: [.regularExpression, .caseInsensitive]) {
                cleaned.removeSubrange(range)
            }
            
            // 去除结尾的 ```
            let endCodeBlockPattern = "\\n```\\s*$"
            if let range = cleaned.range(of: endCodeBlockPattern, options: .regularExpression) {
                cleaned.removeSubrange(range)
            }
        }
        
        return cleaned
    }
    
    // MARK: - 检测内容类型
    private func detectContentType(_ content: String) -> ContentType {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        
        // 检测markdown代码块中的HTML
        let htmlCodeBlockPattern = "^```html\\s*\\n"
        if lowercased.range(of: htmlCodeBlockPattern, options: .regularExpression) != nil {
            return .html
        }
        
        // 检测HTML - 使用正则表达式
        // 1. 检测 DOCTYPE
        let doctypePattern = "^\\s*<!doctype\\s+html"
        if lowercased.range(of: doctypePattern, options: .regularExpression) != nil {
            return .html
        }
        
        // 2. 检测 <html 标签（可能有属性）
        let htmlTagPattern = "^\\s*<html[\\s>]"
        if lowercased.range(of: htmlTagPattern, options: .regularExpression) != nil {
            return .html
        }
        
        // 3. 检测常见的HTML结构标签
        let structureTagsPattern = "<(head|body|title|meta|style|script)[\\s>]"
        if lowercased.range(of: structureTagsPattern, options: .regularExpression) != nil {
            return .html
        }
        
        // 4. 检测HTML标签密度（如果有多个HTML标签，很可能是HTML）
        let htmlTagCountPattern = "<[a-z][a-z0-9]*[\\s>]"
        let matches = lowercased.ranges(of: htmlTagCountPattern, options: .regularExpression)
        if matches.count >= 3 {
            return .html
        }
        
        // 5. 检测代码块
        if trimmed.hasPrefix("```") {
            return .code
        }
        
        // 默认为Markdown
        return .markdown
    }
    
    // MARK: - 进度视图
    /// 显示AI制定计划的进度，包括动画和步骤列表
    /// 新增了流动的渐变进度条，让用户感知到系统正在工作
    private var progressView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 标题
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.theme(.primary))
                    Text("AI正在制定您的专属健康计划")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color("text_primary"))
                }
                .padding(.top, 24)
                
                // 进度动画 - 流动的渐变条，让用户知道系统没有卡住
                LoadingProgressBar()
                    .padding(.horizontal, 40)
                    .padding(.top, 12)
                
                // 进度步骤列表
                VStack(spacing: 12) {
                    ForEach(Array(progressSteps.enumerated()), id: \.offset) { index, step in
                        ProgressStepRow(
                            step: step,
                            isActive: index == currentStepIndex,
                            isCompleted: index < currentStepIndex
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                
                // 生成中的报告占位卡片
                if contentType == .html || (generatedContent?.count ?? 0) > 1000 {
                    GeneratingReportCard(contentLength: generatedContent?.count ?? 0, contentType: contentType)
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                }
            }
        }
    }
    
    // MARK: - 结果视图
    /// 显示AI生成的健康计划内容
    /// WebView内部已启用滚动，用户可以直接在WebView内滚动查看完整HTML内容
    private var resultView: some View {
        VStack(spacing: 0) {
            // 内容显示 - WebView 内部已启用滚动
            if let content = generatedContent {
                // 检测内容类型并清理内容
                let type = contentType == .unknown ? detectContentType(content) : contentType
                let cleanedContent = cleanContent(content, type: type)
                
                if type == .html {
                    // HTML 内容用 WebView 渲染
                    // WebView 已启用内部滚动，用户可以在 WebView 内滚动查看完整内容
                    WebView(htmlContent: cleanedContent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                } else {
                    // Markdown 或代码用 MarkdownText 渲染，需要外层 ScrollView
                    ScrollView {
                        MarkdownText(cleanedContent, fontSize: 15)
                            .padding(16)
                    }
                }
            } else {
                // 无内容时显示提示
                Text("暂无内容")
                    .foregroundStyle(Color("text_secondary"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // 底部操作按钮 - 重新设计
            VStack(spacing: 0) {
                Divider()
                    .background(Color("divider").opacity(0.3))
                
                HStack(spacing: 12) {
                    // 重新生成按钮 - 次按钮（玻璃透明）
                    Button {
                        showRegenerateInput = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 15, weight: .semibold))
                            Text("重新生成")
                        }
                    }
                    .buttonStyle(SecondaryActionButtonStyle())

                    // 采纳计划按钮 - 主按钮（主题色玻璃）
                    Button {
                        adoptPlan()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15, weight: .semibold))
                            Text("采纳计划")
                        }
                    }
                    .buttonStyle(PrimaryActionButtonStyle(tint: AppColor.primary))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(Color("background"))
        }
        .sheet(isPresented: $showRegenerateInput) {
            RegenerateInputSheet(
                prompt: $regeneratePrompt,
                isPresented: $showRegenerateInput,
                onConfirm: {
                    regeneratePlan(withPrompt: regeneratePrompt)
                }
            )
        }
    }
    
    // MARK: - 错误视图
    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color("error"))
            
            Text("生成失败")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color("text_primary"))
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundStyle(Color("text_secondary"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button {
                startGeneration()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("重试")
                }
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .padding(.top, 12)
            .frame(maxWidth: 220)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 业务逻辑
    
    /// 停止SSE客户端
    /// 若当前 run 仍在生成中，调用 /ai/chat/interrupt 通知服务端中断当前 run，
    /// 避免离开页面后服务端继续执行造成资源浪费
    /// （/ai/chat/completions/v1 断开连接不会自动中断会话，必须显式调用中断接口）。
    private func stopClient() {
        // 捕获当前 run 信息，用于中断请求
        let runId = streamAccumulator?.message?.runId
        let cid = conversationId

        streamAccumulator = nil

        // 仅当确实有进行中的 run 时才发送中断请求
        if generationState == .generating, let runId = runId, let cid = cid {
            BgResultNetWork<ChatInterruptRequest, Data>(
                aiUrl(AI_CHAT_INTERRUPT),
                method: .post,
                params: ChatInterruptRequest(conversationId: cid, runId: runId)
            ).response()
        }

        guard let client = sseClient else {
            return
        }
        sseClient = nil
        client.disconnect()
    }
    
    /// 开始生成计划
    private func startGeneration() {
        stopClient() // 先停止之前的连接并中断进行中的 run

        generationState = .generating
        errorMessage = nil
        progressSteps = []
        currentStepIndex = 0
        generatedContent = nil
        contentType = .unknown
        currentMessageId = nil

        // 构建请求内容
        let prompt = buildPrompt()
        let requestContent = MessageContentBlock.text(TextBlockMessage(text: prompt))

        startStreamRequest(conversationId: conversationId, contents: [requestContent])
    }

    /// 发起一次 AI 生成请求（新版流式事件协议）
    /// 通过 ChatStreamAccumulator 把 RUN_STARTED ~ RUN_FINISHED/RUN_ERROR 之间的
    /// 事件（THINKING/TOOL_CALL/TEXT 等）合并处理，从累积出的消息中提取
    /// 文本内容（HTML/Markdown）与进度步骤。
    private func startStreamRequest(conversationId: String?, contents: [MessageContentBlock]) {
        let chatRequest = ChatRequest(
            conversationId: conversationId,
            messageId: ULIDUtils.generate(),
            contents: contents,
            metadata: nil
        )

        // 新版事件累积器
        let accumulator = ChatStreamAccumulator(conversationIdProvider: { self.conversationId })
        streamAccumulator = accumulator

        accumulator.onMessageCreated = { newMessage in
            // 更新会话ID
            if let cid = newMessage.conversationId, !cid.isEmpty {
                self.conversationId = cid
            }
            // 记录消息ID（runId），用于采纳报告时追溯
            self.currentMessageId = newMessage.messageId
        }
        accumulator.onMessageUpdated = { updatedMessage in
            self.handleAccumulatedMessage(updatedMessage)
        }
        accumulator.onRunFinished = { _ in
            if self.generationState == .generating {
                if let content = self.generatedContent, !content.isEmpty {
                    self.generationState = .completed
                }
            }
        }
        accumulator.onRunError = { _, errMsg in
            self.generationState = .error
            self.errorMessage = errMsg
        }

        // 调用AI API（原始文本回调，解析为新版流式事件协议）
        sseClient = SseApi.postResponse(
            aiUrl(AI_CHAT_COMPLETIONS),
            param: chatRequest,
            headers: [HEAD_TOKEN: TokenUtils.getToken()]
        ) { rawData in
            guard let streamEvent = try? JSONFormatUtil.defaultInstall.decodeFromString(rawData, as: ChatStreamEvent.self) else {
                print("⚠️ 无法解析流式事件：\(rawData)")
                return
            }
            accumulator.apply(streamEvent)
        } errorHandle: { error in
            self.handleError(error)
        } stateChangeHandle: { state in
            if state == .disconnected {
                // 连接已关闭，清理引用，避免后续 stopClient 对已关闭的连接重复 disconnect
                self.sseClient = nil
                if self.generationState == .generating {
                    if let content = self.generatedContent, !content.isEmpty {
                        self.generationState = .completed
                    }
                }
            }
        } sendSuccessHanle: {
            // AI请求发送成功
        } sendFailureHandler: { error in
            self.handleError(error)
        }
    }
    
    /// 构建提示词
    private func buildPrompt() -> String {
        return """
        生成健康曲线方案：【身高】：\(startHeight)cm, 【体重】：\(startWeight)kg，【日常活动水平】：\(activityLevel), 【目标体重】：\(targetWeight)kg, 【计划周期】：\(planDuration)周, 【减肥方案】：\(planType.title)
        """
    }
    
    /// 处理累积后的AI响应消息
    /// 从累积器的消息中提取文本内容（HTML/Markdown）和进度步骤
    private func handleAccumulatedMessage(_ message: DisplayChatMessage) {
        // 合并所有文本块作为生成的内容（HTML 或 Markdown）
        let textContent = message.allTextContent
        if !textContent.isEmpty {
            generatedContent = textContent
            updateContentType(textContent)
        }

        // 处理进度步骤（progress_step / __fragment__ 工具调用）
        for content in message.contents {
            if case .toolUse(let toolUse) = content {
                handleProgressStep(toolUse)
            }
        }
    }

    /// 更新内容类型
    private func updateContentType(_ content: String) {
        // 已经识别为HTML模式则不再改变
        if contentType == .html {
            return
        }

        // 先检测是否是HTML内容的开始
        let isHTMLContent = content.contains("<!DOCTYPE") ||
                           content.contains("<html") ||
                           content.contains("<head>") ||
                           content.contains("<body>") ||
                           content.contains("```html")

        if isHTMLContent {
            contentType = .html
        } else if contentType == .unknown && content.count >= 200 {
            // 长文本内容（可能是markdown或其他），检测具体类型
            contentType = detectContentType(content)
        }
    }
    
    /// 处理进度步骤
    /// 新版协议下工具调用通过 TOOL_CALL_START/DELTA/END 事件流式传输，
    /// 内容已由累积器累加到 toolUse.content 中，这里直接解析即可
    private func handleProgressStep(_ toolUse: ToolUseBlockMessage) {
        // 只处理进度步骤相关的工具调用
        guard toolUse.name == "progress_step" || toolUse.name == "__fragment__" else {
            return
        }

        // 尝试解析累积的内容
        tryParseProgressStep(toolUse.content ?? "")
    }

    /// 尝试解析进度步骤
    private func tryParseProgressStep(_ jsonStr: String) {
        guard !jsonStr.isEmpty else {
            return
        }

        // 尝试解析JSON
        do {
            if let data = jsonStr.data(using: .utf8),
               let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {

                if let stepName = json["stepName"] as? String,
                   let description = json["description"] as? String {

                    // 检查是否已存在相同的步骤
                    if !progressSteps.contains(where: { $0.title == stepName }) {
                        let step = ProgressStep(title: stepName, description: description)
                        progressSteps.append(step)
                        currentStepIndex = progressSteps.count - 1
                    }
                }
            }
        } catch {
            // 解析失败是正常的，因为可能还在累积中
        }
    }
    
    /// 处理错误
    private func handleError(_ error: Error) {
        generationState = .error
        
        if let sseError = error as? SSEError {
            switch sseError {
            case .invalidURL:
                errorMessage = "无效的请求地址"
            case .invalidResponse:
                errorMessage = "服务器响应无效"
            case .connectionFailed(let reason):
                errorMessage = "连接失败：\(reason)"
            case .parsingError:
                errorMessage = "数据解析错误"
            case .disconnected:
                errorMessage = "连接已断开"
            case .requestBodyError(let err):
                errorMessage = "请求数据错误：\(err.localizedDescription)"
            }
        } else {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain {
                switch nsError.code {
                case NSURLErrorNotConnectedToInternet:
                    errorMessage = "网络未连接，请检查网络设置"
                case NSURLErrorTimedOut:
                    errorMessage = "请求超时，请稍后重试"
                case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost:
                    errorMessage = "无法连接到服务器"
                case NSURLErrorNetworkConnectionLost:
                    errorMessage = "网络连接已断开"
                default:
                    errorMessage = "网络错误：\(error.localizedDescription)"
                }
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    /// 采纳计划 - 将生成的AI报告通过回调传回给父视图
    /// - 构造AIGeneratedReport对象包含HTML内容和对话ID
    /// - 通过onAdoptPlan回调将报告传递回父视图
    /// - 关闭当前Sheet视图
    private func adoptPlan() {
        // 确保有生成的内容
        guard let content = generatedContent, !content.isEmpty else {
            return
        }
        
        // 构造AI生成的报告对象，包含HTML内容、会话ID和消息ID
        let report = AIGeneratedReport(
            htmlContent: content,
            conversationId: conversationId ?? "",
            messageId: currentMessageId ?? ULIDUtils.generate()
        )
        
        // 通过回调将报告传回给父视图，用于显示在HealthCurveManagePlanFormView中
        onAdoptPlan?(report)
        
        // 停止SSE客户端连接
        stopClient()
        // 关闭当前视图
        dismiss()
    }
    
    /// 重新生成计划
    private func regeneratePlan(withPrompt prompt: String) {
        // 保存当前的conversationId，用于继续对话
        let savedConversationId = conversationId
        // 捕获前一个 run 的 id，用于先中断再发起新请求
        let previousRunId = streamAccumulator?.message?.runId

        // 在原有提示基础上增加用户反馈
        let basePrompt = buildPrompt()
        let fullPrompt = "\(basePrompt)\n\n用户反馈：\(prompt)"

        // 停止当前连接（此时 generationState 为 .completed，stopClient 不会重复发送中断）
        stopClient()

        // 重置状态但保持conversationId
        generationState = .generating
        errorMessage = nil
        progressSteps = []
        currentStepIndex = 0
        generatedContent = nil
        contentType = .unknown
        currentMessageId = nil
        conversationId = savedConversationId // 保持conversationId

        // 构建请求内容
        let requestContent = MessageContentBlock.text(TextBlockMessage(text: fullPrompt))

        // 关键：先中断前一个 run，等中断请求完成（无论成功失败）后再发起新请求。
        // 若前一个 run 遗留了未完成的工具调用（pending tool call），直接发起新 run
        // 会被服务端拒绝（"Pending tool calls exist without results"），必须先用
        // /ai/chat/interrupt 结束旧 run，清理其挂起的工具调用状态。
        if let runId = previousRunId, let cid = conversationId {
            BgResultNetWork<ChatInterruptRequest, Data>(
                aiUrl(AI_CHAT_INTERRUPT),
                method: .post,
                params: ChatInterruptRequest(conversationId: cid, runId: runId)
            )
            .finalHandleFunc { _ in
                self.startStreamRequest(conversationId: self.conversationId, contents: [requestContent])
            }
            .response()
        } else {
            startStreamRequest(conversationId: conversationId, contents: [requestContent])
        }
    }
}

// MARK: - 支持视图

/// 加载进度条 - 流动的渐变动画
/// 在"AI正在制定您的专属健康计划"下方显示，让用户感知到系统正在处理
struct LoadingProgressBar: View {
    /// 流动条完成一次循环的周期（秒）
    private let period: Double = 1.5
    /// 流动条相对父容器宽度的占比
    private let barWidthRatio: CGFloat = 0.4

    var body: some View {
        // 使用 TimelineView + Canvas 实现流动效果：
        // view 自身的 frame 恒定（高度固定 6，宽度撑满父容器），
        // 动画完全在 Canvas 内部重绘完成，不修改任何 view frame，
        // 从而避免触发外层 ScrollView 反复重布局导致的"一直往上滚"问题。
        TimelineView(.animation) { context in
            LoadingProgressCanvas(date: context.date, period: period, barWidthRatio: barWidthRatio)
        }
        .frame(height: 6)
        .frame(maxWidth: .infinity)
    }
}

/// 流动条 Canvas 子视图：把 Canvas 从 TimelineView 闭包里抽出来，
/// 避免 SwiftUI @ViewBuilder 闭包对 `let` 语句+ Canvas 嵌套的泛型推断问题。
private struct LoadingProgressCanvas: View {
    let date: Date
    let period: Double
    let barWidthRatio: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let h = size.height
            let radius = h / 2
            let t = date.timeIntervalSinceReferenceDate
            let phase = CGFloat((t.truncatingRemainder(dividingBy: period)) / period)

            // 1. 背景条
            let bgPath = Path(
                roundedRect: CGRect(x: 0, y: 0, width: size.width, height: h),
                cornerRadius: radius
            )
            ctx.fill(
                bgPath,
                with: .color(Color.theme(.primary).opacity(0.12))
            )

            // 2. 流动条：固定 frame，通过 phase 计算 x 位置
            let barWidth = size.width * barWidthRatio
            let travel = size.width - barWidth
            let x = travel * phase
            let barPath = Path(
                roundedRect: CGRect(x: x, y: 0, width: barWidth, height: h),
                cornerRadius: radius
            )
            let gradient = Gradient(stops: [
                .init(color: Color.theme(.primary).opacity(0.3), location: 0.0),
                .init(color: Color.theme(.primary), location: 0.5),
                .init(color: Color.theme(.primary).opacity(0.3), location: 1.0)
            ])
            ctx.fill(
                barPath,
                with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: x, y: 0),
                    endPoint: CGPoint(x: x + barWidth, y: 0)
                )
            )
        }
    }
}

/// 生成中的报告卡片 - 忽隐忽现效果
struct GeneratingReportCard: View {
    let contentLength: Int
    let contentType: ContentType
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 16) {
            // 左侧图标 - 忽隐忽现动画
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.theme(.primary).opacity(0.15),
                                Color.theme(.primary).opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Image(systemName: "doc.richtext.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.theme(.primary),
                                Color.theme(.primary).opacity(0.7)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .opacity(isAnimating ? 0.4 : 1.0)
            .animation(
                Animation.easeInOut(duration: 1.2)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
            
            // 右侧信息
            VStack(alignment: .leading, spacing: 6) {
                Text("健康计划报告")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))
                
                HStack(spacing: 4) {
                    Text(contentTypeLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color("text_secondary"))
                    
                    Text("·")
                        .font(.system(size: 13))
                        .foregroundStyle(Color("text_secondary").opacity(0.5))
                    
                    // 动态显示生成的字符数
                    Text(contentLengthLabel)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.theme(.primary))
                        .animation(.easeInOut(duration: 0.3), value: contentLength)
                }
            }
            
            Spacer()
            
            // 右侧加载动画
            ProgressView()
                .scaleEffect(0.9)
                .tint(Color.theme(.primary))
        }
        .glassCardStyle()
        .onAppear {
            isAnimating = true
        }
    }
    
    private var contentTypeLabel: String {
        switch contentType {
        case .html:
            return "HTML"
        case .markdown:
            return "Markdown"
        case .code:
            return "代码"
        case .unknown:
            return "文档"
        }
    }
    
    private var contentLengthLabel: String {
        if contentLength == 0 {
            return "生成中..."
        } else if contentLength < 1000 {
            return "\(contentLength) 字符"
        } else {
            let kb = Double(contentLength) / 1000.0
            return String(format: "%.1f KB", kb)
        }
    }
}

/// 进度步骤行
struct ProgressStepRow: View {
    let step: ProgressStep
    let isActive: Bool
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // 状态图标
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(statusColor)
                } else if isActive {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(statusColor)
                } else {
                    Circle()
                        .fill(statusColor.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            
            // 步骤信息
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.system(size: 15, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(Color("text_primary"))
                
                Text(step.description)
                    .font(.system(size: 13))
                    .foregroundStyle(Color("text_secondary"))
            }
            
            Spacer()
        }
        .padding(12)
        .glassContainer(
            isActive
                ? Glass.regular.interactive().tint(Color.theme(.primary).opacity(0.08))
                : .regular.interactive(),
            cornerRadius: 12
        )
    }
    
    private var statusColor: Color {
        if isCompleted {
            return Color.theme(.primary)
        } else if isActive {
            return Color.theme(.primary)
        } else {
            return Color("text_secondary").opacity(0.3)
        }
    }
}

/// 重新生成输入弹窗
struct RegenerateInputSheet: View {
    @Binding var prompt: String
    @Binding var isPresented: Bool
    let onConfirm: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("告诉AI您的想法")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color("text_primary"))
                    
                    Text("例如：我希望增加更多的力量训练，减少有氧运动")
                        .font(.system(size: 13))
                        .foregroundStyle(Color("text_secondary"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                
                // 输入框
                TextEditor(text: $prompt)
                    .frame(height: 120)
                    .inputFieldStyle()
                    .padding(.horizontal, 16)
                
                Spacer()
            }
            .padding(.top, 20)
            .background(Color("background"))
            .navigationTitle("重新生成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isPresented = false
                    }
                    .foregroundStyle(Color("text_secondary"))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确定") {
                        isPresented = false
                        onConfirm()
                    }
                    .foregroundStyle(Color.theme(.primary))
                    .fontWeight(.semibold)
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

/// WebView - 用于显示HTML内容
/// 支持内容自适应高度，避免额外的空白区域
struct WebView: UIViewRepresentable {
    /// HTML 内容字符串，用于渲染
    let htmlContent: String
    
    /// 创建 WKWebView 实例
    /// - 设置透明背景，实现与 SwiftUI 界面的无缝集成
    /// - 启用内部滚动，让 WebView 可以滚动显示长HTML内容
    /// - 返回配置完毕的 WKWebView 对象
    func makeUIView(context: Context) -> WKWebView {
        // 创建 WKWebView 配置，禁用自动媒体播放
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        
        // 初始化 WKWebView
        let webView = WKWebView(frame: .zero, configuration: configuration)
        // 设置透明背景，使内容与页面背景融合
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        // 启用内部滚动，允许 WebView 滚动显示长内容
        webView.scrollView.isScrollEnabled = true
        // 启用弹跳效果，提供原生iOS滚动体验
        webView.scrollView.bounces = true
        return webView
    }
    
    /// 更新 WKWebView 内容
    /// 当 htmlContent 属性更新时，将新的HTML内容加载到WebView中
    /// - 自动包装纯HTML为完整文档结构
    /// - 添加响应式视口配置
    func updateUIView(_ webView: WKWebView, context: Context) {
        // 为HTML内容添加自适应高度的包装
        let wrappedHTML = wrapHTMLWithAutoHeight(htmlContent)
        webView.loadHTMLString(wrappedHTML, baseURL: nil)
    }
    
    /// 将HTML内容包装为完整文档，支持自适应高度
    /// - 检测是否已包含 html 标签，避免重复包装
    /// - 添加视口元标签确保响应式布局
    /// - 添加CSS样式使内容充满可用宽度
    /// - 返回包装后的完整HTML文档
    private func wrapHTMLWithAutoHeight(_ html: String) -> String {
        // 检查是否已包含 HTML 结构标签
        if html.contains("<html") || html.contains("<HTML") {
            // 已包含完整 HTML 结构，直接返回
            return html
        }
        
        // 为纯 HTML 片段添加完整文档包装
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    line-height: 1.6;
                    color: #333;
                    background-color: transparent;
                }
                img {
                    max-width: 100%;
                    height: auto;
                }
                table {
                    width: 100%;
                    border-collapse: collapse;
                }
                td, th {
                    padding: 8px;
                    text-align: left;
                    border-bottom: 1px solid #ddd;
                }
            </style>
        </head>
        <body>
            \(html)
        </body>
        </html>
        """
    }
}

// MARK: - 数据模型

/// 生成状态
enum GenerationState {
    case idle           // 初始状态
    case generating     // 生成中
    case completed      // 完成
    case error          // 错误
}

/// 进度步骤
struct ProgressStep {
    let title: String
    let description: String
}

// MARK: - 预览
#Preview {
    AIPlanGeneratorView(
        startHeight: "165",
        startWeight: "65",
        targetWeight: "55",
        planDuration: 8,
        planType: .moderate,
        activityLevel: "轻体力"
    )
}

// MARK: - String扩展

extension String {
    /// 查找所有匹配的范围
    func ranges(of pattern: String, options: String.CompareOptions = []) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var searchRange = self.startIndex..<self.endIndex
        
        while let range = self.range(of: pattern, options: options, range: searchRange) {
            ranges.append(range)
            searchRange = range.upperBound..<self.endIndex
        }
        
        return ranges
    }
}

// MARK: - Color扩展

extension Color {
    /// 从十六进制字符串创建颜色
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
