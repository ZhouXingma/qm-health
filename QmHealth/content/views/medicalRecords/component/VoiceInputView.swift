import SwiftUI

// MARK: - 录音输入视图

struct VoiceInputView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var text: String
    @State private var isRecording = false
    @State private var recognizedTexts: [String] = []
    @State private var currentRecognizedText: String = ""
    private let speechRecognizer = SpeechRecognizer()
    
    /// 语音识别重启间隔（秒），默认10秒
    /// 可根据场景调整：症状描述建议15-20秒，医生对话建议5-8秒
    var restartInterval: TimeInterval = 10
    
    var body: some View {
        NavigationView {
            ZStack {
                Color("background").ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 识别内容显示区域
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            if recognizedTexts.isEmpty && currentRecognizedText.isEmpty {
                                EmptyVoiceInputView()
                            } else {
                                VStack(spacing: 12) {
                                    // 已完成的识别文本
                                    ForEach(recognizedTexts.indices, id: \.self) { index in
                                        VoiceTextBubble(text: recognizedTexts[index], isRecording: false)
                                    }
                                    
                                    // 当前正在识别的文本（仅录音中显示尾部的状态圈圈）
                                    if !currentRecognizedText.isEmpty {
                                        VoiceTextBubble(text: currentRecognizedText, isRecording: isRecording)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                    
                    // 录音控制区域
                    VoiceRecordingControls(
                        isRecording: $isRecording,
                        onToggleRecording: toggleRecording
                    )
                }
            }
            .navigationTitle("录音输入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        saveRecognizedText()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(recognizedTexts.isEmpty && currentRecognizedText.isEmpty)
                }
            }
        }
        .onAppear {
            // 设置语音识别重启间隔
            speechRecognizer.restartInterval = restartInterval

            speechRecognizer.onTextUpdate = { recognizedText in
                if recognizedText == "" {
                    // 识别完成，保存当前文本
                    if !self.currentRecognizedText.isEmpty {
                        recognizedTexts.append(self.currentRecognizedText)
                        self.currentRecognizedText = ""
                    }
                } else {
                    // 更新当前识别文本
                    self.currentRecognizedText = recognizedText
                }
            }
        }
        .onDisappear {
            // 页面销毁时确保停止录音，释放麦克风等资源
            if isRecording {
                speechRecognizer.stopRecording()
            }
        }
    }
    
    private func toggleRecording() {
        if isRecording {
            speechRecognizer.stopRecording()
            // 停止录音时，主动把最后一段尚未提交的文本归并到已完成列表，
            // 避免 SpeechRecognizer 不会触发空字符串回调时，
            // 气泡尾部的 ProgressView 状态圈圈一直残留不消失
            if !currentRecognizedText.isEmpty {
                recognizedTexts.append(currentRecognizedText)
                currentRecognizedText = ""
            }
        } else {
            speechRecognizer.startRecording()
        }
        isRecording.toggle()
    }
    
    private func saveRecognizedText() {
        // 合并所有识别的文本
        var allTexts = recognizedTexts
        if !currentRecognizedText.isEmpty {
            allTexts.append(currentRecognizedText)
        }
        
        let newText = allTexts.joined(separator: "\n")
        
        // 如果原文本不为空，添加换行符
        if !text.isEmpty && !newText.isEmpty {
            text += "\n" + newText
        } else {
            text = newText
        }
    }
}

// 空录音视图
struct EmptyVoiceInputView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(Color("text_secondary").opacity(0.3))
            
            VStack(spacing: 8) {
                Text("点击下方按钮开始录音")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color("text_secondary"))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
}

// 录音控制区域
struct VoiceRecordingControls: View {
    @Binding var isRecording: Bool
    let onToggleRecording: () -> Void

    @State private var recordingDuration: TimeInterval = 0
    @State private var pulseStart: Date = .init()
    @State private var timerTask: Task<Void, Never>?

    var body: some View {
        Button(action: onToggleRecording) {
            HStack(spacing: 16) {
                // 左侧：圆形按钮装饰（带脉冲环，不独立响应点击）
                ZStack {
                    if isRecording {
                        ForEach(0..<3, id: \.self) { index in
                            PulsingRing(start: pulseStart, delay: Double(index) * 0.6)
                        }
                    }

                    ZStack {
                        Circle()
                            .fill(isRecording ? Color.red : Color.theme(.primary))
                            .shadow(
                                color: (isRecording ? Color.red : Color.theme(.primary)).opacity(0.4),
                                radius: 10, x: 0, y: 5
                            )

                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                            .scaleEffect(isRecording ? 1.05 : 1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isRecording)
                    }
                    .frame(width: 56, height: 56)
                    .appGlass(
                        Glass.regular.interactive().tint(isRecording ? Color.red : Color.theme(.primary)),
                        in: Circle()
                    ) {
                        Circle()
                            .fill(isRecording ? Color.red : Color.theme(.primary))
                    }
                }
                .frame(width: 80, height: 80)

                // 右侧：状态文字 + 波形 + 提示
                VStack(alignment: .leading, spacing: 6) {
                    if isRecording {
                        HStack(spacing: 8) {
                            WaveformBars()
                                .frame(height: 22)
                            Text(formatDuration(recordingDuration))
                                .font(.system(size: 17, weight: .semibold).monospacedDigit())
                                .foregroundStyle(Color.red)
                                .contentTransition(.numericText())
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    } else {
                        Text("点击开始录音")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color("text_primary"))
                            .transition(.opacity)
                    }

                    Text(isRecording ? "正在录音，再次点击停止" : "支持识别普通话，自动分段")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("text_secondary"))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .appGlass(
            Glass.regular.interactive(),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        ) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color("content_bg"))
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                pulseStart = Date()
                recordingDuration = 0
                timerTask?.cancel()
                timerTask = Task { @MainActor in
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .milliseconds(200))
                        if !Task.isCancelled {
                            recordingDuration += 0.2
                        }
                    }
                }
            } else {
                timerTask?.cancel()
                timerTask = nil
            }
        }
        .onDisappear {
            timerTask?.cancel()
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - 脉冲扩散圆环
/// 从中心向外扩散并淡出的圆环，录音中循环播放
struct PulsingRing: View {
    let start: Date
    let delay: Double
    var color: Color = .red
    var lineWidth: CGFloat = 2

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let elapsed = context.date.timeIntervalSince(start) - delay
            let progress = (elapsed.truncatingRemainder(dividingBy: 1.8)) / 1.8
            let scale = 0.6 + progress * 0.6
            let opacity = max(0, 1.0 - progress)

            Circle()
                .stroke(color.opacity(opacity * 0.4), lineWidth: lineWidth)
                .scaleEffect(scale)
        }
    }
}

// MARK: - 律动波形
/// 5 个胶囊条按时间正弦波动，模拟录音时的音频波形
struct WaveformBars: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    let phase = time * 4 + Double(index) * 0.7
                    let normalized = (sin(phase) + 1) / 2
                    let height = 8 + normalized * 20

                    Capsule()
                        .fill(Color.red)
                        .frame(width: 4, height: height)
                        .animation(.easeInOut(duration: 0.15), value: height)
                }
            }
        }
    }
}

// 录音文本气泡
struct VoiceTextBubble: View {
    let text: String
    let isRecording: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 左侧图标
            ZStack {
                Circle()
                    .fill(Color.clear)
                    .appGlass(
                        Glass.clear.interactive().tint(Color.theme(.primary).opacity(0.25)),
                        in: Circle()
                    ) {
                        Circle().fill(Color.theme(.primary).opacity(0.1))
                    }
                    .frame(width: 32, height: 32)

                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.theme(.primary))
            }

            // 文本内容
            HStack(alignment: .top, spacing: 8) {
                Text(text)
                    .font(.system(size: 15))
                    .foregroundColor(Color("text_primary"))
                    .fixedSize(horizontal: false, vertical: true)

                if isRecording {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(14)
        .glassContainer(.regular.interactive(), cornerRadius: 14)
    }
}
