import SwiftUI

// MARK: - 消息通知按钮（含徽标）
struct MessageNotificationButton: View {
    @Binding var unreadCount: Int
    @Binding var showSheet: Bool
    
    var body: some View {
        Button {
            showSheet = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(unreadCount > 0 ? Color.white :AppColor.primary)
                    .frame(width: 40, height: 40)
                    .appGlass(
                        unreadCount > 0
                            ? .regular.interactive().tint(AppColor.primary)
                            : .regular.interactive(),
                        in: Circle()
                    )

                if unreadCount > 0 {
                    Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(minWidth: 18, minHeight: 18)
                        .padding(.horizontal, unreadCount > 9 ? 3 : 0)
                        .background(Color.red)
                        .clipShape(Capsule())
                        .offset(x: 2, y: -2)
                        .transition(.scale(scale: 0.5, anchor: .topTrailing).combined(with: .opacity))
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .animation(.spring(response: 0.4, dampingFraction: 0.65), value: unreadCount)
    }
}

// MARK: - 消息筛选
enum MessageFilter: String, CaseIterable {
    case all = "全部"
    case read = "已读"
    case unread = "未读"
}

// MARK: - 消息列表 Sheet
struct MessageListView: View {
    @EnvironmentObject var globalModel: GlobalModel
    @Binding var isPresented: Bool
    var onUnreadCountRefresh: (() -> Void)?
    
    @State private var messages: [MessageNotification] = []
    @State private var isEditMode = false
    @State private var selectedIds: Set<String> = []
    @State private var filterState: MessageFilter = .all

    // 弹窗管理器（用于 API 失败时弹出提示）
    @State private var popManager: PopManager = PopManager()

    // API 状态
    @State private var currentPage: Int16 = 1
    @State private var totalMessages: Int64 = 0
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var loadError: String?
    @State private var hasInitialLoaded = false
    
    private let pageSize: Int16 = 20
    
    private var hasMoreData: Bool {
        !messages.isEmpty && Int64(messages.count) < totalMessages
    }
    
    private var unreadCount: Int {
        messages.filter { !$0.isRead }.count
    }
    
    private var filteredMessages: [MessageNotification] {
        messages
    }
    
    private var contentState: Int {
        if isLoading && messages.isEmpty { return 0 }
        if loadError != nil && messages.isEmpty { return 1 }
        if messages.isEmpty && hasInitialLoaded { return 2 }
        if !messages.isEmpty { return 3 }
        return -1
    }
    
    @ViewBuilder
    private var contentBody: some View {
        if isLoading && messages.isEmpty {
            loadingView
                .transition(.opacity)
        } else if let error = loadError, messages.isEmpty {
            errorStateView(error)
                .transition(.opacity)
        } else if messages.isEmpty && hasInitialLoaded {
            emptyStateView
                .transition(.opacity)
        } else if !messages.isEmpty {
            messageListContent
                .transition(.opacity)
        } else {
            Color.clear
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 筛选栏
                filterBarView
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                
                contentBody
            }
            .animation(.easeInOut(duration: 0.25), value: contentState)
            .background(Color("background").ignoresSafeArea())
            .navigationTitle("消息中心")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !messages.isEmpty {
                        Button(isEditMode ? "完成" : "编辑") {
                            withAnimation {
                                isEditMode.toggle()
                                if !isEditMode {
                                    selectedIds.removeAll()
                                }
                            }
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.theme(.primary))
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if isEditMode && !selectedIds.isEmpty {
                        Button(role: .destructive) {
                            deleteSelectedMessages()
                        } label: {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                        }
                    } else if unreadCount > 0 && !isEditMode {
                        Button {
                            markAllAsRead()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                Text("全部已读")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(Color.theme(.primary))
                        }
                    } else {
                        Button("关闭") {
                            isPresented = false
                        }
                        .font(.system(size: 15))
                        .foregroundColor(Color("text_secondary"))
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !messages.isEmpty && isEditMode {
                    bottomActionBar
                }
            }
        }
        .presentationDetents([.large])
        .withLocalPop(popManager)
        .task {
            await fetchMessages(reset: true)
            hasInitialLoaded = true
        }
        .refreshable {
            await fetchMessages(reset: true)
        }
        .onChange(of: filterState) { _ in
            Task {
                isEditMode = false
                selectedIds.removeAll()
                await fetchMessages(reset: true)
            }
        }
        // 详情页里"打开 AI 对话"按钮写完 pendingAiChatConversationId 后，
        // Index 会切到 AI Tab，但消息 Sheet 还在这里，需要主动关掉避免遮挡。
        // 列表层直达的 AI 消息也走这条路径，isPresented = false 是冗余兜底
        .onChange(of: globalModel.pendingAiChatConversationId) { _, newValue in
            if newValue != nil {
                isPresented = false
            }
        }
    }
    
    // MARK: - 加载中
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("加载中...")
                .font(.system(size: 14))
                .foregroundColor(Color("text_secondary"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 错误状态
    private func errorStateView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundColor(Color("text_secondary").opacity(0.4))
            
            Text(error)
                .font(.system(size: 15))
                .foregroundColor(Color("text_secondary"))
            
            Button {
                Task { await fetchMessages(reset: true) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("重新加载")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.theme(.primary))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.theme(.primary).opacity(0.12))
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 空状态
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 48))
                .foregroundColor(Color("text_secondary").opacity(0.4))
            
            Text("暂无消息")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color("text_secondary"))
            
            Text("您将在这里收到健康提醒和系统通知")
                .font(.system(size: 13))
                .foregroundColor(Color("text_secondary").opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 筛选栏
    private var filterBarView: some View {
        GlassPillSegmentedSelector(
            selection: Binding<Int>(
                get: { MessageFilter.allCases.firstIndex(of: filterState) ?? 0 },
                set: { filterState = MessageFilter.allCases[$0] }
            ),
            titles: MessageFilter.allCases.map { $0.rawValue }
        )
    }
    
    // MARK: - 消息列表（卡片式）
    private var messageListContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                ForEach(Array(filteredMessages.enumerated()), id: \.element.id) { index, message in
                    if isEditMode {
                        messageRowEditView(message: message)
                            .padding(.horizontal, 16)
                    } else {
                        Group {
                            if message.redirectType == "AIChat" {
                                Button {
                                    if let conversationId = message.redirectParams?["conversationId"] {
                                        globalModel.pendingAiChatConversationId = conversationId
                                    }
                                    markAsRead(message)
                                    isPresented = false
                                } label: {
                                    messageRowView(message: message)
                                }
                            } else {
                                NavigationLink(destination: MessageDetailRouter(message: message, onDelete: {
                                    withAnimation {
                                        messages.removeAll { $0.id == message.id }
                                    }
                                    onUnreadCountRefresh?()
                                })
                                    .onAppear { markAsRead(message) }
                                ) {
                                    messageRowView(message: message)
                                }
                            }
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .padding(.horizontal, 16)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteMessage(message)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                            
                            if !message.isRead {
                                Button {
                                    toggleReadStatus(message)
                                } label: {
                                    Label("已读", systemImage: "checkmark")
                                }
                                .tint(Color.theme(.primary))
                            }
                        }
                    }
                    
                    // 加载更多触发
                    if index == filteredMessages.count - 1 && hasMoreData && !isLoadingMore {
                        loadMoreTrigger
                    }
                }
                
                // 底部加载指示器
                if isLoadingMore {
                    loadMoreIndicator
                } else if !hasMoreData && !messages.isEmpty {
                    noMoreDataView
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(Color("background"))
    }
    
    // MARK: - 加载更多触发
    private var loadMoreTrigger: some View {
        Color.clear
            .frame(height: 1)
            .onAppear {
                Task { await fetchMessages(reset: false) }
            }
    }
    
    // MARK: - 加载更多指示器
    private var loadMoreIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("加载更多...")
                .font(.system(size: 12))
                .foregroundColor(Color("text_secondary"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
    
    // MARK: - 没有更多数据
    private var noMoreDataView: some View {
        Text("— 没有更多消息了 —")
            .font(.system(size: 12))
            .foregroundColor(Color("text_secondary").opacity(0.5))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
    }
    
    // MARK: - 消息卡片（普通模式）
    private func messageRowView(message: MessageNotification) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // 类型图标
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(message.type.color.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: message.type.icon)
                    .font(.system(size: 18))
                    .foregroundColor(message.type.color)
            }

            VStack(alignment: .leading, spacing: 6) {
                // 标题行
                HStack(alignment: .top) {
                    HStack(spacing: 6) {
                        Text(message.title)
                            .font(.system(size: 15, weight: message.isRead ? .regular : .semibold))
                            .foregroundColor(AppColor.textPrimary)
                            .lineLimit(1)

                        if !message.isRead {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                    Spacer(minLength: 8)

                    Text(message.formattedTime)
                        .font(.system(size: 11))
                        .foregroundColor(AppColor.textSecondary)
                        .padding(.top, 2)
                }

                // 内容摘要
                Text(message.content)
                    .font(.system(size: 13))
                    .foregroundColor(AppColor.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCardStyle(
            .regular.interactive().tint(AppColor.content.opacity(0.65)),
            cornerRadius: 16
        )
    }
    
    // MARK: - 消息行（编辑模式）
    private func messageRowEditView(message: MessageNotification) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                toggleSelection(message.id)
            } label: {
                Image(systemName: selectedIds.contains(message.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(selectedIds.contains(message.id) ? AppColor.primary : AppColor.textSecondary.opacity(0.35))
            }
            .buttonStyle(PlainButtonStyle())

            // 类型图标
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(message.type.color.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: message.type.icon)
                    .font(.system(size: 16))
                    .foregroundColor(message.type.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(message.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColor.textPrimary)
                    .lineLimit(1)

                Text(message.formattedTime)
                    .font(.system(size: 11))
                    .foregroundColor(AppColor.textSecondary)
            }

            Spacer()

            if !message.isRead {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCardStyle(
            selectedIds.contains(message.id)
                ? .regular.interactive().tint(AppColor.primary.opacity(0.18))
                : .regular.interactive().tint(AppColor.content.opacity(0.65)),
            cornerRadius: 16
        )
        .animation(.spring(response: 0.3), value: selectedIds)
    }
    
    // MARK: - 底部操作栏（编辑模式）
    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                // 全选/取消全选
                Button {
                    selectAllOrNone()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: selectedIds.count == messages.count ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                        Text(selectedIds.count == messages.count ? "取消全选" : "全选")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(Color.theme(.primary))
                }
                
                Spacer()
                
                // 已选数量
                Text("已选 \(selectedIds.count) 条")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text_secondary"))
                
                Spacer()
                
                // 删除选中
                Button(role: .destructive) {
                    if !selectedIds.isEmpty {
                        deleteSelectedMessages()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                        Text("删除")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(selectedIds.isEmpty ? Color("text_secondary").opacity(0.5) : .red)
                }
                .disabled(selectedIds.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color("background"))
        }
    }
    
    // MARK: - 网络请求
    
    private func fetchMessages(reset: Bool) async {
        guard !isLoading else { return }
        
        isLoading = true
        if !reset { isLoadingMore = true } else { loadError = nil }
        if reset { currentPage = 1 }
        
        let page = currentPage
        let isReadParam: Int16? = filterState == .all ? nil : (filterState == .unread ? 0 : 1)
        let params = MessagePageParam(
            pageNumber: page,
            pageSize: pageSize,
            isRead: isReadParam,
            senderType: nil
        )
        
        await withCheckedContinuation { continuation in
            MessageApiService.getMessagePage(
                params: params,
                completion: { newMessages, total in
                    DispatchQueue.main.async {
                        if reset {
                            messages = newMessages
                        } else {
                            messages.append(contentsOf: newMessages)
                        }
                        totalMessages = total
                        currentPage = Int16(page) + 1
                        isLoading = false
                        isLoadingMore = false
                        continuation.resume()
                    }
                },
                errorHandle: { _, _ in
                    DispatchQueue.main.async {
                        if reset {
                            loadError = "加载失败，请下拉刷新重试"
                        }
                        isLoading = false
                        isLoadingMore = false
                        continuation.resume()
                    }
                },
                popManager: popManager
            )
        }
    }

    // MARK: - 操作方法

    private func markAsRead(_ message: MessageNotification) {
        MessageApiService.markAsRead(
            id: message.id,
            completion: { [self] in
                withAnimation(.easeInOut(duration: 0.3)) {
                    if let index = messages.firstIndex(where: { $0.id == message.id }) {
                        messages[index].isRead = true
                    }
                }
                onUnreadCountRefresh?()
            },
            popManager: popManager
        )
    }

    private func toggleReadStatus(_ message: MessageNotification) {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        messages[index].isRead.toggle()
    }

    private func markAllAsRead() {
        MessageApiService.readAll(
            completion: { [self] in
                withAnimation(.easeInOut(duration: 0.3)) {
                    for index in messages.indices {
                        messages[index].isRead = true
                    }
                }
                onUnreadCountRefresh?()
            },
            popManager: popManager
        )
    }

    private func deleteMessage(_ message: MessageNotification) {
        MessageApiService.batchDelete(
            ids: [message.id],
            completion: { [self] in
                withAnimation {
                    messages.removeAll { $0.id == message.id }
                }
                onUnreadCountRefresh?()
            },
            popManager: popManager
        )
    }

    private func toggleSelection(_ id: String) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    private func selectAllOrNone() {
        if selectedIds.count == messages.count {
            selectedIds.removeAll()
        } else {
            selectedIds = Set(messages.map { $0.id })
        }
    }

    private func deleteSelectedMessages() {
        let ids = Array(selectedIds)
        MessageApiService.batchDelete(
            ids: ids,
            completion: { [self] in
                withAnimation {
                    messages.removeAll { selectedIds.contains($0.id) }
                    selectedIds.removeAll()
                    isEditMode = false
                }
                onUnreadCountRefresh?()
            },
            popManager: popManager
        )
    }
}

// MARK: - 组合视图：按钮 + Sheet
struct MessageNotificationView: View {
    // 首页刷新事件总线
    @EnvironmentObject var refreshBus: HomeRefreshBus
    @State private var showSheet = false
    @State private var unreadCount: Int = 0
    @State private var popManager: PopManager = PopManager()

    var body: some View {
        MessageNotificationButton(unreadCount: $unreadCount, showSheet: $showSheet)
            .onAppear {
                loadUnreadCount()
            }
            .onChange(of: refreshBus.refreshTrigger) { _, _ in
                loadUnreadCount()
            }
            .sheet(isPresented: $showSheet, onDismiss: {
                loadUnreadCount()
            }) {
                MessageListView(isPresented: $showSheet, onUnreadCountRefresh: {
                    loadUnreadCount()
                })
            }
    }

    private func loadUnreadCount() {
        MessageApiService.getUnreadCount(
            completion: { count in
                unreadCount = count
            },
            popManager: popManager
        )
    }
}

#Preview {
    VStack {
        HStack {
            Spacer()
            MessageNotificationView()
        }
        .padding(.horizontal, 20)
        Spacer()
    }
}
