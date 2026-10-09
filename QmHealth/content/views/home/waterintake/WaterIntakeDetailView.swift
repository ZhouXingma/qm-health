//
//  WaterIntakeDetailView.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/11/17.
//

import SwiftUI

struct WaterIntakeDetailView: View {
    @Environment(\.dismiss) private var dismiss

    // 日期范围
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var unitCode = 5

    // 数据
    @State private var currentIntake: Double = 0
    @State private var targetIntake: Double? = nil
    @State private var recordCount: Int = 0
    @State private var progress: Double = 0.0
    @State private var chartData: [ScrollChartDataPoint] = []
    @State private var waterRecords: [WaterRecord] = []

    // 动画状态
    @State private var appearAnimation = false
    @State private var showAddButton = false

    // 弹窗状态
    @State private var showAddRecordSheet = false
    @State private var showEditTargetSheet = false
    @State private var popManager: PopManager = PopManager()

    private let waterTint = Color.blue
    private let targetTint = Color.orange

    var progressValue: Double {
        guard let targetIntakeValue = targetIntake, targetIntakeValue > 0 else {
            return 0
        }
        return min(currentIntake / targetIntakeValue, 1.0)
    }

    var progressColors: [Color] {
        return progressValue >= 1.0
            ? [Color.green, Color.mint]
            : [waterTint, Color.cyan]
    }

    var targetIntakeStr: String {
        guard let targetIntakeValue = targetIntake else {
            return ""
        }
        return String(format: "%.0f", targetIntakeValue)
    }

    var body: some View {
        ZStack {
            // 玻璃背景
            VStack(spacing: 0) {
                // 页面头部
                pageHeader
                    .padding(.horizontal, AppSpacing.screen)
                    .padding(.top, 10)
                    .padding(.bottom, AppSpacing.regular)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.regular) {
                        // 日期选择器
                        dateSelectorSection
                        // 统计卡片区域
                        statisticsSection
                        // 图表区域
                        chartSection
                        // 记录列表
                        recordsSection
                    }
                    .padding(.horizontal, AppSpacing.screen)
                    .padding(.top, AppSpacing.compact)
                    .padding(.bottom, 100)
                }
                .refreshable {
                    loadData()
                }
            }

            // 浮动添加按钮
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    addRecordButton
                        .padding(.trailing, AppSpacing.screen)
                        .padding(.bottom, 30)
                }
            }
        }
        .background(AppColor.background)
        .toolbar(.hidden)
        .onAppear {
            initData()
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                appearAnimation = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.4)) {
                showAddButton = true
            }
        }
        .withLocalPop(popManager)
        .sheet(isPresented: $showAddRecordSheet) {
            AddWaterRecordSheet(
                onAdd: { amount in
                    addWaterRecord(amount: amount)
                }
            )
        }
        .sheet(isPresented: $showEditTargetSheet) {
            WaterDrinkEditTargetView(
                targetIntake: $targetIntake,
                onSave: {
                    updateProgress()
                }
            )
        }
        .edgeSwipeBack()
    }

    // MARK: - 页面头部
    private var pageHeader: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.theme(.primary))
                    .frame(width: 32, height: 32)
                    .glassPill()
            }

            Spacer()

            Text("饮水记录")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppColor.textPrimary)

            Spacer()

            // 占位符保持居中
            Color.clear
                .frame(width: 32, height: 32)
        }
    }

    // MARK: - 日期选择器
    private var dateSelectorSection: some View {
        DateRangeSelect(
            showDateUnit: false,
            startDate: $startDate,
            endDate: $endDate,
            unitCode: $unitCode,
            color: waterTint
        )
        .onChange(of: unitCode) { _, _ in
            loadData()
        }
        .onChange(of: startDate) { _, _ in
            loadData()
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : -20)
        .animation(.easeOut(duration: 0.5).delay(0.1), value: appearAnimation)
    }

    // MARK: - 统计卡片区域
    private var statisticsSection: some View {
        VStack(spacing: AppSpacing.regular) {
            HStack(spacing: AppSpacing.regular) {
                StatCard(
                    title: "总饮水量",
                    value: "\(Int(currentIntake))",
                    unit: "ml",
                    icon: "drop.fill",
                    colors: [waterTint, Color.cyan],
                    delay: 0.2
                )

                StatCard(
                    title: "完成度",
                    value: "\(Int(progressValue * 100))",
                    unit: "%",
                    icon: "checkmark.circle.fill",
                    colors: progressColors,
                    delay: 0.3
                )
            }

            HStack(spacing: AppSpacing.regular) {
                StatCard(
                    title: "记录数",
                    value: "\(recordCount)",
                    unit: "次",
                    icon: "list.bullet",
                    colors: [Color.purple, Color.pink],
                    delay: 0.4
                )

                Button(action: {
                    showEditTargetSheet = true
                }) {
                    StatCard(
                        title: "目标",
                        value: targetIntakeStr,
                        unit: "ml",
                        icon: "target",
                        colors: [targetTint, Color.yellow],
                        delay: 0.5,
                        showEditIcon: true
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 20)
        .animation(.easeOut(duration: 0.6).delay(0.2), value: appearAnimation)
    }

    // MARK: - 图表区域
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.regular) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [waterTint, Color.cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("饮水趋势")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
                Spacer()
            }

            VStack(spacing: 0) {
                if !chartData.isEmpty {
                    ScrollChartLine(
                        data: $chartData,
                        style: ScrollChartStyle(
                            lineColor: [waterTint, Color.cyan],
                            lineWidth: 3,
                            gradientColors: [waterTint.opacity(0.3), Color.cyan.opacity(0.05)],
                            pointColor: waterTint,
                            pointBackgroundColor: Color.white,
                            animationDuration: 1.5,
                            showXAxis: true,
                            showYAxis: true,
                            showGradient: true,
                            xAxisMinSpace: 50,
                            yAxisSep: 5,
                            smoothness: 0.5,
                            showPointCircle: true,
                            showYLines: false,
                            maxValue: 3000,
                            minValue: 0,
                            showAverageLine: true,
                            averageLineColor: waterTint.opacity(0.5),
                            averageLineWidth: 2
                        )
                    )
                    .frame(height: 200)
                } else {
                    VStack(spacing: AppSpacing.regular) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 40))
                            .foregroundStyle(AppColor.textSecondary.opacity(0.5))
                        Text("暂无数据")
                            .font(.system(size: 14))
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .cardStyle()
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 20)
        .animation(.easeOut(duration: 0.6).delay(0.3), value: appearAnimation)
    }

    // MARK: - 记录列表
    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.regular) {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [waterTint, Color.cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("详细记录")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
                Spacer()
                Text("\(recordCount) 次")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColor.textSecondary)
            }

            if waterRecords.isEmpty {
                VStack(spacing: AppSpacing.regular) {
                    Image(systemName: "drop")
                        .font(.system(size: 40))
                        .foregroundStyle(AppColor.textSecondary.opacity(0.5))
                    Text("暂无记录")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColor.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .contentStyle()
            } else {
                LazyVStack(spacing: AppSpacing.regular) {
                    ForEach(Array(waterRecords.enumerated()), id: \.element.id) { index, record in
                        WaterRecordRow(
                            record: record,
                            onDelete: {
                                popManager.showActionPop(
                                    title: "删除确认",
                                    description: "删除后不可恢复，是否确认删除",
                                    buttonText: "删除",
                                    icon: .warn,
                                    buttonCancleShow: true,
                                    buttonCancleTitle: "取消",
                                    customAction: {
                                        self.deleteWaterRecord(record: record)
                                        self.popManager.closePop()
                                    },
                                    customCancelAction: {
                                        self.popManager.closePop()
                                    }
                                )
                            }
                        )
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(x: appearAnimation ? 0 : -30)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.7)
                                .delay(0.4 + Double(index) * 0.1),
                            value: appearAnimation
                        )
                    }
                }
            }
        }
    }

    // MARK: - 浮动添加按钮
    private var addRecordButton: some View {
        Button(action: {
            showAddRecordSheet = true
        }) {
            HStack(spacing: AppSpacing.compact) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                Text("添加")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, AppSpacing.regular)
            .padding(.vertical, AppSpacing.regular)
        }
        .buttonStyle(GlassPillColorButtonStyle(tint: waterTint))
        .scaleEffect(showAddButton ? 1 : 0.8)
        .opacity(showAddButton ? 1 : 0)
    }

    // MARK: - 数据初始化
    private func initData() {
        let calendar = Calendar.current
        startDate = calendar.startOfDay(for: Date())
        endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: Date()) ?? Date()
        loadData()
    }

    private func loadData() {
        loadTarget()
        loadTodayData()
    }

    private func loadTarget() {
        let getParam = MetaDataRecordLatestParam(metadataCode: "饮酒目标")
        BgResultNetWork<MetaDataRecordLatestParam, UsersMetadataRecordDTO>
            .post(apiUrl(METADATA_RECORD_LATEST), params: getParam)
            .complicationHand { (r: UsersMetadataRecordDTO?) in
                DispatchQueue.main.async {
                    self.targetIntake = StringUtils.trans2Double(r?.metadataValue)
                }
            }
            .responseDecodable()
    }

    private func loadTodayData() {
        let queryDTO = UsersWaterIntakeRecordQueryDTO(date: DateUtils.formatDate(startDate, format: DateUtils.DateFormat.ymd))
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
                    recordCount = waterRecords.count
                    currentIntake = waterRecords.reduce(0) { $0 + Double($1.amount) }
                }
            }
            .finalHandleFunc({ _ in
                DispatchQueue.main.async {
                    updateChartData()
                    updateProgress()
                }
            })
            .responseDecodable()
    }

    private func updateChartData() {
        var data: [ScrollChartDataPoint] = []
        for item in waterRecords {
            let p = ScrollChartDataPoint(label: item.time, value: Double(item.amount))
            data.insert(p, at: 0)
        }
        chartData = data
    }

    private func updateProgress() {
        withAnimation(.easeInOut(duration: 0.8)) {
            progress = progressValue
        }
    }

    private func addWaterRecord(amount: Int) {
        let addParam = UsersWaterIntakeRecordDTO(intakeMl: amount, bizLabel: 1)
        BgResultNetWork<UsersWaterIntakeRecordDTO, String>
            .post(apiUrl(WATER_INTAKE_SAVE), params: addParam)
            .complicationHand { (r: String?) in
                DispatchQueue.main.async {
                    loadData()
                }
            }
            .responseDecodable()
    }

    private func deleteWaterRecord(record: WaterRecord) {
        BgResultNetWork<[String: String], Int32>
            .post(apiUrl(WATER_INTAKE_DELETE), params: ["id": record.id])
            .complicationHand { (r: Int32?) in
                DispatchQueue.main.async {
                    loadData()
                }
            }
            .responseDecodable()
    }
}

// MARK: - 统计卡片组件
struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let colors: [Color]
    let delay: Double
    var showEditIcon: Bool = false

    @State private var appear = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.regular) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                if showEditIcon {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: colors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(0.7)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)
                Text(unit)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .cardStyle()
        .scaleEffect(appear ? 1 : 0.9)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay)) {
                appear = true
            }
        }
    }
}

// MARK: - 记录行组件
struct WaterRecordRow: View {
    let record: WaterRecord
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.regular) {
            // 左侧饮水量
            HStack(spacing: AppSpacing.regular) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 12, height: 12)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: AppSpacing.compact) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.blue, Color.cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("\(record.amount)ml")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppColor.textPrimary)
                    }

                    Text(record.time)
                        .font(.system(size: 13))
                        .foregroundStyle(AppColor.textSecondary)
                }
            }

            Spacer()

            // 删除按钮
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(GlassPillColorButtonStyle(tint: AppColor.error, cornerRadius: 18))
        }
        .padding(AppSpacing.regular)
        .contentStyle()
    }
}

// MARK: - 数据模型
struct WaterRecord: Identifiable {
    let id: String
    let time: String
    let amount: Int
    let date: Date
}

// MARK: - 玻璃药丸按钮（带 tint 色，适合浮动按钮）
struct GlassPillColorButtonStyle: ButtonStyle {
    @ObservedObject private var config = AppGlassConfig.shared
    var tint: Color
    var cornerRadius: CGFloat = 28

    func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

        return label
            .appGlass(.regular.interactive().tint(tint), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint)
            }
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .shadow(color: tint.opacity(0.35), radius: 10, x: 0, y: 4)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    WaterIntakeDetailView()
}
