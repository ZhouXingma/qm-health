import SwiftUI

// 刷新通知管理器
class MedicalRecordsRefreshManager: ObservableObject {
    static let shared = MedicalRecordsRefreshManager()

    @Published var shouldRefreshVisited = false
    @Published var shouldRefreshAppointment = false
    @Published var shouldRefreshReports = false

    func refreshAll() {
        shouldRefreshVisited = true
        shouldRefreshAppointment = true
        shouldRefreshReports = true
    }

    func refreshVisited() {
        shouldRefreshVisited = true
    }

    func refreshAppointment() {
        shouldRefreshAppointment = true
    }

    func refreshReports() {
        shouldRefreshReports = true
    }
}

struct MedicalRecordsView: View {
    @State private var selectedTab = 0
    @StateObject private var refreshManager = MedicalRecordsRefreshManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // 自定义头部
            CustomHeader(selectedTab: $selectedTab)

            // TabView 内容区域
            TabView(selection: $selectedTab) {
                // 就诊记录页 (status = 1, 已就诊)
                VisitedRecordsListView()
                    .tag(0)
                    .environmentObject(refreshManager)

                // 提醒页 (status = 0, 预约中)
                AppointmentRecordsListView()
                    .tag(1)
                    .environmentObject(refreshManager)

                // 报告页
                MedicalReportsView()
                    .tag(2)
                    .environmentObject(refreshManager)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .glassBackground()
        .ignoresSafeArea(.all, edges: .bottom)
        .navigationBarHidden(true)
    }
}

// 已就诊记录列表视图
struct VisitedRecordsListView: View {
    @StateObject private var viewModel = MedicalRecordsViewModel(status: 1)
    @EnvironmentObject var refreshManager: MedicalRecordsRefreshManager
    @State private var selectedRecord: MedicalVisitResponse?
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 8, pinnedViews: [.sectionHeaders]) {
                if viewModel.isLoading && viewModel.groupedRecords.isEmpty {
                    // 首次加载状态
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 100)
                } else if viewModel.groupedRecords.isEmpty && !viewModel.isLoading {
                    // 空状态
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(Color("text_primary"))
                        Text("暂无就诊记录")
                            .font(.system(size: 16))
                            .foregroundColor(Color("text_secondary"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                } else {
                    // 按年份分组显示
                    ForEach(viewModel.groupedRecords.keys.sorted(by: >), id: \.self) { year in
                        Section {
                            ForEach(viewModel.groupedRecords[year] ?? []) { record in
                                Button {
                                    selectedRecord = record
                                } label: {
                                    MedicalVisitCard(record: record)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .contextMenu {
                                    Button(role: .destructive) {
                                        viewModel.deleteRecord(recordId: record.id)
                                    } label: {
                                        Label("删除记录", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            YearHeaderView(year: year)
                        }
                    }
                    
                    // 加载更多指示器
                    if viewModel.hasMore {
                        HStack {
                            Spacer()
                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .padding(.vertical, 20)
                            } else {
                                Color.clear
                                    .frame(height: 50)
                                    .onAppear {
                                        viewModel.loadMore()
                                    }
                            }
                            Spacer()
                        }
                    }
                    
                   
                }
            }
            .padding(.horizontal, 16)
            .padding(.top,12)
            
            Color.clear.frame(height: 30)
        }
        .refreshable {
            await viewModel.refresh()
        }
        .onAppear {
            if viewModel.groupedRecords.isEmpty {
                viewModel.loadRecords()
            }
        }
        .onChange(of: refreshManager.shouldRefreshVisited) { shouldRefresh in
            if shouldRefresh {
                viewModel.loadRecords()
                refreshManager.shouldRefreshVisited = false
                refreshManager.refreshReports()
            }
        }
        .sheet(item: $selectedRecord) { record in
            // 用 record.id 作为身份标识，每次进入新记录时强制重建整个视图，
            // 避免 @State（包括 reportFiles、selectedDiseases、medicines）跨记录残留
            CreateMedicalRecordView(
                recordId: record.id,
                onRecordCreated: {
                    viewModel.loadRecords()
                }
            )
            .id(record.id)
        }
    }
}

// 预约提醒列表视图
struct AppointmentRecordsListView: View {
    @StateObject private var viewModel = MedicalRecordsViewModel(status: 0)
    @EnvironmentObject var refreshManager: MedicalRecordsRefreshManager
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 8, pinnedViews: [.sectionHeaders]) {
                if viewModel.isLoading && viewModel.groupedRecords.isEmpty {
                    // 首次加载状态
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 100)
                } else if viewModel.groupedRecords.isEmpty && !viewModel.isLoading {
                    // 空状态
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 48))
                            .foregroundColor(Color("text_primary"))
                        Text("暂无预约记录")
                            .font(.system(size: 16))
                            .foregroundColor(Color("text_secondary"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                } else {
                    // 按年份分组显示
                    ForEach(viewModel.groupedRecords.keys.sorted(by: >), id: \.self) { year in
                        Section {
                            ForEach(viewModel.groupedRecords[year] ?? []) { record in
                                MedicalReminderCard(record: record) {
                                    await viewModel.updateStatus(recordId: record.id, newStatus: 1)
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        viewModel.deleteRecord(recordId: record.id)
                                    } label: {
                                        Label("删除记录", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            YearHeaderView(year: year)
                        }
                    }
                    
                    // 加载更多指示器
                    if viewModel.hasMore {
                        HStack {
                            Spacer()
                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .padding(.vertical, 20)
                            } else {
                                Color.clear
                                    .frame(height: 50)
                                    .onAppear {
                                        viewModel.loadMore()
                                    }
                            }
                            Spacer()
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top,12)
            
            Color.clear.frame(height: 30)
        }
        .refreshable {
            await viewModel.refresh()
        }
        .onAppear {
            if viewModel.groupedRecords.isEmpty {
                viewModel.loadRecords()
            }
        }
        .onChange(of: refreshManager.shouldRefreshAppointment) { shouldRefresh in
            if shouldRefresh {
                viewModel.loadRecords()
                refreshManager.shouldRefreshAppointment = false
                refreshManager.refreshReports()
            }
        }
    }
}

// 年份分组头部视图
struct YearHeaderView: View {
    let year: String

    var body: some View {
        HStack {
            Text(year)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color("text_primary"))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// 就诊记录卡片（新版，使用API数据）
struct MedicalVisitCard: View {
    let record: MedicalVisitResponse
    
    var body: some View {
        HStack(spacing: 12) {
            // 左侧日期标签
            VStack(spacing: 4) {
                Text(record.month)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.white)
                    .tracking(0.5)
                
                Text(record.day)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.white)
                    .tracking(-0.5)

            }
            .frame(width: 50)
            .padding(.vertical, 8)
            .glassContainer(.clear.interactive().tint(Color.theme(.primary).opacity(0.8)), cornerRadius: 8)
            
    
            
            // 右侧内容
            VStack(alignment: .leading, spacing: 8) {
                // 医院名称和状态
                HStack(spacing: 10) {
                    // 医院图标
                    Image(systemName: "cross.case.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.theme(.primary))
                        .frame(width: 20, height: 20)
                    
                    Text(record.hospital)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color("text_primary"))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // 状态标签
                    Text(record.status == 1 ? "已就诊" : "预约中")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(record.status == 1 ? .white : Color.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(record.status == 1 ? Color.theme(.primary) : Color.orange)
                        )
                }
                
                // 科室、医生和诊断信息
                HStack(spacing: 6) {
                    // 科室标签
                    HStack(spacing: 4) {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white)

                        Text(record.department)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .glassPill(.regular.interactive().tint(Color.theme(.primary)))
                    
                    // 医生信息
                    if !record.doctorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "stethoscope")
                                .font(.system(size: 10))
                                .foregroundColor(.white)

                            Text(record.doctorName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .glassPill(.regular.interactive().tint(Color.theme(.primary)))
                    }
                    
                    Spacer()
                    
                    // 诊断结果
                    if let diagnosis = record.diagnosis, !diagnosis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white)

                            Text(diagnosis)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .glassPill(.regular.interactive().tint(.blue))
                    }
                }
            }
        }
        .cardStyle()

    }
}

// ViewModel 管理数据加载和分页
class MedicalRecordsViewModel: ObservableObject {
    @Published var groupedRecords: [String: [MedicalVisitResponse]] = [:]
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMore = true
    
    private var currentPage = 1
    private let pageSize = 10
    private var allRecords: [MedicalVisitResponse] = []
    private let status: Int // 0 = 预约中, 1 = 已就诊
    
    init(status: Int) {
        self.status = status
    }
    
    func loadRecords() {
        guard !isLoading else { return }
        isLoading = true
        currentPage = 1
        
        let params = MedicalVisitPageParam(
            startVisitDate: nil,
            endVisitDate: nil,
            status: status,
            pageNumber: currentPage,
            pageSize: pageSize
        )
        
        BgResultNetWork<MedicalVisitPageParam, Page<MedicalVisitResponse>>.post(
            apiUrl(MEDICALVISIT_PAGE),
            params: params
        )
        .complicationHand { [weak self] (page: Page<MedicalVisitResponse>?) in
            guard let self = self, let page = page else { return }
            
            DispatchQueue.main.async {
                self.allRecords = page.datas
                self.groupRecordsByYear()
                self.hasMore = Int64(self.currentPage * self.pageSize) < page.total
                self.isLoading = false
            }
        }
        .finalHandleFunc { _ in
            self.isLoading = false
        }
        .responseDecodable()
    }
    
    func loadMore() {
        guard !isLoadingMore && hasMore else { return }
        isLoadingMore = true
        currentPage += 1
        
        let params = MedicalVisitPageParam(
            startVisitDate: nil,
            endVisitDate: nil,
            status: status,
            pageNumber: currentPage,
            pageSize: pageSize
        )
        
        BgResultNetWork<MedicalVisitPageParam, Page<MedicalVisitResponse>>.post(
            apiUrl(MEDICALVISIT_PAGE),
            params: params
        )
        .complicationHand { [weak self] (page: Page<MedicalVisitResponse>?) in
            guard let self = self, let page = page else { return }
            
            DispatchQueue.main.async {
                self.allRecords.append(contentsOf: page.datas)
                self.groupRecordsByYear()
                self.hasMore = Int64(self.currentPage * self.pageSize) < page.total
                self.isLoadingMore = false
            }
        }
        .errorHandle { [weak self] (result, error) in
            DispatchQueue.main.async {
                self?.isLoadingMore = false
                self?.currentPage -= 1
                print("加载更多失败: \(error)")
            }
        }
        .responseDecodable()
    }
    
    func refresh() async {
        await withCheckedContinuation { continuation in
            currentPage = 1
            
            let params = MedicalVisitPageParam(
                startVisitDate: nil,
                endVisitDate: nil,
                status: status,
                pageNumber: currentPage,
                pageSize: pageSize
            )
            
            BgResultNetWork<MedicalVisitPageParam, Page<MedicalVisitResponse>>.post(
                apiUrl(MEDICALVISIT_PAGE),
                params: params
            )
            .complicationHand { [weak self] (page: Page<MedicalVisitResponse>?) in
                guard let self = self, let page = page else {
                    continuation.resume()
                    return
                }
                
                DispatchQueue.main.async {
                    self.allRecords = page.datas
                    self.groupRecordsByYear()
                    self.hasMore = Int64(self.currentPage * self.pageSize) < page.total
                    continuation.resume()
                }
            }
            .errorHandle { (result, error) in
                print("刷新失败: \(error)")
                continuation.resume()
            }
            .responseDecodable()
        }
    }
    
    /// 更新就诊状态
    func updateStatus(recordId: String, newStatus: Int) async {
        let params = MedicalVisitUpdateStatusParam(
            id: recordId,
            status: newStatus
        )
        
        await withCheckedContinuation { continuation in
            BgResultNetWork<MedicalVisitUpdateStatusParam, Int32>.post(
                apiUrl(MEDICALVISIT_UPDATE_STATUS),
                params: params
            )
            .complicationHand { [weak self] (response: Int32?) in
                DispatchQueue.main.async {
                    // 更新成功后，从当前列表中移除该记录（因为状态变了）
                    self?.allRecords.removeAll { $0.id == recordId }
                    self?.groupRecordsByYear()
                    
                    // 触发另一个列表的刷新
                    if newStatus == 1 {
                        // 从预约变为已就诊，刷新已就诊列表
                        MedicalRecordsRefreshManager.shared.refreshVisited()
                    } else {
                        // 从已就诊变为预约，刷新预约列表
                        MedicalRecordsRefreshManager.shared.refreshAppointment()
                    }
                    
                    continuation.resume()
                }
            }
            .errorHandle { (result, error) in
                print("更新状态失败: \(error)")
                DispatchQueue.main.async {
                    continuation.resume()
                }
            }
            .responseDecodable()
        }
    }
    
    /// 删除就诊记录
    func deleteRecord(recordId: String) {
        let param = MedicalVisitDetailParam(id: recordId)
        
        BgResultNetWork<MedicalVisitDetailParam, Int32>.post(
            apiUrl(MEDICALVISIT_DELETE),
            params: param
        )
        .complicationHand { [weak self] (response: Int32?) in
            DispatchQueue.main.async {
                // 删除成功后，从列表中移除该记录
                self?.allRecords.removeAll { $0.id == recordId }
                self?.groupRecordsByYear()
            }
        }
        .errorHandle { (result, error) in
            print("删除记录失败: \(error)")
        }
        .responseDecodable()
    }
    
    private func groupRecordsByYear() {
        groupedRecords = Dictionary(grouping: allRecords, by: { $0.year })
    }
}



// 自定义头部
struct CustomHeader: View {
    @Binding var selectedTab: Int
    @State private var showCreateRecord = false

    private var titleText: String {
        switch selectedTab {
        case 0: return "就诊记录"
        case 1: return "就诊提醒"
        case 2: return "就诊报告"
        default: return "就诊"
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // 左侧占位（保持居中）
            Color.clear
                .frame(width: 36, height: 36)

            Spacer()

            // 中间标题和指示器
            VStack(spacing: 8) {
                Text(titleText)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.theme(.primary), Color.theme(.secondary)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                // 圆点指示器
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 10)
                            .frame(width: index == selectedTab ? 16 : 8, height: 6)
                            .foregroundStyle(index == selectedTab ? Color.theme(.primary) : Color("divider"))
                            .animation(.easeInOut(duration: 0.33), value: selectedTab)
                    }
                }
            }

            Spacer()

            // 右侧添加按钮
            Button(action: { showCreateRecord = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .appGlass(.regular.interactive().tint(Color.theme(.primary)), in: Circle())
            }
            .sheet(isPresented: $showCreateRecord) {
                CreateMedicalRecordView(onRecordCreated: {
                    // 添加记录后刷新所有列表
                    MedicalRecordsRefreshManager.shared.refreshAll()
                })
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

// 更新预览
#Preview {
    NavigationStack {
        MedicalRecordsView()
    }
}

// 提醒页专用卡片 - 精致紧凑设计
struct MedicalReminderCard: View {
    let record: MedicalVisitResponse
    let onConfirm: () async -> Void
    
    @State private var isUpdating = false
    @State private var showConfirmAlert = false
    
    private var canConfirm: Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        if let visitDate = dateFormatter.date(from: record.visitDate) {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let visitDay = calendar.startOfDay(for: visitDate)
            return visitDay <= today
        }
        return false
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // 左侧日期区域 - 渐变背景
            VStack(spacing: 2) {
                Text(record.month)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.white.opacity(0.9))
                    .textCase(.uppercase)
                
                Text(record.day)
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(.white)
                
                Text(record.weekday)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(width: 64)
            .frame(maxHeight: .infinity)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 1.0, green: 0.6, blue: 0.2),
                        Color(red: 1.0, green: 0.45, blue: 0.25)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
            // 右侧内容区
            VStack(alignment: .leading, spacing: 10) {
                // 医院名称 + 状态
                HStack(alignment: .center) {
                    Text(record.hospital)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color("text_primary"))
                        .lineLimit(1)
                    
                    Spacer(minLength: 8)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                        
                        Text("待就诊")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color.orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.12))
                    )
                }
                
                // 科室 + 医生 + 时间
                HStack(spacing: 12) {
                    HStack(spacing: 5) {
                        Image(systemName: "cross.case.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color.theme(.primary))
                        
                        Text(record.department)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color("text_secondary"))
                            .lineLimit(1)
                    }
                    
                    if !record.doctorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack(spacing: 5) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color.teal)
                            
                            Text(record.doctorName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color("text_secondary"))
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer(minLength: 0)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color("text_primary"))
                        
                        Text(extractTime(from: record.visitDate))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color("text_primary"))
                    }
                }
            }
            .padding(.leading, 14)
            .padding(.vertical, 14)
            .padding(.trailing, 8)
            
            // 确认按钮
            Button(action: {
                if canConfirm { showConfirmAlert = true }
            }) {
                ZStack {
                    if isUpdating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: canConfirm ? Color.theme(.primary) : Color.gray))
                            .scaleEffect(0.8)
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: canConfirm ? "checkmark.circle.fill" : "hourglass")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(canConfirm ? Color.theme(.primary) : Color.gray.opacity(0.5))
                                .symbolRenderingMode(.hierarchical)
                            
                            Text(canConfirm ? "确认" : "未到")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(canConfirm ? Color.theme(.primary) : Color.gray.opacity(0.5))
                        }
                    }
                }
                .frame(width: 56)
                .frame(maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(canConfirm ? Color.theme(.primary).opacity(0.08) : Color.gray.opacity(0.05))
                )
            }
            .buttonStyle(.plain)
            .disabled(!canConfirm || isUpdating)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
            .alert("确认就诊", isPresented: $showConfirmAlert) {
                Button("取消", role: .cancel) { }
                Button("确认已就诊") {
                    Task {
                        isUpdating = true
                        await onConfirm()
                        isUpdating = false
                    }
                }
            } message: {
                Text("确认您已在\(record.hospital)完成就诊？")
            }
        }
        .frame(height: 88)
        .background(Color("content_bg"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
    
    private func extractTime(from dateTime: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        if let date = dateFormatter.date(from: dateTime) {
            dateFormatter.dateFormat = "HH:mm"
            return dateFormatter.string(from: date)
        }
        return "--:--"
    }
}


// 更新预览
#Preview {
    NavigationStack {
        MedicalRecordsView()
    }
}

