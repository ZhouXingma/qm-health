//
//  AiChatMain.swift
//  QmHealth
//
//  Created by 周荥马 on 2026/2/4.
//

import SwiftUI
import PhotosUI
import Combine

struct AiChatMain: View {
    @EnvironmentObject var globalModel: GlobalModel
    @Binding var selection:Int
    @State private var messages: [DisplayChatMessage] = []
    @State private var conversationId: String? = nil;
    @State private var isAIResponding: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showErrorAlert: Bool = false
    @State private var isLoadingHistory: Bool = false
    
    // UI 控制
    @State private var showPersonSelector = false
    @State private var showHistorySidebar = false
    @State private var showAISettings = false
    // 每次打开聊天历史 Sheet 时重新生成，用于强制 SwiftUI 重建 ChatHistorySheet
    // （及其内部持有数据的 ViewModel），避免连续打开/关闭复用旧实例导致列表数据滞留
    @State private var historySheetId = UUID()

    // 滚动控制相关
    @State private var shouldAutoScroll: Bool = true
    @State private var showScrollToBottomButton: Bool = false
    // 滚动协调器。注意这里用 @State 而不是 @StateObject：本视图只负责"发出滚动请求"，
    // 真正响应请求的是 ChatAutoScroller 这个极小的子视图。这样流式增量触发滚动时
    // 不会让 AiChatMain 的 body 重新求值（否则每个 delta 都要重算消息分组、重建
    // 所有气泡，既卡顿又让文字成块蹦出）。
    @State private var scrollCoordinator = ChatScrollCoordinator()
    @State private var scrollProxy: ScrollViewProxy? = nil


    @State private var bottomY: CGFloat = 0
    @State private var sseClient:SSEClient? = nil
    @State private var scrollResetKey = UUID()

    // 当前流式响应的事件累积器（新版事件协议：RUN_STARTED/THINKING/TOOL_CALL/TEXT/RUN_FINISHED...）
    @State private var streamAccumulator: ChatStreamAccumulator? = nil

    // 机制 A（Permission ASK）：等待用户授权的工具调用列表，独立于消息流，
    // 展示在输入框上方的授权条中
    @State private var pendingConfirmations: [PendingToolConfirmation] = []
    @State private var isSubmittingConfirmation: Bool = false

    // 当前这次请求（一个 run）是否已经产生过任何可见内容（思考/工具调用/文本）。
    // 用于驱动"正在生成回复"指示器：从用户点击发送的那一刻起为 false，
    // 直到 RUN_STARTED 后的第一个内容事件到达才变 true。
    // 与 isAIResponding 解耦，不依赖 messages 数组的最后一条消息状态，
    // 避免"消息已已创建但内容仍为空"这段真空期没有任何加载提示。
    @State private var currentRunHasContent: Bool = false
    @State private var suggestionPageIndex: Int = 0

    // 输入栏（含其上方的授权条）的实时高度。
    // 用 iOS 18+ 的 .onGeometryChange 在输入主体 VStack 上直接读取自己的 size.height，
    // 写到 @State 后给外层 ScrollView 用作消息列表底部 padding。
    // 末尾再 +30（inputBarBottomGap）作为最后一条消息离输入栏的呼吸距离。
    // 早期用 PreferenceKey + GeometryReader 实现过，但兄弟节点 ZStack 里
    // preference 容易收到 0（表现为 padding 不生效），换成 onGeometryChange 更稳。
    @State private var inputBarHeight: CGFloat = 0
    private static let inputBarBottomGap: CGFloat = 30

    private struct HealthQuestionExample: Identifiable {
        let title: String
        let question: String
        let icon: String

        var id: String { question }
    }

    var body: some View {
        ZStack {
            // 背景
            Color("background")
                .ignoresSafeArea()
           
            VStack(spacing: 0) {
                // 顶部导航栏
                ChatHeaderView(showPersonSelector: $showPersonSelector, showHistorySidebar: $showHistorySidebar, currentSelect: $selection)
                    .environmentObject(globalModel)
                
                ZStack {
                    // 消息列表
                    VStack {
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(spacing: 12) {
                                    // 顶部空白
                                    Color.clear.frame(height: 20)
                                    
                                    if messages.isEmpty {
                                        emptyStateView
                                    } else {
                                        // 将消息按 runId 分组显示
                                        let groupedMessages = groupMessagesByRun(messages)
                                        
                                        ForEach(groupedMessages, id: \.id) { group in
                                            MessageGroupView(
                                                group: group,
                                                onAskUserResponse: { interactiveHandle in
                                                    handleAskUserResponse(interactiveHandle)
                                                }
                                            )
                                            .id(group.id)
                                        }
                                    }
                                    if isAIResponding && !currentRunHasContent {
                                        // "正在生成回复"指示：从发送成功到第一个可见内容（思考/工具调用/文本）
                                        // 到达之前的这段等待期都会显示，避免响应较慢时看起来像卡住了
                                        GeneratingIndicatorRow()
                                            .transition(.opacity)
                                            .animation(.easeInOut(duration: 0.2), value: currentRunHasContent)
                                    }
                                    
                                    Color.clear.frame(height: inputBarHeight + AiChatMain.inputBarBottomGap)
                                    
                                    // 底部锚点 - 仅在此处计算滚动位置
                                    Color.clear
                                        .frame(height: 1)
                                        .id("bottom")
                                        .background(
                                            GeometryReader { geometry in
                                                Color.clear
                                                    .preference(
                                                        key: AiChatMainScrollViewBottomKey.self,
                                                        value: geometry.frame(in: .named("scroll")).maxY
                                                    )
                                            }
                                        )

                                }
                                .padding(.horizontal, 16)

                            }
                            .id(scrollResetKey)
                            .coordinateSpace(name: "scroll")
                            .simultaneousGesture(
                                TapGesture(count: 1)
                                    .onEnded { _ in KeyBoardUtils.toHideKeyboard()}
                            )
                            .onChange(of: messages.count) { _, _ in
                                // 新消息时滚动
                                if shouldAutoScroll {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        scrollToBottom(proxy: proxy)
                                    }
                                }
                            }
                            // 视口贴近底部时（用户手动滚回 / 程序滚动落到底部），
                            // 主动收回按钮、恢复自动跟随。否则会出现
                            // "已经看到最后一条消息、按钮还挂在右下角"的尴尬，
                            // 并且只有在 ScrollView 几何真正变化时才会触发，性能可控
                            .onScrollGeometryChange(for: Bool.self) { geometry in
                                // 30pt 容差：避免小幅抖动 / 键盘弹出导致的瞬时偏移反复切换状态
                                let contentH = geometry.contentSize.height
                                let containerH = geometry.containerSize.height
                                let isAtBottom = geometry.contentOffset.y + containerH >= contentH - 30
                                return isAtBottom
                            } action: { _, isAtBottom in
                                if isAtBottom {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showScrollToBottomButton = false
                                    }
                                    if !shouldAutoScroll {
                                        shouldAutoScroll = true
                                    }
                                } else {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showScrollToBottomButton = true
                                    }
                                    if shouldAutoScroll {
                                        shouldAutoScroll = false
                                    }
                                }
                            }
                            .onAppear {
                                scrollProxy = proxy
                            }
                            .overlay(alignment: .bottom) {
                                // 流式内容更新时的自动滚动响应器：只有这个零尺寸子视图会因为
                                // 滚动请求而刷新，父视图（消息列表）完全不受影响
                                ChatAutoScroller(coordinator: scrollCoordinator) {
                                    guard shouldAutoScroll else { return }
                                    scrollToBottom(proxy: proxy, animated: false)
                                }
                            }
                            .overlay(alignment: .bottomTrailing) {
                                // 回到底部按钮
                                // 仅在消息列表非空时才显示：空列表时 ScrollView 里只有
                                // emptyStateView，没有真正可"回到底部"的内容，
                                // 此时按钮没有语义意义
                                if showScrollToBottomButton && !messages.isEmpty {
                                    Button {
                                        shouldAutoScroll = true
                                        // 立即滚动（无动画、无延迟）：
                                        // 避开 ScrollView 的"动画中"状态——
                                        // 若用 withAnimation 把 scrollTo 包起来，
                                        // 那 200ms 动画期间到达的流式增量会被动画系统
                                        // 持续覆盖回插值位置，导致点击后到位的自动滚动失效
                                        proxy.scrollTo("bottom", anchor: .bottom)
                                    } label: {
                                        VStack {
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundStyle(ChatTheme.textPrimary)
                                        }.frame(width: 44, height: 44, alignment: .center)
                                        // 先填 clear 再套玻璃，否则玻璃 tint 颜色显示异常
                                        .background(Circle().fill(Color.clear))
                                        .appGlass(.regular.interactive(), in: Circle())
                                    }.transition(.scale.combined(with: .opacity))
                                        .padding(.trailing, 20)
                                        .padding(.bottom, inputBarHeight + AiChatMain.inputBarBottomGap)
                                       
                                }
                            }
                        }
                    }
                    
                    VStack {
                        Spacer()
                        VStack {
                            Spacer()
                            Text("回答由AI生成，仅供参考")
                                .font(.system(size: 12))
                                .foregroundStyle(.gray)
                        }.frame(maxWidth:.infinity)
                            .frame(height: 80)
                        .padding(.vertical,10)
                        .background(LinearGradient(colors: [AppColor.background.opacity(0),AppColor.background.opacity(1),AppColor.background.opacity(1)], startPoint: .top, endPoint: .bottom))
                    }.ignoresSafeArea()
                        .opacity(messages.isEmpty ? 0 : 1)
                        
                    
                    
                    VStack {
                        Spacer()
                        // 输入主体
                        VStack(spacing: 0) {
                            // 机制 A（Permission ASK）授权条 —— 独立于消息流，悬浮在输入框上方
                            if !pendingConfirmations.isEmpty {
                                PermissionConfirmBar(
                                    confirmations: pendingConfirmations,
                                    isSubmitting: isSubmittingConfirmation,
                                    onAllow: { respondToPendingConfirmations(confirmed: true) },
                                    onDeny: { respondToPendingConfirmations(confirmed: false) }
                                )
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: pendingConfirmations)
                            }

                            AiChatMainSubBar(
                                isAIResponding: $isAIResponding,
                                onSendMessage: { text, files, imageDatas in
                                    sendMessage(text, files: files, imageDatas: imageDatas)
                                },
                                onStop: {
                                    stopClient()
                                }
                            ).background(Color.clear)
                                .padding(.horizontal, 10)
                        }
                        // 直接读取输入主体 VStack 自己的高度，比 PreferenceKey 在兄弟布局里更可靠
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.size.height
                        } action: { newHeight in
                            if abs(newHeight - inputBarHeight) > 0.5 {
                                inputBarHeight = newHeight
                                // 输入栏高度变化（授权条出现 / 改输入框行数）后，
                                // 也保持粘在最后一条消息上
                                if shouldAutoScroll, let proxy = scrollProxy {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                        scrollToBottom(proxy: proxy)
                                    }
                                }
                            }
                        }

                    }
                }
               
                
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .navigationBarHidden(true)
        .sheet(isPresented: $showPersonSelector) {
            PersonSelectorSheet(isPresented: $showPersonSelector)
                .environmentObject(globalModel)
        }
        .sheet(isPresented: $showHistorySidebar) {
            ChatHistorySheet(
                isPresented: $showHistorySidebar,
                onSelectConversation: { conversationId in
                    loadChatDetail(conversationId: conversationId)
                },
                onNewConversation: {
                    startNewConversation()
                }
                // onSettings: 临时关闭（聊天历史中的 AI 模型设置入口暂不开启）
                // onSettings: {
                //     showAISettings = true
                // }
            )
            // 每次打开都用新的 id 强制 SwiftUI 重建整个 Sheet 视图树（包含其 @StateObject
            // ViewModel），避免连续打开/关闭时被复用旧实例、停留在上一次的历史数据上
            .id(historySheetId)
        }
        /*
        // 临时关闭：聊天历史 → AI 模型设置入口
        .sheet(isPresented: $showAISettings) {
            // ChatHistorySheet 内的"设置"按钮触发的 AI 服务商配置页。
            // 关闭时不重置 conversationId 等会话状态——AI 配置与会话完全独立。
            AIConfigListView()
                .environmentObject(globalModel)
        }
        */
        .onChange(of: showHistorySidebar) { _, isShowing in
            if isShowing {
                historySheetId = UUID()
            }
        }
        .onAppear {
            handlePendingConversation()
            // 进入页面时预加载主模型配置到 cache，避免首次 sendMessage 时 metadata 缺字段
            MainModelConfigCache.shared.ensureLoaded()
        }
        .onChange(of: globalModel.pendingAiChatConversationId) { _, newValue in
            if let conversationId = newValue {
                loadChatDetail(conversationId: conversationId)
                globalModel.pendingAiChatConversationId = nil
            }
        }
        .onDisappear {
            // 视图消失时仅做本地清理（断开连接），不通知服务端中断当前 run
            stopClient(notifyServer: false)
        }
        .alert("错误", isPresented: $showErrorAlert) {
            Button("确定", role: .cancel) {
                errorMessage = nil
            }
            Button("重试") {
                retryLastMessage()
            }
        } message: {
            Text(errorMessage ?? "未知错误")
        }
    }
    
    
    private var emptyStateView: some View {
        VStack(spacing: ChatTheme.spacingLg) {
            assistantIntroCard

            questionCarousel
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .padding(.top, 22)
        .padding(.horizontal, 4)
    }

    private var assistantIntroCard: some View {
        HStack(spacing: ChatTheme.spacingMd) {
            ZStack {
                Circle()
                    .fill(ChatTheme.accent)
                    .frame(width: 52, height: 52)

                Image(systemName: "cross.case.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .shadow(color: ChatTheme.accent.opacity(0.2), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text("健康助手")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(ChatTheme.textPrimary)

                    Text("AI 陪伴")
                        .font(ChatTheme.caption(10))
                        .foregroundStyle(ChatTheme.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(ChatTheme.accent.opacity(0.12)))
                }

                Text("解读健康指标 · 整理就诊信息 · 规划日常习惯")
                    .font(.system(size: 13))
                    .foregroundStyle(ChatTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: "sparkles")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(ChatTheme.accent.opacity(0.7))
                .frame(width: 30, height: 30)
                .background(Circle().fill(ChatTheme.accent.opacity(0.08)))
        }
        .padding(ChatTheme.spacingMd)

        .appGlass(.regular, in:RoundedRectangle(cornerRadius: ChatTheme.radiusLg))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("健康助手，解读健康指标、整理就诊信息、规划日常习惯")
    }

    private var questionCarousel: some View {
        VStack(alignment: .leading, spacing: ChatTheme.spacingSm) {
            HStack {
                Text("试着这样问")
                    .font(ChatTheme.title(14))
                    .foregroundStyle(ChatTheme.textPrimary)

                Spacer()

                Text("点击开始咨询")
                    .font(ChatTheme.caption(11))
                    .foregroundStyle(ChatTheme.textSecondary)
            }

            TabView(selection: $suggestionPageIndex) {
                ForEach(Array(healthQuestionExamplePages.enumerated()), id: \.offset) { pageIndex, examples in
                    VStack(spacing: ChatTheme.spacingSm) {
                        ForEach(examples) { example in
                            Button {
                                sendMessage(example.question)
                            } label: {
                                HStack(spacing: ChatTheme.spacingMd) {
                                    Image(systemName: example.icon)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(ChatTheme.accent)
                                        .frame(width: 38, height: 38)
                                        .background(Circle().fill(ChatTheme.accent.opacity(0.12)))

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(example.title)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(ChatTheme.textPrimary)

                                        Text(example.question)
                                            .font(.system(size: 12))
                                            .foregroundStyle(ChatTheme.textSecondary)
                                            .lineLimit(1)
                                    }

                                    Spacer(minLength: 4)
                                }
                                .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
                                .padding(.horizontal, ChatTheme.spacingMd)
                                .appGlass(.clear.interactive(), in: RoundedRectangle(cornerRadius: ChatTheme.radiusMd))
                            }
                            .buttonStyle(.plain)
                            .disabled(isAIResponding)
                            
                           
                        }
                    }
                    .tag(pageIndex)
                }
            }
            .frame(height: 148)
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onReceive(Timer.publish(every: 4, on: .main, in: .common).autoconnect()) { _ in
                guard !isAIResponding, healthQuestionExamplePages.count > 1 else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    suggestionPageIndex = (suggestionPageIndex + 1) % healthQuestionExamplePages.count
                }
            }
            

            carouselPageIndicator
        }
        .padding(ChatTheme.spacingMd)
        .appGlass(.regular, in:RoundedRectangle(cornerRadius: ChatTheme.radiusLg))
    }

    private var carouselPageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(healthQuestionExamplePages.indices, id: \.self) { index in
                Capsule()
                    .fill(index == suggestionPageIndex ? ChatTheme.accent : ChatTheme.accent.opacity(0.24))
                    .frame(width: index == suggestionPageIndex ? 22 : 6, height: 6)
                    .animation(.easeInOut(duration: 0.25), value: suggestionPageIndex)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("示例问题第 \(suggestionPageIndex + 1) 页，共 \(healthQuestionExamplePages.count) 页")
    }

    private var healthQuestionExamplePages: [[HealthQuestionExample]] {
        stride(from: 0, to: healthQuestionExamples.count, by: 2).map { startIndex in
            Array(healthQuestionExamples[startIndex..<min(startIndex + 2, healthQuestionExamples.count)])
        }
    }

    private var healthQuestionExamples: [HealthQuestionExample] {
        [
            HealthQuestionExample(
                title: "指标解读",
                question: "我的血压和心率记录需要注意什么？",
                icon: "waveform.path.ecg"
            ),
            HealthQuestionExample(
                title: "用药提醒",
                question: "帮我整理今天的用药注意事项。",
                icon: "pills.fill"
            ),
            HealthQuestionExample(
                title: "饮水计划",
                question: "根据我的情况，今天应该怎样安排饮水？",
                icon: "drop.fill"
            ),
            HealthQuestionExample(
                title: "就诊准备",
                question: "去医院复诊前，我应该准备哪些信息？",
                icon: "stethoscope"
            )
        ]
    }

    // 滚动到底部
    // - animated: 新消息、点击"回到底部"等离散操作用动画；
    //   流式输出期间必须关闭动画，否则每 100ms 就叠加一次 0.2s 的滚动动画，
    //   互相打断会让内容看起来一顿一顿地往上跳
    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        guard animated else {
            proxy.scrollTo("bottom", anchor: .bottom)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo("bottom", anchor: .bottom)
                
            }
        }
    }
    // 停止客户端
    // - notifyServer: 是否通知服务端中断当前 run。
    //   只有用户主动点击输入栏的"停止"按钮时才通知服务端（AI_CHAT_INTERRUPT）；
    //   离开页面、切换会话等被动场景仅做本地清理（断开流式连接），不请求中断接口，
    //   让服务端自然跑完当前 run 并把结果存进历史，下次进入会话仍能看到完整回复。
    private func stopClient(notifyServer: Bool = true) {
        // 捕获当前的会话和运行信息，用于发送中断请求
        let interruptedMessage = streamAccumulator?.message
        let runId = interruptedMessage?.runId
        let cid = conversationId

        streamAccumulator = nil
        pendingConfirmations = []
        isSubmittingConfirmation = false
        currentRunHasContent = false

        // 用户主动中断（点击"停止"按钮）时，给当前正在输出的消息本地打上
        // interruptedByUser 标记并触发刷新，让流式界面立即显示"已中断"，
        // 不必等下次从历史加载（后端历史里同样会写入这个标记）
        if notifyServer, let interruptedMessage = interruptedMessage {
            var metadata = interruptedMessage.metadata ?? [:]
            metadata["interruptedByUser"] = AnyCodable(true)
            interruptedMessage.metadata = metadata
            interruptedMessage.objectWillChange.send()
        }

        // 发送中断请求到服务端，通知后端停止当前 run
        if notifyServer, let runId = runId, let cid = cid {
            BgResultNetWork<ChatInterruptRequest, Data>(
                aiUrl(AI_CHAT_INTERRUPT),
                method: .post,
                params: ChatInterruptRequest(conversationId: cid, runId: runId)
            ).response()
        }

        guard let client = self.sseClient else {
            return
        }
        
        // 先清空引用，避免在回调中再次访问
        self.sseClient = nil
        
        // 然后断开连接
        client.disconnect()
        
        // 更新状态
        isAIResponding = false
    }
    
    // 发送消息
    private func sendMessage(
        _ text: String = "",
        showUserMessage: Bool = true,
        meta: [String: AnyCodable]? = nil,
        files: [ChatFileInfo] = [],
        imageDatas: [Data] = [],
        interactiveHandle: InteractiveHandleBlockMessage? = nil
    ) {
        if isAIResponding {
            return
        }
        // 重置滚动状态
        shouldAutoScroll = true
        showScrollToBottomButton = false
        // 重置"正在生成回复"指示器状态，等待新一轮 run 产生第一个内容块
        currentRunHasContent = false

        var userDisplayMessage: DisplayChatMessage? = nil
        
        // 构建用户消息内容块（文本 + 文件），UI 展示和发送请求共用
        var userContentBlocks: [MessageContentBlock] = []
        for file in files {
            userContentBlocks.append(.file(FileOfIdMessage(fileId: file.fileId, fileName: file.fileName, fileType: file.fileType)))
        }
        if !text.isEmpty {
            userContentBlocks.append(.text(TextBlockMessage(text: text)))
        }
        
        var messageId = ULIDUtils.generate();
        // 只有在需要显示时才添加用户消息
        if showUserMessage {
            let timestamp = DateUtils.dateToTimestamp(Date())
            userDisplayMessage = DisplayChatMessage(
                conversationId: conversationId,
                runId: nil,
                messageId: messageId,
                role: .user,
                purpose: .chat,
                timestamp: timestamp,
                contents: userContentBlocks,
                metadata: meta,
                displayState: .sending
            )
            messages.append(userDisplayMessage!)
        }
        
        // 构建发送给服务端的 contentBlocks，在用户内容基础上前置 interactiveHandle
        var contentBlocks: [MessageContentBlock] = []
        if let interactiveHandle = interactiveHandle {
            contentBlocks.append(.interactiveHandle(interactiveHandle))
        }
        contentBlocks.append(contentsOf: userContentBlocks)

        // 把用户在 AI 设置页选中的厂商/模型合并进 metadata，
        // 让本地 AI 代理知道该用哪个厂商的哪个模型来路由请求。
        let requestMetadata = Self.mergeAIVendorMetadata(existing: meta)

        let chatRequest = ChatRequest(
            conversationId: conversationId,
            messageId: messageId,
            contents: contentBlocks,
            metadata: requestMetadata
        )
        
        // 新版事件累积器：负责把 RUN_STARTED ~ RUN_FINISHED/RUN_ERROR 之间的
        // 一系列事件（THINKING/TOOL_CALL/TEXT 等）合并为一条 assistant 消息
        let accumulator = ChatStreamAccumulator(conversationIdProvider: { self.conversationId })
        streamAccumulator = accumulator
        
        accumulator.onMessageCreated = { newMessage in
            // 更新用户消息的会话/运行信息
            if let userMsg = userDisplayMessage {
                if StringUtils.isBlank(userMsg.runId ?? "") {
                    userMsg.runId = newMessage.runId
                }
                if StringUtils.isBlank(userMsg.conversationId ?? "") {
                    userMsg.conversationId = newMessage.conversationId
                }
                userMsg.markAsSuccess()
            }

            if StringUtils.isBlank(self.conversationId ?? ""), let cid = newMessage.conversationId, !StringUtils.isBlank(cid) {
                self.conversationId = cid
            }

            // 新 run 刚开始，还没有任何可见内容，继续显示"正在生成回复"指示器
            if currentRunHasContent {
                currentRunHasContent = false
            }

            messages.append(newMessage)
            if shouldAutoScroll {
                scrollCoordinator.requestNow()
            }
        }
        accumulator.onMessageUpdated = { updatedMessage in
            // 只要出现了任何内容块（思考/工具调用/文本等），就说明模型已经开始
            // 产出可见结果，隐藏"正在生成回复"指示器。
            // 这里必须判断当前值再赋值：@State 重复赋同一个值也会让 AiChatMain
            // 整体重新求值，流式场景下等于每个 delta 重建一次完整消息列表。
            if !updatedMessage.contents.isEmpty && !currentRunHasContent {
                currentRunHasContent = true
            }
            if shouldAutoScroll && updatedMessage.id == messages.last?.id {
                scrollCoordinator.request()
            }
        }
        accumulator.onRunFinished = { _ in
            isAIResponding = false
        }
        accumulator.onRunError = { _, errMsg in
            isAIResponding = false
            errorMessage = errMsg
            showErrorAlert = true
        }
        accumulator.onPendingConfirmations = { confirmations in
            // 机制 A：权限确认与消息流无关，直接展示为独立的授权条
            pendingConfirmations = confirmations
            // 权限询问期间 run 已经暂停（PERMISSION_ASKING），允许用户重新发起输入
            isAIResponding = false
        }
        accumulator.onExternalToolResult = { toolCallId, result in
            patchToolUseResult(toolCallId: toolCallId, result: result)
        }

        // 立即进入"响应中"状态并展示生成指示器：不等待网络连接完全建立，
        // 只要用户点击发送就给出即时反馈，避免响应较慢时被误认为卡住
        isAIResponding = true

        // 调用 AI 聊天 API（原始文本回调，解析为新版流式事件协议）
        sseClient = SseApi.postResponse(
            aiUrl(AI_CHAT_COMPLETIONS),
            param: chatRequest,
            headers: [HEAD_TOKEN:TokenUtils.getToken()]
        ) { rawData in
            guard let streamEvent = try? JSONFormatUtil.defaultInstall.decodeFromString(rawData, as: ChatStreamEvent.self) else {
                print("⚠️ 无法解析流式事件：\(rawData)")
                return
            }
            accumulator.apply(streamEvent)
        } errorHandle: { error in
            handleError(error, for: accumulator.message)
        } stateChangeHandle: { state in
            print("连接状态变更：\(state)")
            
            // 连接结束时的处理
            if state == .disconnected {
                isAIResponding = false
                if let responseMessage = accumulator.message, responseMessage.displayState.isLoading {
                    responseMessage.markAsSuccess()
                }
            }
        } sendSuccessHanle: {
            userDisplayMessage?.markAsSuccess()
            isAIResponding = true
            
            // 如果是交互处理请求，在请求成功后更新对应的 toolUse 消息
            if let interactiveHandle = interactiveHandle {
                // 查找对应的 ask_user toolUse 消息并更新其 result
                // 倒序遍历消息列表，找到对应的 assistant 消息中的 toolUse 并更新
                for i in stride(from: messages.count - 1, through: 0, by: -1) {
                    let message = messages[i]
                    
                    // 查找 assistant 角色的消息中的 toolUse
                    if message.role == .assistant {
                        var updatedContents = message.contents
                        var hasUpdated = false
                        
                        for (contentIndex, content) in updatedContents.enumerated() {
                            if case .toolUse(let toolUseBlock) = content {
                                // 检查是否是对应的 ask_user 工具（通过 messageId 和 toolCallId 匹配）
                                if toolUseBlock.id == interactiveHandle.toolCallId && message.messageId == interactiveHandle.messageId {
                                    print("📝 更新 toolUse result: id='\(toolUseBlock.id)' value='\(interactiveHandle.value.value)'")
                                    // 将 value 序列化为 JSON 字符串，保留结构以便 AIAskUserResponseView 解析
                                    let resultString = interactiveHandle.resultStringForToolUse()
                                    updatedContents[contentIndex] = .toolUse(ToolUseBlockMessage(
                                        id: toolUseBlock.id,
                                        name: toolUseBlock.name,
                                        input: toolUseBlock.input,
                                        content: toolUseBlock.content,
                                        result: resultString,
                                        metadata: toolUseBlock.metadata
                                    ))
                                    hasUpdated = true
                                    break
                                }
                            }
                        }
                        
                        // 🔑 关键修复：重新赋值整个 contents 数组来触发 @Published 更新
                        // 必须在主线程执行，并创建新数组实例以确保 SwiftUI 检测到变化
                        if hasUpdated {
                            DispatchQueue.main.async {
                                // 创建新数组实例触发 @Published 的 willSet
                                message.contents = Array(updatedContents)
                                // 显式触发 ObservableObject 的更新通知
                                message.objectWillChange.send()
                            }
                            break
                        }
                    }
                }
                
                // 插入用户回复消息
                let timestamp = DateUtils.dateToTimestamp(Date())
                let interactiveUserMessage = DisplayChatMessage(
                    conversationId: conversationId,
                    runId: nil,
                    messageId: "temp_\(ULIDUtils.generate())",
                    role: .user,
                    purpose: .interactive,
                    timestamp: timestamp,
                    contents: [.interactiveHandle(interactiveHandle)],
                    displayState: .success
                )
                messages.append(interactiveUserMessage)
            }
        } sendFailureHandler: { error in
            userDisplayMessage?.markAsFailed(error: error.localizedDescription)
            isAIResponding = false
            handleSendError(error)
        }
    }

    /// 把用户在 AI 设置页选中的"主模型"配置合并进请求 metadata，
    /// 让本地 AI 代理服务（/ai/chat/completions/v1）按 vendor + model 路由请求。
    ///
    /// - existing: 调用方已传入的 metadata（可能是 confirmResults 等），不覆盖已有键
    /// - 数据源：MainModelConfigCache 缓存的当前用户主模型（purpose=1 且 enabled=1）
    /// - 缓存未加载时 fire-and-forget 触发异步加载，本次请求保持原有 metadata
    private static func mergeAIVendorMetadata(existing: [String: AnyCodable]?) -> [String: AnyCodable]? {
        // 首次进入时启动一次异步加载（即使本次不命中，下次 sendMessage 就有缓存了）
        MainModelConfigCache.shared.ensureLoaded()
        guard let cached = MainModelConfigCache.shared.current else {
            return existing
        }
        var merged = existing ?? [:]
        // 不覆盖已有键：调用方传入的 metadata 优先级更高（例如 confirmResults）
        for (key, value) in cached {
            if merged[key] == nil {
                merged[key] = value
            }
        }
        return merged
    }

    /// 用于权限确认（机制 A）恢复场景：工具调用发生在被拦截的上一个 run，
    /// 而执行结果在恢复后的新 run 里以 TOOL_RESULT_* 事件返回，新的
    /// ChatStreamAccumulator 实例并不知道旧 run 里的 toolUse，需要跨消息回填。
    private func patchToolUseResult(toolCallId: String, result: String) {
        for i in stride(from: messages.count - 1, through: 0, by: -1) {
            let message = messages[i]
            guard message.role == .assistant else { continue }

            var updatedContents = message.contents
            var hasUpdated = false

            for (contentIndex, content) in updatedContents.enumerated() {
                if case .toolUse(let toolUseBlock) = content, toolUseBlock.id == toolCallId {
                    updatedContents[contentIndex] = .toolUse(ToolUseBlockMessage(
                        id: toolUseBlock.id,
                        name: toolUseBlock.name,
                        input: toolUseBlock.input,
                        content: toolUseBlock.content,
                        result: result,
                        metadata: toolUseBlock.metadata
                    ))
                    hasUpdated = true
                    break
                }
            }

            if hasUpdated {
                // 内容变更由消息自身的 @Published 通知到对应的消息组视图，
                // 这里只需要请求一次滚动；是否真正滚动仍由 shouldAutoScroll 把关
                message.updateContents(updatedContents)
                scrollCoordinator.request()
                return
            }
        }
    }

    // 处理 ask_user 工具的用户回复
    private func handleAskUserResponse(_ interactiveHandle: InteractiveHandleBlockMessage) {
        // 复用 sendMessage 方法，不显示用户消息，只发送交互处理块
        sendMessage(
            showUserMessage: false,
            interactiveHandle: interactiveHandle
        )
    }

    // MARK: - 机制 A：权限确认（Permission ASK）

    /// 用户对授权条中的工具调用做出允许/拒绝的决定
    /// 提交格式见文件顶部注释与 ConfirmResultPayload 定义：
    /// 通过 ChatRequest.metadata["confirmResults"] 携带一个数组，
    /// 每项包含 { toolCallId, toolName, confirmed }，后端根据 toolCallId
    /// 从会话中挂起的 ASKING 状态里取回完整的 ToolUseBlock 并构造 ConfirmResult。
    private func respondToPendingConfirmations(confirmed: Bool) {
        guard !pendingConfirmations.isEmpty, !isSubmittingConfirmation else { return }

        let confirmations = pendingConfirmations
        let payload = confirmations.map { item in
            ConfirmResultPayload(toolCallId: item.id, toolName: item.name, confirmed: confirmed)
        }

        guard let payloadDicts = try? payload.map({ try JSONFormatUtil.defaultInstall.encodeToDictionary($0) }) else {
            return
        }
        
        isSubmittingConfirmation = true
        // 提交成功或失败后都清空授权条，避免重复提交；真正的结果以后续 SSE 流为准
        pendingConfirmations = []
        // 授权条消失的瞬间就顶上"正在生成回复"指示器，避免点击允许/拒绝后
        // 在恢复流返回结果之前出现一段没有任何反馈的空白
        currentRunHasContent = false
        isAIResponding = true

        let chatRequest = ChatRequest(
            conversationId: conversationId,
            messageId: ULIDUtils.generate(),
            contents: [],
            metadata: ["confirmResults": AnyCodable(payloadDicts)]
        )

        let accumulator = ChatStreamAccumulator(conversationIdProvider: { self.conversationId })
        streamAccumulator = accumulator

        accumulator.onMessageCreated = { newMessage in
            if currentRunHasContent {
                currentRunHasContent = false
            }
            messages.append(newMessage)
            if shouldAutoScroll { scrollCoordinator.requestNow() }
        }
        accumulator.onMessageUpdated = { updatedMessage in
            if !updatedMessage.contents.isEmpty && !currentRunHasContent {
                currentRunHasContent = true
            }
            if shouldAutoScroll && updatedMessage.id == messages.last?.id {
                scrollCoordinator.request()
            }
        }
        accumulator.onRunFinished = { _ in isAIResponding = false }
        accumulator.onRunError = { _, errMsg in
            isAIResponding = false
            errorMessage = errMsg
            showErrorAlert = true
        }
        accumulator.onPendingConfirmations = { confirmations in
            pendingConfirmations = confirmations
            isAIResponding = false
        }
        accumulator.onExternalToolResult = { toolCallId, result in
            // 工具结果本身也算"可见内容"，回填后应立即隐藏生成指示器
            currentRunHasContent = true
            patchToolUseResult(toolCallId: toolCallId, result: result)
        }

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
            isSubmittingConfirmation = false
            handleError(error, for: accumulator.message)
        } stateChangeHandle: { state in
            if state == .disconnected {
                isSubmittingConfirmation = false
                isAIResponding = false
                if let responseMessage = accumulator.message, responseMessage.displayState.isLoading {
                    responseMessage.markAsSuccess()
                }
            }
        } sendSuccessHanle: {
            isSubmittingConfirmation = false
            isAIResponding = true
        } sendFailureHandler: { error in
            isSubmittingConfirmation = false
            handleSendError(error)
        }
    }
    
    // 处理错误
    private func handleError(_ error: Error, for message: DisplayChatMessage?) {
        print("AI 响应错误：\(error)")
        
        isAIResponding = false
        
        // 更新消息状态
        if let message = message {
            message.markAsFailed(error: "AI 响应出现错误")
            if message.contents.isEmpty {
                // 添加错误提示到 contents
                message.contents.append(.text(TextBlockMessage(text: "抱歉，AI 响应出现错误，请稍后重试")))
            }
        }
        
        // 显示错误信息
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
        
        showErrorAlert = true
    }
    
    // 处理发送错误
    private func handleSendError(_ error: Error) {
        print("发送消息错误：\(error)")
        
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                errorMessage = "网络未连接，无法发送消息"
            case NSURLErrorTimedOut:
                errorMessage = "发送超时，请检查网络连接"
            default:
                errorMessage = "发送失败：\(error.localizedDescription)"
            }
        } else {
            errorMessage = "发送失败：\(error.localizedDescription)"
        }
        
        showErrorAlert = true
    }
    
    // 重试最后一条失败的消息
    private func retryLastMessage() {
        guard let lastUserMessage = messages.last(where: { $0.isUserMessage && $0.displayState.isFailed }) else {
            return
        }
        
        // 移除失败的消息和可能的错误响应
        messages.removeAll { message in
            message.messageId == lastUserMessage.messageId ||
            (message.isAssistantMessage && message.timestamp > lastUserMessage.timestamp)
        }
        
        // 重新发送
        sendMessage(lastUserMessage.textContent ?? "")
    }
    
    // 加载聊天详情
    private func startNewConversation() {
        // 新建会话属于被动切换场景，只做本地清理，不通知服务端中断
        stopClient(notifyServer: false)
        scrollResetKey = UUID()
        messages.removeAll()
        conversationId = nil
        isAIResponding = false
        errorMessage = nil
        showErrorAlert = false
    }
    
    /// 处理从消息通知跳转过来的待加载会话
    private func handlePendingConversation() {
        guard let conversationId = globalModel.pendingAiChatConversationId else { return }
        globalModel.pendingAiChatConversationId = nil
        loadChatDetail(conversationId: conversationId)
    }
    
    private func loadChatDetail(conversationId: String) {
        // 防止重复加载
        if isLoadingHistory {
            return
        }

        isLoadingHistory = true
        // 切换会话属于被动场景：断开上一个会话的流式连接即可，
        // 不通知服务端中断当前 run，让其在后台跑完并写入历史
        stopClient(notifyServer: false)
        scrollResetKey = UUID()
        pendingConfirmations = []

        // 清空当前消息
        messages.removeAll()
        self.conversationId = conversationId
        
        // 调用 API 获取聊天详情
        BgResultNetWork<ChatDetailRequest, [ChatMessage]>
            .post(
                aiUrl(AI_CHAT_DETAIL),
                params: ChatDetailRequest(conversationId: conversationId)
            )
            .complicationHand { (detailList:[ChatMessage]?) in
                guard let details = detailList else {
                    isLoadingHistory = false
                    return
                }

                // 过滤掉权限确认的"回执"消息（metadata 携带 agentscope_confirm_results）。
                // 这类消息只是用户点击"允许/拒绝"后系统自动补的一条占位记录
                // （contents 通常是"用户已确认工具调用"），不属于对话内容，不应展示。
                let visibleDetails = details.filter { !$0.isConfirmResultMessage }

                // 转换为 DisplayChatMessage
                var loadedMessages: [DisplayChatMessage] = []
                for detail in visibleDetails {
                    let displayMsg = DisplayChatMessage(from: detail, displayState: .success)
                    loadedMessages.append(displayMsg)
                }
                
                // 处理 tool 角色的消息，将 toolResult 关联到对应的 toolUse
                processToolResults(&loadedMessages)

                // 历史会话中的普通工具调用（非 ask_user）不会再补发 toolResult 块，
                // 执行结果只体现在后续的最终回复文本里。如果不处理，result 始终为 nil，
                // 推理时间线会一直显示"执行中"。既然是已完成的历史会话，
                // 这里统一回填一个非空占位结果，标记为"已完成"。
                fillCompletedHistoricalToolResults(&loadedMessages)

//                // Debug: 打印 loadedMessages 内容
//                print("=== loadedMessages (\(loadedMessages.count) 条) ===")
//                for (index, msg) in loadedMessages.enumerated() {
//                    let contentsDesc = msg.contents.map { block -> String in
//                        switch block {
//                        case .text(let b):
//                            return "{type:text, text:\"\(b.text.prefix(100))\"}"
//                        case .thinking(let b):
//                            return "{type:thinking, thinking:\"\(b.thinking.prefix(100))\"}"
//                        case .system(let b):
//                            return "{type:system, system:\"\(b.system.prefix(100))\"}"
//                        case .toolUse(let b):
//                            return "{type:toolUse, id:\(b.id), name:\(b.name),content:\(b.content), input:\(b.input), result:\(b.result)}"
//                        case .toolResult(let b):
//                            return "{type:toolResult, toolUseId:\(b.id), content:\(b.result)}"
//                        case .interactiveHandle(let b):
//                            return "{type:interactiveHandle, id:\(b.toolCallId)}"
//                        case .file(let b):
//                            return "{type:file, name:\(b.fileName ?? "")}"
//                        }
//                    }.joined(separator: ", ")
//                    print("[\(index)] id:\(msg.messageId) role:\(msg.role) purpose:\(msg.purpose) contents:[\(contentsDesc)]")
//                }
//                print("=== loadedMessages end ===")
                
                // 更新消息列表
                messages = loadedMessages
                isLoadingHistory = false

                // 历史填充完成后，再启动恢复流，避免恢复流的增量消息被历史加载覆盖。
                // 恢复接口返回的已完成流（仅 RUN_FINISHED）由累积器内部忽略，无需额外处理。
                resumeConversation(conversationId: conversationId)

                // 滚动到底部
                if let proxy = scrollProxy {
                    shouldAutoScroll = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        scrollToBottom(proxy: proxy)
                    }
                }
            }
            .errorHandle { _, error in
                isLoadingHistory = false
                errorMessage = "加载聊天记录失败"
                showErrorAlert = true
                print("加载聊天详情失败：\(error)")
            }
            .responseDecodable()
    }

    /// 恢复会话：进入历史会话时调用 /ai/chat/completions/v1，body 只带 conversationId。
    /// 返回的流与正常聊天一致，用累积器实时渲染；若后端返回已完成流
    /// （如仅一个 RUN_FINISHED 事件），累积器不会创建消息，无需任何处理。
    private func resumeConversation(conversationId: String) {
        let accumulator = ChatStreamAccumulator(conversationIdProvider: { self.conversationId })
        streamAccumulator = accumulator

        accumulator.onMessageCreated = { newMessage in
            if StringUtils.isBlank(self.conversationId ?? ""), let cid = newMessage.conversationId, !StringUtils.isBlank(cid) {
                self.conversationId = cid
            }
            // 恢复流真正开始产生新消息时才进入"响应中"状态；
            // 若返回的是已完成流（无 RUN_STARTED，不触发此处），保持静默状态不干扰 UI
            self.isAIResponding = true
            if self.currentRunHasContent {
                self.currentRunHasContent = false
            }
            self.messages.append(newMessage)
            if self.shouldAutoScroll {
                self.scrollCoordinator.requestNow()
            }
        }
        accumulator.onMessageUpdated = { updatedMessage in
            if !updatedMessage.contents.isEmpty && !self.currentRunHasContent {
                self.currentRunHasContent = true
            }
            if self.shouldAutoScroll && updatedMessage.id == self.messages.last?.id {
                self.scrollCoordinator.request()
            }
        }
        accumulator.onRunFinished = { _ in
            self.isAIResponding = false
        }
        accumulator.onRunError = { _, errMsg in
            self.isAIResponding = false
            self.errorMessage = errMsg
            self.showErrorAlert = true
        }
        accumulator.onExternalToolResult = { toolCallId, result in
            self.patchToolUseResult(toolCallId: toolCallId, result: result)
        }

        sseClient = SseApi.postResponse(
            aiUrl(AI_CHAT_COMPLETIONS),
            param: ChatResumeRequest(conversationId: conversationId),
            headers: [HEAD_TOKEN: TokenUtils.getToken()]
        ) { rawData in
            guard let streamEvent = try? JSONFormatUtil.defaultInstall.decodeFromString(rawData, as: ChatStreamEvent.self) else {
                print("⚠️ 无法解析流式事件：\(rawData)")
                return
            }
            accumulator.apply(streamEvent)
        } errorHandle: { error in
            self.handleError(error, for: accumulator.message)
        } stateChangeHandle: { state in
            if state == .disconnected {
                self.isAIResponding = false
                if let responseMessage = accumulator.message, responseMessage.displayState.isLoading {
                    responseMessage.markAsSuccess()
                }
            }
        } sendSuccessHanle: {
            // 连接建立成功，但尚未收到内容事件，不在此处进入"响应中"状态
        } sendFailureHandler: { error in
            self.isAIResponding = false
            self.handleSendError(error)
        }
    }

    /// 处理历史聊天消息中的工具调用关系
    /// 将 toolResult 和 interactiveHandle 关联到对应的 toolUse，实现完整的交互链条
    /// 
    /// 此方法用于处理历史聊天记录中的工具调用关联关系：
    /// 1. 收集所有 toolResult（工具执行结果）和 interactiveHandle（用户对交互式工具的回复）
    /// 2. 将这些结果关联到对应的 toolUse 消息上，实现完整的交互链条显示
    /// 
    /// - Parameter messages: 需要处理的消息列表（引用传递，会直接修改）
    private func processToolResults(_ messages: inout [DisplayChatMessage]) {
        // 收集所有 toolResult 消息（工具执行结果）
        // key: toolUse id, value: result
        var toolResults: [String: String] = [:]
        
        // 收集所有 interactiveHandle 消息（用户对 ask_user 工具的回复）
        // key: messageId + toolCallId, value: InteractiveHandleInfo
        var interactiveHandles: [String: InteractiveHandleInfo] = [:]
        
        // 第一遍扫描：收集所有 toolResult 和 interactiveHandle
        for message in messages {
            // 处理 role 为 tool 的消息
            // 注意：tool 角色的消息可能包含两种类型的内容：
            // 1. toolResult - 工具执行的结果
            // 2. interactiveHandle - 用户对交互式工具（如 ask_user）的回复
            if message.role == .tool {
                for content in message.contents {
                    // 提取 toolResult（工具执行结果）
                    if case .toolResult(let toolResultBlock) = content {
                        toolResults[toolResultBlock.id] = String(describing: toolResultBlock.result.value)
                    }
                    // 🔑 关键修复：提取 interactiveHandle（用户回复）
                    // role 为 tool 的消息也可能包含 interactiveHandle，表示用户对 ask_user 工具的回复
                    // 这是历史聊天记录中的格式，需要正确识别和处理
                    else if case .interactiveHandle(let interactiveBlock) = content {
                        let key = "\(interactiveBlock.messageId)_\(interactiveBlock.toolCallId)"
                        interactiveHandles[key] = InteractiveHandleInfo(
                            messageId: interactiveBlock.messageId,
                            toolCallId: interactiveBlock.toolCallId,
                            name: interactiveBlock.name,
                            messageType: interactiveBlock.messageType,
                            value: interactiveBlock.value
                        )
                    }
                }
            }

            // 处理 role 为 assistant 的消息中的 toolResult（新版协议下，
            // toolResult 可能直接嵌套在 assistant 消息中，而非独立的 tool 角色消息）
            if message.role == .assistant {
                for content in message.contents {
                    if case .toolResult(let toolResultBlock) = content {
                        let key = toolResultBlock.id
                        if toolResults[key] == nil {
                            toolResults[key] = String(describing: toolResultBlock.result.value)
                        }
                    }
                }
            }

            // 处理 role 为 user 的消息中的 interactiveHandle
            // 这是实时交互时的格式，也需要支持
            if message.role == .user {
                for content in message.contents {
                    if case .interactiveHandle(let interactiveBlock) = content {
                        let key = "\(interactiveBlock.messageId)_\(interactiveBlock.toolCallId)"
                        interactiveHandles[key] = InteractiveHandleInfo(
                            messageId: interactiveBlock.messageId,
                            toolCallId: interactiveBlock.toolCallId,
                            name: interactiveBlock.name,
                            messageType: interactiveBlock.messageType,
                            value: interactiveBlock.value
                        )
                    }
                }
            }
        }

        // 🔑 关键修复：为了方便匹配，创建一个只用 toolCallId 作为 key 的字典
        // 因为 JSON 数据中 interactiveHandle 的 messageId 可能不准确
        // 使用 toolCallId 作为唯一标识更加可靠
        var interactiveHandlesByToolCallId: [String: InteractiveHandleInfo] = [:]
        for (_, handle) in interactiveHandles {
            interactiveHandlesByToolCallId[handle.toolCallId] = handle
        }
        
        // 第二遍扫描：倒序遍历消息，找到对应的 toolUse 并更新 result
        // 倒序遍历是为了更快找到最近的匹配
        for i in stride(from: messages.count - 1, through: 0, by: -1) {
            let message = messages[i]
            
            // 查找 assistant 角色的消息中的 toolUse
            if message.role == .assistant {
                var updatedContents = message.contents
                var hasUpdated = false
                
                // 遍历消息中的所有内容块
                for (contentIndex, content) in updatedContents.enumerated() {
                    if case .toolUse(let toolUseBlock) = content {
                        // 检查是否有对应的 toolResult（普通工具的执行结果）
                        if let result = toolResults[toolUseBlock.id] {
                            // 更新 toolUse 的 result 字段
                            updatedContents[contentIndex] = .toolUse(ToolUseBlockMessage(
                                id: toolUseBlock.id,
                                name: toolUseBlock.name,
                                input: toolUseBlock.input,
                                content: toolUseBlock.content,
                                result: result,
                                metadata: toolUseBlock.metadata
                            ))
                            hasUpdated = true
                        }
                        
                        // 🔑 关键修复：检查是否有对应的 interactiveHandle（用户对 ask_user 工具的回复）
                        // 直接用 toolUseBlock.id（即 toolCallId）来匹配，不依赖 messageId
                        // 因为历史数据中 interactiveHandle 的 messageId 可能不准确
                        if let interactiveHandle = interactiveHandlesByToolCallId[toolUseBlock.id] {
                            // 使用 resultStringForToolUse() 将用户回复序列化为标准 JSON 字符串
                            // 这样 AIAskUserResponseView 才能正确解析并显示用户的回复内容
                            let resultString = interactiveHandle.resultStringForToolUse()
                            updatedContents[contentIndex] = .toolUse(ToolUseBlockMessage(
                                id: toolUseBlock.id,
                                name: toolUseBlock.name,
                                input: toolUseBlock.input,
                                content: toolUseBlock.content,
                                result: resultString,
                                metadata: toolUseBlock.metadata
                            ))
                            hasUpdated = true
                        }
                    }
                }
                
                // 如果有更新，重新赋值整个 contents 数组，触发 SwiftUI 的 @Published 更新
                if hasUpdated {
                    // 清理已匹配的 toolResult 块——其数据已转移到对应的 toolUse.result，
                    // 留在 contents 中会变成游离块，且可能干扰正文渲染
                    updatedContents.removeAll { content in
                        if case .toolResult(let tr) = content, toolResults[tr.id] != nil {
                            return true
                        }
                        return false
                    }
                    message.contents = updatedContents
                }
            }
        }
    }

    /// 为历史会话中已完成但没有 toolResult 的普通工具调用回填一个占位 result。
    /// 用于兼容旧版协议的历史数据：新版协议下 toolResult 可能直接嵌套在 assistant
    /// 消息中（由 processToolResults 处理），但如果旧历史数据中既没有独立的 tool
    /// 角色消息也没有嵌套的 toolResult 块，则 toolUse.result 会是 nil，
    /// 导致 ReasoningChainView 判断为"仍在执行中"。直接标记为已完成即可。
    /// ask_user 走独立的交互回复逻辑，这里不处理。
    private func fillCompletedHistoricalToolResults(_ messages: inout [DisplayChatMessage]) {
        for message in messages {
            guard message.role == .assistant else { continue }

            var updatedContents = message.contents
            var hasUpdated = false

            for (index, content) in updatedContents.enumerated() {
                if case .toolUse(let toolUseBlock) = content,
                   !toolUseBlock.isAskUserTool,
                   toolUseBlock.result == nil {
                    updatedContents[index] = .toolUse(ToolUseBlockMessage(
                        id: toolUseBlock.id,
                        name: toolUseBlock.name,
                        input: toolUseBlock.input,
                        content: toolUseBlock.content,
                        result: "success",
                        metadata: toolUseBlock.metadata
                    ))
                    hasUpdated = true
                }
            }

            if hasUpdated {
                message.contents = updatedContents
            }
        }
    }

    /// 用于存储 interactiveHandle 信息的辅助结构体
    private struct InteractiveHandleInfo {
        let messageId: String
        let toolCallId: String
        let name: String?
        let messageType: String
        let value: AnyCodable
        
        /// 将 value 序列化为 JSON 字符串，用于存入 ToolUseBlockMessage.result
        /// 保留结构以便 AIAskUserResponseView 解析
        /// - Returns: JSON 字符串，如果序列化失败则返回原始描述
        func resultStringForToolUse() -> String {
            // 优先使用 JSONEncoder 编码，保证所有嵌套类型都能正确序列化
            if let data = try? JSONEncoder().encode(value),
               let str = String(data: data, encoding: .utf8) {
                print("📦 InteractiveHandleInfo.resultStringForToolUse: \(str)")
                return str
            }
            
            // 降级：使用 String(describing:)
            let fallback = String(describing: value.value)
            print("⚠️ InteractiveHandleInfo.resultStringForToolUse 降级到 String(describing): \(fallback)")
            return fallback
        }
    }

    private func fetchImageDatas(fileIds: [String], completion: @escaping ([Data]) -> Void) {
        if fileIds.isEmpty {
            completion([])
            return
        }
        
        var results: [Data?] = Array(repeating: nil, count: fileIds.count)
        let group = DispatchGroup()
        
        for (index, fileId) in fileIds.enumerated() {
            group.enter()
            let urlString = apiUrl(FILE_LOAD) + "/\(fileId)"
            BgResultNetWork<Empty, Data>(urlString, method: .get)
                .complicationHand { data in
                    results[index] = data
                    group.leave()
                }
                .errorHandle { _, _ in
                    group.leave()
                }
                .response()
        }
        
        group.notify(queue: .main) {
            completion(results.compactMap { $0 })
        }
    }
    
    // MARK: - 消息分组函数
    
    /// 将消息按 runId 分组
    /// 同一个 runId 的连续 assistant/tool 消息会被合并到一个组中
    private func groupMessagesByRun(_ messages: [DisplayChatMessage]) -> [MessageGroup] {
        var groups: [MessageGroup] = []
        var currentGroup: [DisplayChatMessage] = []
        var currentRunId: String? = nil
        
        for message in messages {
            // 用户消息总是单独一组
            if message.role == .user {
                // 先保存之前的组
                if !currentGroup.isEmpty {
                    groups.append(MessageGroup(messages: currentGroup))
                    currentGroup = []
                    currentRunId = nil
                }
                // 添加用户消息组
                groups.append(MessageGroup(messages: [message]))
                continue
            }
            
            // Assistant 或 Tool 消息
            if message.role == .assistant || message.role == .tool {
                let messageRunId = message.runId
                
                // 如果 runId 相同，加入当前组
                if let currentId = currentRunId, currentId == messageRunId {
                    currentGroup.append(message)
                } else {
                    // runId 不同，保存当前组，开始新组
                    if !currentGroup.isEmpty {
                        groups.append(MessageGroup(messages: currentGroup))
                    }
                    currentGroup = [message]
                    currentRunId = messageRunId
                }
            }
        }
        
        // 处理最后一组
        if !currentGroup.isEmpty {
            groups.append(MessageGroup(messages: currentGroup))
        }
        
        return groups
    }
}

// 1. 定义 PreferenceKey
struct AiChatMainScrollViewBottomKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// 把内层输入栏（含其上方授权条）测出的实时高度传到外层 ScrollView，
/// 让消息列表底部留出刚好能避开输入栏的 padding，避免最后一条消息被遮挡。
struct AiChatMainInputBarHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
// 注：早先用 PreferenceKey + GeometryReader 在兄弟节点 ZStack 里传高度，
// 实际运行中 onPreferenceChange 收不到正确值（兄弟节点 preference 容易丢）。
// 已改用 iOS 18+ 的 .onGeometryChange 直接在输入主体 VStack 上读自己的 size，
// 这个 PreferenceKey 保留仅为兼容历史引用，暂无使用方。

// MARK: - 消息组数据结构

/// 消息组 - 表示一个或多个相关的消息
struct MessageGroup: Identifiable {
    let id: String
    let messages: [DisplayChatMessage]
    
    init(messages: [DisplayChatMessage]) {
        self.messages = messages
        // 使用第一条消息的 messageId 作为组 ID
        self.id = messages.first?.messageId ?? UUID().uuidString
    }
    
    /// 是否是用户消息组
    var isUserGroup: Bool {
        return messages.first?.role == .user
    }
    
    /// 是否是 AI 消息组（可能包含多个 assistant 和 tool 消息）
    var isAssistantGroup: Bool {
        return messages.contains { $0.role == .assistant || $0.role == .tool }
    }
}

// MARK: - 消息组视图

/// 消息组视图 - 根据消息组类型显示不同内容
struct MessageGroupView: View {
    let group: MessageGroup
    var onAskUserResponse: ((InteractiveHandleBlockMessage) -> Void)?
    
    var body: some View {
        if group.isUserGroup {
            // 用户消息组 - 直接显示
            ForEach(group.messages, id: \.messageId) { message in
                MessageBubbleView(message: message, onAskUserResponse: onAskUserResponse)
            }
        } else if group.isAssistantGroup {
            // AI 消息组 - 需要合并显示
            CombinedAssistantMessageView(messages: group.messages, onAskUserResponse: onAskUserResponse)
        }
    }
}

// MARK: - 合并的 AI 消息视图

/// 合并的 AI 消息视图 - 将同一个 run 内多个 assistant/tool 消息的内容合并显示
///
/// 关键点：合并结果由 `AssistantMessageGroupModel` 维护，它直接订阅组内每条消息的
/// 变更通知。这样流式增量只会刷新当前这一个消息组，而不需要父视图（整个聊天列表）
/// 重新求值 —— 之前的实现在 body 里现场 new 一个 DisplayChatMessage，导致内容更新
/// 必须靠父视图整体重建才能生效，是"文字成块蹦出"的主要原因之一。
struct CombinedAssistantMessageView: View {
    let messages: [DisplayChatMessage]
    var onAskUserResponse: ((InteractiveHandleBlockMessage) -> Void)?

    @StateObject private var model = AssistantMessageGroupModel()

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                AIMessageContentView(
                    contents: model.contents,
                    displayState: model.displayState,
                    messageId: model.messageId,
                    // 结束状态标记（中断/异常/补偿终止）走 @Published，才能在流式中实时刷新
                    endTag: model.endTag,
                    onAskUserResponse: onAskUserResponse
                )
                
                // AI 消息错误状态提示
                if case .failed = model.displayState {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(ChatTheme.danger)
                        
                        Text("响应失败")
                            .font(.system(size: 12))
                            .foregroundStyle(ChatTheme.danger)
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            model.bind(messages)
        }
        .onChange(of: messages.map(\.messageId)) { _, _ in
            // 组内新增/替换了消息（例如同一个 run 又追加了一条 tool 消息）
            model.bind(messages)
        }
    }
}

// MARK: - AI 消息组合并模型

/// 维护"同一个 run 内多条消息合并后的内容"，并订阅每条消息的变更。
final class AssistantMessageGroupModel: ObservableObject {
    @Published private(set) var contents: [MessageContentBlock] = []
    @Published private(set) var displayState: MessageDisplayState = .success
    /// 组内消息的结束状态标记（中断 / 运行异常 / 补偿终止），用于实时显示
    @Published private(set) var endTag: MessageEndTag?

    private(set) var messageId: String = ""

    private var messages: [DisplayChatMessage] = []
    private var cancellables: [AnyCancellable] = []

    /// 绑定消息组；消息对象未变化时不会重复订阅
    func bind(_ newMessages: [DisplayChatMessage]) {
        let isSameBinding = newMessages.count == messages.count
            && zip(newMessages, messages).allSatisfy { $0 === $1 }

        if !isSameBinding {
            messages = newMessages
            messageId = newMessages.first?.messageId ?? ""
            // objectWillChange 在属性赋值之前触发，延后一拍到主队列才能读到新值
            cancellables = newMessages.map { message in
                message.objectWillChange
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] _ in
                        self?.recompute()
                    }
            }
        }

        recompute()
    }

    private func recompute() {
        let merged = Self.mergeMessageContents(messages)
        let state = messages.last?.displayState ?? .success

        if !Self.isEqual(merged, contents) {
            contents = merged
        }
        if state != displayState {
            displayState = state
        }
        let tag = resolveMessageEndTag(messages)
        if tag != endTag {
            endTag = tag
        }
    }

    private static func isEqual(_ lhs: [MessageContentBlock], _ rhs: [MessageContentBlock]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for (index, block) in lhs.enumerated() {
            if !block.isEqual(to: rhs[index]) { return false }
        }
        return true
    }
    
    /// 合并多个消息的内容块
    /// 策略：按顺序收集所有 thinking、toolUse、text 内容
    private static func mergeMessageContents(_ messages: [DisplayChatMessage]) -> [MessageContentBlock] {
        var mergedContents: [MessageContentBlock] = []
        
        for message in messages {
            // 如果是 tool 消息，需要将 toolResult 更新到对应的 toolUse 中
            if message.role == .tool {
                for content in message.contents {
                    if case .toolResult(let toolResult) = content {
                        updateToolUseWithResult(&mergedContents, toolResult: toolResult)
                    }
                }
            } else {
                // assistant 消息，直接添加其内容
                mergedContents.append(contentsOf: message.contents)
            }
        }
        
        return mergedContents
    }
    
    /// 更新 toolUse 的 result 字段
    private static func updateToolUseWithResult(_ contents: inout [MessageContentBlock], toolResult: ToolResultBlockMessage) {
        let resultString = String(describing: toolResult.result.value)
        
        // 倒序查找对应的 toolUse
        for i in stride(from: contents.count - 1, through: 0, by: -1) {
            if case .toolUse(let toolUse) = contents[i] {
                if toolUse.id == toolResult.id {
                    contents[i] = .toolUse(ToolUseBlockMessage(
                        id: toolUse.id,
                        name: toolUse.name,
                        input: toolUse.input,
                        content: toolUse.content,
                        result: resultString,
                        metadata: toolUse.metadata
                    ))
                    break
                }
            }
        }
    }
}

// MARK: - 自动滚动协调

/// 自动滚动协调器：把"内容更新"与"执行滚动"解耦，并对滚动请求做固定间隔节流。
final class ChatScrollCoordinator: ObservableObject {
    @Published private(set) var tick: Int = 0

    private let throttler = IntervalThrottler(interval: 0.1)

    /// 流式内容更新时的滚动请求（节流，最多每 100ms 一次）
    func request() {
        throttler.submit { [weak self] in
            self?.tick &+= 1
        }
    }

    /// 离散事件（新消息插入等）的滚动请求，立即生效
    func requestNow() {
        throttler.cancel()
        tick &+= 1
    }
}

/// 零尺寸的滚动响应器：只有它会因为滚动请求而刷新，消息列表本身不受影响
struct ChatAutoScroller: View {
    @ObservedObject var coordinator: ChatScrollCoordinator
    let onScroll: () -> Void

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .onChange(of: coordinator.tick) { _, _ in
                onScroll()
            }
    }
}

#Preview {
    @Previewable @State var selection:Int = 0
    AiChatMain(selection: $selection)
        .environmentObject(GlobalModel.shared)
}

// MARK: - 主模型配置缓存

/// 缓存当前登录用户的"主模型"配置（purpose=1 且 enabled=1）。
///
/// 设计要点：
/// - 单进程内单例，所有 AiChatMain 实例共享
/// - 首次访问时异步拉取一次，成功后写入缓存
/// - 提供 invalidate() 方法，配置页保存后调用以强制下次重新拉取
final class MainModelConfigCache {
    static let shared = MainModelConfigCache()
    private init() {}

    /// 当前主模型的 metadata 注入项。nil 表示未配置或未加载完成。
    private(set) var current: [String: AnyCodable]?

    /// 是否已尝试过首次加载（成功或失败都算）
    private var hasLoadedOnce: Bool = false

    /// 正在加载中时，避免重复发请求
    private var isLoading: Bool = false

    /// 触发首次加载（幂等）。已加载过则直接返回。
    func ensureLoaded() {
        if hasLoadedOnce || isLoading { return }
        isLoading = true
        UsersModelConfigApi.list(
            completion: { list in
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.hasLoadedOnce = true
                    self.applyList(list)
                }
            },
            errorHandle: { _, _ in
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.hasLoadedOnce = true
                    // 加载失败不写入缓存，下次 ensureLoaded 仍会触发
                    self.current = nil
                }
            }
        )
    }

    /// 强制刷新（配置页保存后调用）
    func invalidate() {
        hasLoadedOnce = false
        current = nil
        ensureLoaded()
    }

    private func applyList(_ list: [UsersModelConfigDTO]) {
        // 选 purpose=1（主模型）且 enabled=1 的第一条
        let main = list.first { dto in
            dto.purpose == AIModelPurpose.main.rawValue && dto.isEnabled
        }
        guard let main = main,
              let type = main.modelType, !type.isEmpty,
              let name = main.modelName, !name.isEmpty else {
            current = nil
            return
        }
        var dict: [String: AnyCodable] = [
            "vendor": AnyCodable(type),
            "model": AnyCodable(name)
        ]
        if main.isMultimodalFlag {
            dict["multimodal"] = AnyCodable(true)
        }
        current = dict
    }
}
