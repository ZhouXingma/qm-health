import SwiftUI

// MARK: - 今日用药计划卡片
/// 与实际用药记录分开显示，突出待服和已服状态。
struct TodayMedicinePlanCard: View {
    let plan: TodayMedicinePlanDTO
    var onTap: () -> Void = {}

    private var statusColor: Color {
        plan.isTaken ? Color.theme(.primary) : Color("warning")
    }

    private var statusTitle: String {
        plan.isTaken ? "已服用" : "待服用"
    }

    private var statusIcon: String {
        plan.isTaken ? "checkmark.circle.fill" : "clock.badge.exclamationmark.fill"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(statusColor.opacity(0.14))
                        .frame(width: 44, height: 44)

                    Image(systemName: plan.isTaken ? "pills.fill" : "pills.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(statusColor)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(plan.medicineName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color("text_primary"))
                        .lineLimit(1)

                    HStack(spacing: 7) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 11))
                        Text("今日 \(plan.time) 应服")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Color("text_secondary"))
                }

                Spacer(minLength: 8)

                Label(statusTitle, systemImage: statusIcon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(statusColor.opacity(0.12)))
            }

            HStack(spacing: 8) {
                if !plan.specificationText.isEmpty {
                    detailTag(icon: "cross.vial", text: plan.specificationText)
                }
                detailTag(icon: "pills", text: "本次 \(plan.doseText)")

                Spacer(minLength: 0)

                if plan.isTaken, let takingTime = plan.takingTime, !takingTime.isEmpty {
                    Text("实际：\(takingTime)")
                        .font(.system(size: 11))
                        .foregroundStyle(Color("text_secondary"))
                        .lineLimit(1)
                }
            }

            if let medicalAdvice = plan.medicalAdvice, !medicalAdvice.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 12))
                    Text(medicalAdvice)
                        .font(.system(size: 12))
                        .lineLimit(2)
                }
                .foregroundStyle(Color("text_secondary"))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color("input_bg"))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .appGlass(
            Glass.regular.interactive().tint(statusColor.opacity(plan.isTaken ? 0.14 : 0.18)),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        ) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(statusColor.opacity(plan.isTaken ? 0.06 : 0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(statusColor.opacity(plan.isTaken ? 0.22 : 0.36), lineWidth: 1)
                )
        }
        .onTapGesture(perform: onTap)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("点击添加本次用药记录")
    }

    private func detailTag(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color("text_secondary"))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color("content_bg").opacity(0.85))
            .clipShape(Capsule())
    }
}

#Preview {
    TodayMedicinePlanCard(
        plan: TodayMedicinePlanDTO(
            planId: "preview",
            medicineName: "维生素 B12 片",
            medicineForm: "2",
            specification: "25",
            specificationUnit: "mcg",
            frequencyType: 4,
            time: "08:00",
            doseUnit: "片",
            doseAmount: 1,
            isTaken: false,
            takingRecordId: nil,
            takingTime: nil,
            medicalAdvice: "建议早餐后服用",
            lastTakingTime: nil
        )
    )
    .padding()
}
