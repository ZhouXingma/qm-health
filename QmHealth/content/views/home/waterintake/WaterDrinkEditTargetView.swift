//
//  WaterDrinkEditTargetView.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/11/17.
//

import SwiftUI

struct WaterDrinkEditTargetView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var targetIntake: Double?
    var onSave: (() -> Void)? = nil

    @State private var inputText: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var saving = false

    private let presetValues = [1500, 1800, 2000, 2500, 3000]
    private let targetTint = Color.orange

    var targetIntakeStr: String {
        return targetIntake == nil ? "" : String(Int(targetIntake!))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.card) {
                    headerSection

                    currentTargetSection

                    inputSection

                    presetSection
                }
                .padding(.horizontal, AppSpacing.screen)
                .padding(.vertical, AppSpacing.card)
            }
            .background(AppColor.background)
            .navigationTitle("设置目标饮水量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundStyle(AppColor.textSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                saveButton
                    .padding(.horizontal, AppSpacing.screen)
                    .padding(.vertical, AppSpacing.regular)
                    .background(AppColor.background)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isTextFieldFocused = true
                }
            }
        }
        .sheetAppBackground()
    }

    // MARK: - 标题说明
    private var headerSection: some View {
        VStack(spacing: AppSpacing.compact) {
            Text("建议每日饮水量：1500-3000ml")
                .font(.system(size: 13))
                .foregroundStyle(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 当前目标显示
    private var currentTargetSection: some View {
        VStack(spacing: AppSpacing.regular) {
            Text("当前目标")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColor.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(targetIntakeStr)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.orange, Color.yellow],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("ml")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .padding(.vertical, AppSpacing.card)
        .frame(maxWidth: .infinity)
        .contentStyle()
    }

    // MARK: - 输入框
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.regular) {
            Text("输入新目标 (500-5000)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColor.textSecondary)

            HStack(spacing: AppSpacing.regular) {
                TextField("请输入目标饮水量", text: $inputText)
                    .keyboardType(.numberPad)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .focused($isTextFieldFocused)
                    .onChange(of: inputText) { _, newValue in
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered != newValue {
                            inputText = filtered
                            return
                        }
                        if let v = Int(filtered), v > 5000 {
                            inputText = "5000"
                        }
                    }
                Text("ml")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppColor.textSecondary)
            }
            .inputFieldStyle()
        }
    }

    // MARK: - 快速选择
    private var presetSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.regular) {
            Text("快速选择")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColor.textSecondary)

            HStack(spacing: AppSpacing.regular) {
                ForEach(presetValues, id: \.self) { value in
                    Button {
                        hideKeyboard()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            inputText = "\(value)"
                        }
                    } label: {
                        Text("\(value)ml")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.regular)
                    }
                    .buttonStyle(GlassSelectButtonStyle(
                        isSelected: inputText == "\(value)",
                        tint: targetTint
                    ))
                }
            }
        }
    }

    // MARK: - 保存按钮
    private var saveButton: some View {
        Button {
            hideKeyboard()
            saveTarget()
        } label: {
            HStack(spacing: 8) {
                if saving {
                    ProgressView()
                        .tint(.white)
                }
                Text("保存")
            }
        }
        .buttonStyle(PrimaryActionButtonStyle(tint: targetTint))
        .disabled(saving)
    }

    private func hideKeyboard() {
        isTextFieldFocused = false
    }

    private func saveTarget() {
        guard !saving else { return }
        saving = true
        guard let newValue = Double(inputText.trimmingCharacters(in: .whitespaces)) else {
            saving = false
            return
        }
        if newValue == targetIntake {
            saving = false
            return
        }
        let clampedValue = min(max(newValue, 500), 5000)
        let params = MetaDataAddParam(
            metadataCode: "饮酒目标",
            metadataValue: String(format: "%.0f", clampedValue),
            bizLabel: 1
        )
        BgResultNetWork<MetaDataAddParam, String>.post(apiUrl(METADATA_RECORD_ADD), params: params)
            .complicationHand { (s: String?) in
                DispatchQueue.main.async {
                    targetIntake = clampedValue
                    onSave?()
                    dismiss()
                }
            }
            .finalHandleFunc { _ in
                DispatchQueue.main.async {
                    saving = false
                }
            }
            .responseDecodable()
    }
}

#Preview {
    @Previewable @State var targetIntake: Double? = 2000
    WaterDrinkEditTargetView(targetIntake: $targetIntake)
}
