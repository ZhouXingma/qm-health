// MARK: - VoiceInputView 使用示例
// 此文件展示如何在不同场景下配置语音识别重启间隔

import SwiftUI

// 示例1：症状描述场景（需要较长的识别时间）
struct SymptomInputExample: View {
    @State private var symptomText = ""
    @State private var showVoiceInput = false
    
    var body: some View {
        Button("录入症状") {
            showVoiceInput = true
        }
        .sheet(isPresented: $showVoiceInput) {
            // 症状描述通常较长，设置20秒重启间隔
            VoiceInputView(text: $symptomText, restartInterval: 20)
        }
    }
}

// 示例2：医生对话场景（需要较短的识别时间）
struct DoctorConversationExample: View {
    @State private var conversationText = ""
    @State private var showVoiceInput = false
    
    var body: some View {
        Button("记录对话") {
            showVoiceInput = true
        }
        .sheet(isPresented: $showVoiceInput) {
            // 医生对话通常较短且快速，设置5秒重启间隔
            VoiceInputView(text: $conversationText, restartInterval: 5)
        }
    }
}

// 示例3：默认场景（使用默认10秒间隔）
struct DefaultVoiceInputExample: View {
    @State private var defaultText = ""
    @State private var showVoiceInput = false
    
    var body: some View {
        Button("录音输入") {
            showVoiceInput = true
        }
        .sheet(isPresented: $showVoiceInput) {
            // 不指定 restartInterval，使用默认的10秒
            VoiceInputView(text: $defaultText)
        }
    }
}

// MARK: - 推荐的间隔时间配置
/*
 根据不同场景推荐的 restartInterval 值：
 
 1. 症状描述/病史记录：15-20秒
    - 用户需要详细描述症状，语句较长
    - 需要更多时间组织语言
 
 2. 医生对话/快速记录：5-8秒
    - 对话内容简短，语速较快
    - 需要快速捕捉关键信息
 
 3. 医嘱/备注：10-15秒
    - 内容长度适中
    - 使用默认或略长的间隔
 
 4. 药品名称/简短信息：3-5秒
    - 内容非常简短
    - 需要快速识别和重启
 */
