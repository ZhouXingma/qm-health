//
//  ChatHistorySidebar.swift
//  QmHealth
//
//  Created by Kiro on 2026/2/23.
//

import SwiftUI
import Combine

// MARK: - 聊天历史 ViewModel
///
/// 将数据加载/分页/删除逻辑从 View 中抽出来，交由独立的 ObservableObject 管理。
/// 这样做主要是为了绕开 SwiftUI 的一个常见陷阱：如果只把状态放在 View 自己的
/// `@State` 里，并依赖 `.onAppear` 触发加载，当同一个 `.sheet` 在短时间内
/// 被关闭又重新打开时，SwiftUI 有时会复用旧的视图身份，`@State` 不会被重置，
/// `.onAppear` 也不会重新触发，界面就会停留在上一次打开时的旧数据上
/// （表现上很像"缓存不刷新"，但根因是视图没有被重建，而不是网络层缓存）。
///
/// 现在的方案是：ViewModel 的生命周期完全跟随 Sheet 的展示/关闭
/// （在 AiChatMain 中通过 `.id()` 强制每次打开都重新创建 ChatHistorySheet），
/// 从而保证每次打开历史列表都会发起一次全新的请求。
@MainActor
final class ChatHistoryViewModel: ObservableObject {
    @Published var chatHistory: [GroupedChatHistory] = []
    @Published var isLoading = false
    @Published var hasMoreData = true
    @Published var totalCount = 0

    private var currentPage = 1
    let pageSize = 20

    /// 运行状态轮询定时器：仅当列表中存在 running == true 的会话时才启动，
    /// 所有会话都结束后自动停止，避免无条件轮询浪费请求
    private var refreshTimer: AnyCancellable?
    /// 定时刷新是否正在进行（独立于 isLoading，避免刷新时干扰列表底部"加载更多"的 UI 与请求）
    private var isRefreshing = false

    /// 定时刷新间隔（秒）
    private let refreshInterval: TimeInterval = 5

    /// 当前列表里是否有会话仍在运行
    private var hasRunningConversation: Bool {
        chatHistory.contains { $0.items.contains { $0.running == true } }
    }

    deinit {
        refreshTimer?.cancel()
    }

    /// 是否已经完成过第一次加载（用于区分"首次加载中"和"加载更多中"）
    var hasLoadedOnce: Bool { !chatHistory.isEmpty || (!isLoading && totalCount == 0 && !hasMoreData) }

    /// 首次加载 / 下拉刷新：重置分页状态并重新请求第一页
    func reload(popManager: PopManager) {
        guard !isLoading else { return }

        isLoading = true
        currentPage = 1

        let params = ChatHistoryRequest(pageNumber: currentPage, pageSize: pageSize)

        BgResultNetWork<ChatHistoryRequest, ChatHistoryResponse>.post(
            aiUrl(AI_CHAT_HISTORY),
            params: params,
            popManager: popManager
        )
        .complicationHand { [weak self] (response: ChatHistoryResponse?) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false

                guard let response = response else { return }

                self.totalCount = response.totalCount
                self.hasMoreData = response.results.count >= self.pageSize
                self.chatHistory = self.groupChatHistory(response.results)
                // 存在运行中的会话则启动定时刷新，否则停止
                self.updateRefreshTimer()
            }
        }
        .errorHandle { [weak self] _, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                popManager.showSimplePop(title: "提示", description: "加载失败：\(error)")
            }
        }
        .responseDecodable()
    }

    /// 加载下一页
    func loadMore(popManager: PopManager) {
        guard !isLoading && hasMoreData else { return }

        isLoading = true
        currentPage += 1

        let params = ChatHistoryRequest(pageNumber: currentPage, pageSize: pageSize)

        BgResultNetWork<ChatHistoryRequest, ChatHistoryResponse>.post(
            aiUrl(AI_CHAT_HISTORY),
            params: params,
            popManager: popManager
        )
        .complicationHand { [weak self] (response: ChatHistoryResponse?) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false

                guard let response = response else { return }

                self.hasMoreData = response.results.count >= self.pageSize
                let allItems = self.chatHistory.flatMap { $0.items } + response.results
                self.chatHistory = self.groupChatHistory(allItems)
                self.updateRefreshTimer()
            }
        }
        .errorHandle { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.currentPage -= 1
            }
        }
        .responseDecodable()
    }

    /// 批量删除会话，成功后从本地列表中移除
    func delete(ids: [String], popManager: PopManager, completion: @escaping (Bool) -> Void) {
        BgResultNetWork<[String], Empty>.post(
            aiUrl(AI_CHAT_BATCH_DELETE),
            params: ids,
            popManager: popManager
        )
        .complicationHand { [weak self] (_: Empty?) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.chatHistory = self.chatHistory.compactMap { group in
                    let filteredItems = group.items.filter { !ids.contains($0.id) }
                    if filteredItems.isEmpty { return nil }
                    return GroupedChatHistory(dateTitle: group.dateTitle, items: filteredItems)
                }
                // 若被删除的正是运行中的会话，需要同步检查并停止刷新
                self.updateRefreshTimer()
                completion(true)
            }
        }
        .errorHandle { _, error in
            DispatchQueue.main.async {
                popManager.showSimplePop(title: "提示", description: "删除失败：\(error)")
                completion(false)
            }
        }
        .responseDecodable()
    }

    private func groupChatHistory(_ items: [ChatHistoryItem]) -> [GroupedChatHistory] {
        let grouped = Dictionary(grouping: items) { $0.dateGroupTitle }

        let sortedKeys = grouped.keys.sorted { key1, key2 in
            if key1 == "今天" { return true }
            if key2 == "今天" { return false }
            if key1 == "昨天" { return true }
            if key2 == "昨天" { return false }
            return key1 > key2
        }

        return sortedKeys.map { key in
            let sortedItems = grouped[key]?.sorted {
                $0.modifiedDate > $1.modifiedDate
            } ?? []
            return GroupedChatHistory(dateTitle: key, items: sortedItems)
        }
    }

    // MARK: - 运行状态定时刷新
    ///
    /// 按需轮询：仅当列表中存在 running == true 的会话时启动定时器，
    /// 每次刷新拿到最新第一页后重新判断，所有会话都结束后立即停止刷新。
    /// 这样既能让"运行中"闪烁点随会话结束自动消失，又不会在没有任何
    /// 会话运行时继续发请求。

    /// 根据当前列表是否存在运行中的会话，决定启动还是停止定时刷新
    private func updateRefreshTimer() {
        if hasRunningConversation {
            startRefreshTimerIfNeeded()
        } else {
            stopRefreshTimer()
        }
    }

    private func startRefreshTimerIfNeeded() {
        guard refreshTimer == nil else { return }
        refreshTimer = Timer.publish(every: refreshInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshRunningStatus()
            }
    }

    private func stopRefreshTimer() {
        refreshTimer?.cancel()
        refreshTimer = nil
    }

    /// 定时刷新：只拉取第一页并合并进当前列表，用于更新 running 状态与标题
    private func refreshRunningStatus() {
        guard !isLoading, !isRefreshing else { return }
        isRefreshing = true

        let params = ChatHistoryRequest(pageNumber: 1, pageSize: pageSize)
        // 定时刷新属于静默操作，不依赖 View 的 popManager，失败也不弹窗打扰用户
        BgResultNetWork<ChatHistoryRequest, ChatHistoryResponse>.post(
            aiUrl(AI_CHAT_HISTORY),
            params: params
        )
        .complicationHand { [weak self] (response: ChatHistoryResponse?) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isRefreshing = false
                guard let response = response else { return }

                // 用最新第一页替换列表中对应的项（running 会话必定最新、排在最前），
                // 其余已加载的后续页保持不变，避免刷新导致用户已加载的列表缩短
                let currentItems = self.chatHistory.flatMap { $0.items }
                let newIds = Set(response.results.map { $0.id })
                let remaining = currentItems.filter { !newIds.contains($0.id) }
                self.totalCount = response.totalCount
                self.chatHistory = self.groupChatHistory(response.results + remaining)
                // 重新判断是否仍有运行中的会话，没有则停止刷新
                self.updateRefreshTimer()
            }
        }
        .errorHandle { [weak self] _, _ in
            DispatchQueue.main.async {
                // 刷新失败不打断轮询，下一轮继续尝试
                self?.isRefreshing = false
            }
        }
        .responseDecodable()
    }
}

// MARK: - 聊天历史 Sheet
struct ChatHistorySheet: View {
    @Binding var isPresented: Bool
    var onSelectConversation: ((String) -> Void)?
    var onNewConversation: (() -> Void)?
    var onSettings: (() -> Void)?
    @StateObject private var viewModel = ChatHistoryViewModel()
    @State private var isEditMode = false
    @State private var selectedIds: Set<String> = []
    @State private var isDeleting = false
    @StateObject private var popManager = PopManager()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ZStack {
                    Color("background").ignoresSafeArea()
                    VStack {
                        if viewModel.isLoading && viewModel.chatHistory.isEmpty {
                            loadingView
                        } else if viewModel.chatHistory.isEmpty {
                            emptyView
                        } else {
                            historyListView
                        }
                        bottomButtonsView
                    }
                }
            }
            .navigationTitle("聊天历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !viewModel.chatHistory.isEmpty {
                        Button(isEditMode ? "完成" : "编辑") {
                            if isEditMode {
                                isEditMode = false
                                selectedIds.removeAll()
                            } else {
                                isEditMode = true
                            }
                        }
                        .font(.system(size: 15, weight: .medium))
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if isEditMode && !selectedIds.isEmpty {
                        Button(role: .destructive) {
                            deleteSelectedConversations()
                        } label: {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 16))
                        }
                    } else {
                        Button("关闭") {
                            isPresented = false
                        }
                    }
                }
            }
        }
        .withLocalPop(popManager)
        .onAppear {
            // 每次 Sheet 展示都强制重新拉取第一页，
            // 不依赖任何本地缓存，保证新会话能够立刻可见
            viewModel.reload(popManager: popManager)
        }
        .presentationDetents([.large])
    }
    
    // MARK: - 加载视图
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("加载中...")
                .font(.system(size: 14))
                .foregroundColor(Color("text_secondary"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 空状态视图
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(Color("text_secondary").opacity(0.5))
            
            Text("暂无聊天记录")
                .font(.system(size: 16))
                .foregroundColor(Color("text_secondary"))
            
            Text("开始与 AI 助手对话吧")
                .font(.system(size: 14))
                .foregroundColor(Color("text_secondary").opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 历史列表视图
    private var historyListView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(viewModel.chatHistory) { group in
                    Section {
                        ForEach(group.items) { item in
                            if isEditMode {
                                ChatHistoryItemEditView(
                                    item: item,
                                    isSelected: selectedIds.contains(item.id),
                                    onToggle: { toggleSelection(item.id) }
                                )
                            } else {
                                ChatHistoryItemView(item: item) {
                                    onSelectConversation?(item.id)
                                    isPresented = false
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text(group.dateTitle)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color("text_secondary"))
                                .textCase(.none)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                        .background(Color("background"))
                    }
                }
                
                // 加载更多
                if viewModel.hasMoreData {
                    loadMoreView
                }
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - 加载更多视图
    private var loadMoreView: some View {
        HStack(spacing: 8) {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                Text("加载中...")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text_secondary"))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .onAppear {
            viewModel.loadMore(popManager: popManager)
        }
    }
    
    // MARK: - 底部按钮视图
    private var bottomButtonsView: some View {
        HStack(spacing: 12) {
            Button {
                onNewConversation?()
                isPresented = false
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    Text("新建会话")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(Color.theme(.primary))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryActionButtonStyle())
            /*
            // 临时隐藏：AI 模型设置入口（暂不开启）
            Button {
                onSettings?()
                isPresented = false
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16))
                    Text("设置")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(Color.theme(.primary))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.theme(.primary).opacity(0.1))
                .cornerRadius(12)
            }
            */
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color("background"))
    }
    
    // MARK: - 选择管理方法
    private func toggleSelection(_ id: String) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }
    
    private func deleteSelectedConversations() {
        guard !selectedIds.isEmpty && !isDeleting else { return }
        
        isDeleting = true
        let idsToDelete = Array(selectedIds)
        
        viewModel.delete(ids: idsToDelete, popManager: popManager) { success in
            isDeleting = false
            if success {
                selectedIds.removeAll()
                isEditMode = false
                popManager.showSimplePop(title: "提示", description: "删除成功")
            }
        }
    }
}

// MARK: - 聊天历史项视图
struct ChatHistoryItemView: View {
    let item: ChatHistoryItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 8) {
                Text(item.title)
                    .font(.system(size: 15))
                    .foregroundColor(Color("text_primary"))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 会话仍在运行中时，标题右侧显示闪烁点
                if item.running == true {
                    RunningIndicatorDot()
                        .padding(.top, 5)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.01))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 运行中指示点

/// 会话运行中的闪烁指示点：实心圆点 + 一层持续放大淡出的波纹，提示该会话仍在生成回复
struct RunningIndicatorDot: View {
    @State private var pulsing = false

    var body: some View {
        ZStack {
            // 扩散波纹
            Circle()
                .stroke(Color.theme(.primary).opacity(0.5), lineWidth: 1.5)
                .frame(width: 8, height: 8)
                .scaleEffect(pulsing ? 2 : 1)
                .opacity(pulsing ? 0 : 0.9)
                .animation(
                    .easeOut(duration: 1.0).repeatForever(autoreverses: false),
                    value: pulsing
                )

            // 实心圆点
            Circle()
                .fill(Color.theme(.primary))
                .frame(width: 8, height: 8)
        }
        .frame(width: 14, height: 14)
        .onAppear {
            pulsing = true
        }
    }
}

// MARK: - 聊天历史项视图（编辑模式）
struct ChatHistoryItemEditView: View {
    let item: ChatHistoryItem
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(isSelected ? Color.theme(.primary) : Color("text_secondary"))
                    .frame(width: 24, height: 24)
                
                Text(item.title)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color("text_primary"))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.01))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ChatHistorySheet(isPresented: .constant(true))
}
