import SwiftUI

// MARK: - 表单区域组件

// 基本信息区域
struct BasicInfoSection: View {
    @Binding var date: Date
    @Binding var hospital: String
    @Binding var department: String
    @Binding var doctor: String
    
    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "基本信息", icon: "info.circle.fill")
            
            VStack(spacing: 0) {
                // 就诊日期和时间
                DateTimePickerRow(title: "就诊时间", date: $date)
                
                Divider()
                
                // 就诊医院
                TextFieldRow(
                    title: "就诊医院",
                    placeholder: "请输入医院名称",
                    text: $hospital,
                    isRequired: true
                )
                
                Divider()
                
                // 就诊科室
                TextFieldRow(
                    title: "就诊科室",
                    placeholder: "请输入科室名称",
                    text: $department,
                    isRequired: true
                )
                
                Divider()

                // 医生姓名
                TextFieldRow(
                    title: "医生姓名",
                    placeholder: "请输入医生姓名（选填）",
                    text: $doctor,
                    isRequired: false
                )
            }
            .cardStyle()
        }
    }
}

// 症状描述区域
struct SymptomDescriptionSection: View {
    @Binding var symptomDescription: String
    var onVoiceInput: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "症状描述", icon: "heart.text.square.fill")
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("症状详情")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("text_primary"))
                    
                    Spacer()
                    
                    // 录音按钮
                    Button(action: onVoiceInput) {
                        HStack(spacing: 6) {
                            Image(systemName: "mic.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("录音")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .appGlass(
                            Glass.regular.interactive().tint(Color.theme(.primary)),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        ) {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.theme(.primary), Color.theme(.primary).opacity(0.85)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: Color.theme(.primary).opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                    }
                }

                ZStack(alignment: .topLeading) {
                    if symptomDescription.isEmpty {
                        Text("请描述您的症状\n如：头痛、发热、咳嗽、胸闷等")
                            .font(.system(size: 15))
                            .foregroundColor(Color("text_secondary").opacity(0.5))
                            .padding(.top, 8)
                            .padding(.leading, 4)
                    }

                    TextEditor(text: $symptomDescription)
                        .font(.system(size: 15))
                        .foregroundColor(Color("text_primary"))
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                }
            }
            .cardStyle()
        }
    }
}

// 诊断信息区域
struct DiagnosisSection: View {
    @Binding var diagnosis: String
    @Binding var summary: String
    let onVoiceInput: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "诊断信息", icon: "stethoscope")
            
            VStack(spacing: 0) {
                // 诊断结果 - 简洁输入
                HStack(spacing: 8) {
                    Text("诊断结果")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("text_primary"))
                    
                    Spacer()
                    
                    TextField("如：高血压、感冒", text: $diagnosis)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 15))
                        .foregroundColor(Color("text_primary"))
                }
                .padding(.vertical, 14)
                
                Divider().padding(.bottom, 14)
                
                // 医嘱备注 - 详细输入，带录音功能
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("医嘱备注")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color("text_primary"))
                        
                        Spacer()
                        
                        // 录音按钮
                        Button(action: onVoiceInput) {
                            HStack(spacing: 6) {
                                Image(systemName: "mic.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("录音")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .appGlass(
                                Glass.regular.interactive().tint(Color.theme(.primary)),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            ) {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.theme(.primary), Color.theme(.primary).opacity(0.85)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .shadow(color: Color.theme(.primary).opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                        }
                    }
                    
                    ZStack(alignment: .topLeading) {
                        if summary.isEmpty {
                            Text("请输入医嘱或备注信息\n如：注意休息、按时服药、定期复查等")
                                .font(.system(size: 15))
                                .foregroundColor(Color("text_secondary").opacity(0.5))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        
                        TextEditor(text: $summary)
                            .font(.system(size: 15))
                            .foregroundColor(Color("text_primary"))
                            .frame(minHeight: 100)
                            .scrollContentBackground(.hidden)
                    }
                }
            }
            .cardStyle()
        }
    }
}
