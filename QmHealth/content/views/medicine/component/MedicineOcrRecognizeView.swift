//
//  MedicineOcrRecognizeView.swift
//  QmHealth
//  用药信息 OCR 识别（通用组件）
//

import SwiftUI
import PhotosUI
import UIKit

// MARK: - 用药信息 OCR 识别
/// 复用场景：
/// - 用药计划页：`saveMode = .directPlan`，识别结果由组件直接调用用药计划接口保存。
/// - 就诊记录：`saveMode = .draft`，识别结果仅回传给调用方，随就诊记录一起提交。
struct MedicineOcrRecognizeView: View {
    enum SaveMode {
        /// 直接保存为用药计划
        case directPlan
        /// 仅回传草稿，不调用保存接口
        case draft

        var actionTitle: String {
            switch self {
            case .directPlan: return "保存用药计划"
            case .draft: return "加入就诊用药"
            }
        }
    }

    let saveMode: SaveMode
    /// 完成回调：直接保存模式回传已保存计划（含服务端 id），草稿模式回传待提交计划。
    let onCompleted: ([UsersMedicinePlanDTO]) -> Void

    @Environment(\.dismiss) private var dismiss

    // 当前页面作用域的弹窗，避免在 sheet 内使用全局弹窗被遮挡到背后。
    private let subPopManager = SubPopManager()
    @StateObject private var popManager = PopManager()

    // 表单值域与剂型默认剂量单位
    @State private var valueScopes: [String: ValueScopeInfo] = [:]
    @State private var medicineFormUnits: [String: [String]] = [:]

    // 图片
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var imageAttachments: [MedicineOcrImageAttachment] = []
    @State private var previewItem: MedicineOcrPreviewItem?
    @State private var uploadedFileIds: [String] = []
    @State private var isUploadingImages = false

    // 识别与保存
    @State private var isRecognizing = false
    @State private var isSaving = false
    @State private var recognizedMedicines: [EditableOcrMedicine] = []
    @State private var editingMedicine: EditableOcrMedicine?

    private let maxImageSelection = 9

    init(
        saveMode: SaveMode,
        initialImages: [Data] = [],
        onCompleted: @escaping ([UsersMedicinePlanDTO]) -> Void
    ) {
        self.saveMode = saveMode
        self.onCompleted = onCompleted
        _imageAttachments = State(initialValue: initialImages.map {
            MedicineOcrImageAttachment(id: ULIDUtils.generate(), data: $0)
        })
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "用药识别")
                .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    uploadArea
                    recognizeButton

                    if isRecognizing {
                        RecognizingAnimationView(title: "正在识别用药信息...")
                            .transition(.opacity)
                    }

                    if !recognizedMedicines.isEmpty {
                        resultSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(TapGesture().onEnded { hideKeyboard() })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("background"))
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .photosPicker(
            isPresented: $showImagePicker,
            selection: $selectedPhotoItems,
            maxSelectionCount: maxImageSelection,
            matching: .images
        )
        .onChange(of: selectedPhotoItems) { _, newValue in
            let items = Array(newValue)
            selectedPhotoItems = []
            guard !items.isEmpty else { return }
            loadImages(items: items)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(isPresented: $showCamera) { imageData in
                imageAttachments.append(MedicineOcrImageAttachment(
                    id: ULIDUtils.generate(),
                    data: imageData
                ))
                uploadedFileIds = []
            }
        }
        .fullScreenCover(item: $previewItem) { item in
            OcrImagePreviewView(images: item.images, initialIndex: item.initialIndex)
        }
        .sheet(item: $editingMedicine) { item in
            AddMedicinePlanView(
                valueScopes: $valueScopes,
                medicineFormUnits: $medicineFormUnits,
                onSaved: { _ in },
                editingPlan: item.plan,
                onDraftSaved: { updated in
                    if let index = recognizedMedicines.firstIndex(where: { $0.id == item.id }) {
                        recognizedMedicines[index].plan = updated
                    }
                },
                headerTitle: "编辑识别用药",
                submitTitle: "确定"
            )
        }
        .overlay {
            if isUploadingImages {
                uploadingOverlay
            }
        }
        .onAppear {
            loadValueScopes()
            loadMedicineFormUnits()
        }
        .withLocalSubPop(subPopManager)
        .withLocalPop(popManager)
    }

    // MARK: - 上传区域
    private var uploadArea: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Button(action: { showImagePicker = true }) {
                    VStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 22))
                            .foregroundColor(Color.theme(.primary))
                        Text("相册")
                            .font(.system(size: 12))
                            .foregroundStyle(Color("text_secondary"))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                }
                .glassContainer(.regular.interactive(), cornerRadius: AppRadius.medium)

                Button(action: { showCamera = true }) {
                    VStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color.theme(.primary))
                        Text("拍照")
                            .font(.system(size: 12))
                            .foregroundStyle(Color("text_secondary"))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                }
                .glassContainer(.regular.interactive(), cornerRadius: AppRadius.medium)
            }

            if !imageAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(imageAttachments.indices, id: \.self) { index in
                            if let image = UIImage(data: imageAttachments[index].data) {
                                ZStack(alignment: .topTrailing) {
                                    Button {
                                        let images = imageAttachments.compactMap { UIImage(data: $0.data) }
                                        guard !images.isEmpty else { return }
                                        previewItem = MedicineOcrPreviewItem(
                                            id: ULIDUtils.generate(),
                                            images: images,
                                            initialIndex: index
                                        )
                                    } label: {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 68, height: 68)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        imageAttachments.remove(at: index)
                                        uploadedFileIds = []
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(Color.white)
                                            .padding(6)
                                    }
                                    .buttonStyle(.plain)
                                    .appGlass(.regular.interactive(), in: Circle()) {
                                        Circle().fill(Color.black.opacity(0.75))
                                    }
                                    .offset(x: 10, y: -10)
                                }
                                .padding(.top, 6)
                                .padding(.trailing, 6)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }

            Text("支持处方单、药店小票、药盒、药袋或用药医嘱截图")
                .font(.system(size: 12))
                .foregroundStyle(Color("text_secondary"))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 识别按钮
    private var recognizeButton: some View {
        Button(action: startRecognize) {
            Text(canStartRecognize
                 ? (recognizedMedicines.isEmpty ? "开始识别" : "重新识别")
                 : "请先上传图片")
        }
        .buttonStyle(ProcessingActionButtonStyle(
            isLoading: isRecognizing,
            tint: Color.theme(.primary),
            cornerRadius: 24
        ))
        .disabled(!canStartRecognize || isUploadingImages)
    }

    // MARK: - 识别结果
    private var resultSection: some View {
        VStack(spacing: 14) {
            confirmBanner

            HStack(spacing: 8) {
                Text("识别到 \(recognizedMedicines.count) 种药品")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))
                Spacer()
                Text("点击卡片可修改")
                    .font(.system(size: 12))
                    .foregroundStyle(Color("text_secondary"))
            }

            ForEach(recognizedMedicines) { item in
                medicineCard(item)
            }

            Button(action: save) {
                Text(isSaving ? "保存中…" : "\(saveMode.actionTitle)（\(recognizedMedicines.count)）")
            }
            .buttonStyle(ProcessingActionButtonStyle(
                isLoading: isSaving,
                tint: Color.theme(.primary),
                cornerRadius: 25
            ))
            .disabled(isSaving)
            .padding(.top, 2)
        }
    }

    private var confirmBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundColor(Color("warning"))
            Text("请确认识别结果，点击药品可修改剂量、频次与日期")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color("text_primary"))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .appGlass(.clear.tint(Color("warning").opacity(0.15)),
                  in: RoundedRectangle(cornerRadius: 12, style: .continuous)) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color("warning").opacity(0.12))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color("warning").opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - 单个药品卡片
    private func medicineCard(_ item: EditableOcrMedicine) -> some View {
        let plan = item.plan
        let chips = scheduleChips(plan)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
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

                    Image(systemName: MedicineFormIcon.systemName(for: plan.medicineForm.flatMap {
                        valueScopes["medicineForm"]?.desc(forValue: $0)
                    }))
                        .font(.system(size: 19))
                        .foregroundStyle(Color.theme(.primary))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.medicineName ?? "未命名药品")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color("text_primary"))
                        .lineLimit(1)

                    Text(subtitle(plan))
                        .font(.system(size: 12))
                        .foregroundStyle(Color("text_secondary"))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    Image(systemName: "pencil")
                        .font(.system(size: 10, weight: .semibold))
                    Text("编辑")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color.theme(.primary))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .glassPillColor(.clear.interactive(), Color.theme(.primary).opacity(0.15))
            }
            .contentShape(Rectangle())
            .onTapGesture { editingMedicine = item }

            if !chips.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 6) {
                        Image(systemName: plan.frequencyTypeEnum?.icon ?? "repeat")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.theme(.primary))
                        Text(scheduleTitle(plan))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color("text_primary"))
                    }

                    HFlow(alignment: .top, itemSpacing: 6, rowSpacing: 6) {
                        ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                            Text(chip)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color("text_secondary"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color("input_bg"))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            if let advice = plan.medicalAdvice, !advice.isEmpty {
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

            Divider().overlay(Color("divider"))

            HStack(spacing: 12) {
                LabelTag(icon: "calendar", text: periodText(plan))

                if let source = plan.sourceTypeEnum {
                    LabelTag(icon: "tag", text: source.displayName)
                }

                Spacer(minLength: 6)

                Button {
                    remove(item.id)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                        Text("移除")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Color("error"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                }
                .glassPillColor(.clear.interactive(), Color("error").opacity(0.12))
            }
        }
        .cardStyle()
    }

    // MARK: - 上传中的遮罩
    private var uploadingOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.black.opacity(0.12))
                .appGlass(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous)) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(0.12))
                }
            VStack(spacing: 8) {
                ProgressView()
                Text("图片上传中...")
                    .font(.system(size: 13))
                    .foregroundStyle(Color("text_primary"))
            }
        }
    }

    // MARK: - 展示辅助
    private func subtitle(_ plan: UsersMedicinePlanDTO) -> String {
        var parts: [String] = []
        if let form = plan.medicineForm,
           let description = valueScopes["medicineForm"]?.desc(forValue: form) {
            parts.append(description)
        }
        if !plan.specificationString.isEmpty {
            parts.append(plan.specificationString)
        }
        return parts.isEmpty ? "未识别剂型与规格" : parts.joined(separator: " · ")
    }

    private func scheduleTitle(_ plan: UsersMedicinePlanDTO) -> String {
        let label = plan.frequencyType.flatMap {
            valueScopes["medicineFrequencyType"]?.desc(forValue: "\($0)")
        } ?? ""

        switch plan.frequencyTypeEnum {
        case .daily:
            return label.isEmpty ? "每天" : label
        case .cyclic:
            let unit = plan.takingInfo?.cycleUnit == 2 ? "周" : "天"
            let use = plan.takingInfo?.cycleUseTimes ?? 1
            let stop = plan.takingInfo?.cycleStopTimes ?? 1
            return "服\(use)\(unit)停\(stop)\(unit)"
        case .weekly:
            let days = plan.takingInfo?.weeklyDays.map(\.label) ?? []
            return days.isEmpty ? "每周特定日" : days.joined(separator: "、")
        case .interval:
            return "每隔\(plan.takingInfo?.intervalDays ?? 2)天"
        case .asNeeded:
            return label.isEmpty ? "按需服用" : label
        case .none:
            return "暂无服药安排"
        }
    }

    private func scheduleChips(_ plan: UsersMedicinePlanDTO) -> [String] {
        guard let info = plan.takingInfo else { return [] }
        switch plan.frequencyTypeEnum {
        case .daily, .cyclic, .interval:
            return (info.times ?? []).map(chipText)
        case .weekly:
            return info.weeklyDays.flatMap { day in
                day.times.map { "\(day.label) \(chipText($0))" }
            }
        case .asNeeded, .none:
            return []
        }
    }

    private func chipText(_ dose: DoseTime) -> String {
        "\(dose.time) · \(Self.doseAmountText(dose.doseAmount))\(dose.doseUnit)"
    }

    private func periodText(_ plan: UsersMedicinePlanDTO) -> String {
        let start = plan.startDate ?? "--"
        let end = plan.endDate?.isEmpty == false ? plan.endDate! : "长期"
        return "\(start) 至 \(end)"
    }

    private static func doseAmountText(_ amount: Double) -> String {
        amount == amount.rounded() ? String(Int(amount)) : String(amount)
    }

    // MARK: - 状态
    private var canStartRecognize: Bool {
        (!imageAttachments.isEmpty || !uploadedFileIds.isEmpty) && !isUploadingImages
    }

    // MARK: - 图片处理
    private func loadImages(items: [PhotosPickerItem]) {
        Task {
            var loaded: [MedicineOcrImageAttachment] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    loaded.append(MedicineOcrImageAttachment(id: ULIDUtils.generate(), data: data))
                }
            }
            DispatchQueue.main.async {
                self.imageAttachments.append(contentsOf: loaded)
                self.uploadedFileIds = []
            }
        }
    }

    // MARK: - 识别
    private func startRecognize() {
        guard canStartRecognize else { return }

        if !uploadedFileIds.isEmpty {
            recognize(fileIds: uploadedFileIds)
            return
        }

        isUploadingImages = true
        let files = imageAttachments.map {
            FileUploadInfo(
                data: $0.data,
                fileName: "medicine_ocr_\(ULIDUtils.generate()).jpg",
                mimeType: "image/jpeg"
            )
        }

        BgResultNetWork<Empty, [FilesDTO]>.upload(apiUrl(FILE_UPLOAD), params: nil, popManager: popManager)
            .complicationHand { (result: [FilesDTO]?) in
                DispatchQueue.main.async {
                    guard let uploaded = result, !uploaded.isEmpty else {
                        self.isUploadingImages = false
                        self.showLocalPop(title: "提示", description: "图片上传失败，请重试")
                        return
                    }
                    let fileIds = uploaded.compactMap { $0.id }
                    self.isUploadingImages = false
                    self.uploadedFileIds = fileIds
                    self.recognize(fileIds: fileIds)
                }
            }
            .errorHandle { _, _ in
                DispatchQueue.main.async {
                    self.isUploadingImages = false
                    self.showLocalPop(title: "提示", description: "图片上传失败，请重试")
                }
            }
            .upload(fileInfos: files)
    }

    private func recognize(fileIds: [String]) {
        guard !fileIds.isEmpty else { return }
        isRecognizing = true

        let param = OcrRecognizeParam(fileIds: fileIds, question: kMedicineOcrQuestion)
        BgResultNetWork<OcrRecognizeParam, String>.post(
            aiUrl(AI_CHAT_OCR),
            params: param,
            timeOutForRequest: 300,
            popManager: popManager
        )
        .complicationHand { (data: String?) in
            DispatchQueue.main.async {
                self.isRecognizing = false
                guard let jsonStr = data, !jsonStr.isEmpty else {
                    self.showLocalPop(title: "提示", description: "识别失败，请重试")
                    return
                }
                self.applyRecognitionResult(jsonStr)
            }
        }
        .errorHandle { _, _ in
            DispatchQueue.main.async {
                self.isRecognizing = false
                self.showLocalPop(title: "提示", description: "识别失败，请重试")
            }
        }
        .responseDecodable()
    }

    private func applyRecognitionResult(_ raw: String) {
        let cleaned = MedicineOcrParser.stripCodeFence(raw)
        let decoder = JSONFormatUtil.defaultInstall

        var items: [MedicineOcrItemDTO]?
        if let list = try? decoder.decodeFromString(cleaned, as: [MedicineOcrItemDTO].self) {
            items = list
        } else if let single = try? decoder.decodeFromString(cleaned, as: MedicineOcrItemDTO.self) {
            items = [single]
        }

        guard let items else {
            showLocalPop(title: "提示", description: "识别结果解析失败，请重试")
            return
        }

        let plans = items.compactMap {
            $0.asMedicinePlan(valueScopes: valueScopes, medicineFormUnits: medicineFormUnits)
        }

        guard !plans.isEmpty else {
            showLocalPop(title: "提示", description: "未识别到用药信息，请换一张更清晰的图片")
            return
        }

        recognizedMedicines = plans.map { EditableOcrMedicine(plan: $0) }
    }

    // MARK: - 保存
    private func save() {
        guard !isSaving else { return }
        let plans = recognizedMedicines.map(\.plan)
        guard !plans.isEmpty else {
            showLocalPop(title: "提示", description: "没有可保存的用药信息")
            return
        }

        switch saveMode {
        case .draft:
            onCompleted(plans)
            dismiss()
        case .directPlan:
            savePlansToServer(plans)
        }
    }

    /// 直接保存模式：逐个调用用药计划新增接口，全部结束后统一回调。
    private func savePlansToServer(_ plans: [UsersMedicinePlanDTO]) {
        isSaving = true
        var saved: [UsersMedicinePlanDTO] = []
        var failed: [UsersMedicinePlanDTO] = []
        var remaining = plans.count

        func finish() {
            isSaving = false
            if failed.isEmpty {
                onCompleted(saved)
                dismiss()
            } else {
                recognizedMedicines = failed.map { EditableOcrMedicine(plan: $0) }
                showLocalPop(
                    title: "保存未完成",
                    description: "已保存 \(saved.count) 个，\(failed.count) 个失败，请重试"
                )
            }
        }

        for plan in plans {
            BgResultNetWork<UsersMedicinePlanDTO, String>.post(
                apiUrl(MEDICINE_PLAN_ADD),
                params: plan,
                popManager: popManager
            )
            .complicationHand { (planId: String?) in
                DispatchQueue.main.async {
                    var savedPlan = plan
                    savedPlan.id = planId
                    saved.append(savedPlan)
                    remaining -= 1
                    if remaining == 0 { finish() }
                }
            }
            .errorHandle { _, _ in
                DispatchQueue.main.async {
                    failed.append(plan)
                    remaining -= 1
                    if remaining == 0 { finish() }
                }
            }
            .responseDecodable()
        }
    }

    // MARK: - 值域
    private func loadValueScopes() {
        guard valueScopes.isEmpty else { return }
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
                valueScopes = data
            }
        }
        .responseDecodable()
    }

    private func loadMedicineFormUnits() {
        guard medicineFormUnits.isEmpty else { return }
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

    // MARK: - 提示与删除
    private func remove(_ id: String) {
        recognizedMedicines.removeAll { $0.id == id }
    }

    private func showLocalPop(title: String, description: String) {
        subPopManager.showCustomSubPopWithHeight(height: 220, customAction: {}) {
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(Color("warning"))
                    .padding(.top, 12)
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color("text_primary"))
                Text(description)
                    .font(.system(size: 14))
                    .foregroundStyle(Color("text_secondary"))
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - 本地辅助类型
private struct MedicineOcrImageAttachment: Identifiable {
    let id: String
    let data: Data
}

private struct MedicineOcrPreviewItem: Identifiable {
    let id: String
    let images: [UIImage]
    let initialIndex: Int
}

private struct EditableOcrMedicine: Identifiable {
    let id = ULIDUtils.generate()
    var plan: UsersMedicinePlanDTO
}
