import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - 创建就诊记录视图
/// 用于创建新的就诊记录或预约记录
/// 支持添加基本信息、诊断信息、检查报告等
struct CreateMedicalRecordView: View {
    @Environment(\.dismiss) var dismiss
    
    /// 记录ID（编辑模式时使用）
    var recordId: String?
    
    /// 记录数据（用于快速显示，编辑模式时使用）
    var recordData: MedicalVisitResponse?
    
    /// 记录创建/更新成功后的回调
    var onRecordCreated: (() -> Void)?
    
    // MARK: - 表单字段
    @State private var date = Date()
    @State private var hospital = ""
    @State private var department = ""
    @State private var doctor = ""
    @State private var diagnosis = ""
    @State private var symptomDescription = ""
    @State private var summary = ""
    @State private var reportFiles: [ReportFile] = []
    @State private var selectedDiseases: [SelectedDisease] = []
    /// 就诊状态：0 = 预约中/未就诊，1 = 已就诊。与就诊时间解耦，
    /// 即便 date 是未来的预约时间，用户也可以主动标记为已就诊（例如提前就诊）。
    @State private var visitStatus: Int = 1
    /// 详情接口回填的已保存用药，以及当前表单新增但尚未提交的用药草稿。
    @State private var medicines: [UsersMedicinePlanDTO] = []
    /// 用药计划表单所需的动态值域和剂型默认剂量单位。
    @State private var medicineValueScopes: [String: ValueScopeInfo] = [:]
    @State private var medicineFormUnits: [String: [String]] = [:]
    
    // MARK: - UI 状态
    @State private var showFilePicker = false
    @State private var showImagePicker = false
    @State private var showOcrSheet = false
    @State private var showAddMedicine = false
    @State private var editingReportIndex: Int?
    @State private var viewingReportIndex: Int?
    @State private var showVoiceInput = false
    @State private var showSymptomVoiceInput = false
    @State private var isSaving = false
    @State private var showLoadingAlert = false
    @State private var loadingMessage = ""
    @State private var isLoadingData = false
    @State private var dataLoadedTimestamp: Date = Date()
    @State private var popManager: PopManager = PopManager()

    /// 当前详情请求的序号；每次开始新加载递增，
    /// 异步回调里若发现 token 已变则丢弃结果，避免旧请求的数据被写入新记录。
    @State private var loadToken: Int = 0
    @State private var currentLoadedId: String? = nil
    
    /// 是否为编辑模式
    private var isEditMode: Bool {
        recordId != nil || recordData != nil
    }
    
    /// 根据当前就诊状态判断记录类型（就诊/预约）
    /// 改用 visitStatus 推导，不再和 date 绑定：date 仅表示计划就诊时间，
    /// 实际状态由用户主动控制（已就诊/未就诊）。
    private var recordType: RecordType {
        visitStatus == 1 ? .visit : .appointment
    }
    
    /// 表单验证：医院和科室为必填项
    private var isFormValid: Bool {
        !hospital.isEmpty && !department.isEmpty && !isSaving
    }

    /// 供 OCR 识别的图片数据（仅图片类型的报告转成 JPEG 数据，PDF 忽略）
    private var ocrInitialImageDatas: [Data] {
        reportFiles.compactMap { file in
            guard file.type == .image, let image = file.thumbnail else { return nil }
            return image.jpegData(compressionQuality: 1.0) ?? image.pngData()
        }
    }

    /// 用户点击 OCR 识别时缓存的图片数据快照。
    /// 计算属性 ocrInitialImageDatas 依赖 reportFiles，sheet 内容闭包在 SwiftUI
    /// 求值时可能因为 body 重算时机问题拿到空数据，导致图片"没带过去"。
    /// 这里在点击 OCR 的瞬间把数据快照到 @State，sheet 直接使用快照，避免上述问题。
    @State private var pendingOcrImages: [Data] = []
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        RecordTypeIndicator(recordType: recordType)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            visitStatus = visitStatus == 1 ? 0 : 1
                        }

                        BasicInfoSection(
                            date: $date,
                            hospital: $hospital,
                            department: $department,
                            doctor: $doctor
                        )

                        DiseaseSelectionSection(
                            selectedDiseases: $selectedDiseases
                        )

                        SymptomDescriptionSection(
                            symptomDescription: $symptomDescription,
                            onVoiceInput: { showSymptomVoiceInput = true }
                        )

                        DiagnosisSection(
                            diagnosis: $diagnosis,
                            summary: $summary,
                            onVoiceInput: { showVoiceInput = true }
                        )

                        ReportFilesSection(
                            reportFiles: $reportFiles,
                            onAddImage: { showImagePicker = true },
                            onAddFile: { showFilePicker = true },
                            onViewReport: { index in viewingReportIndex = index },
                            onEditReport: { index in editingReportIndex = index },
                            onOcrRecognize: {
                                // 在打开 sheet 前把图片数据快照到 @State，
                                // 避免 sheet 内容闭包求值时拿不到最新数据导致图片"没带过去"。
                                pendingOcrImages = ocrInitialImageDatas
                                showOcrSheet = true
                            }
                        )

                        MedicalRecordMedicineSection(
                            medicines: medicines,
                            medicineFormDescription: { form in
                                medicineValueScopes["medicineForm"]?.desc(forValue: form) ?? "未设置剂型"
                            },
                            onAdd: { showAddMedicine = true },
                            onDelete: { index in medicines.remove(at: index) }
                        )

                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                .id(dataLoadedTimestamp)
                .simultaneousGesture(TapGesture().onEnded { hideKeyboard() })
            }
            .navigationTitle(isEditMode ? "编辑就诊记录" : "新建就诊记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isEditMode {
                        Button {
                            if let id = recordId ?? recordData?.id {
                                deleteRecord(id: id)
                            }
                        } label: {
                            Text("删除")
                                .foregroundStyle(.red)
                                .fontWeight(.semibold)
                        }
                    } else {
                        Button("取消") {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveRecord()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isFormValid)
                }
            }
        }
        .sheetAppBackground()
        .overlay {
            if showLoadingAlert || isLoadingData {
                LoadingOverlay(message: isLoadingData ? "加载中..." : loadingMessage)
            }
        }
        .onAppear {
            loadInitialData()
            loadMedicineFormOptions()
        }
        .sheet(isPresented: $showAddMedicine) {
            AddMedicinePlanView(
                valueScopes: $medicineValueScopes,
                medicineFormUnits: $medicineFormUnits,
                onSaved: { _ in },
                onDraftSaved: { plan in
                    medicines.append(plan)
                }
            )
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(reportFiles: $reportFiles)
        }
        .sheet(isPresented: $showFilePicker) {
            DocumentPicker(reportFiles: $reportFiles)
        }
        .sheet(isPresented: $showOcrSheet) {
            OcrRecognizeView(
                initialImages: pendingOcrImages,
                onUploadComplete: { fileIds in
                    handleOcrUploadedFileIds(fileIds)
                }
            )
        }
        .sheet(item: Binding(
            get: { editingReportIndex.map { EditingReport(index: $0) } },
            set: { editingReportIndex = $0?.index }
        )) { item in
            EditReportNameView(reportFile: $reportFiles[item.index])
        }
        .sheet(isPresented: $showVoiceInput) {
            VoiceInputView(text: $summary, restartInterval: 5)
        }
        .sheet(isPresented: $showSymptomVoiceInput) {
            VoiceInputView(text: $symptomDescription, restartInterval: 20)
        }
        .fullScreenCover(item: Binding(
            get: { viewingReportIndex.map { ViewingReport(index: $0) } },
            set: { viewingReportIndex = $0?.index }
        )) { item in
            ReportFileViewer(
                reportFiles: reportFiles,
                initialIndex: item.index
            )
        }
        .withLocalPop(popManager)
    }
    
    // 辅助结构体用于 sheet(item:)
    private struct EditingReport: Identifiable {
        let id = UUID()
        let index: Int
    }
    
    private struct ViewingReport: Identifiable {
        let id = UUID()
        let index: Int
    }
    
    // MARK: - 数据加载
    private func loadInitialData() {
        if let record = recordData {
            fillFormData(
                visitDate: record.visitDate,
                hospital: record.hospital,
                department: record.department,
                doctorName: record.doctorName,
                diagnosis: record.diagnosis,
                symptomDescription: record.symptomDescription,
                remarks: record.remarks,
                status: record.status
            )
        }

        if let id = recordId ?? recordData?.id {
            loadDetailFromAPI(recordId: id)
        }
    }

    /// 清空与「就诊记录」绑定的所有本地状态，进入新记录时必须先调用，
    /// 否则旧记录的 reportFiles / selectedDiseases / medicines 会残留到新记录上。
    private func resetRecordState() {
        reportFiles = []
        selectedDiseases = []
        medicines = []
        pendingOcrImages = []
        editingReportIndex = nil
        viewingReportIndex = nil
        diagnosis = ""
        symptomDescription = ""
        summary = ""
        visitStatus = 1
    }
    
    private func loadMedicineFormOptions() {
        if medicineValueScopes.isEmpty {
            let params = ValueScopeGetParamDTO(codes: [
                "medicineForm",
                "medicineSpecificationUnit",
                "medicineFrequencyType",
                "medicinePlanSourceType"
            ])
            BgResultNetWork<ValueScopeGetParamDTO, [String: ValueScopeInfo]>.post(
                apiUrl(VALUE_SCOPE_LIST),
                params: params,
                popManager: popManager
            )
            .complicationHand { (data: [String: ValueScopeInfo]?) in
                if let data {
                    medicineValueScopes = data
                }
            }
            .responseDecodable()
        }

        if medicineFormUnits.isEmpty {
            BgResultNetWork<Empty?, [String: [String]]>.post(
                apiUrl(MEDICINE_PLAN_FORM_UNITS),
                params: nil,
                popManager: popManager
            )
            .complicationHand { (data: [String: [String]]?) in
                if let data {
                    medicineFormUnits = data
                }
            }
            .responseDecodable()
        }
    }

    private func deleteRecord(id: String) {
        popManager.showActionPop(
            title: "删除确认",
            description: "删除后不可恢复，是否确认删除",
            buttonText: "删除",
            icon: .warn,
            buttonCancleShow: true,
            buttonCancleTitle: "取消",
            customAction: {
                BgResultNetWork<[String:String], Int32>
                    .post(apiUrl(MEDICALVISIT_DELETE),params: ["id":id],popManager: popManager)
                    .complicationHand { (_:Int32?) in
                        dismiss()
                        onRecordCreated?()
                    }
                    .responseDecodable()
                self.popManager.closePop()
            },
            customCancelAction: {
                self.popManager.closePop()
            }
        )
    }
    
    private func loadDetailFromAPI(recordId: String) {
        // 切换到新记录前先递增 token + 清空旧状态 + 重置状态
        // 三步必须组合使用，单靠 .id() 在某些路径下仍会保留 @State
        loadToken += 1
        let myToken = loadToken
        currentLoadedId = recordId
        resetRecordState()

        isLoadingData = true

        let param = MedicalVisitDetailParam(id: recordId)

        BgResultNetWork<MedicalVisitDetailParam, MedicalVisitDetailResponse>.post(
            apiUrl(MEDICALVISIT_DETAIL),
            params: param,
            popManager: popManager
        )
        .complicationHand { [self] (response: MedicalVisitDetailResponse?) in
            // token 已变说明用户已切换到另一条记录，回调结果丢弃
            guard myToken == self.loadToken else { return }

            guard let response = response else {
                DispatchQueue.main.async {
                    self.isLoadingData = false
                }
                return
            }

            DispatchQueue.main.async {
                // 二次校验：再次确认当前加载的仍是同一条记录
                guard myToken == self.loadToken, self.currentLoadedId == recordId else { return }

                let visit = response.visit

                self.fillFormData(
                    visitDate: visit.visitDate,
                    hospital: visit.hospital,
                    department: visit.department,
                    doctorName: visit.doctorName,
                    diagnosis: visit.diagnosis,
                    symptomDescription: visit.symptomDescription,
                    remarks: visit.remarks,
                    status: visit.status
                )

                if let reports = response.reports, !reports.isEmpty {
                    self.loadReportFiles(reports: reports, token: myToken)
                }

                if let diseases = response.diseases, !diseases.isEmpty {
                    self.selectedDiseases = diseases.map { disease in
                        SelectedDisease(
                            diseaseId: disease.diseaseId,
                            name: disease.name,
                            severity: disease.severity,
                            status: disease.status
                        )
                    }
                }

                self.medicines = response.medicines?.map { $0.asMedicinePlan() } ?? []

                self.isLoadingData = false
            }
        }
        .errorHandle { (result, error) in
            DispatchQueue.main.async {
                guard myToken == self.loadToken else { return }
                self.isLoadingData = false
                print("加载详情失败: \(error)")
            }
        }
        .responseDecodable()
    }

    private func loadReportFiles(reports: [MedicalReportResponse], token: Int) {
        for report in reports {
            if report.isImage == 1 {
                loadImageFromServer(
                    fileId: report.fileUrl,
                    reportType: report.reportType,
                    fileName: report.fileName,
                    token: token
                )
            } else {
                // token 校验后再写入，避免旧请求污染新记录
                guard token == loadToken else { return }
                let reportFile = ReportFile(
                    name: report.fileName,
                    displayName: report.reportType,
                    type: .pdf,
                    url: nil,
                    thumbnail: nil,
                    size: nil,
                    isUploaded: true,
                    uploadedFileId: report.fileUrl
                )
                self.reportFiles.append(reportFile)
            }
        }
    }

    private func loadImageFromServer(fileId: String, reportType: String, fileName: String, token: Int) {
        let urlString = apiUrl(FILE_LOAD) + "/\(fileId)"

        BgResultNetWork<Empty, Data>(urlString, method: .get, popManager: popManager)
            .complicationHand { [self] (data: Data?) in
                guard let data = data, let image = UIImage(data: data) else {
                    print("无法解析图片数据")
                    return
                }

                DispatchQueue.main.async {
                    guard token == self.loadToken else { return }
                    let reportFile = ReportFile(
                        name: fileName,
                        displayName: reportType,
                        type: .image,
                        url: nil,
                        thumbnail: image,
                        size: Int64(data.count),
                        isUploaded: true,
                        uploadedFileId: fileId
                    )
                    self.reportFiles.append(reportFile)
                    self.dataLoadedTimestamp = Date()
                }
            }
            .errorHandle { (result, error) in
                print("下载图片失败: \(error)")
            }
            .response()
    }
    
    private func fillFormData(
        visitDate: String,
        hospital: String,
        department: String,
        doctorName: String,
        diagnosis: String?,
        symptomDescription: String?,
        remarks: String?,
        status: Int?
    ) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = dateFormatter.date(from: visitDate) {
            self.date = date
        }

        self.hospital = hospital
        self.department = department
        self.doctor = doctorName
        self.diagnosis = diagnosis ?? ""
        self.symptomDescription = symptomDescription ?? ""
        self.summary = remarks ?? ""
        // 优先使用服务端返回的真实状态；新建模式不传 status，保持默认 1（已就诊）
        if let status {
            self.visitStatus = status
        }
        self.dataLoadedTimestamp = Date()
    }
    
    // MARK: - 保存逻辑
    private func saveRecord() {
        guard !isSaving else { return }
        isSaving = true
        
        if isEditMode {
            if !reportFiles.isEmpty {
                uploadReportFiles(isEdit: true)
            } else {
                updateMedicalVisit(reports: nil)
            }
        } else {
            if !reportFiles.isEmpty {
                uploadReportFiles(isEdit: false)
            } else {
                submitMedicalVisit(reports: nil)
            }
        }
    }

    private func handleMedicalVisitSaveFailure<R: Codable>(
        result: BgResult<R>?,
        error: BgResultNetWorkError
    ) {
        let message = result?.message ?? networkErrorMessage(error)
        print("就诊记录保存失败：code=\(result?.code.description ?? "无")，message=\(message)，error=\(error)")

        DispatchQueue.main.async {
            showLoadingAlert = false
            isSaving = false
            showAlert(title: "保存失败", message: message)
        }
    }

    private func networkErrorMessage(_ error: BgResultNetWorkError) -> String {
        switch error {
        case .timeout(_, let message),
             .network(_, let message),
             .parameter(_, let message),
             .parsing(_, let message),
             .http(_, let message),
             .validation(_, let message),
             .requestError(_, let message),
             .unknown(_, let message):
            return message
        }
    }
    
    private func uploadReportFiles(isEdit: Bool) {
        showLoadingAlert = true
        loadingMessage = "正在上传报告文件..."
        
        var uploadedReports: [MedicalReportAddParam] = []
        
        let alreadyUploadedFiles = reportFiles.filter { $0.isUploaded }
        let filesToUpload = reportFiles.filter { !$0.isUploaded }
        
        for reportFile in alreadyUploadedFiles {
            if let fileId = reportFile.uploadedFileId {
                let report = MedicalReportAddParam(
                    visitId: "",
                    reportType: reportFile.displayName,
                    fileUrl: fileId,
                    fileName: reportFile.name,
                    description: nil,
                    isImage: reportFile.type == .image ? 1 : 0
                )
                uploadedReports.append(report)
            }
        }
        
        if filesToUpload.isEmpty {
            if isEdit {
                updateMedicalVisit(reports: uploadedReports.isEmpty ? nil : uploadedReports)
            } else {
                submitMedicalVisit(reports: uploadedReports.isEmpty ? nil : uploadedReports)
            }
            return
        }
        
        let totalFiles = filesToUpload.count
        var uploadedCount = 0
        
        for reportFile in filesToUpload {
            uploadSingleFile(reportFile) { fileId in
                if let fileId = fileId {
                    let report = MedicalReportAddParam(
                        visitId: "",
                        reportType: reportFile.displayName,
                        fileUrl: fileId,
                        fileName: reportFile.name,
                        description: nil,
                        isImage: reportFile.type == .image ? 1 : 0
                    )
                    uploadedReports.append(report)
                }
                
                uploadedCount += 1
                loadingMessage = "正在上传报告文件 (\(uploadedCount)/\(totalFiles))..."
                
                if uploadedCount == totalFiles {
                    if uploadedReports.isEmpty {
                        showLoadingAlert = false
                        isSaving = false
                        showAlert(title: "上传失败", message: "报告文件上传失败，请重试")
                    } else {
                        if isEdit {
                            updateMedicalVisit(reports: uploadedReports)
                        } else {
                            submitMedicalVisit(reports: uploadedReports)
                        }
                    }
                }
            }
        }
    }
    
    /// 把 OCR 上传成功后回传的文件 id 按顺序关联到当前报告列表中类型为 image 的报告上，
    /// 标记为已上传。保存就诊记录时会跳过这些文件，避免同一张图片被上传两次产生两份文件记录。
    private func handleOcrUploadedFileIds(_ fileIds: [String]) {
        let imageIndices = reportFiles.indices.filter { reportFiles[$0].type == .image }
        let count = min(imageIndices.count, fileIds.count)
        for i in 0..<count {
            reportFiles[imageIndices[i]].isUploaded = true
            reportFiles[imageIndices[i]].uploadedFileId = fileIds[i]
        }
    }

    private func uploadSingleFile(_ reportFile: ReportFile, completion: @escaping (String?) -> Void) {
        var fileData: Data?
        var fileName: String = reportFile.name
        var mimeType: String = ""
        
        if reportFile.type == .image, let image = reportFile.thumbnail {
            fileData = image.jpegData(compressionQuality: 0.8)
            fileName = reportFile.name + ".jpg"
            mimeType = "image/jpeg"
        } else if reportFile.type == .pdf, let url = reportFile.url {
            fileData = try? Data(contentsOf: url)
            mimeType = "application/pdf"
        }
        
        guard let data = fileData else {
            completion(nil)
            return
        }
        
        let files:[FileUploadInfo] = [
            FileUploadInfo(data: data, fileName: fileName, mimeType: mimeType)
        ]
        
        BgResultNetWork<Empty, [FilesDTO]>.upload(apiUrl(FILE_UPLOAD), params: nil, popManager: popManager)
        .complicationHand { (results:[FilesDTO]?) in
            if let fileId = results?.first?.id {
                completion(fileId)
            } else {
                completion(nil)
            }
        }.upload(fileInfos: files)
    }
    
    private func submitMedicalVisit(reports: [MedicalReportAddParam]?) {
        loadingMessage = "正在保存就诊记录..."
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let visitDateStr = dateFormatter.string(from: date)
        
        let diseases = selectedDiseases.map { disease in
            MedicalVisitDiseaseParam(
                diseaseId: disease.diseaseId,
                name: disease.name,
                severity: disease.severity,
                status: disease.status
            )
        }
        
        let param = MedicalVisitAddParam(
            hospital: hospital,
            department: department,
            doctorName: doctor,
            visitDate: visitDateStr,
            diagnosis: diagnosis.isEmpty ? nil : diagnosis,
            status: visitStatus,
            remarks: summary.isEmpty ? nil : summary,
            symptomDescription: symptomDescription.isEmpty ? nil : symptomDescription,
            reports: reports,
            diseases: diseases.isEmpty ? nil : diseases,
            medicines: medicines.isEmpty ? nil : medicines.map { MedicalVisitMedicineParam(plan: $0) }
        )
        
        BgResultNetWork<MedicalVisitAddParam, String>.post(apiUrl(MEDICALVISIT_ADD), params: param, popManager: popManager)
            .complicationHand { [onRecordCreated] (visiteId:String?) in
                onRecordCreated?()
                dismiss()
            }
            .finalHandleFunc({ _ in
                showLoadingAlert = false
                isSaving = false
            })
            .errorHandle { result, error in
                handleMedicalVisitSaveFailure(result: result, error: error)
            }
            .responseDecodable()
    }
    
    private func updateMedicalVisit(reports: [MedicalReportAddParam]?) {
        guard let id = recordId ?? recordData?.id else { return }
        
        loadingMessage = "正在更新就诊记录..."
        showLoadingAlert = true
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let visitDateStr = dateFormatter.string(from: date)
        
        let diseases = selectedDiseases.map { disease in
            MedicalVisitDiseaseParam(
                diseaseId: disease.diseaseId,
                name: disease.name,
                severity: disease.severity,
                status: disease.status
            )
        }
        
        let param = MedicalVisitUpdateParam(
            id: id,
            hospital: hospital,
            department: department,
            doctorName: doctor,
            visitDate: visitDateStr,
            diagnosis: diagnosis.isEmpty ? nil : diagnosis,
            status: visitStatus,
            remarks: summary.isEmpty ? nil : summary,
            symptomDescription: symptomDescription.isEmpty ? nil : symptomDescription,
            reports: reports,
            diseases: diseases.isEmpty ? nil : diseases,
            medicines: medicines.isEmpty ? nil : medicines.map { MedicalVisitMedicineParam(plan: $0) }
        )
        
        BgResultNetWork<MedicalVisitUpdateParam, Int32>.post(apiUrl(MEDICALVISIT_UPDATE), params: param, popManager: popManager)
            .complicationHand { [onRecordCreated] (response: Int32?) in
                onRecordCreated?()
                dismiss()
            }
            .finalHandleFunc({ _ in
                showLoadingAlert = false
                isSaving = false
            })
            .errorHandle { result, error in
                handleMedicalVisitSaveFailure(result: result, error: error)
            }
            .responseDecodable()
    }
    
    /// 使用当前页面的本地弹窗管理器，确保提示位于 Sheet 的正确层级。
    private func showAlert(title: String, message: String) {
        popManager.showSimplePop(title: title, description: message)
    }
}

// MARK: - 就诊用药列表
/// 用药区与检查报告保持一致的独立层级；已有 ID 的项目仅允许删除，修改需删除后重新添加。
private struct MedicalRecordMedicineSection: View {
    let medicines: [UsersMedicinePlanDTO]
    let medicineFormDescription: (String) -> String
    let onAdd: () -> Void
    let onDelete: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                SectionHeader(title: "用药信息", icon: "pills.fill")
                Spacer()
                Button(action: onAdd) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("添加")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .appGlass(
                        Glass.regular.interactive().tint(Color.theme(.primary)),
                        in: Capsule()
                    ) {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.theme(.primary), Color.theme(.primary).opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: Color.theme(.primary).opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                }
            }
            .padding(.bottom, 5)

            if medicines.isEmpty {
                EmptyMedicineView(onAdd: onAdd)
            } else {
                VStack(spacing: 10) {
                    ForEach(medicines.indices, id: \.self) { index in
                        MedicalRecordMedicineRow(
                            medicine: medicines[index],
                            medicineFormDescription: medicineFormDescription,
                            onDelete: { onDelete(index) }
                        )
                    }
                }
                .cardStyle()
            }
        }
    }
}

private struct EmptyMedicineView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "pills.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(Color("text_secondary").opacity(0.3))

            Text("暂无用药信息")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color("text_secondary"))

            Text("添加本次就诊开具的药品，保存记录时会一并提交")
                .font(.system(size: 13))
                .foregroundColor(Color("text_secondary").opacity(0.7))

            Button(action: onAdd) {
                HStack(spacing: 6) {
                    Image(systemName: "pills.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("添加药品")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(Color.theme(.primary))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.theme(.primary).opacity(0.1))
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .cardStyle()
    }
}

private struct MedicalRecordMedicineRow: View {
    let medicine: UsersMedicinePlanDTO
    let medicineFormDescription: (String) -> String
    let onDelete: () -> Void

    private var formDescription: String {
        medicineFormDescription(medicine.medicineForm ?? "")
    }

    private var statusText: String {
        medicine.id == nil ? "待随本次就诊记录保存" : "已保存，仅可删除；如需修改请删除后重新添加"
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .frame(width: 56, height: 56)
                    .appGlass(
                        Glass.clear.interactive().tint(Color.theme(.primary).opacity(0.25)),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    ) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.theme(.primary).opacity(0.15), Color.theme(.primary).opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                Image(systemName: MedicineFormIcon.systemName(for: formDescription))
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(Color.theme(.primary))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(medicine.medicineName ?? "未命名药品")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color("text_primary"))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(formDescription)
                    Text("•")
                    Text(medicine.specificationString.isEmpty ? "未填写规格" : medicine.specificationString)
                }
                .font(.system(size: 13))
                .foregroundColor(Color("text_secondary"))

                Text(statusText)
                    .font(.system(size: 11))
                    .foregroundColor(medicine.id == nil ? Color.theme(.primary) : Color("text_secondary"))
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Color("text_secondary").opacity(0.5))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("background"))
        )
    }
}

// MARK: - 预览
#Preview {
    CreateMedicalRecordView()
}
