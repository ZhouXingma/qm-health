//
//  AiChatMainSubBar.swift
//  QmHealth
//
//  Created by 周荥马 on 2026/2/4.
//
// MARK: - 功能说明
// 这个文件包含 AI 聊天输入栏的主要组件，包括：
// 1. AiChatMainSubBar - 主输入栏视图
// 2. MulLineTextField - 多行文本输入框（UIViewRepresentable）
// 3. CustomTextView - 自定义 UITextView，支持 placeholder 和自定义菜单
// 4. 辅助视图 - ActionMenuView、ActionMenuChip、FullScreenTextEditor

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

// MARK: - 数据模型

/// 图片附件模型
private struct ImageAttachment: Identifiable {
    let id: String
    let data: Data
    var fileId: String?
    var fileType: ChatFileType = .image
}

// MARK: - 主视图：AiChatMainSubBar

struct AiChatMainSubBar: View {
    @Namespace private var namespace
    
    // MARK: - 状态管理
    
    /// 输入框文本内容
    @State private var inputText: String = ""
    
    /// 文本框高度（用于自适应多行）
    @State private var textViewHeight: CGFloat = 22
    
    /// 是否显示展开按钮
    @State private var showExpandButton: Bool = false
    
    /// 是否显示全屏编辑器
    @State private var showFullScreenEditor: Bool = false
    
    /// 是否显示操作菜单
    @State private var showActionMenu: Bool = false
    
    /// 是否显示图片选择器
    @State private var showImagePicker: Bool = false
    
    /// 是否显示相机视图
    @State private var showCamera: Bool = false
    
    /// 选中的图片项
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    
    /// 是否正在上传图片
    @State private var isUploadingImages: Bool = false
    
    /// 已附加的图片列表
    @State private var imageAttachments: [ImageAttachment] = []
    
    /// 是否显示多行文本输入框
    @State private var showMulLineTextField: Bool = false
    
    /// AI 是否正在响应
    @Binding var isAIResponding: Bool
    
    /// 输入框焦点状态
    @FocusState private var inputTextFocuseState: Bool
    
    // MARK: - 语音输入状态
    
    /// 语音识别器（点按麦克风开始/结束识别，识别过程中的文字会实时写入输入框）
    @State private var speechRecognizer = SpeechRecognizer()
    
    /// 是否正在进行语音输入
    @State private var isVoiceRecording: Bool = false
    
    /// 开始语音输入时输入框内已有的文本，识别到的新文字会追加在其后面
    @State private var voiceBaseText: String = ""
    
    // MARK: - 回调函数
    
    /// 发送消息回调：(文本, 文件信息列表, 图片数据列表)
    var onSendMessage: ((String, [ChatFileInfo], [Data]) -> Void)?
    
    /// 停止 AI 响应回调
    var onStop: (() -> Void)?
    
    // MARK: - 常量
    
    /// 单行文本框高度基准
    private let singleLineHeight: CGFloat = 22
    
    /// 最多可选择的图片数量
    private let maxImageSelection: Int = 5

    // MARK: - 方法：语音输入
    
    /// 点击麦克风按钮：第一次点击开始语音输入，再次点击结束语音输入。
    /// 开始前会先请求语音识别权限；识别过程中的文字会实时追加显示在输入框中。
    private func toggleVoiceInput() {
        if isVoiceRecording {
            stopVoiceInput()
            return
        }
        
        // 语音输入时先收起操作菜单、展开输入框，让用户能实时看到转写文字
        withAnimation(.spring(response: 0.3)) {
            showActionMenu = false
            showMulLineTextField = true
        }
        
        speechRecognizer.requestAuthorization { granted in
            DispatchQueue.main.async {
                guard granted else {
                    PopManager.shared.showSimplePop(title: "提示", description: "请在设置中开启语音识别与麦克风权限")
                    return
                }
                self.startVoiceInput()
            }
        }
    }
    
    /// 开始语音输入
    private func startVoiceInput() {
        // 记录开始识别前输入框已有的文本，新识别的内容追加在其后
        voiceBaseText = inputText

        // 静默重启时的文本保留方案：识别器因静默约 10 秒会自动重启识别任务，
        // 重启后新任务会先回调一次空字符串（段边界）。这里用"已定稿累计 +
        // 当前任务累计"拼装，只把空回调当作段边界并入累计，其他时候整段覆盖：
        // · 空回调 = 任务开始/重启：当前段定稿并入累计，已输出的文字保留；
        // · 非空回调 = SFSpeech 的累计文本，直接整段覆盖。
        // 注意不能用"累计变短"当重启信号：识别中途会推翻重写前几个字（长度可能变短），
        // 拿它做判断会把旧文本和新文本拼接到一起，产生重复。
        var accumulatedText = ""
        var currentCumulative = ""

        speechRecognizer.onTextUpdate = { recognizedText in
            DispatchQueue.main.async {
                let trimmed = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    // 任务开始/静默重启的空回调：当前段定稿并入累计，已输出的文字保留在输入框
                    accumulatedText += currentCumulative
                    currentCumulative = ""
                    return
                }
                currentCumulative = recognizedText
                self.inputText = self.voiceBaseText + accumulatedText + currentCumulative
            }
        }

        speechRecognizer.startRecording()
        withAnimation(.spring(response: 0.3)) {
            isVoiceRecording = true
        }
        // 关闭键盘，避免语音识别时键盘和转写内容抢占注意力
        inputTextFocuseState = false
    }
    
    /// 结束语音输入
    private func stopVoiceInput() {
        // 先固化当前已转写进输入框的文本，再解除识别回调。
        // stopRecording() 里 endAudio()/cancel() 会触发识别任务的收尾回调，
        // 若回调仍挂在 onTextUpdate 上，可能回写一次空/不完整的结果，
        // 把刚说出的文字清掉（TextEditor 失能切换时也可能发生类似的清空）。
        // 解除后，已转写内容已经都在 inputText 里，不会因为停止而丢失。
        let finalText = inputText
        speechRecognizer.onTextUpdate = nil

        speechRecognizer.stopRecording()
        // 注意：这里不能更新 voiceBaseText。stopRecording() 后识别任务仍可能异步回调一次最终识别结果，
        // 若在此处把本次识别文本写入 voiceBaseText，那次回调会把结果再拼接一遍导致文本重复。
        // 下一轮录音的基准文本由 startVoiceInput() 在开始时重新捕获输入框当前内容即可。
        withAnimation(.spring(response: 0.3)) {
            isVoiceRecording = false
        }

        // 兜底：收尾回调可能已在主队列排队待写入（晚于上面的解绑才生效），
        // 若把输入框写空则用停止前固化的文本恢复，保证已转写内容不丢失。
        DispatchQueue.main.async {
            if StringUtils.isBlank(self.inputText) {
                self.inputText = finalText
            }
        }
    }
    
    // MARK: - 方法
    
    /// 处理拍照完成
    private func handleCameraPhoto(imageData: Data) {
        let attachment = ImageAttachment(id: ULIDUtils.generate(), data: imageData, fileId: nil)
        imageAttachments.append(attachment)
        
        // 上传单张图片
        let (fileName, mimeType) = ("camera_\(ULIDUtils.generate()).jpg", "image/jpeg")
        let fileInfo = FileUploadInfo(data: imageData, fileName: fileName, mimeType: mimeType)
        
        isUploadingImages = true
        BgResultNetWork<Empty, [FilesDTO]>.upload(apiUrl(FILE_UPLOAD), params: nil)
            .complicationHand { (results: [FilesDTO]?) in
                if let result = results?.first {
                    if let index = self.imageAttachments.firstIndex(where: { $0.id == attachment.id }) {
                        self.imageAttachments[index].fileId = result.id
                    }
                } else {
                    PopManager.shared.showSimplePop(title: "提示", description: "图片上传失败！")
                    self.imageAttachments.removeAll { $0.id == attachment.id }
                }
            }
            .errorHandle { _, _ in
                self.isUploadingImages = false
                PopManager.shared.showSimplePop(title: "提示", description: "图片上传失败！")
                self.imageAttachments.removeAll { $0.id == attachment.id }
            }
            .finalHandleFunc { _ in
                self.isUploadingImages = false
            }
            .upload(fileInfos: [fileInfo])
    }
    
    /// 发送消息
    /// - 检查文本或图片是否存在
    /// - 检查图片是否上传完成
    /// - 调用回调函数发送消息
    /// - 清空输入框和附件
    private func sendMessage() {
        let hasText = !StringUtils.isBlank(inputText)
        let hasImages = !imageAttachments.isEmpty
        
        // 检查是否正在上传图片
        if isUploadingImages {
            PopManager.shared.showSimplePop(title: "提示", description: "图片上传中，请稍后再发送")
            return
        }
        
        // 检查是否有内容且 AI 未在响应
        guard (hasText || hasImages) && !isAIResponding else { return }
        
        // 检查图片是否全部上传完成
        let fileIds = imageAttachments.compactMap { $0.fileId }
        if hasImages && fileIds.count != imageAttachments.count {
            PopManager.shared.showSimplePop(title: "提示", description: "图片上传未完成")
            return
        }
        
        // 调用回调函数发送消息
        let files = imageAttachments.compactMap { attachment -> ChatFileInfo? in
            guard let fileId = attachment.fileId else { return nil }
            return ChatFileInfo(fileId: fileId, fileName: nil, fileType: attachment.fileType)
        }
        onSendMessage?(inputText, files, imageAttachments.map { $0.data })
        
        // 清空输入框
        inputText = ""
        voiceBaseText = ""
        textViewHeight = singleLineHeight
        showExpandButton = false
        imageAttachments.removeAll()
        
        // 关闭键盘
        inputTextFocuseState = false
    }
    
    /// 上传图片
    /// - Parameter items: 选中的图片项
    private func uploadImages(items: [PhotosPickerItem]) {
        let limitedItems = Array(items.prefix(maxImageSelection))
        guard !limitedItems.isEmpty else { return }
        isUploadingImages = true
        
        Task {
            var files: [FileUploadInfo] = []
            files.reserveCapacity(limitedItems.count)
            var attachments: [ImageAttachment] = []
            attachments.reserveCapacity(limitedItems.count)
            
            // 加载图片数据
            for item in limitedItems {
                guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                let attachment = ImageAttachment(id: ULIDUtils.generate(), data: data, fileId: nil)
                attachments.append(attachment)
                let (fileName, mimeType) = imageFileMeta(from: item)
                files.append(FileUploadInfo(data: data, fileName: fileName, mimeType: mimeType))
            }
            
            DispatchQueue.main.async {
                self.imageAttachments = Array(attachments.prefix(self.maxImageSelection))
                guard !files.isEmpty else {
                    self.isUploadingImages = false
                    return
                }
                
                // 上传文件到服务器
                BgResultNetWork<Empty, [FilesDTO]>.upload(apiUrl(FILE_UPLOAD), params: nil)
                    .complicationHand { (results: [FilesDTO]?) in
                        if results == nil || results?.isEmpty == true {
                            PopManager.shared.showSimplePop(title: "提示", description: "图片上传失败！")
                            return
                        }
                        
                        // 更新附件的 fileId
                        var updated = self.imageAttachments
                        if let results = results {
                            for (index, file) in results.enumerated() {
                                if index < attachments.count {
                                    let attachmentId = attachments[index].id
                                    if let targetIndex = updated.firstIndex(where: { $0.id == attachmentId }) {
                                        updated[targetIndex].fileId = file.id
                                    }
                                }
                            }
                            self.imageAttachments = updated
                        }
                    }
                    .errorHandle { _, _ in
                        self.isUploadingImages = false
                        PopManager.shared.showSimplePop(title: "提示", description: "图片上传失败！")
                    }
                    .finalHandleFunc { _ in
                        self.isUploadingImages = false
                    }
                    .upload(fileInfos: files)
            }
        }
    }
    
    /// 获取图片文件元数据
    /// - Parameter item: 图片项
    /// - Returns: (文件名, MIME 类型)
    private func imageFileMeta(from item: PhotosPickerItem) -> (String, String) {
        let contentType = item.supportedContentTypes.first
        if let type = contentType {
            if type.conforms(to: .png) {
                return (ULIDUtils.generate() + ".png", "image/png")
            }
            if type.conforms(to: .gif) {
                return (ULIDUtils.generate() + ".gif", "image/gif")
            }
            if type.conforms(to: .heic) {
                return (ULIDUtils.generate() + ".heic", "image/heic")
            }
            if type.conforms(to: .heif) {
                return (ULIDUtils.generate() + ".heif", "image/heif")
            }
            if type.conforms(to: .jpeg) {
                return (ULIDUtils.generate() + ".jpg", "image/jpeg")
            }
        }
        return (ULIDUtils.generate() + ".jpg", "image/jpeg")
    }

    // MARK: - 视图构建
    
    var body: some View {
        VStack {
            // 图片预览区域
            subFilePreView
            
            // 操作菜单区域
            subActions
            
            // 输入框主体区域
            subHandleMain
        }
        .padding(.vertical, 10)
        .sheet(isPresented: $showFullScreenEditor) {
            FullScreenTextEditor(text: $inputText, isPresented: $showFullScreenEditor, onSend: {
                sendMessage()
            })
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(isPresented: $showCamera) { imageData in
                handleCameraPhoto(imageData: imageData)
            }
        }
        .onChange(of: inputTextFocuseState) { _, newValue in
            if newValue {
                // 获得焦点时隐藏操作菜单
                showActionMenu = false
            } else {
                // 失去焦点且输入框为空时隐藏多行输入框
                // 语音输入期间会主动失焦（避免键盘挡住转写内容），此时不应收起输入框
                if StringUtils.isBlank(inputText) && !isVoiceRecording {
                    showMulLineTextField = false
                }
            }
        }
        .onChange(of: showMulLineTextField) { _, newValue in
            if newValue {
                // 显示多行输入框时获得焦点
                inputTextFocuseState = true
            }
        }
        .onDisappear {
            inputTextFocuseState = false
            if isVoiceRecording {
                stopVoiceInput()
            }
        }
        .photosPicker(
            isPresented: $showImagePicker,
            selection: $selectedPhotoItems,
            maxSelectionCount: maxImageSelection,
            matching: .images
        )
        .onChange(of: selectedPhotoItems) { _, newValue in
            let items = Array(newValue.prefix(maxImageSelection))
            guard !items.isEmpty else { return }
            selectedPhotoItems = []
            uploadImages(items: items)
        }
        .appGlass(.regular, in: RoundedRectangle(cornerRadius: ChatTheme.radiusLg))
        .overlay {
            // 图片上传中的加载指示器
            if isUploadingImages {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.black.opacity(0.12))
                        .background(.ultraThinMaterial)
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("图片上传中...")
                            .font(.system(size: 13))
                            .foregroundStyle(Color("text_primary"))
                    }
                }
            }
        }
    }
    
    // MARK: - 子视图：图片预览
    
    /// 显示已选择的图片预览
    private var subFilePreView: some View {
        VStack {
            if !imageAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(imageAttachments.indices, id: \.self) { index in
                            if let image = UIImage(data: imageAttachments[index].data) {
                                ZStack(alignment: .topTrailing) {
                                    // 图片缩略图
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 68, height: 68)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                        )
                                    
                                    // 删除按钮
                                    Button {
                                        imageAttachments.remove(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(Color.white)
                                            .background(Circle().fill(Color.black.opacity(0.75)))
                                            .padding(6)
                                    }
                                    .buttonStyle(.plain)
                                    .contentShape(Circle())
                                    .offset(x: 10, y: -10)
                                    .zIndex(3)
                                }
                                .padding(.top, 6)
                                .padding(.trailing, 6)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
    
    // MARK: - 子视图：操作菜单
    
    /// 显示操作菜单（拍照、图片、文件、通话等）
    private var subActions: some View {
        VStack {
            if showActionMenu {
                ActionMenuView(
                    isPresented: $showActionMenu,
                    showCamera: $showCamera,
                    onSelectImage: {
                        showImagePicker = true
                    }
                )
                .padding(.horizontal, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - 子视图：输入框主体
    
    /// 输入框主体，包含文本输入、按钮等
    private var subHandleMain: some View {
        HStack(spacing: 10) {
            VStack {
                // 多行文本输入框
                if showMulLineTextField {
                    HStack(alignment: .top) {
                        HStack {
                            MulLineTextField(
                                text: $inputText,
                                height: $textViewHeight,
                                placeholder: isVoiceRecording ? "正在聆听，请说话..." : "发消息或点击语音输入...",
                                font: .systemFont(ofSize: 17),
                                maxLines: 3,
                                onSubmit: {
                                    sendMessage()
                                }
                            )
                            .frame(height: textViewHeight)
                            .frame(maxWidth: .infinity)
                            .focused($inputTextFocuseState)
                            .disabled(isVoiceRecording)
                            .onChange(of: textViewHeight) { _, newValue in
                                showExpandButton = newValue > singleLineHeight + 5
                            }
                        }.padding(.horizontal, 5)
  
                            .cornerRadius(8)
                        
                        // 全屏编辑按钮（当文本框高度超过 60 时显示）
                        if textViewHeight > 60 {
                            VStack(alignment: .trailing) {
                                Button {
                                    showFullScreenEditor = true
                                } label: {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color("text_secondary"))
                                        .padding(8)
                                        .background(
                                            Circle().fill(Color.white.opacity(0.9))
                                        )
                                }
                            }.frame(width: 18, alignment: .topTrailing)
                        }
                    }.frame(height: textViewHeight)
                }
                
                // 底部按钮栏
                HStack {
                    // 语音输入按钮：点一下开始语音输入，再点一下结束
                    VoiceInputButton(isRecording: isVoiceRecording, action: toggleVoiceInput)
                    
                    // 输入提示文本 / 语音输入状态提示
                    if isVoiceRecording {
                        VoiceRecordingHint()
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    } else if !showMulLineTextField {
                        Button {
                            DispatchQueue.main.async {
                                showMulLineTextField = true
                            }
                        } label: {
                            Text("发消息或点击语音输入")
                        }.foregroundStyle(Color("text_secondary"))
                    }
                    
                    Spacer()
                    
                    // 相机按钮
                    Button {
                        showCamera = true
                    } label: {
                        Image(systemName: "camera")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color("text_primary"))
                    }
                    .buttonStyle(.plain)
                    
                    // 更多操作按钮
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showActionMenu.toggle()
                            if showActionMenu {
                                inputTextFocuseState = false
                            }
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color("text_primary"))
                    }
                    
                    // 发送/停止按钮
                    // 注意：语音输入结束后输入框会失去焦点，但已经转写出的文字需要能被发送，
                    // 所以这里不再要求"必须处于焦点状态"，只要输入框展开且有内容即可显示；
                    // 语音输入进行中则先隐藏，避免和"正在聆听"提示同时出现
                    if (!isVoiceRecording && showMulLineTextField && !StringUtils.isBlank(inputText)) || isAIResponding {
                        Button {
                            if isAIResponding {
                                onStop?()
                            } else {
                                sendMessage()
                            }
                        } label: {
                            Image(systemName: isAIResponding ? "stop.fill" : "arrow.up")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.white)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle().fill(Color.theme(.primary))
                                )
                        }
                    }
                }.frame(minHeight: 35)
                .animation(.easeInOut(duration: 0.2), value: isVoiceRecording)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 50)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 16)
    }
}

// MARK: - 语音输入按钮

/// 语音输入触发按钮：麦克风图标。
/// 未录音时为普通图标；录音中背景变为主色圆形，图标切换为方形（停止），
/// 并叠加一层持续放大淡出的波纹动画，提示"正在聆听"。
struct VoiceInputButton: View {
    let isRecording: Bool
    let action: () -> Void
    
    /// 波纹脈冲动画的展开进度，录音时循环播放
    @State private var pulse: Bool = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
        }) {
            ZStack {
                // 录音中的扩散波纹
                if isRecording {
                    Circle()
                        .stroke(Color.theme(.primary).opacity(0.5), lineWidth: 1.5)
                        .frame(width: 34, height: 34)
                        .scaleEffect(pulse ? 1.5 : 1.0)
                        .opacity(pulse ? 0 : 0.8)
                        .animation(
                            .easeOut(duration: 1.1).repeatForever(autoreverses: false),
                            value: pulse
                        )
                }
                
                Circle()
                    .fill(isRecording ? Color.theme(.primary) : Color.clear)
                    .frame(width: 30, height: 30)
                
                Image(systemName: isRecording ? "square.fill" : "waveform.circle")
                    .font(.system(size: isRecording ? 13 : 25, weight: .medium))
                    .foregroundStyle(isRecording ? Color.white : Color("text_primary"))
            }
            .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .onChange(of: isRecording) { _, newValue in
            pulse = false
            if newValue {
                // 延迟一帧启动，确保动画从初始状态开始扩散
                DispatchQueue.main.async {
                    pulse = true
                }
            }
        }
    }
}

// MARK: - 语音输入提示

/// 录音中的状态提示：跳动的波形条 + "正在聆听..." 文案
struct VoiceRecordingHint: View {
    @State private var animate = false
    
    private let barCount = 4
    
    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(Color.theme(.primary))
                        .frame(width: 3, height: animate ? CGFloat.random(in: 6...16) : 6)
                        .animation(
                            .easeInOut(duration: 0.35)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.12),
                            value: animate
                        )
                }
            }
            .frame(height: 16)
            
            Text("正在聆听...")
                .font(.system(size: 14))
                .foregroundStyle(Color.theme(.primary))
        }
        .onAppear {
            animate = true
        }
    }
}

// MARK: - 操作菜单视图

/// 操作菜单视图 - 在输入框下方展开，当前提供拍照、图片两个入口
/// （文件、通话待实现，代码已注释保留）
struct ActionMenuView: View {
    @Binding var isPresented: Bool
    @Binding var showCamera: Bool
    var onSelectImage: (() -> Void)?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ActionMenuChip(
                    icon: "camera.fill",
                    title: "拍照",
                    action: {
                        isPresented = false
                        showCamera = true
                    }
                )
                ActionMenuChip(
                    icon: "photo.fill",
                    title: "图片",
                    action: {
                        isPresented = false
                        onSelectImage?()
                    }
                )
                // 「文件」和「通话」功能暂未实现，先隐藏，后续补齐后再放开
//                ActionMenuChip(
//                    icon: "doc.fill",
//                    title: "文件",
//                    action: {
//                        isPresented = false
//                        // TODO: 实现上传文件功能
//                        print("上传文件")
//                    }
//                )
//                ActionMenuChip(
//                    icon: "phone.fill",
//                    title: "通话",
//                    action: {
//                        isPresented = false
//                        // TODO: 实现语音通话功能
//                        print("语音通话")
//                    }
//                )
            }
            .padding(.vertical, 6)
        }
    }
}

// MARK: - 操作菜单项

/// 单个菜单项（横向胶囊形状）
struct ActionMenuChip: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color("text_primary"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color("input_bg"))
                    .overlay(
                        Capsule().stroke(Color("divider"), lineWidth: 1)
                    )
            )
        }
    }
}
// MARK: - 全屏文本编辑器

/// 全屏文本编辑器 - 用于编辑较长的消息
struct FullScreenTextEditor: View {
    @Binding var text: String
    @Binding var isPresented: Bool
    var onSend: () -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $text)
                    .font(.system(size: 18))
                    .padding()
            }
            .navigationTitle("编辑消息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        isPresented = false
                        onSend()
                    } label: {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("发送")
                        }
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
// MARK: - 多行文本输入框（SwiftUI 原生实现）

/// 多行文本输入框 - 使用 SwiftUI 原生 TextEditor
/// 功能：
/// - 支持自动高度调整（最多 3 行）
/// - 支持 placeholder 显示
/// - 支持表情符号输入
/// - 无光标错位问题
struct MulLineTextField: View {
    
    @Binding var text: String
    @Binding var height: CGFloat
    var placeholder: String = ""
    var font: UIFont = .systemFont(ofSize: 18)
    var maxLines: Int = 3
    var onSubmit: (() -> Void)?
    
    @State private var isScrollEnabled: Bool = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Placeholder
            if text.isEmpty {
                Text(placeholder)
                    .font(Font(font))
                    .foregroundColor(.gray.opacity(0.5))
                    .allowsHitTesting(false)
                    .padding(.top, 8)
                    .padding(.horizontal, 5)
            }
            
            // 实际的文本编辑器
            TextEditor(text: $text)
                .font(Font(font))
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .scrollDisabled(!isScrollEnabled) // 根据内容动态启用/禁用滚动
                .scrollIndicators(.hidden)
                .onChange(of: text) { _, newText in
                    calculateHeight(for: newText)
                }
                .onAppear {
                    calculateHeight(for: text)
                }
        }
    }
    
    private func calculateHeight(for text: String) {
        let lineHeight = font.lineHeight
        let maxHeight = lineHeight * CGFloat(maxLines)
        
        // 计算文本实际需要的高度
        let textToMeasure = text.isEmpty ? " " : text
        let size = textToMeasure.boundingRect(
            with: CGSize(width: UIScreen.main.bounds.width - 100, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        ).size
        
        let actualTextHeight = size.height + 16 // +16 for padding
        let calculatedHeight = min(actualTextHeight, maxHeight + 16)
        
        // 当文本高度超过最大显示高度时启用滚动
        isScrollEnabled = actualTextHeight > maxHeight + 16
        
        if abs(height - calculatedHeight) > 1.0 {
            DispatchQueue.main.async {
                height = calculatedHeight
            }
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var isAiResponding = false
    AiChatMainSubBar(isAIResponding: $isAiResponding).background(Color.green.opacity(0.4))
}
