//
//  EditableValueDisplay.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/11/14.
//

import SwiftUI

struct EditableValueDisplay: View {
    // 值
    @Binding var value: Double
    // 单位
    let unit: String
    // 最大值
    let minValue: Double
    // 最小值
    let maxValue: Double
    // 步宽
    let step: Double
    // 值的格式
    let valueFormate: String
    
    // 是否编辑值
    @State private var isEditingValue: Bool = false
    // 编辑文本
    @State private var editingText: String = ""
    // 编辑文本的关注
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("当前数值")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 4) {
                        if isEditingValue {
                            TextField("", text: $editingText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(maxWidth: 120)
                                .focused($isTextFieldFocused)
                                .onAppear {
                                    isTextFieldFocused = true
                                }
                                .onSubmit {
                                    commitEdit()
                                }
                                .inputFieldStyle()
                        } else {
                            Text("\(value, specifier: valueFormate)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .contentTransition(.numericText(value: value))
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: value)
                        }

                        Text(unit)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 4)
                    }
                }

                Spacer()

                VStack(spacing: 8) {
                    if isEditingValue {
                        Button {
                            commitEdit()
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.green, .mint],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .appGlass(.regular.interactive(), in: Circle()) {
                            Circle().fill(AppColor.content.opacity(0.6))
                        }
                        .transition(.scale.combined(with: .opacity))

                        Button {
                            isEditingValue = false
                            isTextFieldFocused = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.red, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .appGlass(.regular.interactive(), in: Circle()) {
                            Circle().fill(AppColor.content.opacity(0.6))
                        }
                    } else {
                        Button {
                            startEditing()
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .appGlass(.regular.interactive(), in: Circle()) {
                            Circle().fill(AppColor.content.opacity(0.6))
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .appGlass(.clear.tint(Color.blue.opacity(0.1)),
                      in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.blue.opacity(0.2), .cyan.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            
            if !isEditingValue {
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        Text("点击编辑按钮修改数值")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.05))
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isEditingValue)
    }
    
    private func startEditing() {
        editingText = String(format: valueFormate, value)
        isEditingValue = true
    }
    
    private func commitEdit() {
        if let newValue = Double(editingText) {
            let clampedValue = min(max(newValue, minValue), maxValue)
            let roundedValue = round(clampedValue / step) * step
            value = roundedValue
        }
        isEditingValue = false
        isTextFieldFocused = false
    }
}

#Preview {
    @Previewable @State var weight: Double = 70;
    // 体重

    VStack(alignment: .leading, spacing: 12) {
        Label {
            Text("体重")
                .font(.title2)
                .fontWeight(.bold)
        } icon: {
            Image(systemName: "figure.stand")
                .font(.title2)
                .foregroundStyle(.blue)
        }
        
        VStack(spacing: 12) {
            EditableValueDisplay(
                value: $weight,
                unit: "kg",
                minValue: 30,
                maxValue: 150,
                step: 0.1,
                valueFormate: "%.1f"
            )
            
            CaliperRuler(
                value: $weight,
                minValue: 30,
                maxValue: 150,
                step: 0.1
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
        )
    }
    
}
