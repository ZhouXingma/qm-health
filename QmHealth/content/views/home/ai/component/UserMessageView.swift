//
//  UserMessageView.swift
//  QmHealth
//
//  Created by 周荥马 on 2026/2/10.
//

import SwiftUI
import UIKit

// 用户消息视图 - 根据消息类型显示不同内容
struct UserMessageView: View {
    @ObservedObject var message: DisplayChatMessage
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // 遍历 contents，根据类型显示对应内容
            ForEach(Array(message.contents.enumerated()), id: \.offset) { index, content in
                switch content {
                case .text(let textBlock):
                    UserTextMessageView(text: textBlock.text)
                    
                case .file(let fileBlock):
                    UserFileMessageView(
                        fileId: fileBlock.fileId,
                        fileName: fileBlock.fileName ?? "",
                        fileType: fileBlock.fileType
                    )
                    
                case .interactiveHandle(_):
                    // interactiveHandle 消息由 AIMessageView 处理，此处不渲染
                    EmptyView()
                    
                default:
                    // 其他类型暂不显示
                    EmptyView()
                }
            }
            
            HStack {
                Text(formatTime(message.timestamp))
                    .font(.system(size: 11))
                    .foregroundStyle(Color("text_secondary").opacity(0.6))
                    .padding(.trailing, 4)
            }
        }
    }
    
    private func formatTime(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// 用户文本消息
struct UserTextMessageView: View {
    let text: String
    
    var body: some View {
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(text)
                .font(.system(size: 16))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(ChatTheme.userBubbleGradient)
                .textSelection(.enabled)
                .clipShape(
                    .rect(
                        topLeadingRadius: ChatTheme.radiusLg,
                        bottomLeadingRadius: ChatTheme.radiusLg,
                        bottomTrailingRadius: 6,
                        topTrailingRadius: ChatTheme.radiusLg
                    )
                )
                .shadow(color: ChatTheme.accent.opacity(0.25), radius: 10, x: 0, y: 4)
        }
    }
}

// 用户文件消息 - 根据 fileType 决定显示图片还是文件图标
struct UserFileMessageView: View {
    let fileId: String
    let fileName: String
    let fileType: String
    
    @State private var imageData: Data? = nil
    @State private var isLoadingImage: Bool = false
    @State private var previewImage: _PreviewImage? = nil
    
    private var isImage: Bool { fileType == ChatFileType.image.rawValue }
    
    var body: some View {
        Group {
            if isImage {
                imageContent
            } else {
                fileContent
            }
        }
        .onAppear {
            if isImage && imageData == nil {
                loadImage()
            }
        }
    }
    
    // MARK: - 图片展示
    private var imageContent: some View {
        Group {
            if let data = imageData, let uiImage = UIImage(data: data) {
                Button {
                    previewImage = _PreviewImage(image: uiImage)
                } label: {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 180, height: 180)
                        .clipShape(
                            .rect(
                                topLeadingRadius: 20,
                                bottomLeadingRadius: 20,
                                bottomTrailingRadius: 4,
                                topTrailingRadius: 20
                            )
                        )
                        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .sheet(item: $previewImage) { item in
                    _ChatImageViewer(image: item.image)
                }
            } else {
                // 加载中占位
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.theme(.primary).opacity(0.15))
                        .frame(width: 180, height: 180)
                    if isLoadingImage {
                        ProgressView()
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 32))
                            .foregroundStyle(Color("text_secondary").opacity(0.4))
                    }
                }
            }
        }
    }
    
    // MARK: - 文件展示
    private var fileContent: some View {
        HStack(spacing: 8) {
            Image(systemName: fileIconName)
                .font(.system(size: 16))
                .foregroundStyle(Color.white)
            
            Text(fileName.isEmpty ? fileId : fileName)
                .font(.system(size: 14))
                .foregroundStyle(Color.white)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ChatTheme.userBubbleGradient)
        .clipShape(
            .rect(
                topLeadingRadius: ChatTheme.radiusLg,
                bottomLeadingRadius: ChatTheme.radiusLg,
                bottomTrailingRadius: 6,
                topTrailingRadius: ChatTheme.radiusLg
            )
        )
        .shadow(color: ChatTheme.accent.opacity(0.25), radius: 10, x: 0, y: 4)
    }
    
    private var fileIconName: String {
        switch fileType {
        case ChatFileType.pdf.rawValue: return "doc.richtext.fill"
        case ChatFileType.doc.rawValue: return "doc.text.fill"
        case ChatFileType.md.rawValue:  return "doc.plaintext.fill"
        default:                        return "doc.fill"
        }
    }
    
    private func loadImage() {
        isLoadingImage = true
        let urlString = apiUrl(FILE_LOAD + "/\(fileId)")
        BgResultNetWork<Empty, Data>(urlString, method: .get)
            .complicationHand { data in
                self.imageData = data
                self.isLoadingImage = false
            }
            .errorHandle { _, _ in
                self.isLoadingImage = false
            }
            .response()
    }
}

private struct _PreviewImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

// 图片全屏预览（供 UserFileMessageView 使用）
private struct _ChatImageViewer: View {
    let image: UIImage
    
    @Environment(\.dismiss) var dismiss
    @State private var baseScale: CGFloat = 1.0
    @GestureState private var gestureScale: CGFloat = 1.0
    @State private var baseOffset: CGSize = .zero
    @GestureState private var gestureOffset: CGSize = .zero
    @State private var rotation: Angle = .zero

    private var effectiveScale: CGFloat {
        min(max(baseScale * gestureScale, 1.0), 5.0)
    }
    
    private var effectiveOffset: CGSize {
        guard effectiveScale > 1 else { return .zero }
        return CGSize(
            width: baseOffset.width + gestureOffset.width,
            height: baseOffset.height + gestureOffset.height
        )
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                LinearGradient(
                    colors: [Color(.secondarySystemBackground), Color(.systemBackground)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                GeometryReader { _ in
                    ZStack {
                        Color.clear
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .scaleEffect(effectiveScale)
                            .rotationEffect(rotation)
                            .offset(effectiveOffset)
                            .highPriorityGesture(
                                DragGesture(minimumDistance: 1)
                                    .updating($gestureOffset) { value, state, _ in
                                        state = value.translation
                                    }
                                    .onEnded { value in
                                        guard baseScale > 1.0 else {
                                            baseOffset = .zero
                                            return
                                        }
                                        baseOffset = CGSize(
                                            width: baseOffset.width + value.translation.width,
                                            height: baseOffset.height + value.translation.height
                                        )
                                    }
                            )
                            .simultaneousGesture(
                                MagnificationGesture()
                                    .updating($gestureScale) { value, state, _ in
                                        state = value
                                    }
                                    .onEnded { value in
                                        let newScale = baseScale * value
                                        baseScale = min(max(newScale, 1.0), 5.0)
                                        if baseScale == 1.0 { baseOffset = .zero }
                                    }
                            )
                            .onTapGesture(count: 2) {
                                withAnimation(.spring(response: 0.3)) {
                                    if baseScale > 1.0 {
                                        baseScale = 1.0
                                        baseOffset = .zero
                                    } else {
                                        baseScale = 2.0
                                    }
                                }
                            }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            rotation = Angle(degrees: rotation.degrees + 90)
                        }
                    } label: {
                        Image(systemName: "rotate.right")
                    }
                }
            }
        }
    }
}


