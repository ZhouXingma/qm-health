//
//  AddWaterRecordSheet.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/11/19.
//

import SwiftUI

struct AddWaterRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (Int) -> Void

    @State private var selectedAmount: Int = 250
    @State private var customText: String = ""
    @FocusState private var isInputFocused: Bool
    let presetAmounts = [150, 250, 300, 500]

    private let minAmount: Int = 10
    private let maxAmount: Int = 2000
    private let step: Int = 5

    private let waterTint = Color.blue

    var displayAmount: Int {
        if !customText.isEmpty, let value = Int(customText) {
            return max(minAmount, min(maxAmount, value))
        }
        return selectedAmount
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.card) {
                    // 当前饮水量显示区域
                    heroAmountSection
                        .padding(.top, AppSpacing.compact)

                    // 快速选择
                    presetSection

                    // 自定义输入
                    customSection
                }
                .padding(.horizontal, AppSpacing.screen)
                .padding(.vertical, AppSpacing.card)
            }
            .background(AppColor.background)
            .navigationTitle("添加饮水记录")
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
                confirmButton
                    .padding(.horizontal, AppSpacing.screen)
                    .padding(.vertical, AppSpacing.regular)
                    .background(AppColor.background)
            }
        }
        .sheetAppBackground()
    }

    // MARK: - 当前饮水量显示
    private var heroAmountSection: some View {
        VStack(spacing: AppSpacing.regular) {
            Text("本次饮水量")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColor.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(displayAmount)")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .contentTransition(.numericText(value: Double(displayAmount)))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: displayAmount)
                Text("ml")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(AppColor.textSecondary)
            }
            .padding(.vertical, AppSpacing.compact)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.card)
        .contentStyle()
    }

    // MARK: - 快速选择
    private var presetSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.regular) {
            Text("快速选择")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColor.textSecondary)

            HStack(spacing: AppSpacing.regular) {
                ForEach(presetAmounts, id: \.self) { amount in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            selectedAmount = amount
                            customText = ""
                            isInputFocused = false
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 20))
                            Text("\(amount)ml")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.regular)
                    }
                    .buttonStyle(GlassSelectButtonStyle(
                        isSelected: customText.isEmpty && selectedAmount == amount,
                        tint: waterTint,
                        cornerRadius: AppRadius.medium
                    ))
                }
            }
        }
    }

    // MARK: - 自定义输入
    private var customSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.regular) {
            Text("自定义饮水量 (\(minAmount)-\(maxAmount)ml)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColor.textSecondary)

            HStack(spacing: AppSpacing.regular) {
                TextField("输入饮水量", text: $customText)
                    .keyboardType(.numberPad)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .focused($isInputFocused)
                    .onChange(of: customText) { _, newValue in
                        // 仅保留数字
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered != newValue {
                            customText = filtered
                            return
                        }
                        // 限制范围
                        if let v = Int(filtered), v > maxAmount {
                            customText = "\(maxAmount)"
                        }
                    }
                Text("ml")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppColor.textSecondary)
            }
            .inputFieldStyle()

            // 滑块
            VStack(spacing: 8) {
                Slider(
                    value: Binding(
                        get: { Double(displayAmount) },
                        set: { newValue in
                            selectedAmount = Int(newValue)
                            customText = ""
                        }
                    ),
                    in: Double(minAmount)...Double(maxAmount),
                    step: Double(step)
                )
                .tint(waterTint)

                HStack {
                    Text("\(minAmount)ml")
                    Spacer()
                    Text("\(maxAmount)ml")
                }
                .font(.system(size: 12))
                .foregroundStyle(AppColor.textSecondary)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - 确认按钮
    private var confirmButton: some View {
        Button {
            let finalAmount = displayAmount
            onAdd(finalAmount)
            dismiss()
        } label: {
            Text("确认添加")
        }
        .buttonStyle(PrimaryActionButtonStyle(tint: waterTint))
    }
}

#Preview {
    AddWaterRecordSheet(onAdd: { _ in })
}
