import SwiftUI

// MARK: - 用药记录子页面
struct MedicineRecordsTabView: View {
    @Binding var showAddRecord: Bool
    @State private var selectedDate = Date()
    @State private var medicineRecords: [MedicineRecord] = []
    @State private var todayMedicinePlans: [TodayMedicinePlanDTO] = []
    @State private var selectedTodayMedicinePlan: TodayMedicinePlanDTO?
    @State private var selectDayItem: DayItem = buildDayItem(date: Date())
    @State private var loadingRecords = false
    @State private var loadingTodayPlans = false
    @State private var markedDatesSet: Set<String> = []
    @State private var currentMonth: String = ""

    // 有用药记录的日期（从接口获取）
    var markedDates: Set<String> {
        markedDatesSet
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
               
                VStack {
                    Color.clear.frame(height: 20)
                    // 用药列表
                    ScrollView(.vertical, showsIndicators: false) {
                        Color.clear.frame(height: 360)
                        LazyVStack(spacing: 12) {
                            if loadingRecords {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                    Spacer()
                                }
                                .padding(.vertical, 40)
                            } else if medicineRecords.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "pills.circle")
                                        .font(.system(size: 48))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [Color.theme(.primary).opacity(0.3), Color.theme(.secondary).opacity(0.3)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                    Text("该日期暂无用药记录")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color("text_secondary"))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            } else {
                                ForEach(medicineRecords) { record in
                                    MedicineRecordCard(record: record)
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                deleteRecord(record: record)
                                            } label: {
                                                Label("删除", systemImage: "trash")
                                            }
                                        }
                                }
                            }

                            todayMedicinePlansSection
                            
                            Color.clear.frame(height: 40)
                        }
                        .padding(.horizontal, 20)

                    }
                }
                
                VStack {
                    // 日历组件
                    Color.clear.frame(height: 4)
                    CalendarView(
                        onDateSelected: { dayItem in
                            selectDayItem = dayItem
                            let oldDate = selectedDate
                            selectedDate = dayItem.date
                            loadMedicineRecords(for: dayItem.date)

                            // 检查月份是否变化
                            let calendar = Calendar.current
                            let oldMonth = calendar.component(.month, from: oldDate)
                            let oldYear = calendar.component(.year, from: oldDate)
                            let newMonth = calendar.component(.month, from: dayItem.date)
                            let newYear = calendar.component(.year, from: dayItem.date)

                            if oldYear != newYear || oldMonth != newMonth {
                                loadMarkedDates(for: dayItem.date)
                            }
                        },
                        onMonthChanged: { year, month in
                            // 当月份通过左右按钮切换时，加载该月份的数据
                            var dateComponents = DateComponents()
                            dateComponents.year = year
                            dateComponents.month = month
                            dateComponents.day = 1
                            if let newDate = Calendar.current.date(from: dateComponents) {
                                loadMarkedDates(for: newDate)
                            }
                        },
                        markedDates: markedDates
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    Spacer()
                }
            }
           
            
          

          
        }
        .sheet(isPresented: $showAddRecord, onDismiss: {
            selectedTodayMedicinePlan = nil
        }) {
            AddMedicineRecordView(
                todayPlan: selectedTodayMedicinePlan,
                onSave: {
                    // 保存成功后刷新数据
                    loadMedicineRecords(for: selectedDate)
                    // 强制刷新标记日期（因为添加了新记录）
                    loadMarkedDates(for: selectedDate, forceRefresh: true)
                    // 用药记录可能已匹配到今日计划，刷新计划状态。
                    loadTodayMedicinePlans()
                }
            )
        }
        .onAppear {
            loadMedicineRecords(for: selectedDate)
            loadMarkedDates(for: selectedDate)
            loadTodayMedicinePlans()
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            // 当选择的日期变化时，检查月份是否变化
            let calendar = Calendar.current
            let oldMonth = calendar.component(.month, from: oldValue)
            let oldYear = calendar.component(.year, from: oldValue)
            let newMonth = calendar.component(.month, from: newValue)
            let newYear = calendar.component(.year, from: newValue)

            // 如果月份变化，重新加载标记日期
            if oldYear != newYear || oldMonth != newMonth {
                loadMarkedDates(for: newValue)
            }
        }
    }

    // MARK: - 今日用药计划
    private var isSelectedDateToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    @ViewBuilder
    private var todayMedicinePlansSection: some View {
        if isSelectedDateToday && (loadingTodayPlans || !todayMedicinePlans.isEmpty) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("今日用药计划")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color("text_primary"))

                        Text("计划安排，非实际用药记录")
                            .font(.system(size: 12))
                            .foregroundStyle(Color("text_secondary"))
                    }

                    Spacer()

                    if loadingTodayPlans {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("\(todayMedicinePlans.count) 项")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.theme(.primary))
                    }
                }
                .padding(.top, 20)

                if loadingTodayPlans {
                    ProgressView("正在加载今日计划")
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                } else {
                    ForEach(todayMedicinePlans) { plan in
                        TodayMedicinePlanCard(plan: plan) {
                            selectedTodayMedicinePlan = plan
                            showAddRecord = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - 加载今日用药计划
    private func loadTodayMedicinePlans() {
        guard !loadingTodayPlans else { return }
        loadingTodayPlans = true

        BgResultNetWork<Empty, [TodayMedicinePlanDTO]>.post(
            apiUrl(MEDICINE_PLAN_TODAY),
            params: Empty()
        )
        .complicationHand { (plans: [TodayMedicinePlanDTO]?) in
            todayMedicinePlans = plans ?? []
            loadingTodayPlans = false
        }
        .errorHandle { (_, _) in
            todayMedicinePlans = []
            loadingTodayPlans = false
        }
        .responseDecodable()
    }

    // MARK: - 加载用药记录
    private func loadMedicineRecords(for date: Date) {
        guard !loadingRecords else { return }
        loadingRecords = true

        // 格式化日期为 "yyyy-MM-dd"
        let dateString = DateUtils.formatDate(date, format: DateUtils.DateFormat.ymd)
        let params = MedicineListByDateParam(date: dateString)

        // POST 请求获取指定日期的用药记录
        BgResultNetWork<MedicineListByDateParam, [UsersMedicineDTO]>.post(apiUrl(MEDICINE_TAKE_LIST_BY_DATE), params: params)
            .complicationHand { (dtos: [UsersMedicineDTO]?) in
                // 将 UsersMedicineDTO 转换为 MedicineRecord
                if let dtos = dtos {
                    medicineRecords = dtos.map { dto in
                        var record = MedicineRecord()
                        record.idValue = dto.id
                        record.userId = dto.userId
                        record.medicineId = dto.medicineId
                        record.medicineName = dto.medicineName
                        record.dose = dto.dose
                        record.doseUnit = dto.doseUnit
                        record.specification = dto.specification
                        record.specificationUnit = dto.specificationUnit
                        record.remarks = dto.remarks
                        record.takingTime = dto.takingTime
                        record.adverseReactions = dto.adverseReactions
                        return record
                    }
                } else {
                    medicineRecords = []
                }
                loadingRecords = false
            }
            .errorHandle { (_, _) in
                loadingRecords = false
            }
            .responseDecodable()
    }

    // MARK: - 加载标记日期
    private func loadMarkedDates(for date: Date, forceRefresh: Bool = false) {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let yearMonth = String(format: "%d-%02d", year, month)

        // 如果已经加载过这个月份且不是强制刷新，不再重复加载
        if !forceRefresh && currentMonth == yearMonth {
            return
        }

        currentMonth = yearMonth
        let params = MedicineListDatesByMonthParam(yearMonth: yearMonth)

        // POST 请求获取指定月份有记录的日期
        BgResultNetWork<MedicineListDatesByMonthParam, [MedicineDateInfo]>.post(apiUrl(MEDICINE_TAKE_LIST_DATES_BY_MONTH), params: params)
            .complicationHand { (dateInfos: [MedicineDateInfo]?) in
                if let dateInfos = dateInfos {
                    // 提取日期字符串，格式为 "yyyy-MM-dd"
                    markedDatesSet = Set(dateInfos.map { $0.date })
                } else {
                    markedDatesSet = []
                }
            }
            .errorHandle { (_, _) in
                // 加载失败时保持原有数据
            }
            .responseDecodable()
    }

    // MARK: - 删除记录
    private func deleteRecord(record: MedicineRecord) {
        guard let recordId = record.idValue else { return }

        // 调用删除接口，POST 请求，参数：{"id":"xxxx"}，返回：{"code": 200, "message": "成功", "data": 0}
        BgResultNetWork<[String: String], Int32>.post(apiUrl(MEDICINE_TAKE_DELETE), params: ["id": recordId])
            .complicationHand { (_: Int32?) in
                // 删除成功后，从列表中移除并刷新数据
                medicineRecords.removeAll { $0.id == record.id }
                // 重新加载数据以确保同步
                loadMedicineRecords(for: selectedDate)
                // 强制刷新标记日期（因为删除了记录）
                loadMarkedDates(for: selectedDate, forceRefresh: true)
                // 删除的记录可能影响今日计划的已服状态。
                loadTodayMedicinePlans()
            }
            .errorHandle { (_, _) in
                // 删除失败时的处理
            }
            .responseDecodable()
    }
}
