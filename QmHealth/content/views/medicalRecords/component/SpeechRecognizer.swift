//
//  Untitled.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/3/8.
//
import SwiftUI
import Speech
import AVFoundation

/// 语音识别管理类
/// 负责使用 `SFSpeechRecognizer` 进行语音识别，并将识别文本通过回调传递出去
class SpeechRecognizer: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    /// 语音识别器（中文环境）
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    /// 语音识别请求对象
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    /// 语音识别任务对象
    private var recognitionTask: SFSpeechRecognitionTask?
    /// 音频引擎（用于录音）
    private let audioEngine = AVAudioEngine()
    
    /// 识别结果回调，每当识别到文本时触发
    var onTextUpdate: ((String) -> Void)?

    /// 记录上次识别的时间
    private var lastTranscriptionTime: Date?

    private var timer: Timer?  // 定时器用于定期重启任务

    /// 是否已经停止。endAudio() 之后系统仍会触发一次最终结果回调（传入累计全文本），
    /// 此时若不忽略，VoiceInputView 会把已经分段过的文本再合并显示一遍，导致重复。
    /// startRecording 时重置为 false，stopRecording 时置为 true。
    private var isStopped = true
    
    /// 定时器重启间隔（秒），默认10秒
    var restartInterval: TimeInterval = 10
    
    override init() {
        super.init()
        speechRecognizer?.delegate = self
    }
    
    /// 请求语音识别权限
    /// - Parameter completion: 回调返回是否授权成功
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            completion(status == .authorized)
        }
    }
    
    /// 配置并激活录音用的 AVAudioSession
    /// 必须在安装 Tap / 读取 inputNode 格式之前激活会话，
    /// 否则 inputNode.outputFormat 可能与硬件真实格式不一致，
    /// 从而在 installTap 时触发 "Failed to create tap due to format mismatch" 崩溃
    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    /// 开始录音并进行语音识别
    func startRecording() {
        isStopped = false
        do {
            // 如果音频引擎正在运行，先停止并清理之前的识别任务
            if audioEngine.isRunning {
                audioEngine.stop()
                recognitionRequest?.endAudio()
            }

            // 取消现有的识别任务，防止多个任务同时运行
            recognitionTask?.cancel()
            recognitionTask = nil

            // 先激活音频会话，确保 inputNode 的格式与硬件实际格式一致
            try configureAudioSession()

            self.createRequestAndRecognition()

            // 准备并启动音频引擎
            audioEngine.prepare()
            try audioEngine.start()
            restartTime()
        } catch {
            print("语音识别初始化失败: \(error)")
        }
    }
    
    /// 暂停录音（不会终止识别任务，但停止音频输入）
    func pause() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.pause()
        recognitionRequest?.endAudio()
    }
    
    /// 恢复录音
    func resume() {
        do {
            // 恢复时同样需要保证音频会话处于激活状态
            try configureAudioSession()

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            // 重新安装 Tap 以继续录音
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.recognitionRequest?.append(buffer)
            }

            try audioEngine.start()
        } catch {
            print("恢复语音识别失败: \(error)")
        }
    }
    
    /// 停止录音并清理所有资源
    func stopRecording() {
        isStopped = true
        timer?.invalidate()
        timer = nil
        // 结束语音识别请求
        recognitionRequest?.endAudio()
        // 移除音频输入 Tap，避免占用输入流
        audioEngine.inputNode.removeTap(onBus: 0)
        // 如果音频引擎仍在运行，则停止
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        // 清理识别请求和任务
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        // 释放音频会话，避免持续占用麦克风及影响其他音频场景
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    @objc private func restartTime() {
        print("重置时间......");
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: restartInterval, target: self, selector: #selector(restartRecognition), userInfo: nil, repeats: true)
    }
    @objc private func restartRecognition() {
        print("重启语音识别任务...")
        timer?.invalidate()
        timer = nil
        // 结束语音识别请求
        recognitionRequest?.endAudio()
        // 清理识别请求和任务
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        createRequestAndRecognition()
     }
    
    private  func createRequestAndRecognition() {
        let inputNode = audioEngine.inputNode
        // 确保没有已安装的 tap，防止重复 installTap
        inputNode.removeTap(onBus: 0)
        // 创建新的语音识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        // 允许自动添加标点符号，并启用部分结果回传
        recognitionRequest.addsPunctuation = true
        recognitionRequest.shouldReportPartialResults = true
        
        // 启动语音识别任务
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            // 已停止后忽略回调，避免 endAudio 触发的最终累计结果导致重复显示
            if self.isStopped { return }

            if let result = result {
                let formattedText = result.bestTranscription.formattedString
                self.onTextUpdate?(formattedText)
                restartTime()
            }
        }
        
        // 配置音频输入格式，并在音频流中安装 Tap 以捕获音频数据
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
    }
}
