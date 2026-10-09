import SwiftUI

// MARK: - 消息详情页
struct MessageDetailView: View {
    @EnvironmentObject var globalModel: GlobalModel
    @Environment(\.dismiss) private var dismiss
    let message: MessageNotification
    var onDelete: (() -> Void)?
    @State private var showDeleteAlert = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // 顶部类型横幅
                typeBannerView

                // 内容卡片
                contentCardView

                // 智能体消息专属操作：跳转到 AI 对话
                if message.type == .ai || message.senderType == .ai || message.redirectType == "AIChat" {
                    openAiChatButton
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 30)
        }
        .background(Color("background").ignoresSafeArea())
        .navigationTitle("消息详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                }
            }
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteMessage()
            }
        } message: {
            Text("确定要删除这条消息吗？")
        }
    }

    /// 跳转到 AI 对话：写 pendingAiChatConversationId（外层 Index 会切到 AI Tab），
    /// 标记已读，然后 dismiss 详情页（消息 Sheet 会通过 onChange 监听自动关闭）。
    private func openAiChat() {
        if let conversationId = message.redirectParams?["conversationId"] {
            globalModel.pendingAiChatConversationId = conversationId
        }
        // 标记已读
        MessageApiService.markAsRead(
            id: message.id,
            completion: { },
            popManager: PopManager()
        )
        dismiss()
    }

    // MARK: - 打开 AI 对话按钮（仅智能体消息显示）
    private var openAiChatButton: some View {
        Button(action: openAiChat) {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("打开 AI 对话")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(PrimaryActionButtonStyle(
            tint: message.type.color,
            cornerRadius: 14
        ))
    }
    
    private func deleteMessage() {
        MessageApiService.batchDelete(ids: [message.id]) {
            self.onDelete?()
            self.dismiss()
        }
    }
    
    // MARK: - 类型横幅
    private var typeBannerView: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.white.opacity(0.25))
                    .frame(width: 48, height: 48)
                
                Image(systemName: message.type.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(message.type.label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                
                Text(message.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(message.type.color.gradient)
        )
    }
    
    // MARK: - 内容卡片
    private var contentCardView: some View {
        VStack(spacing: 0) {
            // 时间
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 13))
                    .foregroundColor(AppColor.textSecondary)

                Text(message.formattedTimeDetail)
                    .font(.system(size: 14))
                    .foregroundColor(AppColor.textSecondary)

                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)

            // 分割线
            Divider()
                .padding(.leading, 18)

            // 内容
            Text(message.content)
                .font(.system(size: 16))
                .foregroundColor(AppColor.textPrimary)
                .lineSpacing(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity)
        .glassContainer(
            .regular.interactive().tint(AppColor.content.opacity(0.65)),
            cornerRadius: 18
        )
    }
}

// MARK: - 消息详情的路由（按类型分发）
struct MessageDetailRouter: View {
    let message: MessageNotification
    var onDelete: (() -> Void)?
    @EnvironmentObject var globalModel: GlobalModel
    
    var body: some View {
        switch message.type {
        case .healthReminder:
            MessageDetailView(message: message, onDelete: onDelete)
        case .system:
            MessageDetailView(message: message, onDelete: onDelete)
        case .medication:
            MessageDetailView(message: message, onDelete: onDelete)
        case .appointment:
            MessageDetailView(message: message, onDelete: onDelete)
        case .ai:
            MessageDetailView(message: message, onDelete: onDelete)
        case .otherUser:
            MessageDetailView(message: message, onDelete: onDelete)
        }
    }
}

// MARK: - 时间格式扩展
extension MessageNotification {
    var formattedTimeDetail: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        return formatter.string(from: time)
    }
}

#Preview {
    NavigationView {
        MessageDetailView(
            message: MessageNotification(
                id: "1",
                type: .healthReminder,
                title: "血压测量提醒",
                content: "您已连续3天未测量血压，请及时测量并记录。保持规律的血压监测有助于及时发现异常，建议每天早晚各测量一次。",
                time: Date(),
                isRead: false,
                senderType: nil,
                redirectType: nil,
                redirectParams: nil
            )
        )
    }
}
