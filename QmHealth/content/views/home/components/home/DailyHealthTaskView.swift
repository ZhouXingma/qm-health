//
//  DailyHealthTaskView.swift
//  QmHealth
//  每日健康任务模块
//  Created on 2026/6/26.
//

import SwiftUI

struct DailyHealthTaskView: View {
    // 首页刷新事件总线
    @EnvironmentObject var refreshBus: HomeRefreshBus
    @State private var tasks: [DailyTaskDTO] = []
    @State private var isLoading = true
    @State private var hasError = false
    @State private var progress: Double = 0.0
    @State private var selectedTask: DailyTaskDTO?
    @State private var filterStatus: Int16? = nil  // nil=全部, 0=未开始, 1=进行中, 2=已完成, 3=已取消

    // MARK: - 统计数据

    /// 有效任务（排除已取消）
    private var validTasks: [DailyTaskDTO] {
        tasks.filter { $0.status != DailyTaskStatus.cancelled.rawValue }
    }

    /// 筛选后展示的任务
    private var displayedTasks: [DailyTaskDTO] {
        guard let f = filterStatus else { return tasks }
        return tasks.filter { $0.status == f }
    }

    /// 进行中数
    private var inProgressCount: Int {
        tasks.filter { $0.status == DailyTaskStatus.inProgress.rawValue }.count
    }

    /// 已完成数
    private var completedCount: Int {
        tasks.filter { $0.status == DailyTaskStatus.completed.rawValue }.count
    }

    /// 已取消数
    private var cancelledCount: Int {
        tasks.filter { $0.status == DailyTaskStatus.cancelled.rawValue }.count
    }

    /// 完成率
    private var completionRate: Double {
        guard !validTasks.isEmpty else { return 0 }
        return Double(completedCount) / Double(validTasks.count)
    }

    private var completionPercent: String {
        "\(Int(completionRate * 100))%"
    }

    private var progressColors: [Color] {
        if completionRate >= 1.0 {
            return [Color.green, Color.mint]
        } else {
            return [Color.theme(.primary), Color.theme(.primary).opacity(0.6)]
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            headerRow
            contentArea
        }
        .cardStyle()
        .onAppear { loadTasks() }
        .onChange(of: refreshBus.refreshTrigger) { _, _ in loadTasks() }
        .onChange(of: tasks.count) { _, _ in updateProgress() }
        .sheet(item: $selectedTask) { task in
            DailyTaskEditSheet(task: task, onSave: { loadTasks() })
        }
    }

    // MARK: - 子视图

    private var headerRow: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "checklist")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.theme(.primary), Color.theme(.primary).opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("健康任务")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))
            }
            Spacer()
            NavigationLink {
                DailyHealthTaskDetailView(tasks: tasks)
            } label: {
                Text("查看更多")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.theme(.primary))
            }
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        if isLoading {
            VStack {
                ProgressView().tint(Color.theme(.primary))
            }
            .frame(height: 80)
        } else if hasError || tasks.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "checklist")
                    .font(.system(size: 32))
                    .foregroundStyle(Color("text_secondary").opacity(0.5))
                Text(tasks.isEmpty ? "暂无健康任务" : "加载失败")
                    .font(.system(size: 14))
                    .foregroundStyle(Color("text_secondary"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        } else {
            progressStats
                .padding(.vertical, 6)
            if !tasks.isEmpty {
                taskPreviewList
            }
        }
    }

    private var taskPreviewList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今日任务")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color("text_secondary"))
                .frame(maxWidth: .infinity, alignment: .leading)

            if displayedTasks.isEmpty {
                Text("无匹配任务")
                    .font(.system(size: 13))
                    .foregroundStyle(Color("text_secondary"))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(displayedTasks, id: \.id) { task in
                            Button {
                                selectedTask = task
                            } label: {
                                TaskRowCard(task: task)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 240)
            }
        }
    }

    // MARK: - 加载数据

    private func loadTasks() {
        isLoading = true
        hasError = false
        // 先清空旧账户的任务，避免接口返回 nil 时仍展示上一个账号的任务列表
        tasks = []

        let today = DateUtils.formatDate(Date(), format: DateUtils.DateFormat.ymd)
        let param = DailyTaskQueryParam(taskDate: today)

        BgResultNetWork<DailyTaskQueryParam, [DailyTaskDTO]>
            .post(apiUrl(DAILY_TASK_LIST), params: param)
            .complicationHand { (data: [DailyTaskDTO]?) in
                DispatchQueue.main.async {
                    if let taskList = data {
                        self.tasks = taskList.sorted { ($0.priority ?? 0) < ($1.priority ?? 0) }
                    }
                    updateProgress()
                    isLoading = false
                }
            }
            .errorHandle { (_, _) in
                DispatchQueue.main.async {
                    hasError = true
                    isLoading = false
                }
            }
            .responseDecodable()
    }

    private func updateProgress() {
        withAnimation {
            progress = completionRate
        }
    }

    private var progressStats: some View {
        let notStartedCount = tasks.filter { $0.status == DailyTaskStatus.notStarted.rawValue }.count
        return HStack(spacing: 0) {
            ZStack {
                CircleProgress(
                    lineWeight: 7.0,
                    colors: progressColors,
                    progress: $progress
                )
                .frame(width: 72, height: 72)

                VStack(spacing: 0) {
                    Text(completionPercent)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color("text_primary"))
                    Text("共\(tasks.count)项")
                        .font(.system(size: 10))
                        .foregroundStyle(Color("text_secondary"))
                }
            }
            .frame(width: 80)
            .padding(.trailing, 8)

            statButton(filter: DailyTaskStatus.notStarted.rawValue, value: "\(notStartedCount)", label: "未开始", color: .blue)
            statButton(filter: DailyTaskStatus.inProgress.rawValue, value: "\(inProgressCount)", label: "进行中", color: Color.theme(.primary))
            statButton(filter: DailyTaskStatus.completed.rawValue, value: "\(completedCount)", label: "已完成", color: .green)
            statButton(filter: DailyTaskStatus.cancelled.rawValue, value: "\(cancelledCount)", label: "已取消", color: .red)
        }
    }

    private func statButton(filter: Int16?, value: String, label: String, color: Color) -> some View {
        let isActive = filterStatus == filter
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                filterStatus = isActive ? nil : filter
            }
        } label: {
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 17, weight: isActive ? .bold : .medium))
                Text(label)
                    .font(.system(size: 11, weight: isActive ? .semibold : .regular))
            }
            .foregroundStyle(isActive ? color : Color("text_secondary"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? color.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 任务行卡片

struct TaskRowCard: View {
    let task: DailyTaskDTO

    private var taskType: TaskTypeEnum? {
        TaskTypeEnum(rawValue: task.taskType ?? 0)
    }

    private var taskStatus: DailyTaskStatus {
        DailyTaskStatus(rawValue: task.status ?? 0) ?? .notStarted
    }

    private var typeColor: Color {
        taskType?.color ?? Color.theme(.primary)
    }

    var body: some View {
        HStack(spacing: 12) {
            // 1、类型图标
            Image(systemName: taskType?.iconName ?? "list.bullet")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(typeColor)
                .frame(width: 24)

            // 2、任务内容
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(task.taskDesc ?? "")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(taskStatus == .completed || taskStatus == .cancelled ? Color("text_secondary") : Color("text_primary"))
                        .strikethrough(taskStatus == .completed || taskStatus == .cancelled)

                    if task.priority == DailyTaskPriority.high.rawValue {
                        Text("高优先")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.red.opacity(0.1)))
                    }

                    // 状态标签
                    statusTag
                }

                if let target = task.targetValue, !target.isEmpty {
                    Text(target)
                        .font(.system(size: 12))
                        .foregroundStyle(Color("text_secondary"))
                        .lineLimit(1)
                }
            }

            Spacer()

            // 3、状态图标
            statusIcon
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .appGlass(
            .regular.interactive().tint(AppColor.content.opacity(0.8)),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    /// 状态玻璃 tint（按任务状态变化，让液态玻璃保留状态视觉区分）
    private var statusGlassTint: Color {
        switch taskStatus {
        case .completed: return Color.green.opacity(0.22)
        case .cancelled: return Color(.systemGray6).opacity(0.6)
        default: return typeColor.opacity(0.18)
        }
    }

    /// 状态文字标签
    @ViewBuilder
    private var statusTag: some View {
        if taskStatus != .notStarted {
            Text(taskStatus.displayName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(statusTagColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(statusTagColor.opacity(0.12)))
        }
    }

    private var statusTagColor: Color {
        switch taskStatus {
        case .inProgress: return Color.theme(.primary)
        case .completed: return .green
        case .cancelled: return Color("text_secondary")
        case .notStarted: return .blue
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch taskStatus {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.green)
        case .inProgress:
            Image(systemName: "circle.dotted")
                .font(.system(size: 20))
                .foregroundStyle(typeColor)
        case .cancelled:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color("text_secondary"))
        case .notStarted:
            Image(systemName: "circle")
                .font(.system(size: 20))
                .foregroundStyle(Color("divider"))
        }
    }
}

// MARK: - 任务详情页

struct DailyHealthTaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var tasks: [DailyTaskDTO]
    @State private var selectedTask: DailyTaskDTO?
    @State private var filterStatus: Int16? = nil
    @State private var tabIndex: Int = 0

    // 统计页专属
    @State private var statDate: Date = Date()
    @State private var statTasks: [DailyTaskDTO] = []
    @State private var statLoading = false
    @State private var statRange: Int = 0  // 0=日, 1=月, 2=年

    // 月维度模拟数据
    @State private var monthlyTotalTasks: Int = 0
    @State private var monthlyNotStartedTasks: Int = 0
    @State private var monthlyInProgressTasks: Int = 0
    @State private var monthlyCompletedTasks: Int = 0
    @State private var monthlyCancelledTasks: Int = 0
    @State private var monthlyCategoryStats: [CategoryStat] = []
    @State private var monthlyHeatmapData: [DayTaskStat] = []

    // 年维度模拟数据
    @State private var yearlyTotalTasks: Int = 0
    @State private var yearlyNotStartedTasks: Int = 0
    @State private var yearlyInProgressTasks: Int = 0
    @State private var yearlyCompletedTasks: Int = 0
    @State private var yearlyCancelledTasks: Int = 0
    @State private var yearlyCategoryStats: [CategoryStat] = []
    @State private var yearlyHeatmapData: [MonthTaskStat] = []

    init(tasks: [DailyTaskDTO]) {
        _tasks = State(initialValue: tasks)
    }

    // MARK: - 今日任务计算属性

    private var displayedTasks: [DailyTaskDTO] {
        guard let f = filterStatus else { return tasks }
        return tasks.filter { $0.status == f }
    }

    private var displayedGroupedTasks: [(type: TaskTypeEnum, items: [DailyTaskDTO])] {
        let grouped = Dictionary(grouping: displayedTasks) { task -> TaskTypeEnum in
            TaskTypeEnum(rawValue: task.taskType ?? 0) ?? .other
        }
        return grouped.sorted { $0.key.rawValue < $1.key.rawValue }.map { ($0.key, $0.value) }
    }

    private var completionRate: Double {
        let valid = tasks.filter { $0.status != DailyTaskStatus.cancelled.rawValue }
        guard !valid.isEmpty else { return 0 }
        return Double(valid.filter { $0.status == DailyTaskStatus.completed.rawValue }.count) / Double(valid.count)
    }

    // MARK: - 统计页计算属性

    private var statCompletionRate: Double {
        let valid = statTasks.filter { $0.status != DailyTaskStatus.cancelled.rawValue }
        guard !valid.isEmpty else { return 0 }
        return Double(valid.filter { $0.status == DailyTaskStatus.completed.rawValue }.count) / Double(valid.count)
    }

    private var statGroupedTasks: [(type: TaskTypeEnum, items: [DailyTaskDTO])] {
        let grouped = Dictionary(grouping: statTasks) { task -> TaskTypeEnum in
            TaskTypeEnum(rawValue: task.taskType ?? 0) ?? .other
        }
        return grouped.sorted { $0.key.rawValue < $1.key.rawValue }.map { ($0.key, $0.value) }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color("background"), Color("input_bg").opacity(0.3)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            GeometryReader { geometry in
                VStack(spacing: 0) {
                    pageHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 12)

                    TabView(selection: $tabIndex) {
                        todayTab.tag(0)
                        statTab.tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(width: geometry.size.width)
                    .frame(height: geometry.size.height - headerHeight)
                }
            }
        }
        .toolbar(.hidden)
        .sheet(item: $selectedTask) { task in
            DailyTaskEditSheet(task: task, onSave: { reloadTasks() })
        }
    }

    /// 页面头部高度（topPadding 10 + header ~36 + bottomPadding 12 ≈ 58）
    private var headerHeight: CGFloat { 60 }

    // MARK: - 页面头部

    private var pageHeader: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.theme(.primary))
                    .frame(width: 32, height: 32)
                    .glassPill()
            }
            Spacer()
            VStack(spacing: 6) {
                Text(tabIndex == 0 ? "今日任务" : "任务统计")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color("text_primary"))
                HStack(spacing: 8) {
                    ForEach(0...1, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 10)
                            .frame(width: i == tabIndex ? 16 : 8, height: 6)
                            .foregroundStyle(i == tabIndex ? Color.theme(.primary) : Color("divider"))
                            .animation(.easeInOut(duration: 0.33), value: tabIndex)
                    }
                }
            }
            Spacer()
            if tabIndex == 1 {
                statRangePicker
            } else {
                Color.clear.frame(width: 32, height: 32)
            }
        }
    }

    // MARK: - Tab 0: 今日任务

    private var todayTab: some View {
        VStack(spacing: 0) {
            overviewSection
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ForEach(displayedGroupedTasks, id: \.type) { group in
                        groupSection(group)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
    }

    private var overviewSection: some View {
        let notStartedCount = tasks.filter { $0.status == DailyTaskStatus.notStarted.rawValue }.count
        let inProgressCount = tasks.filter { $0.status == DailyTaskStatus.inProgress.rawValue }.count
        let completedCount = tasks.filter { $0.status == DailyTaskStatus.completed.rawValue }.count
        let cancelledCount = tasks.filter { $0.status == DailyTaskStatus.cancelled.rawValue }.count

        return HStack(spacing: 0) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray6), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 72, height: 72)
                Circle()
                    .trim(from: 0, to: completionRate)
                    .stroke(Color.theme(.primary), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(Int(completionRate * 100))%")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color("text_primary"))
                    Text("共\(tasks.count)项")
                        .font(.system(size: 10))
                        .foregroundStyle(Color("text_secondary"))
                }
            }
            .frame(width: 80)
            .padding(.trailing, 8)

            statButton(filter: DailyTaskStatus.notStarted.rawValue, value: "\(notStartedCount)", label: "未开始", color: .blue)
            statButton(filter: DailyTaskStatus.inProgress.rawValue, value: "\(inProgressCount)", label: "进行中", color: Color.theme(.primary))
            statButton(filter: DailyTaskStatus.completed.rawValue, value: "\(completedCount)", label: "已完成", color: .green)
            statButton(filter: DailyTaskStatus.cancelled.rawValue, value: "\(cancelledCount)", label: "已取消", color: .red)
        }
        .padding(16)
        .appGlass(
            .regular.interactive().tint(AppColor.content.opacity(0.65)),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    // MARK: - Tab 1: 统计

    private var statTab: some View {
        VStack(spacing: 0) {
            // 按日：日期选择器 + 详情
            if statRange == 0 {
                // 日期选择器
                DateNavigator(date: $statDate, onDateChanged: { loadStatTasks() })
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                statOverview.padding(.horizontal, 20)

                if statLoading {
                    Spacer()
                    ProgressView().tint(Color.theme(.primary))
                    Spacer()
                } else if statTasks.isEmpty {
                    Spacer()
                    Text("该日期暂无任务").font(.system(size: 14)).foregroundStyle(Color("text_secondary"))
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            ForEach(statGroupedTasks, id: \.type) { group in
                                statGroupSection(group).padding(.horizontal, 20)
                            }
                        }
                        .padding(.top, 8).padding(.bottom, 40)
                    }
                }
            } else if statRange == 1 {
                // 按月
                MonthNavigator(date: $statDate, onDateChanged: { loadMonthlyData() })
                    .padding(.horizontal, 20).padding(.bottom, 8)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        monthlyOverviewCard.padding(.horizontal, 20)
                        monthlyCategoryStatsCard.padding(.horizontal, 20)
                        monthHeatmapCard.padding(.horizontal, 20)
                    }
                    .padding(.top, 4).padding(.bottom, 40)
                }
                .onAppear { loadMonthlyData() }
            } else {
                // 按年
                YearNavigator(date: $statDate, onDateChanged: { loadYearlyData() })
                    .padding(.horizontal, 20).padding(.bottom, 8)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        yearlyOverviewCard.padding(.horizontal, 20)
                        yearlyCategoryStatsCard.padding(.horizontal, 20)
                        yearHeatmapCard.padding(.horizontal, 20)
                    }
                    .padding(.top, 4).padding(.bottom, 40)
                }
                .onAppear { loadYearlyData() }
            }
        }
        .onAppear { loadStatTasks() }
    }

    // MARK: - 日/月/年 选择器

    private var statRangePicker: some View {
        let titles = ["日", "月", "年"]
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                statRange = (statRange + 1) % 3
            }
        } label: {
            Text(titles[statRange])
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.theme(.primary))
                .frame(width: 36, height: 36)
                .glassPill()
        }
    }

    // MARK: - 年维度视图

    /// 年度总览卡片：总计 = 未完成(未开始+进行中) + 已完成 + 已取消
    private var yearlyOverviewCard: some View {
        let notCompleted = yearlyNotStartedTasks + yearlyInProgressTasks
        return HStack(spacing: 0) {
            yearlyStatItem(value: "\(yearlyTotalTasks)", label: "总计", color: Color.theme(.primary))
            Text("=")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color("text_secondary"))
            yearlyStatItem(value: "\(notCompleted)", label: "未完成", color: .orange)
            Text("+")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color("text_secondary"))
            yearlyStatItem(value: "\(yearlyCompletedTasks)", label: "已完成", color: .green)
            Text("+")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color("text_secondary"))
            yearlyStatItem(value: "\(yearlyCancelledTasks)", label: "已取消", color: .gray)
        }
        .padding(16)
        .appGlass(
            .regular.interactive().tint(AppColor.content.opacity(0.65)),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    private func yearlyStatItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color("text_secondary"))
        }
        .frame(maxWidth: .infinity)
    }

    /// 年度按任务分类统计卡片
    private var yearlyCategoryStatsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("按任务分类")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))
                Spacer()
                Text("\(yearlyCompletedTasks)/\(yearlyTotalTasks - yearlyCancelledTasks)（\(yearlyCancelledTasks)）")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.theme(.primary))
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(Array(yearlyCategoryStats.enumerated()), id: \.offset) { i, stat in
                    if i > 0 { Divider().padding(.leading, 16) }
                    HStack(spacing: 12) {
                        Image(systemName: stat.type.iconName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(stat.type.color)
                            .frame(width: 22)
                        Text(stat.name)
                            .font(.system(size: 14))
                            .foregroundStyle(Color("text_primary"))
                        Spacer()

                        let barWidth: CGFloat = stat.validTotal > 0 ? max(4, CGFloat(stat.completed) / CGFloat(stat.validTotal) * 60) : 0
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(.systemGray6))
                                .frame(width: 60, height: 6)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(stat.type.color)
                                .frame(width: barWidth, height: 6)
                        }

                        // 已完成 / 有效总数（已取消）
                        Text("\(stat.completed)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(stat.type.color)
                        Text("/")
                            .font(.system(size: 14))
                            .foregroundStyle(Color("text_secondary"))
                        Text("\(stat.validTotal)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color("text_secondary"))
                        Text("（\(stat.cancelled)）")
                            .font(.system(size: 11))
                            .foregroundStyle(Color("text_secondary").opacity(0.7))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                }
            }
        }
        .appGlass(
            .regular.interactive().tint(AppColor.content.opacity(0.65)),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    /// 年度热力图卡片（12个月网格，点击跳月份）
    private var yearHeatmapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("各月任务统计")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color("text_primary"))
                .padding(.horizontal, 16)
                .padding(.top, 14)

            YearHeatmapView(
                date: statDate,
                data: yearlyHeatmapData,
                onMonthTapped: { targetDate in
                    statDate = targetDate
                    withAnimation(.easeInOut(duration: 0.2)) {
                        statRange = 1
                    }
                    loadMonthlyData()
                }
            )
            .padding(.horizontal, 16)

            // 图例
            HStack(spacing: 6) {
                Text("少")
                    .font(.system(size: 11))
                    .foregroundStyle(Color("text_secondary"))
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(MonthHeatmapView.heatmapColor(level: level, maxLevel: 4))
                        .frame(width: 16, height: 14)
                }
                Text("多")
                    .font(.system(size: 11))
                    .foregroundStyle(Color("text_secondary"))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .appGlass(
            .regular.interactive().tint(AppColor.content.opacity(0.65)),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    // MARK: - 年度统计数据加载

    /// 加载年度统计数据
    private func loadYearlyData() {
        let year = Calendar.current.component(.year, from: statDate)
        let param = YearlyStatsQueryParam(year: year)
        let request: BgResultNetWork<YearlyStatsQueryParam, YearlyStatsDTO> = .post(apiUrl(DAILY_TASK_YEARLY_STATS), params: param)
        request
            .complicationHand { (dto: YearlyStatsDTO?) in
                DispatchQueue.main.async {
                    applyYearlyStats(dto)
                }
            }
            .errorHandle { _, _ in
                // 接口失败保持当前数据不变
            }
            .responseDecodable()
    }

    /// 将接口返回数据应用到状态变量
    /// API 状态码：0=未开始, 2=已取消, 3=已完成（1=进行中未返回则默认为0）
    private func applyYearlyStats(_ dto: YearlyStatsDTO?) {
        guard let dto = dto else { return }

        // 1、状态总览 → 总计 = 未完成 + 已完成 + 已取消
        let statusList = dto.statusSummary ?? []
        var notStarted = 0, inProgress = 0, completed = 0, cancelled = 0
        for s in statusList {
            switch Int16(s.status ?? 0) {
            case DailyTaskStatus.notStarted.rawValue: notStarted = s.count ?? 0
            case DailyTaskStatus.inProgress.rawValue: inProgress = s.count ?? 0
            case DailyTaskStatus.completed.rawValue: completed = s.count ?? 0
            case DailyTaskStatus.cancelled.rawValue: cancelled = s.count ?? 0
            default: break
            }
        }
        yearlyTotalTasks = notStarted + inProgress + completed + cancelled
        yearlyNotStartedTasks = notStarted
        yearlyInProgressTasks = inProgress
        yearlyCompletedTasks = completed
        yearlyCancelledTasks = cancelled

        // 2、按任务类型统计
        var catStats: [CategoryStat] = []
        for ts in dto.typeStatusSummary ?? [] {
            let typeCode = ts.taskType ?? 0
            let typeObj = mapApiType(typeCode)
            let apiName = ts.taskTypeName ?? typeObj.displayName
            var cNotStarted = 0, cInProgress = 0, cCompleted = 0, cCancelled = 0
            for sc in ts.statusCounts ?? [] {
                let c = sc.count ?? 0
                switch Int16(sc.status ?? 0) {
                case DailyTaskStatus.notStarted.rawValue: cNotStarted = c
                case DailyTaskStatus.inProgress.rawValue: cInProgress = c
                case DailyTaskStatus.completed.rawValue: cCompleted = c
                case DailyTaskStatus.cancelled.rawValue: cCancelled = c
                default: break
                }
            }
            let total = cNotStarted + cInProgress + cCompleted + cCancelled
            if total > 0 {
                catStats.append(CategoryStat(type: typeObj, name: apiName, notStarted: cNotStarted, inProgress: cInProgress, completed: cCompleted, cancelled: cCancelled))
            }
        }
        yearlyCategoryStats = catStats

        // 3、各月热力图数据（补全12个月，无数据的月份 total=0）
        var monthMap: [Int: (total: Int, completed: Int, cancelled: Int)] = [:]
        for ms in dto.monthlyStatusSummary ?? [] {
            let month = ms.period ?? 1
            var msTotal = 0, msCompleted = 0, msCancelled = 0
            for sc in ms.statusCounts ?? [] {
                let c = sc.count ?? 0
                msTotal += c
                switch Int16(sc.status ?? 0) {
                case DailyTaskStatus.completed.rawValue: msCompleted = c
                case DailyTaskStatus.cancelled.rawValue: msCancelled = c
                default: break
                }
            }
            monthMap[month] = (msTotal, msCompleted, msCancelled)
        }
        var heatmap: [MonthTaskStat] = []
        for month in 1...12 {
            let data = monthMap[month] ?? (0, 0, 0)
            heatmap.append(MonthTaskStat(month: month, total: data.total, completed: data.completed, cancelled: data.cancelled))
        }
        yearlyHeatmapData = heatmap
    }

    /// 将 API 任务类型编码映射到本地 TaskTypeEnum（仅用于图标/颜色，名称用接口返回的 taskTypeName）
    private func mapApiType(_ code: Int) -> TaskTypeEnum {
        switch code {
        case 1: return .diet
        case 2: return .exercise
        case 3: return .water
        case 4: return .medical
        case 5: return .measureIndicator
        default: return .other
        }
    }

    private var statOverview: some View {
        let notStartedCount = statTasks.filter { $0.status == DailyTaskStatus.notStarted.rawValue }.count
        let inProgressCount = statTasks.filter { $0.status == DailyTaskStatus.inProgress.rawValue }.count
        let completedCount = statTasks.filter { $0.status == DailyTaskStatus.completed.rawValue }.count
        let cancelledCount = statTasks.filter { $0.status == DailyTaskStatus.cancelled.rawValue }.count

        return HStack(spacing: 0) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray6), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 72, height: 72)
                Circle()
                    .trim(from: 0, to: statCompletionRate)
                    .stroke(Color.theme(.primary), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(Int(statCompletionRate * 100))%")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color("text_primary"))
                    Text("共\(statTasks.count)项")
                        .font(.system(size: 10))
                        .foregroundStyle(Color("text_secondary"))
                }
            }
            .frame(width: 80)
            .padding(.trailing, 8)

            vstackStat(value: "\(notStartedCount)", label: "未开始", color: .blue)
            vstackStat(value: "\(inProgressCount)", label: "进行中", color: Color.theme(.primary))
            vstackStat(value: "\(completedCount)", label: "已完成", color: .green)
            vstackStat(value: "\(cancelledCount)", label: "已取消", color: .red)
        }
        .padding(16)
        .appGlass(
            .regular.interactive().tint(AppColor.content.opacity(0.65)),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    // MARK: - 月维度视图

    /// 月度总览卡片：总计 = 未完成(未开始+进行中) + 已完成 + 已取消
    private var monthlyOverviewCard: some View {
        let notCompleted = monthlyNotStartedTasks + monthlyInProgressTasks
        return HStack(spacing: 0) {
            monthlyStatItem(value: "\(monthlyTotalTasks)", label: "总计", color: Color.theme(.primary))
            Text("=")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color("text_secondary"))
            monthlyStatItem(value: "\(notCompleted)", label: "未完成", color: .orange)
            Text("+")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color("text_secondary"))
            monthlyStatItem(value: "\(monthlyCompletedTasks)", label: "已完成", color: .green)
            Text("+")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color("text_secondary"))
            monthlyStatItem(value: "\(monthlyCancelledTasks)", label: "已取消", color: .gray)
        }
        .padding(16)
        .appGlass(
            .regular.interactive().tint(AppColor.content.opacity(0.65)),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    private func monthlyStatItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color("text_secondary"))
        }
        .frame(maxWidth: .infinity)
    }

    /// 月度按任务分类统计卡片
    private var monthlyCategoryStatsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题行，右侧显示总数
            HStack {
                Text("按任务分类")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))
                Spacer()
                Text("\(monthlyCompletedTasks)/\(monthlyTotalTasks - monthlyCancelledTasks)（\(monthlyCancelledTasks)）")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.theme(.primary))
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // 各分类行
            VStack(spacing: 0) {
                ForEach(Array(monthlyCategoryStats.enumerated()), id: \.offset) { i, stat in
                    if i > 0 { Divider().padding(.leading, 16) }
                    HStack(spacing: 12) {
                        Image(systemName: stat.type.iconName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(stat.type.color)
                            .frame(width: 22)
                        Text(stat.name)
                            .font(.system(size: 14))
                            .foregroundStyle(Color("text_primary"))
                        Spacer()

                        // 进度条（基于有效总数）
                        let barWidth: CGFloat = stat.validTotal > 0 ? max(4, CGFloat(stat.completed) / CGFloat(stat.validTotal) * 60) : 0
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(.systemGray6))
                                .frame(width: 60, height: 6)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(stat.type.color)
                                .frame(width: barWidth, height: 6)
                        }

                        // 已完成 / 有效总数（已取消）
                        Text("\(stat.completed)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(stat.type.color)
                        Text("/")
                            .font(.system(size: 14))
                            .foregroundStyle(Color("text_secondary"))
                        Text("\(stat.validTotal)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color("text_secondary"))
                        Text("（\(stat.cancelled)）")
                            .font(.system(size: 11))
                            .foregroundStyle(Color("text_secondary").opacity(0.7))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                }
            }
        }
        .appGlass(
            .regular.interactive().tint(AppColor.content.opacity(0.65)),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    /// 月度热力图卡片
    private var monthHeatmapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("每日任务热力图")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color("text_primary"))
                .padding(.horizontal, 16)
                .padding(.top, 14)

            MonthHeatmapView(
                date: statDate,
                data: monthlyHeatmapData,
                onDayTapped: { targetDate in
                    statDate = targetDate
                    withAnimation(.easeInOut(duration: 0.2)) {
                        statRange = 0
                    }
                    loadStatTasks()
                }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 14)

            // 图例
            HStack(spacing: 6) {
                Text("少")
                    .font(.system(size: 11))
                    .foregroundStyle(Color("text_secondary"))
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(MonthHeatmapView.heatmapColor(level: level, maxLevel: 4))
                        .frame(width: 16, height: 14)
                }
                Text("多")
                    .font(.system(size: 11))
                    .foregroundStyle(Color("text_secondary"))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .appGlass(
            .regular.interactive().tint(AppColor.content.opacity(0.65)),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    // MARK: - 月度统计数据加载

    /// 加载月度统计数据
    private func loadMonthlyData() {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: statDate)
        let month = calendar.component(.month, from: statDate)
        let param = MonthlyStatsQueryParam(year: year, month: month)
        let request: BgResultNetWork<MonthlyStatsQueryParam, MonthlyStatsDTO> = .post(apiUrl(DAILY_TASK_MONTHLY_STATS), params: param)
        request
            .complicationHand { (dto: MonthlyStatsDTO?) in
                DispatchQueue.main.async {
                    applyMonthlyStats(dto)
                }
            }
            .errorHandle { _, _ in
                // 接口失败保持当前数据不变
            }
            .responseDecodable()
    }

    /// 将接口返回数据应用到状态变量
    private func applyMonthlyStats(_ dto: MonthlyStatsDTO?) {
        guard let dto = dto else { return }

        // 1、状态总览 → 总计 = 未完成(未开始+进行中) + 已完成 + 已取消
        let statusList = dto.statusSummary ?? []
        var notStarted = 0, inProgress = 0, completed = 0, cancelled = 0
        for s in statusList {
            switch Int16(s.status ?? 0) {
            case DailyTaskStatus.notStarted.rawValue: notStarted = s.count ?? 0
            case DailyTaskStatus.inProgress.rawValue: inProgress = s.count ?? 0
            case DailyTaskStatus.completed.rawValue: completed = s.count ?? 0
            case DailyTaskStatus.cancelled.rawValue: cancelled = s.count ?? 0
            default: break
            }
        }
        monthlyTotalTasks = notStarted + inProgress + completed + cancelled
        monthlyNotStartedTasks = notStarted
        monthlyInProgressTasks = inProgress
        monthlyCompletedTasks = completed
        monthlyCancelledTasks = cancelled

        // 2、按任务类型统计
        var catStats: [CategoryStat] = []
        for ts in dto.typeStatusSummary ?? [] {
            let typeCode = ts.taskType ?? 0
            let typeObj = mapApiType(typeCode)
            let apiName = ts.taskTypeName ?? typeObj.displayName
            var cNotStarted = 0, cInProgress = 0, cCompleted = 0, cCancelled = 0
            for sc in ts.statusCounts ?? [] {
                let c = sc.count ?? 0
                switch Int16(sc.status ?? 0) {
                case DailyTaskStatus.notStarted.rawValue: cNotStarted = c
                case DailyTaskStatus.inProgress.rawValue: cInProgress = c
                case DailyTaskStatus.completed.rawValue: cCompleted = c
                case DailyTaskStatus.cancelled.rawValue: cCancelled = c
                default: break
                }
            }
            let total = cNotStarted + cInProgress + cCompleted + cCancelled
            if total > 0 {
                catStats.append(CategoryStat(type: typeObj, name: apiName, notStarted: cNotStarted, inProgress: cInProgress, completed: cCompleted, cancelled: cCancelled))
            }
        }
        monthlyCategoryStats = catStats

        // 3、每日热力图数据（补全当月所有天，无数据的天 total=0）
        let calendar = Calendar.current
        let daysInMonth = calendar.range(of: .day, in: .month, for: statDate)?.count ?? 30
        var dayMap: [Int: (total: Int, completed: Int, cancelled: Int)] = [:]
        for ds in dto.dailyStatusSummary ?? [] {
            let day = ds.period ?? 1
            var dTotal = 0, dCompleted = 0, dCancelled = 0
            for sc in ds.statusCounts ?? [] {
                let c = sc.count ?? 0
                dTotal += c
                switch Int16(sc.status ?? 0) {
                case DailyTaskStatus.completed.rawValue: dCompleted = c
                case DailyTaskStatus.cancelled.rawValue: dCancelled = c
                default: break
                }
            }
            dayMap[day] = (dTotal, dCompleted, dCancelled)
        }
        var heatmap: [DayTaskStat] = []
        for day in 1...daysInMonth {
            let d = dayMap[day] ?? (0, 0, 0)
            heatmap.append(DayTaskStat(day: day, total: d.total, completed: d.completed, cancelled: d.cancelled))
        }
        monthlyHeatmapData = heatmap
    }

    // MARK: - 辅助函数

    private func statButton(filter: Int16?, value: String, label: String, color: Color) -> some View {
        let isActive = filterStatus == filter
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { filterStatus = isActive ? nil : filter }
        } label: {
            VStack(spacing: 4) {
                Text(value).font(.system(size: 17, weight: isActive ? .bold : .medium))
                Text(label).font(.system(size: 11, weight: isActive ? .semibold : .regular))
            }
            .foregroundStyle(isActive ? color : Color("text_secondary"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(isActive ? color.opacity(0.12) : Color.clear))
        }
        .buttonStyle(.plain)
    }

    private func vstackStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 17, weight: .medium))
            Text(label).font(.system(size: 11))
        }
        .foregroundStyle(Color("text_secondary"))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private func loadStatTasks() {
        statLoading = true
        let dateStr = DateUtils.formatDate(statDate, format: DateUtils.DateFormat.ymd)
        let param = DailyTaskQueryParam(taskDate: dateStr)
        let request: BgResultNetWork<DailyTaskQueryParam, [DailyTaskDTO]> = .post(apiUrl(DAILY_TASK_LIST), params: param)
        request
            .complicationHand { data in
                DispatchQueue.main.async {
                    statTasks = (data ?? []).sorted { ($0.priority ?? 0) < ($1.priority ?? 0) }
                    statLoading = false
                }
            }
            .errorHandle { _, _ in
                DispatchQueue.main.async { statLoading = false }
            }
            .responseDecodable()
    }

    private func reloadTasks() {
        let today = DateUtils.formatDate(Date(), format: DateUtils.DateFormat.ymd)
        let param = DailyTaskQueryParam(taskDate: today)
        let request: BgResultNetWork<DailyTaskQueryParam, [DailyTaskDTO]> = .post(apiUrl(DAILY_TASK_LIST), params: param)
        request
            .complicationHand { data in
                DispatchQueue.main.async {
                    if let taskList = data { tasks = taskList.sorted { ($0.priority ?? 0) < ($1.priority ?? 0) } }
                }
            }
            .responseDecodable()
    }

    private func groupSection(_ group: (type: TaskTypeEnum, items: [DailyTaskDTO])) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: group.type.iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(LinearGradient(colors: [group.type.color, group.type.color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Text(group.type.displayName).font(.system(size: 16, weight: .semibold)).foregroundStyle(Color("text_primary"))
                Spacer()
                Text("\(group.items.filter { $0.status == DailyTaskStatus.completed.rawValue }.count)/\(group.items.count)")
                    .font(.system(size: 13)).foregroundStyle(Color("text_secondary"))
            }
            VStack(spacing: 8) {
                ForEach(group.items, id: \.id) { task in
                    Button { selectedTask = task } label: { TaskRowCard(task: task) }.buttonStyle(.plain)
                }
            }
        }
    }

    private func statGroupSection(_ group: (type: TaskTypeEnum, items: [DailyTaskDTO])) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: group.type.iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(LinearGradient(colors: [group.type.color, group.type.color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Text(group.type.displayName).font(.system(size: 16, weight: .semibold)).foregroundStyle(Color("text_primary"))
                Spacer()
                Text("\(group.items.filter { $0.status == DailyTaskStatus.completed.rawValue }.count)/\(group.items.count)")
                    .font(.system(size: 13)).foregroundStyle(Color("text_secondary"))
            }
            VStack(spacing: 8) {
                ForEach(group.items, id: \.id) { task in
                    TaskRowCard(task: task)
                }
            }
        }
    }
}

// MARK: - 任务编辑 Sheet

struct DailyTaskEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let task: DailyTaskDTO
    var onSave: (() -> Void)?

    private var taskType: TaskTypeEnum? {
        TaskTypeEnum(rawValue: task.taskType ?? 0)
    }

    private var typeColor: Color {
        taskType?.color ?? Color.theme(.primary)
    }

    private let allStatuses: [(DailyTaskStatus, String)] = [
        (.notStarted, "未开始"),
        (.inProgress, "进行中"),
        (.completed, "已完成"),
        (.cancelled, "已取消")
    ]

    @State private var selectedStatus: DailyTaskStatus
    @State private var currentValueText: String

    init(task: DailyTaskDTO, onSave: (() -> Void)? = nil) {
        self.task = task
        self.onSave = onSave
        _selectedStatus = State(initialValue: DailyTaskStatus(rawValue: task.status ?? 0) ?? .notStarted)
        _currentValueText = State(initialValue: task.currentValue ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            // 简洁标题栏：左侧关闭按钮 + 中间标题（液态玻璃风格）
            titleBar

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.regular) {
                    // 1、任务名称 + 详细信息
                    detailCard

                    // 2、修改状态
                    statusSection

                    // 3、目标 / 当前 对比 + 编辑
                    compareAndEditSection

                    // 4、保存
                    saveButton
                }
                .padding(.horizontal, AppSpacing.screen)
                .padding(.top, AppSpacing.compact)
                .padding(.bottom, 30)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .pageBackground()
    }

    /// 简洁标题栏：左侧玻璃圆形关闭按钮 + 居中标题
    private var titleBar: some View {
        HStack {
            Color.clear.frame(width: 32, height: 32)
            Spacer()
            Text("任务详情")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppColor.textPrimary)
            Spacer()
            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, AppSpacing.screen)
        .padding(.top, AppSpacing.card)
        .padding(.bottom, AppSpacing.compact)
    }

    // MARK: - 1、详情卡片

    private var detailCard: some View {
        VStack(spacing: 0) {
            // 任务名 + 类型图标
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(typeColor.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: taskType?.iconName ?? "list.bullet")
                        .font(.system(size: 20))
                        .foregroundStyle(typeColor)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.taskDesc ?? "")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColor.textPrimary)
                    Text(taskType?.displayName ?? "")
                        .font(.system(size: 13))
                        .foregroundStyle(typeColor)
                }
                Spacer()
                if task.priority == DailyTaskPriority.high.rawValue {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                }
            }.padding(.bottom, 10)

            // 详细信息行
            detailRow(icon: "flag", label: "优先级", value: DailyTaskPriority(rawValue: task.priority ?? 2)?.displayName ?? "中")
            detailRow(icon: "doc.text", label: "来源", value: task.taskSource ?? "—")
            detailRow(icon: "calendar", label: "日期", value: task.taskDate ?? "—")
        }
        .cardStyle()
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColor.textSecondary)
                .frame(width: 18)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(AppColor.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColor.textPrimary)
        }
        .padding(.vertical, 10)
    }

    // MARK: - 2、修改状态

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.regular) {
            HStack(spacing: 8) {
                Image(systemName: "circle.dotted")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColor.primary)
                Text("修改状态")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColor.textSecondary)
            }

            // 横向 4 选 1，液态玻璃选中态按状态色着色
            HStack(spacing: 8) {
                ForEach(allStatuses, id: \.0.rawValue) { (status, name) in
                    let isSel = selectedStatus == status
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedStatus = status
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: isSel ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                            Text(name)
                                .font(.system(size: 12, weight: isSel ? .semibold : .medium))
                        }
                        .foregroundStyle(isSel ? .white : statusBgColor(status))
                    }
                    .buttonStyle(GlassSelectButtonStyle(
                        isSelected: isSel,
                        tint: statusBgColor(status),
                        verticalPadding: 12,
                        cornerRadius: AppRadius.medium
                    ))
                }
            }
        }
    }

    // MARK: - 3、目标 vs 当前 对比 + 编辑

    private var compareAndEditSection: some View {
        VStack(spacing: 12) {
            // 目标行
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "target")
                        .font(.system(size: 13))
                        .foregroundStyle(typeColor)
                    Text("目标")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColor.textSecondary)
                }
                Spacer()
                Text(task.targetValue ?? "—")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColor.textPrimary)
            }

            Divider()

            // 当前行 + 编辑
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "pencil.and.list.clipboard")
                        .font(.system(size: 13))
                        .foregroundStyle(typeColor)
                    Text("当前")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColor.textSecondary)
                    Spacer()
                }

                TextField("输入当前完成情况...", text: $currentValueText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColor.textPrimary)
                    .inputFieldStyle()
            }
        }.cardStyle()
    }

    // MARK: - 保存

    @State private var isSaving = false

    private var saveButton: some View {
        Button {
            saveTask()
        } label: {
            HStack(spacing: 6) {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColor.textSecondary))
                }
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                Text(isSaving ? "保存中..." : "保存修改")
            }.foregroundStyle(AppColor.primary)
        }
        .buttonStyle(SecondaryActionButtonStyle())
        .disabled(isSaving)
    }

    // MARK: - 保存请求

    private func saveTask() {
        guard !isSaving, let taskId = task.id else { return }
        isSaving = true

        let updateDTO = DailyTaskDTO()
        updateDTO.id = taskId
        updateDTO.status = selectedStatus.rawValue
        updateDTO.currentValue = currentValueText.isEmpty ? nil : currentValueText

        let request: BgResultNetWork<DailyTaskDTO, String> = .post(
            apiUrl(DAILY_TASK_SAVE_OR_UPDATE),
            params: updateDTO
        )
        request
            .complicationHand { (_: String?) in
                DispatchQueue.main.async {
                    isSaving = false
                    onSave?()
                    dismiss()
                }
            }
            .errorHandle { (_, _) in
                DispatchQueue.main.async {
                    isSaving = false
                }
            }
            .responseDecodable()
    }

    // MARK: - 颜色辅助

    private func statusBgColor(_ status: DailyTaskStatus) -> Color {
        switch status {
        case .completed: return .green
        case .inProgress: return Color.theme(.primary)
        case .cancelled: return Color("text_secondary")
        case .notStarted: return Color("text_secondary")
        }
    }

    private func statusTextColor(_ status: DailyTaskStatus) -> Color {
        switch status {
        case .completed: return .green
        case .inProgress: return Color.theme(.primary)
        default: return Color("text_secondary")
        }
    }
}

// MARK: - 分类统计数据模型

/// 任务分类统计（细粒度状态）
struct CategoryStat {
    let type: TaskTypeEnum
    let name: String
    let notStarted: Int
    let inProgress: Int
    let completed: Int
    let cancelled: Int

    /// 总数
    var total: Int { notStarted + inProgress + completed + cancelled }
    /// 有效总数（不含已取消）
    var validTotal: Int { notStarted + inProgress + completed }
}

// MARK: - 热力图数据模型

/// 每日任务统计数据
struct DayTaskStat: Identifiable {
    let id = UUID()
    /// 日期（当月第几天，1-31）
    let day: Int
    /// 当日任务总数（含已取消）
    let total: Int
    /// 当日已完成任务数
    let completed: Int
    /// 当日已取消任务数
    let cancelled: Int

    /// 有效总数（不含已取消）
    var validTotal: Int { total - cancelled }

    /// 完成率（基于有效总数）
    var completionRate: Double {
        validTotal > 0 ? Double(completed) / Double(validTotal) : 0
    }
}

// MARK: - 月度热力图组件

struct MonthHeatmapView: View {
    /// 选中年月
    let date: Date
    /// 每日统计数据
    let data: [DayTaskStat]
    /// 点击某天回调
    var onDayTapped: ((Date) -> Void)? = nil

    private let calendar = Calendar.current
    private let weekSymbols = ["一", "二", "三", "四", "五", "六", "日"]
    private let columnCount = 7
    private let spacing: CGFloat = 3

    /// 当月天数
    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    /// 当月第一天是周几（1=周日...7=周六）→ 转换为 0=周一...6=周日
    private var firstWeekdayOffset: Int {
        let comps = calendar.dateComponents([.year, .month], from: date)
        guard let firstDay = calendar.date(from: comps) else { return 0 }
        let wd = calendar.component(.weekday, from: firstDay) // 1=Sun
        return wd == 1 ? 6 : wd - 2 // 0=Mon
    }

    /// 总行数
    private var rowCount: Int {
        (firstWeekdayOffset + daysInMonth + 6) / 7
    }

    /// 当月是否就是本月（用于判断未来日期）
    private var isCurrentMonth: Bool {
        let now = calendar.dateComponents([.year, .month], from: Date())
        let sel = calendar.dateComponents([.year, .month], from: date)
        return now.year == sel.year && now.month == sel.month
    }

    /// 今天几号
    private var todayDay: Int {
        calendar.component(.day, from: Date())
    }

    /// 热力图颜色（按完成率分级，低级别也保持可读性）
    static func heatmapColor(level: Int, maxLevel: Int) -> Color {
        let colors: [Color] = [
            Color(.systemGray6),
            Color.green.opacity(0.45),
            Color.green.opacity(0.6),
            Color.green.opacity(0.75),
            Color.green.opacity(0.9)
        ]
        return colors[min(level, colors.count - 1)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            // 星期头
            HStack(spacing: spacing) {
                ForEach(weekSymbols, id: \.self) { sym in
                    Text(sym)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color("text_secondary"))
                        .frame(maxWidth: .infinity)
                }
            }

            // 日期网格
            ForEach(0..<rowCount, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<columnCount, id: \.self) { col in
                        let index = row * columnCount + col
                        let day = index - firstWeekdayOffset + 1
                        if day >= 1 && day <= daysInMonth {
                            let stat = data.first { $0.day == day }
                            let isFuture = isCurrentMonth && day > todayDay
                            let isEmpty = (stat?.total ?? 0) == 0
                            let isDisabled = isFuture || isEmpty
                            Button {
                                var comps = calendar.dateComponents([.year, .month], from: date)
                                comps.day = day
                                if let targetDate = calendar.date(from: comps) {
                                    onDayTapped?(targetDate)
                                }
                            } label: {
                                heatmapCell(day: day, col: col, isFuture: isFuture, isEmpty: isEmpty)
                            }
                            .buttonStyle(.plain)
                            .disabled(isDisabled)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
        }
    }

    /// 单个热力图格子
    @ViewBuilder
    private func heatmapCell(day: Int, col: Int, isFuture: Bool = false, isEmpty: Bool = false) -> some View {
        let stat = data.first { $0.day == day }
        let rate = stat?.completionRate ?? 0
        let total = stat?.total ?? 0
        let level: Int = {
            if total == 0 { return 0 }
            switch rate {
            case 0: return 0
            case 0..<0.25: return 1
            case 0.25..<0.5: return 2
            case 0.5..<0.75: return 3
            default: return 4
            }
        }()

        let isDimmed = isFuture || isEmpty
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(isDimmed ? Color(.systemGray6) : Self.heatmapColor(level: level, maxLevel: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color("divider"), lineWidth: 0.5)
                )
            VStack(spacing: 0) {
                Text("\(day)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isDimmed ? Color("text_secondary").opacity(0.4) : .white.opacity(0.95))
                if total > 0 && !isDimmed {
                    let validTotal = stat?.validTotal ?? total
                    Text("\(stat?.completed ?? 0)/\(validTotal)")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - 年度热力图数据模型

/// 月度任务统计数据
struct MonthTaskStat: Identifiable {
    let id = UUID()
    /// 月份（1-12）
    let month: Int
    /// 当月任务总数（含已取消）
    let total: Int
    /// 当月已完成任务数
    let completed: Int
    /// 当月已取消任务数
    let cancelled: Int

    /// 有效总数（不含已取消）
    var validTotal: Int { total - cancelled }

    /// 完成率（基于有效总数）
    var completionRate: Double {
        validTotal > 0 ? Double(completed) / Double(validTotal) : 0
    }

    var monthName: String {
        ["1月","2月","3月","4月","5月","6月",
         "7月","8月","9月","10月","11月","12月"][month - 1]
    }
}

// MARK: - 年度热力图组件（12月网格）

struct YearHeatmapView: View {
    let date: Date
    let data: [MonthTaskStat]
    var onMonthTapped: ((Date) -> Void)? = nil

    private let calendar = Calendar.current
    private let columns = 4
    private let spacing: CGFloat = 8

    /// 选中是否今年
    private var isCurrentYear: Bool {
        calendar.component(.year, from: Date()) == calendar.component(.year, from: date)
    }

    /// 当前月份
    private var nowMonth: Int {
        calendar.component(.month, from: Date())
    }

    var body: some View {
        let rows = (data.count + columns - 1) / columns

        VStack(spacing: spacing) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<columns, id: \.self) { col in
                        let index = row * columns + col
                        if index < data.count {
                            let stat = data[index]
                            let isFuture = isCurrentYear && stat.month > nowMonth
                            let isDisabled = isFuture || stat.total == 0
                            Button {
                                var comps = calendar.dateComponents([.year], from: date)
                                comps.month = stat.month
                                comps.day = 1
                                if let targetDate = calendar.date(from: comps) {
                                    onMonthTapped?(targetDate)
                                }
                            } label: {
                                monthCell(stat: stat, isFuture: isFuture, isEmpty: stat.total == 0)
                            }
                            .buttonStyle(.plain)
                            .disabled(isDisabled)
                        } else {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func monthCell(stat: MonthTaskStat, isFuture: Bool = false, isEmpty: Bool = false) -> some View {
        let rate = stat.completionRate
        let total = stat.total
        let level: Int = {
            if total == 0 { return 0 }
            switch rate {
            case 0: return 0
            case 0..<0.25: return 1
            case 0.25..<0.5: return 2
            case 0.5..<0.75: return 3
            default: return 4
            }
        }()

        let bgColor: Color = {
            if isFuture { return Color(.systemGray6) }
            if isEmpty { return Color(.systemGray6) }
            return MonthHeatmapView.heatmapColor(level: level, maxLevel: 4)
        }()

        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(bgColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color("divider"), lineWidth: 0.5)
                )

            VStack(spacing: 4) {
                Text(stat.monthName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isFuture ? Color("text_secondary").opacity(0.4) : (isEmpty ? Color("text_secondary") : (total > 0 ? .white : Color("text_secondary"))))
                if isFuture {
                    Text("—")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("text_secondary").opacity(0.4))
                } else if total > 0 {
                    Text("\(stat.completed)/\(stat.validTotal)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                } else {
                    Text("暂无")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("text_secondary"))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - 预览

#Preview("首页模块") {
    DailyHealthTaskView()
        .padding()
        .background(Color("background"))
}

#Preview("详情页") {
    let jsonData = """
    [
        {"id":"1","taskType":3,"taskDesc":"全天饮水","targetValue":"2150ml","taskDate":"2026-06-26","status":1,"priority":1},
        {"id":"2","taskType":1,"taskDesc":"吃早餐","targetValue":"无糖豆浆 + 杂粮馒头","taskDate":"2026-06-26","status":2,"priority":1},
        {"id":"3","taskType":1,"taskDesc":"吃午餐","targetValue":"糙米饭 + 鸡胸肉","taskDate":"2026-06-26","status":1,"priority":2},
        {"id":"4","taskType":1,"taskDesc":"吃晚餐","targetValue":"蒸红薯 + 清蒸鱼","taskDate":"2026-06-26","status":0,"priority":2},
        {"id":"5","taskType":2,"taskDesc":"动感单车","targetValue":"低阻力30分钟","taskDate":"2026-06-26","status":0,"priority":2},
        {"id":"6","taskType":4,"taskDesc":"医院就诊","targetValue":"邵逸夫医院 内科","taskDate":"2026-06-26","status":3,"priority":3},
        {"id":"7","taskType":5,"taskDesc":"测量血压","targetValue":"120/80 mmHg","taskDate":"2026-06-26","status":0,"priority":1},
        {"id":"8","taskType":99,"taskDesc":"阅读健康文章","targetValue":"至少1篇","taskDate":"2026-06-26","status":1,"priority":3}
    ]
    """.data(using: .utf8)!
    let tasks = try! JSONDecoder().decode([DailyTaskDTO].self, from: jsonData)
    return DailyHealthTaskDetailView(tasks: tasks)
}

#Preview("编辑Sheet") {
    let jsonData = """
    {"id":"1","taskType":3,"taskDesc":"全天饮水","targetValue":"2150ml","currentValue":"已喝1000ml","taskDate":"2026-06-26","status":1,"priority":1,"taskSource":"健康曲线计划"}
    """.data(using: .utf8)!
    let task = try! JSONDecoder().decode(DailyTaskDTO.self, from: jsonData)
    return DailyTaskEditSheet(task: task)
}
