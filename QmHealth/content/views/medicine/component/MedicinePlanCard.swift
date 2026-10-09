//
//  MedicinePlanCard.swift
//  QmHealth
//  用药计划卡片
//
//  Created by 周荥马 on 2025/12/8.
//

import SwiftUI

// MARK: - 用药计划卡片
struct MedicinePlanCard: View {
    let plan: UsersMedicinePlanDTO
    /// 值域数据：medicineForm / medicineSpecificationUnit / medicineFrequencyType
    let valueScopes: [String: ValueScopeInfo]
    /// 点击药品信息区域时打开编辑页面。
    var onEdit: () -> Void = {}

    @State private var isDetailsExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow

            if isDetailsExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    Divider()
                        .background(Color("divider"))

                    frequencySection

                    if let advice = plan.medicalAdvice, !advice.isEmpty {
                        adviceRow(advice)
                    }

                    footerRow
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .cardStyle()
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: isDetailsExpanded)
    }

    // MARK: - 头部：图标 + 药品名称 + 规格 + 状态标签
    private var headerRow: some View {
        HStack(alignment: .center, spacing: 12) {
            // 药品图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.theme(.primary).opacity(0.16), Color.theme(.secondary).opacity(0.16)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: MedicineFormIcon.systemName(for: medicineFormDescription))
                    .font(.system(size: 19))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.theme(.primary), Color.theme(.secondary)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .contentShape(Circle())
            .onTapGesture(perform: onEdit)

            VStack(alignment: .leading, spacing: 4) {
                Text(plan.medicineName ?? "未知药品")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))
                    .lineLimit(1)

                if !subtitleText.isEmpty {
                    Text(subtitleText)
                        .font(.system(size: 12))
                        .foregroundStyle(Color("text_secondary"))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)

            Spacer(minLength: 8)

            Button {
                isDetailsExpanded.toggle()
            } label: {
                Image(systemName: isDetailsExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(
                        isDetailsExpanded
                            ? Color.theme(.primary)
                            : Color("text_secondary").opacity(0.48)
                    )
                    .frame(width: 38, height: 38)
                    .background(
                        Circle().fill(
                            isDetailsExpanded
                                ? Color.theme(.primary).opacity(0.12)
                                : Color.clear
                        )
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isDetailsExpanded ? "收起用药计划详情" : "展开用药计划详情")
            .accessibilityHint("查看服药安排、医嘱、计划周期和来源")
        }
    }

    /// 剂型中文描述，用于显示和选择对应的 SF Symbol。
    private var medicineFormDescription: String? {
        guard let form = plan.medicineForm else { return nil }
        return valueScopes["medicineForm"]?.desc(forValue: form)
    }

    /// 剂型 + 规格（如 "药片・0.25g"）
    private var subtitleText: String {
        var parts: [String] = []
        if let medicineFormDescription {
            parts.append(medicineFormDescription)
        }
        if !plan.specificationString.isEmpty {
            parts.append(plan.specificationString)
        }
        return parts.joined(separator: "・")
    }

    // MARK: - 频次区域：图标 + 主描述 + 时间点标签
    private var frequencySection: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.theme(.primary).opacity(0.1))
                    .frame(width: 28, height: 28)

                if let icon = plan.frequencyTypeEnum?.icon {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.theme(.primary))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(frequencyMainText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color("text_primary"))

                if plan.frequencyTypeEnum == .weekly {
                    weeklyScheduleRows
                } else if !displayTimes.isEmpty {
                    HFlow(alignment: .top, itemSpacing: 6, rowSpacing: 6) {
                        ForEach(Array(displayTimes.enumerated()), id: \.offset) { _, item in
                            doseChip(dayLabel: nil, time: item.time)
                        }
                    }
                }
            }
        }
    }

    private var weeklyScheduleRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array((plan.takingInfo?.weeklyDays ?? []).enumerated()), id: \.offset) { _, day in
                HStack(alignment: .top, spacing: 9) {
                    Text(day.label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.theme(.primary))
                        .frame(width: 28, height: 27)
                        .background(Color.theme(.primary).opacity(0.1))
                        .clipShape(Capsule())

                    HFlow(alignment: .top, itemSpacing: 6, rowSpacing: 6) {
                        ForEach(Array(day.times.enumerated()), id: \.offset) { _, time in
                            doseChip(dayLabel: nil, time: time)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// 单个时间点标签（如 "08:00・1颗" 或 "周一 08:00・1颗"）
    private func doseChip(dayLabel: String?, time: DoseTime) -> some View {
        HStack(spacing: 3) {
            if let dayLabel = dayLabel {
                Text(dayLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.theme(.primary))
            }
            Text(time.time)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color("text_primary"))
            Text("・\(Self.doseAmountText(time.doseAmount))\(time.doseUnit)")
                .font(.system(size: 11))
                .foregroundStyle(Color("text_secondary"))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color("input_bg"))
        .cornerRadius(8)
    }

    /// 频次主描述文案（不含时间点，时间点单独展示为标签）
    private var frequencyMainText: String {
        let frequencyLabel: String
        if let frequencyType = plan.frequencyType,
           let desc = valueScopes["medicineFrequencyType"]?.desc(forValue: "\(frequencyType)") {
            frequencyLabel = desc
        } else {
            frequencyLabel = ""
        }

        let info = plan.takingInfo

        switch plan.frequencyTypeEnum {
        case .daily:
            return frequencyLabel.isEmpty ? "每天" : frequencyLabel
        case .cyclic:
            let unit = (info?.cycleUnit == 2) ? "周" : "天"
            let use = info?.cycleUseTimes ?? 0
            let stop = info?.cycleStopTimes ?? 0
            return "服\(use)\(unit)停\(stop)\(unit)"
        case .weekly:
            let days = info?.weeklyDays ?? []
            return days.map { $0.label }.joined(separator: "、")
        case .interval:
            let intervalDays = info?.intervalDays ?? 1
            return "每隔\(intervalDays)天"
        case .asNeeded:
            return frequencyLabel.isEmpty ? "按需服用" : frequencyLabel
        case .none:
            return frequencyLabel.isEmpty ? "暂无服药安排" : frequencyLabel
        }
    }

    /// 需要展示为标签的时间点（每周特定日会带上星期标签，超过 4 个折叠提示）
    private var displayTimes: [(dayLabel: String?, time: DoseTime)] {
        let info = plan.takingInfo
        var items: [(dayLabel: String?, time: DoseTime)] = []

        switch plan.frequencyTypeEnum {
        case .daily, .cyclic, .interval:
            items = (info?.times ?? []).map { (nil, $0) }
        case .weekly:
            for day in info?.weeklyDays ?? [] {
                for time in day.times {
                    items.append((day.label, time))
                }
            }
        case .asNeeded, .none:
            items = []
        }

        return items
    }

    /// 剂量数值展示，去除多余的小数点0（1.0 -> 1，0.5 -> 0.5）
    private static func doseAmountText(_ amount: Double) -> String {
        if amount == amount.rounded() {
            return String(Int(amount))
        }
        return String(amount)
    }

    // MARK: - 医嘱/备注提示条
    private func adviceRow(_ advice: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color("warning"))

            Text(advice)
                .font(.system(size: 12))
                .foregroundStyle(Color("text_secondary"))
                .lineLimit(2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("warning").opacity(0.08))
        .cornerRadius(10)
    }

    // MARK: - 底部：计划周期 + 来源
    private var footerRow: some View {
        HStack(spacing: 14) {
            LabelTag(icon: "calendar", text: periodText)

            if let sourceType = plan.sourceTypeEnum {
                LabelTag(icon: "tag", text: sourceType.displayName)
            }

            Spacer()
        }
    }

    /// 计划周期文案（如 "2025-01-01 至 长期"）
    private var periodText: String {
        let start = plan.startDate ?? "--"
        let end = plan.endDate?.isEmpty == false ? plan.endDate! : "长期"
        return "\(start) 至 \(end)"
    }
}

#Preview {
    let mockValueScopes: [String: ValueScopeInfo] = [
        "medicineForm": ValueScopeInfo(code: "medicineForm", desc: "药品类型", valueScope: [
            ValueScopeItem(value: "2", desc: "药片")
        ]),
        "medicineFrequencyType": ValueScopeInfo(code: "medicineFrequencyType", desc: "用药频率单位", valueScope: [
            ValueScopeItem(value: "1", desc: "每天"),
            ValueScopeItem(value: "2", desc: "循环定时"),
            ValueScopeItem(value: "3", desc: "每周特定日"),
            ValueScopeItem(value: "4", desc: "每隔N天"),
            ValueScopeItem(value: "5", desc: "按需")
        ])
    ]

    return ScrollView {
        VStack(spacing: 12) {
            MedicinePlanCard(
                plan: UsersMedicinePlanDTO(
                    id: "1",
                    medicineName: "阿莫西林胶囊",
                    medicineForm: "2",
                    specification: "0.25",
                    specificationUnit: "g",
                    frequencyType: 1,
                    takingInfo: TakingInfoRaw(times: [
                        DoseTime(time: "08:00", doseUnit: "颗", doseAmount: 1),
                        DoseTime(time: "12:00", doseUnit: "颗", doseAmount: 0.5)
                    ]),
                    startDate: "2025-01-01",
                    endDate: nil,
                    sourceType: 1,
                    medicalAdvice: "饭后服用，避免空腹刺激肠胃"
                ),
                valueScopes: mockValueScopes
            )

            MedicinePlanCard(
                plan: UsersMedicinePlanDTO(
                    id: "2",
                    medicineName: "维生素D滴剂",
                    medicineForm: "13",
                    specification: "400",
                    specificationUnit: "IU",
                    frequencyType: 3,
                    takingInfo: TakingInfoRaw(
                        mon: [DoseTime(time: "08:00", doseUnit: "滴", doseAmount: 2)],
                        wed: [DoseTime(time: "08:00", doseUnit: "滴", doseAmount: 2)],
                        fri: [DoseTime(time: "08:00", doseUnit: "滴", doseAmount: 2)]
                    ),
                    startDate: "2025-01-15",
                    sourceType: 2
                ),
                valueScopes: mockValueScopes
            )

            MedicinePlanCard(
                plan: UsersMedicinePlanDTO(
                    id: "3",
                    medicineName: "布洛芬缓释胶囊",
                    frequencyType: 5,
                    sourceType: 3
                ),
                valueScopes: mockValueScopes
            )
        }
        .padding()
    }
    .background(Color("background"))
}
