//
//  AIConfigListView.swift
//  QmHealth
//
//  AI 模型配置 - 列表页
//
//  - 顶部 Header：标题 + 副标题 + 添加按钮（无背景）
//  - 用途 Tab：主智能体 / OCR 识别
//  - 当前用途下显示已配置的模型列表
//  - 每项：图标 + 模型类型名 + 模型名 + 启用/停用徽章 + 多模态标识，点击进入编辑
//  - 卡片使用液态玻璃效果
//  - 左滑删除
//

import SwiftUI

struct AIConfigListView: View {
    @Environment(\.dismiss) var dismiss

    /// 当前选中的用途 Tab
    @State private var selectedPurpose: AIModelPurpose = .main
    /// 所有已配置列表
    @State private var allConfigs: [UsersModelConfigDTO] = []
    /// 加载状态
    @State private var isLoading: Bool = true
    /// 当前正在删除的 id
    @State private var deletingId: String? = nil
    /// 弹出新增/编辑 sheet 的目标
    @State private var editingTarget: EditingTarget? = nil

    @StateObject private var popManager = PopManager()

    /// 触发编辑/新增的中间态
    private enum EditingTarget: Identifiable {
        case add(initialPurpose: AIModelPurpose)
        case edit(dto: UsersModelConfigDTO)

        var id: String {
            switch self {
            case .add(let p): return "add-\(p.rawValue)"
            case .edit(let dto): return "edit-\(dto.id ?? UUID().uuidString)"
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                purposeTabs
                content
            }
            .pageBackground()
            .navigationTitle("AI 模型")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(AppColor.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        editingTarget = .add(initialPurpose: selectedPurpose)
                    } label: {
                        // 无背景的 + 按钮
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(AppColor.primary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .withLocalPop(popManager)
        .onAppear {
            loadList()
        }
        .sheet(item: $editingTarget) { target in
            switch target {
            case .add(let purpose):
                AIModelConfigEditView(
                    editingDTO: nil,
                    initialPurpose: purpose,
                    allConfigs: allConfigs
                )
            case .edit(let dto):
                AIModelConfigEditView(
                    editingDTO: dto,
                    initialPurpose: nil,
                    allConfigs: allConfigs
                )
            }
        }
        .onChange(of: editingTarget?.id) { _, newValue in
            // sheet 关闭后刷新列表（id 从有值变为 nil）
            if newValue == nil {
                loadList()
            }
        }
    }

    // MARK: - 用途 Tab

    private var purposeTabs: some View {
        HStack(spacing: 0) {
            ForEach(AIModelPurpose.allCases) { p in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPurpose = p
                    }
                } label: {
                    VStack(spacing: 8) {
                        HStack(spacing: 5) {
                            Image(systemName: p.icon)
                                .font(.system(size: 12))
                            Text(p.displayName)
                                .font(.system(size: 14, weight: selectedPurpose == p ? .semibold : .regular))
                        }
                        .foregroundStyle(selectedPurpose == p ? AppColor.primary : AppColor.textSecondary)
                        Capsule()
                            .fill(selectedPurpose == p ? AppColor.primary : Color.clear)
                            .frame(height: 2.5)
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.screen)
        .padding(.bottom, 8)
    }

    // MARK: - 内容区

    @ViewBuilder
    private var content: some View {
        let filtered = allConfigs.filter { $0.purpose == selectedPurpose.rawValue }
        if isLoading {
            VStack(spacing: 12) {
                ProgressView().scaleEffect(1.2)
                Text("加载中...")
                    .font(.system(size: 12))
                    .foregroundColor(AppColor.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filtered.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(filtered, id: \.id) { dto in
                        configCard(dto)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    confirmDelete(dto)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(.horizontal, AppSpacing.screen)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray")
                .font(.system(size: 44))
                .foregroundColor(AppColor.textSecondary.opacity(0.6))
            Text("暂无\(selectedPurpose.displayName)配置")
                .font(.system(size: 14))
                .foregroundColor(AppColor.textSecondary)
            Button {
                editingTarget = .add(initialPurpose: selectedPurpose)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("添加")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(Capsule().fill(AppColor.primary))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }

    private func configCard(_ dto: UsersModelConfigDTO) -> some View {
        let type = dto.modelTypeEnum ?? .deepseek
        return Button {
            editingTarget = .edit(dto: dto)
        } label: {
            HStack(spacing: 12) {
                // 模型类型图标
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(type.color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: type.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(type.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(dto.modelName ?? "未命名模型")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColor.textPrimary)
                            .lineLimit(1)
                        if dto.isMultimodalFlag {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 11))
                                .foregroundStyle(.pink)
                        }
                    }
                    HStack(spacing: 6) {
                        Text(type.displayName)
                            .font(.system(size: 11))
                            .foregroundStyle(type.color)
                        Text("·")
                            .font(.system(size: 11))
                            .foregroundStyle(AppColor.textSecondary)
                        Text(dto.baseUrl ?? "")
                            .font(.system(size: 11))
                            .foregroundStyle(AppColor.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Spacer()

                // 启用/停用状态徽章
                statusBadge(dto: dto)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.clear)   // 先 fill clear，再叠液态玻璃
            .appGlass(.clear.interactive(), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        // 长按弹出系统级菜单：编辑 / 删除
        .contextMenu {
            Button {
                editingTarget = .edit(dto: dto)
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            Button(role: .destructive) {
                confirmDelete(dto)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    /// 启用状态徽章：启用=绿色 + "启用中"，停用=灰色 + "已停用"
    @ViewBuilder
    private func statusBadge(dto: UsersModelConfigDTO) -> some View {
        if dto.isEnabled {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text("启用中")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.green)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.green.opacity(0.12)))
        } else {
            Text("已停用")
                .font(.system(size: 10))
                .foregroundStyle(AppColor.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(AppColor.textSecondary.opacity(0.15)))
        }
    }

    // MARK: - 数据

    private func loadList() {
        isLoading = true
        UsersModelConfigApi.list(completion: { list in
            DispatchQueue.main.async {
                allConfigs = list
                isLoading = false
            }
        }, errorHandle: { _, error in
            DispatchQueue.main.async {
                isLoading = false
                popManager.showSimplePop(title: "提示", description: "加载配置失败：\(error)")
            }
        }, popManager: popManager)
    }

    private func confirmDelete(_ dto: UsersModelConfigDTO) {
        guard let id = dto.id, deletingId == nil else { return }
        deletingId = id
        UsersModelConfigApi.delete(id: id, completion: {
            DispatchQueue.main.async {
                deletingId = nil
                allConfigs.removeAll { $0.id == id }
                popManager.showSimplePop(title: "成功", description: "已删除")
            }
        }, errorHandle: { _, error in
            DispatchQueue.main.async {
                deletingId = nil
                popManager.showSimplePop(title: "失败", description: "删除失败：\(error)")
            }
        }, popManager: popManager)
    }
}

#Preview {
    AIConfigListView()
}
