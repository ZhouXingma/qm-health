//
//  WaterIntakeView.swift
//  QmHealth
//  饮水打卡模块
//  Created by 周荥马 on 2025/9/15.
//

import SwiftUI

struct WaterIntakeView: View {
    // 首页刷新事件总线
    @EnvironmentObject var refreshBus: HomeRefreshBus
    @State private var currentIntake: Double = 0
    @State private var targetIntake: Double? = nil
    @State private var progress: Double = 0.0
    @State private var waterRecords: [WaterRecord] = []

    private let waterBlue = Color.blue
    private let waterCyan = Color.cyan

    var progressValue: Double {
        guard let targetIntakeValue = targetIntake, targetIntakeValue > 0 else {
            return 0
        }
        return min(currentIntake / targetIntakeValue, 1.0)
    }

    var progressColors: [Color] {
        return progressValue >= 1.0
            ? [Color.green, Color.mint]
            : [waterBlue, waterCyan]
    }

    var body: some View {
        VStack(spacing: AppSpacing.regular) {
            // 标题
            HStack {
                HStack(spacing: AppSpacing.compact) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [waterBlue, waterCyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("饮水打卡")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColor.textPrimary)
                }
                Spacer()
                NavigationLink {
                    WaterIntakeDetailView()
                } label: {
                    Text("查看更多")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(waterCyan)
                }
            }

            // 主要进度区域
            VStack(spacing: AppSpacing.regular) {
                ZStack {
                    CircleProgress(
                        lineWeight: 10.0,
                        colors: progressColors,
                        progress: $progress
                    )
                    .frame(width: 120, height: 120)

                    VStack(spacing: 4) {
                        Text("\(Int(currentIntake))")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(AppColor.textPrimary)
                        Text("ml")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }
                .padding(.vertical, AppSpacing.compact)

                HStack(spacing: 4) {
                    Text("目标")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColor.textSecondary)
                    if let targetIntakeValue = targetIntake {
                        Text("\(Int(targetIntakeValue))ml")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColor.textPrimary)
                        Text("·")
                            .foregroundStyle(AppColor.textSecondary)
                        Text("\(Int(progressValue * 100))%")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(progressValue >= 1.0 ? Color.green : waterBlue)
                    } else {
                        Text("未设置")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }
            }

            // 快速添加按钮
            VStack(spacing: AppSpacing.regular) {
                Text("快速添加")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    ForEach([150, 250, 300, 500], id: \.self) { amount in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                addWater(amount: amount)
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 18))
                                Text("\(amount)ml")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(PrimaryActionButtonStyle(
                            tint: waterBlue,
                            cornerRadius: AppRadius.medium,
                            verticalPadding: AppSpacing.regular
                        ))
                    }
                }
            }

            // 今日记录
            if !waterRecords.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("今日记录")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(waterRecords.suffix(5).reversed(), id: \.id) { record in
                                WaterRecordCard(record: record)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
        }
        .cardStyle()
        .onAppear {
            loadData()
        }
        .onChange(of: refreshBus.refreshTrigger) { _, _ in
            loadData()
        }
        .onChange(of: currentIntake) { _, _ in
            updateProgress()
        }
    }

    // MARK: - 饮水记录数据模型
    struct WaterRecord: Identifiable {
        let id: String
        let time: String
        let amount: Int
        let date: Date
    }

    // MARK: - 饮水记录卡片
    struct WaterRecordCard: View {
        let record: WaterRecord

        var body: some View {
            HStack(spacing: AppSpacing.compact) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(record.amount)ml")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColor.textPrimary)
                    Text(record.time)
                        .font(.system(size: 11))
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, AppSpacing.compact)
            .background(Capsule().fill(Color.blue.opacity(0.12)))
        }
    }

    // MARK: - 方法

    private func loadData() {
        // 先清空旧账户的 state，避免接口返回 nil 时仍展示上一个账号的饮水记录/目标
        currentIntake = 0
        targetIntake = nil
        waterRecords = []
        progress = 0
        loadTarget()
        loadTodayData()
    }

    private func loadTarget() {
        // 清空旧目标，避免接口返回 nil 时仍展示上一个账号的目标
        targetIntake = nil
        let getParam = MetaDataRecordLatestParam(metadataCode: "饮酒目标")
        BgResultNetWork<MetaDataRecordLatestParam, UsersMetadataRecordDTO>
            .post(apiUrl(METADATA_RECORD_LATEST), params: getParam)
            .complicationHand { (r: UsersMetadataRecordDTO?) in
                DispatchQueue.main.async {
                    self.targetIntake = StringUtils.trans2Double(r?.metadataValue)
                    self.updateProgress()
                }
            }
            .responseDecodable()
    }

    private func loadTodayData() {
        // 清空旧记录，避免接口返回 nil 时仍展示上一个账号的饮水记录
        waterRecords = []
        currentIntake = 0
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let queryDTO = UsersWaterIntakeRecordQueryDTO(date: DateUtils.formatDate(today, format: DateUtils.DateFormat.ymd))

        BgResultNetWork<UsersWaterIntakeRecordQueryDTO, [UsersWaterIntakeRecordDTO]>
            .post(apiUrl(WATER_INTAKE_LISTBYDATE), params: queryDTO)
            .complicationHand { (r: [UsersWaterIntakeRecordDTO]?) in
                guard let resultList = r else {
                    return
                }
                var waterRecordsTemp: [WaterRecord] = []
                for rItem in resultList {
                    guard let gmtModified = rItem.gmtModified else {
                        continue
                    }
                    let record = WaterRecord(
                        id: rItem.id ?? UUID().uuidString,
                        time: DateUtils.formatDate(gmtModified, format: DateUtils.DateFormat.hm),
                        amount: rItem.intakeMl ?? 0,
                        date: gmtModified
                    )
                    waterRecordsTemp.append(record)
                }
                DispatchQueue.main.async {
                    self.waterRecords = waterRecordsTemp
                    self.currentIntake = waterRecordsTemp.reduce(0) { $0 + Double($1.amount) }
                    self.updateProgress()
                }
            }
            .responseDecodable()
    }

    private func addWater(amount: Int) {
        let addParam = UsersWaterIntakeRecordDTO(intakeMl: amount, bizLabel: 1)
        BgResultNetWork<UsersWaterIntakeRecordDTO, String>
            .post(apiUrl(WATER_INTAKE_SAVE), params: addParam)
            .complicationHand { (r: String?) in
                DispatchQueue.main.async {
                    self.loadTodayData()
                }
            }
            .responseDecodable()
    }

    private func updateProgress() {
        withAnimation {
            progress = progressValue
        }
    }
}

#Preview {
    WaterIntakeView()
        .padding()
        .background(AppColor.background)
}
