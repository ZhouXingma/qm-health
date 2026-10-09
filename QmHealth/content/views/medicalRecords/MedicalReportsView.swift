//
//  MedicalReportsView.swift
//  QmHealth
//
//  就诊报告时间线视图（按就诊聚合，列表形式展示）
//

import SwiftUI
import PDFKit

// MARK: - 就诊聚合单元（一次就诊可能含多份报告）
struct MedicalReportGroup: Identifiable {
    let id: String          // visitDate + hospital
    let visitDate: String?
    let hospital: String?
    let doctorName: String?
    let department: String?
    let diagnosis: String?
    let reports: [MedicalReportVisitResponse]

    var year: String {
        guard let visit = parseDate() else { return "未知" }
        let cal = Calendar.current
        return "\(cal.component(.year, from: visit))年"
    }
    var month: String { _month() + "月" }
    var day: String { _day() }
    var weekday: String { _weekday() }
    var timeText: String { _time() }
    var hospitalShort: String? {
        if let h = hospital, !h.isEmpty { return h }
        return nil
    }

    private func parseDate() -> Date? {
        guard let str = visitDate else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.date(from: str)
    }

    private func _month() -> String {
        guard let d = parseDate() else { return "--" }
        let f = DateFormatter(); f.dateFormat = "MM"; return f.string(from: d)
    }
    private func _day() -> String {
        guard let d = parseDate() else { return "--" }
        let f = DateFormatter(); f.dateFormat = "dd"; return f.string(from: d)
    }
    private func _weekday() -> String {
        guard let d = parseDate() else { return "周--" }
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let cal = Calendar.current
        let idx = cal.component(.weekday, from: d)
        return ["周日","周一","周二","周三","周四","周五","周六"][idx - 1]
    }
    private func _time() -> String {
        guard let d = parseDate() else { return "--:--" }
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d)
    }
}

// MARK: - 就诊报告列表
struct MedicalReportsView: View {
    @StateObject private var viewModel = MedicalReportsViewModel()
    @State private var previewInitial: PreviewTarget?

    /// 全屏预览的入口：记录组 + 选中下标
    struct PreviewTarget: Identifiable {
        let id: String
        let groupId: String
        let initialIndex: Int
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                if viewModel.isLoading && viewModel.groupedRecords.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 100)
                } else if viewModel.groupedRecords.isEmpty && !viewModel.isLoading {
                    emptyView
                } else {
                    ForEach(viewModel.yearKeys, id: \.self) { year in
                        VStack(alignment: .leading, spacing: 10) {
                            YearSectionHeader(year: year, count: viewModel.groupedRecords[year]?.reduce(0) { $0 + $1.reports.count } ?? 0)

                            VStack(spacing: 12) {
                                ForEach(Array((viewModel.groupedRecords[year] ?? []).enumerated()), id: \.element.id) { index, group in
                                    TimelineRow(
                                        group: group,
                                        isFirst: index == 0,
                                        isLast: index == (viewModel.groupedRecords[year]?.count ?? 1) - 1,
                                        onReportTap: { reportIndex in
                                            previewInitial = PreviewTarget(
                                                id: group.id,
                                                groupId: group.id,
                                                initialIndex: reportIndex
                                            )
                                        }
                                    )
                                }
                            }
                        }
                    }

                    if viewModel.hasMore {
                        HStack {
                            Spacer()
                            if viewModel.isLoadingMore {
                                ProgressView().padding(.vertical, 20)
                            } else {
                                Color.clear
                                    .frame(height: 50)
                                    .onAppear { viewModel.loadMore() }
                            }
                            Spacer()
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)

            Color.clear.frame(height: 30)
        }
        .refreshable {
            await viewModel.refresh()
        }
        .onAppear {
            if viewModel.groupedRecords.isEmpty {
                viewModel.loadReports()
            }
        }
        .fullScreenCover(item: $previewInitial) { target in
            if let group = viewModel.findGroup(by: target.groupId) {
                ReportGroupFullScreenView(group: group, initialIndex: target.initialIndex)
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.below.ecg")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.theme(.primary).opacity(0.4), Color.theme(.secondary).opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("暂无就诊报告")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color("text_secondary"))
            Text("添加就诊记录后，相关报告会显示在这里")
                .font(.system(size: 12))
                .foregroundColor(Color("text_secondary"))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
}

// MARK: - 年份分组头部
struct YearSectionHeader: View {
    let year: String
    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(year)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color("text_primary"))

            Text("\(count)份")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.theme(.primary))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(Color.theme(.primary).opacity(0.12))
                )

            Spacer()
        }
        .padding(.top, 4)
        .padding(.bottom, 2)
    }
}

// MARK: - 时间线单行（一次就诊）
struct TimelineRow: View {
    let group: MedicalReportGroup
    let isFirst: Bool
    let isLast: Bool
    let onReportTap: (Int) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 左侧时间线
            VStack(spacing: 0) {
                Rectangle()
                    .fill(isFirst ? Color.clear : Color.theme(.primary).opacity(0.4))
                    .frame(width: 2, height: 14)

                ZStack {
                    Circle()
                        .fill(Color.theme(.primary))
                        .frame(width: 14, height: 14)
                    Circle()
                        .fill(Color("background"))
                        .frame(width: 6, height: 6)
                }
                .frame(width: 14, height: 14)

                Rectangle()
                    .fill(isLast ? Color.clear : Color.theme(.primary).opacity(0.4))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 14)

            VStack(alignment: .leading, spacing: 10) {
                // 日期 + 时间
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(group.day)
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(Color.theme(.primary))
                        .tracking(-0.5)
                    Text(group.month)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color("text_primary"))
                    Text(group.weekday)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color("text_secondary"))
                    Spacer()
                    if group.timeText != "--:--" {
                        Text(group.timeText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color("text_secondary"))
                    }
                }

                VisitInfoCard(group: group, onReportTap: onReportTap)
            }
            .padding(.bottom, isLast ? 0 : 12)
        }
    }
}

// MARK: - 就诊信息卡片（含报告列表）
struct VisitInfoCard: View {
    let group: MedicalReportGroup
    let onReportTap: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部就诊信息
            VStack(alignment: .leading, spacing: 8) {
                if let hospital = group.hospitalShort {
                    HStack(spacing: 5) {
                        Image(systemName: "cross.case.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color.theme(.primary))
                        Text(hospital)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color("text_primary"))
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 8) {
                    if let dept = group.department, !dept.isEmpty {
                        infoChip(icon: "building.2.fill", text: dept)
                    }
                    if let doctor = group.doctorName, !doctor.isEmpty {
                        infoChip(icon: "stethoscope", text: doctor)
                    }
                    Spacer(minLength: 0)
                }

                if let diagnosis = group.diagnosis, !diagnosis.isEmpty {
                    Text(diagnosis)
                        .font(.system(size: 12))
                        .foregroundColor(Color("text_secondary"))
                        .lineLimit(2)
                }
            }

            // 报告列表
            VStack(spacing: 8) {
                ForEach(Array(group.reports.enumerated()), id: \.element.id) { index, report in
                    ReportListRow(report: report)
                        .onTapGesture { onReportTap(index) }
                }
            }
        }
        .cardStyle()
    }

    @ViewBuilder
    private func infoChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(Color.theme(.primary))
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.theme(.primary))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Color.theme(.primary).opacity(0.12))
        )
    }
}

// MARK: - 报告列表行（与编辑就诊记录的报告行样式一致）
struct ReportListRow: View {
    let report: MedicalReportVisitResponse

    @State private var thumbnail: UIImage?
    @State private var loadingThumb = true

    private var fileId: String? {
        guard let s = report.fileUrl, !s.isEmpty else { return nil }
        return s
    }

    var body: some View {
        HStack(spacing: 12) {
            // 缩略图 / 文件图标
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [Color.theme(.primary).opacity(0.15), Color.theme(.primary).opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                if let image = thumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else if loadingThumb {
                    ProgressView()
                        .scaleEffect(0.7)
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.theme(.primary)))
                } else {
                    Image(systemName: reportIcon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(Color.theme(.primary))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(report.reportType ?? "未命名报告")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color("text_primary"))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Image(systemName: fileTypeIcon)
                        .font(.system(size: 10))
                    Text(fileTypeText)
                        .font(.system(size: 11))
                }
                .foregroundColor(Color("text_secondary"))
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.theme(.primary).opacity(0.05))
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onAppear { loadThumbnail() }
    }

    private var reportIcon: String {
        let type = report.reportType ?? ""
        if type.contains("血") { return "drop.fill" }
        if type.contains("CT") || type.contains("ct") { return "rays" }
        if type.contains("X") { return "xray" }
        if type.contains("核磁") || type.contains("MRI") || type.contains("mr") { return "wave.3.right" }
        if type.contains("尿") { return "flask.fill" }
        if type.contains("心电") { return "waveform.path.ecg" }
        return "doc.text.fill"
    }

    private var fileTypeIcon: String {
        // 简化：根据 reportType 是否含常见文件关键词判断
        let type = report.reportType ?? ""
        if type.contains("PDF") || type.contains("pdf") { return "doc.fill" }
        return "photo"
    }

    private var fileTypeText: String {
        let type = report.reportType ?? ""
        if type.contains("PDF") || type.contains("pdf") { return "PDF 文件" }
        return "图片报告"
    }

    private func loadThumbnail() {
        guard thumbnail == nil, let fileId = fileId else {
            loadingThumb = false
            return
        }
        let urlString = apiUrl(FILE_LOAD) + "/\(fileId)"
        BgResultNetWork<Empty, Data>(urlString, method: .get)
            .complicationHand { (data: Data?) in
                DispatchQueue.main.async {
                    loadingThumb = false
                    if let data = data, let image = UIImage(data: data) {
                        thumbnail = image
                    }
                }
            }
            .errorHandle { (_, _) in
                DispatchQueue.main.async {
                    loadingThumb = false
                }
            }
            .response()
    }
}

// MARK: - 就诊全屏查看（一次就诊的多份报告）
struct ReportGroupFullScreenView: View {
    let group: MedicalReportGroup
    let initialIndex: Int

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    @State private var rotations: [Angle]

    init(group: MedicalReportGroup, initialIndex: Int) {
        self.group = group
        self.initialIndex = initialIndex
        _currentIndex = State(initialValue: initialIndex)
        _rotations = State(initialValue: Array(repeating: .zero, count: group.reports.count))
    }

    private var currentFileId: String? {
        guard group.reports.indices.contains(currentIndex) else { return nil }
        return group.reports[currentIndex].fileUrl
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AsyncReportView(fileId: currentFileId ?? "")

            // 顶栏
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                    }
                    Spacer()
                    Text("\(currentIndex + 1) / \(group.reports.count)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.15)))
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                Spacer()
            }

            // 底部信息
            VStack {
                Spacer()
                VStack(spacing: 6) {
                    if let type = group.reports[safe: currentIndex]?.reportType {
                        Text(type)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    if let hospital = group.hospital {
                        Text(hospital)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.black.opacity(0.6)))
                .padding(.bottom, 40)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.width < -50, currentIndex < group.reports.count - 1 {
                        currentIndex += 1
                    } else if value.translation.width > 50, currentIndex > 0 {
                        currentIndex -= 1
                    }
                }
        )
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - 异步报告加载（图片用 ZoomablePreviewImage，PDF 用 PDFView）
struct AsyncReportView: View {
    let fileId: String

    @State private var image: UIImage?
    @State private var pdfData: Data?
    @State private var loading = true
    @State private var loadFailed = false
    @State private var rotation: Angle = .zero

    var body: some View {
        Group {
            if let image = image {
                ZoomablePreviewImage(image: image, rotation: $rotation) {}
                    .background(Color.black)
            } else if let pdfData = pdfData {
                PDFKitFullScreen(data: pdfData)
            } else if loading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.4)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("加载中...")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.6))
                    Text("报告加载失败")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .onAppear { load() }
        .id(fileId) // 切换报告时强制重建
    }

    private func load() {
        guard !fileId.isEmpty else {
            loading = false
            loadFailed = true
            return
        }
        let urlString = apiUrl(FILE_LOAD) + "/\(fileId)"
        BgResultNetWork<Empty, Data>(urlString, method: .get)
            .complicationHand { (data: Data?) in
                DispatchQueue.main.async {
                    loading = false
                    guard let data = data else { loadFailed = true; return }
                    if let img = UIImage(data: data) {
                        image = img
                    } else if PDFDocument(data: data) != nil {
                        pdfData = data
                    } else {
                        loadFailed = true
                    }
                }
            }
            .errorHandle { (_, _) in
                DispatchQueue.main.async {
                    loading = false
                    loadFailed = true
                }
            }
            .response()
    }
}

// MARK: - PDF 全屏
struct PDFKitFullScreen: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .black
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document == nil {
            pdfView.document = PDFDocument(data: data)
        }
    }
}

// MARK: - ViewModel
class MedicalReportsViewModel: ObservableObject {
    @Published var groupedRecords: [String: [MedicalReportGroup]] = [:]
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMore = true

    private(set) var allRecords: [MedicalReportVisitResponse] = []
    private var currentPage = 1
    private let pageSize = 10

    var yearKeys: [String] {
        groupedRecords.keys.sorted(by: >)
    }

    func loadReports() {
        guard !isLoading else { return }
        isLoading = true
        currentPage = 1

        let params = MedicalReportPageParam(pageNumber: currentPage, pageSize: pageSize)

        BgResultNetWork<MedicalReportPageParam, Page<MedicalReportVisitResponse>>.post(
            apiUrl(MEDICAL_REPORT_PAGE),
            params: params
        )
        .complicationHand { [weak self] (page: Page<MedicalReportVisitResponse>?) in
            guard let self = self, let page = page else { return }

            DispatchQueue.main.async {
                self.allRecords = page.datas
                self.groupReports()
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

        let params = MedicalReportPageParam(pageNumber: currentPage, pageSize: pageSize)

        BgResultNetWork<MedicalReportPageParam, Page<MedicalReportVisitResponse>>.post(
            apiUrl(MEDICAL_REPORT_PAGE),
            params: params
        )
        .complicationHand { [weak self] (page: Page<MedicalReportVisitResponse>?) in
            guard let self = self, let page = page else { return }

            DispatchQueue.main.async {
                self.allRecords.append(contentsOf: page.datas)
                self.groupReports()
                self.hasMore = Int64(self.currentPage * self.pageSize) < page.total
                self.isLoadingMore = false
            }
        }
        .errorHandle { [weak self] (result, error) in
            DispatchQueue.main.async {
                self?.isLoadingMore = false
                self?.currentPage -= 1
                print("加载更多报告失败: \(error)")
            }
        }
        .responseDecodable()
    }

    func refresh() async {
        await withCheckedContinuation { continuation in
            currentPage = 1

            let params = MedicalReportPageParam(pageNumber: currentPage, pageSize: pageSize)

            BgResultNetWork<MedicalReportPageParam, Page<MedicalReportVisitResponse>>.post(
                apiUrl(MEDICAL_REPORT_PAGE),
                params: params
            )
            .complicationHand { [weak self] (page: Page<MedicalReportVisitResponse>?) in
                guard let self = self, let page = page else {
                    continuation.resume()
                    return
                }

                DispatchQueue.main.async {
                    self.allRecords = page.datas
                    self.groupReports()
                    self.hasMore = Int64(self.currentPage * self.pageSize) < page.total
                    continuation.resume()
                }
            }
            .errorHandle { (result, error) in
                print("刷新报告失败: \(error)")
                continuation.resume()
            }
            .responseDecodable()
        }
    }

    /// 通过 groupId 查找组（用于全屏预览）
    func findGroup(by groupId: String) -> MedicalReportGroup? {
        for groups in groupedRecords.values {
            if let g = groups.first(where: { $0.id == groupId }) { return g }
        }
        return nil
    }

    /// 把扁平报告列表按 (visitDate + hospital) 聚合
    private func groupReports() {
        var groups: [String: MedicalReportGroup] = [:]
        for r in allRecords {
            let key = "\(r.visitDate ?? "")_\(r.hospital ?? "")"
            if var existing = groups[key] {
                let updated = MedicalReportGroup(
                    id: existing.id,
                    visitDate: existing.visitDate,
                    hospital: existing.hospital,
                    doctorName: existing.doctorName,
                    department: existing.department,
                    diagnosis: existing.diagnosis,
                    reports: existing.reports + [r]
                )
                groups[key] = updated
            } else {
                groups[key] = MedicalReportGroup(
                    id: key,
                    visitDate: r.visitDate,
                    hospital: r.hospital,
                    doctorName: r.doctorName,
                    department: r.department,
                    diagnosis: r.diagnosis,
                    reports: [r]
                )
            }
        }

        // 按 visitDate 倒序排
        let sorted = groups.values.sorted { (a, b) -> Bool in
            (a.visitDate ?? "") > (b.visitDate ?? "")
        }

        // 按年份分组
        var byYear: [String: [MedicalReportGroup]] = [:]
        for g in sorted {
            byYear[g.year, default: []].append(g)
        }
        groupedRecords = byYear
    }
}
