//
//  OcrRecognizeView.swift
//  QmHealth
//
//  Created by 周荥马 on 2026/8/17.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

// MARK: - 固定的 OCR 识别文案（写死，不做任何改动）
private let kOcrQuestion = """
不要做任何多余的动作和查询。识别这个图片，然后按照这个json格式输出，不存在的信息可以不输出，输出内容前后不允许带任何额外符号，只输出纯文本。其中指标编码，请获取系统中的指标编码'get_health_indicators'。如果指标不存在可以使用'add_health_indicator_config'补充健康指标。[{"isHealthIndicator":true,//是否是健康指标 "fileContyentType":"血常规报告单", "success":true,//是否识别成功"ocrInfo":{//ocr识别信息"date":"2026-12-12 12:00:00",//指标时间"hospitalName":"医院名称",//医院名称"doctorName":"医生名字",//医生名字 "name":"患者名字","data":[{"code":"height",//指标编码"name":"身高",//指标名称"value":"165",//身高"unit":"cm",//单位"normal":"参考范围",//参考范围"tag":""//指标状态}]}}]。指标状态"tag"取值仅限："正常"、"偏高"、"偏低"、"异常"、"检出"、"未检出"，无异常则为空字符串
"""

// MARK: - 图片附件模型
private struct OcrImageAttachment: Identifiable {
    let id: String
    let data: Data
    var fileId: String?
}

// MARK: - 图片预览 item（用于 fullScreenCover(item:) 驱动预览）
private struct OcrPreviewImageItem: Identifiable {
    let id: String
    let images: [UIImage]
    let initialIndex: Int
}

// MARK: - 可编辑的识别指标
private struct EditableOcrIndicator: Identifiable {
    let id: String
    // 所属报告在 results 中的下标（用于增删指标后仍能正确分组渲染）
    let reportIndex: Int
    var code: String
    var name: String
    var value: String
    var unit: String
    var normal: String
    var tag: String
    // 指标状态：0=未标记，1=正常，2=偏高，3=偏低，4=异常，5=检出，6=未检出（与后端 IndicatorStatus 对应）
    var status: Int16 = 0

    // 是否缺少指标编码（无法入库，需选择系统指标）
    var codeMissing: Bool {
        code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - 指标编码选择上下文（弹 sheet 选择指标时的用途）
private enum OcrIndicatorPickContext: Identifiable {
    case existing(itemId: String)   // 更换已有指标的编码
    case missing(itemId: String)    // 补选缺失编码的指标
    case new(reportIndex: Int)      // 新增指标

    var id: String {
        switch self {
        case .existing(let itemId): return "existing-\(itemId)"
        case .missing(let itemId): return "missing-\(itemId)"
        case .new(let reportIndex): return "new-\(reportIndex)"
        }
    }
}

// MARK: - OCR 识别页面
struct OcrRecognizeView: View {
    @Environment(\.dismiss) private var dismiss

    // 当前页面作用域的弹窗管理器（避免从 sheet 内部弹全局弹窗被遮挡到背后）
    private let subPopManager = SubPopManager()

    // 当前页面作用域的 PopManager，给 BgResultNetWork 使用，
    // 让网络错误弹窗显示在 sheet 内部而不是被 sheet 遮到背后。
    @StateObject private var popManager = PopManager()

    // 图片相关
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var imageAttachments: [OcrImageAttachment] = []
    @State private var isUploadingImages = false
    @State private var previewItem: OcrPreviewImageItem?
    // 已上传成功得到的文件 id（重试识别时复用，避免重复上传）
    @State private var uploadedFileIds: [String] = []

    // 识别相关
    @State private var isRecognizing = false
    @State private var isSaving = false
    @State private var results: [OcrRecognizeResultDTO] = []
    @State private var editableIndicators: [EditableOcrIndicator] = []
    @State private var showConfirmHint = false
    // 当前选中的报告 tab（用于多报告切换）
    @State private var selectedReportIndex = 0
    // 指标编码选择上下文（缺失补选 / 更换编码 / 新增指标）
    @State private var pickContext: OcrIndicatorPickContext?
    // 已通过「添加指标」成功添加过一次的报告下标（每个报告只允许添加一个）
    @State private var addedIndicatorReports: Set<Int> = []

    private let maxImageSelection = 9

    // 支持从外部预置待识别图片（复用组件时传入，如就诊记录的检查报告图片）
    // onUploadComplete：上传文件成功后回调，回调参数只包含与 initialImages 一一对应的 fileId，
    // 上层（CreateMedicalRecordView）拿到后可将这些文件标记为已上传，避免保存就诊记录时重复上传。
    init(initialImages: [Data] = [], onUploadComplete: (([String]) -> Void)? = nil) {
        self.initialImageCount = initialImages.count
        self.onUploadComplete = onUploadComplete
        if initialImages.isEmpty {
            _imageAttachments = State(initialValue: [])
        } else {
            _imageAttachments = State(initialValue: initialImages.map {
                OcrImageAttachment(id: ULIDUtils.generate(), data: $0)
            })
        }
    }

    /// 初始传入的图片数量（用于回调时只回传对应数量的 fileId，忽略用户在 sheet 内新加的图片）
    private let initialImageCount: Int
    /// 上传成功回调，用于上层把已上传的文件 id 关联到原始报告，避免重复上传
    private let onUploadComplete: (([String]) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "OCR识别")
                .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // 上传区域
                    subUploadArea

                    // 识别按钮
                    Button(action: {
                        startRecognize()
                    }) {
                        Text(canStartRecognize
                             ? (results.isEmpty ? "开始识别" : "重新识别")
                             : "请先上传图片")
                    }
                    .buttonStyle(ProcessingActionButtonStyle(
                        isLoading: isRecognizing,
                        tint: Color.theme(.primary),
                        cornerRadius: 24
                    ))
                    .disabled(!canStartRecognize || isUploadingImages)

                    // 识别过程动效
                    if isRecognizing {
                        RecognizingAnimationView()
                            .transition(.opacity)
                    }

                    // 结果展示
                    if !results.isEmpty {
                        subResultView
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(
                TapGesture(count: 1)
                    .onEnded { _ in hideKeyboard() }
            )
        }
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
                handleCameraPhoto(imageData: imageData)
            }
        }
        .fullScreenCover(item: $previewItem) { item in
            OcrImagePreviewView(images: item.images, initialIndex: item.initialIndex)
        }
        .sheet(item: $pickContext) { context in
            OcrIndicatorSelectView { meta in
                pickContext = nil
                handleIndicatorPicked(meta, context: context)
            }
        }
        .overlay {
            if isUploadingImages {
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
        }
        .withLocalSubPop(subPopManager)
        .withLocalPop(popManager)
    }

    // MARK: - 上传区域
    private var subUploadArea: some View {
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

            // 已选图片预览
            if !imageAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(imageAttachments.indices, id: \.self) { index in
                            if let image = UIImage(data: imageAttachments[index].data) {
                                ZStack(alignment: .topTrailing) {
                                    // 点击放大预览
                                    Button {
                                        let images = imageAttachments.compactMap { UIImage(data: $0.data) }
                                        guard !images.isEmpty else { return }
                                        // 取当前页所有图片，从当前这张开始
                                        previewItem = OcrPreviewImageItem(id: ULIDUtils.generate(), images: images, initialIndex: index)
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

                                    // 删除
                                    Button {
                                        imageAttachments.remove(at: index)
                                        // 图片集合变化，缓存的已上传文件 id 失效
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

            Text("支持相册选择或拍照，可上传一张或多张")
                .font(.system(size: 12))
                .foregroundStyle(Color("text_secondary"))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 结果展示
    private var subResultView: some View {
        VStack(spacing: 16) {
            // 确认提示
            confirmBanner

            // 多报告：tab 切换 + 当前报告提示
            if results.count > 1 {
                reportTabBar
                VStack(spacing: 4) {
                    Text("第 \(selectedReportIndex + 1) / \(results.count) 个报告")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color("text_secondary"))
                    Text("当前显示：\(reportTitle(for: selectedReportIndex))")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("text_secondary"))
                }
                .padding(.vertical, 2)
            }

            // 当前选中的报告卡片
            if results.indices.contains(selectedReportIndex) {
                reportCard(results[selectedReportIndex], reportIndex: selectedReportIndex)
            }

            // 确认保存按钮
            Button(action: {
                saveResults()
            }) {
                Text("确认保存")
            }
            .buttonStyle(ProcessingActionButtonStyle(
                isLoading: isSaving,
                tint: Color.theme(.primary),
                cornerRadius: 25
            ))
            .disabled(isSaving)
        }
    }

    // MARK: - 报告 tab 栏
    private var reportTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(results.indices, id: \.self) { index in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedReportIndex = index
                        }
                    }) {
                        HStack(spacing: 6) {
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .frame(width: 18, height: 18)
                                .background(
                                    Circle().fill(selectedReportIndex == index ? Color.white : Color.clear)
                                )
                                .foregroundStyle(selectedReportIndex == index ? Color.theme(.primary) : Color("text_secondary"))
                            Text(reportTitle(for: index))
                                .font(.system(size: 13, weight: selectedReportIndex == index ? .semibold : .regular))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .glassPillColor(.clear.interactive(), selectedReportIndex == index ? Color.theme(.primary) : nil)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - 确认提示横幅
    private var confirmBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundColor(Color("warning"))
            Text("请确认识别数据准确性，如有错误请直接修改")
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

    // MARK: - 单个报告卡片（含可编辑基本信息 + 可编辑指标列表）
    @ViewBuilder
    private func reportCard(_ result: OcrRecognizeResultDTO, reportIndex: Int) -> some View {
        VStack(spacing: 14) {
            reportHeader(result)

            // 指标区
            let indicators = editableIndicatorsFor(reportIndex: reportIndex)
            if !indicators.isEmpty {
                VStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.theme(.primary))
                        Text("检测指标")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color("text_primary"))
                        Spacer()
                        Text("\(indicators.count) 项")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color("text_secondary"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .glassPill(.clear.interactive())
                    }

                    ForEach(indicators) { item in
                        indicatorCard(item)
                    }
                }
            }

            // 添加指标（先弹 sheet 选择指标编码；每个报告最多添加一次，成功后禁用）
            let isIndicatorAdded = addedIndicatorReports.contains(reportIndex)
            Button(action: { pickContext = .new(reportIndex: reportIndex) }) {
                HStack(spacing: 6) {
                    if isIndicatorAdded {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                    }
                    Text(isIndicatorAdded ? "已成功添加" : "添加指标")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(isIndicatorAdded ? Color("text_secondary") : Color.theme(.primary))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .appGlass(.clear.tint(isIndicatorAdded ? AppColor.input.opacity(0.5) : Color.theme(.primary).opacity(0.12)),
                          in: RoundedRectangle(cornerRadius: 12, style: .continuous)) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isIndicatorAdded ? Color("input_bg") : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isIndicatorAdded ? Color.clear : Color.theme(.primary).opacity(0.5),
                                        style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        )
                }
            }
            .disabled(isIndicatorAdded)
        }
        .padding(16)
        .glassCardStyle(cornerRadius: 18)
    }

    // MARK: - 报告头部（报告类型 + 状态 + 可编辑基本信息）
    private func reportHeader(_ result: OcrRecognizeResultDTO) -> some View {
        VStack(spacing: 14) {
            // 报告类型 + 识别状态
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11)
                        .fill(
                            LinearGradient(
                                colors: [Color.theme(.primary), Color.theme(.secondary)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.fileContyentType ?? "识别报告")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color("text_primary"))
                    Text("基本信息")
                        .font(.system(size: 11))
                        .foregroundStyle(Color("text_secondary"))
                }

                Spacer()

                statusBadge(result)
            }

            Divider()

            // 可编辑基本信息
            VStack(spacing: 10) {
                editableInfoField(icon: "person.fill", label: "姓名", binding: infoBinding(result, \.name))
                editableInfoField(icon: "building.2.fill", label: "医院", binding: infoBinding(result, \.hospitalName))
                editableInfoField(icon: "stethoscope", label: "医生", binding: infoBinding(result, \.doctorName))
                editableDateField(icon: "calendar", label: "时间", result: result)
            }
        }
    }

    // MARK: - 识别状态标签
    @ViewBuilder
    private func statusBadge(_ result: OcrRecognizeResultDTO) -> some View {
        if result.success == true {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                Text("识别成功")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.green)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .glassPillColor(.clear.interactive(), Color.green.opacity(0.18))
        } else if result.success == false {
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                Text("识别失败")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Color("error"))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .glassPillColor(.clear.interactive(), Color("error").opacity(0.18))
        }
    }

    // MARK: - 可编辑信息行（图标 + 标签 + 输入框）
    private func editableInfoField(icon: String, label: String, binding: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Color.theme(.primary))
                .frame(width: 30, height: 30)
                .appGlass(.clear.tint(Color.theme(.primary).opacity(0.15)), in: Circle()) {
                    Circle().fill(Color.theme(.primary).opacity(0.1))
                }

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color("text_secondary"))
                .frame(width: 34, alignment: .leading)

            TextField(label, text: binding)
                .font(.system(size: 13))
                .foregroundStyle(Color("text_primary"))
                .textFieldStyle(.plain)
        }
        .inputFieldStyle()
    }

    // MARK: - 可编辑时间行（DatePicker，必填）
    private func editableDateField(icon: String, label: String, result: OcrRecognizeResultDTO) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Color.theme(.primary))
                .frame(width: 30, height: 30)
                .appGlass(.clear.tint(Color.theme(.primary).opacity(0.15)), in: Circle()) {
                    Circle().fill(Color.theme(.primary).opacity(0.1))
                }

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color("text_secondary"))
                .frame(width: 34, alignment: .leading)

            DatePicker("测量时间",
                       selection: dateBinding(result),
                       displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .datePickerStyle(.compact)
        }
        .inputFieldStyle()
    }

    // MARK: - 指标卡片（可编辑 + 可删除）
    private func indicatorCard(_ item: EditableOcrIndicator) -> some View {
        let iconInfo = getHealthIndicatorIcon(item.code)
        let hasTag = !item.tag.isEmpty

        return VStack(spacing: 12) {
            // 顶部：图标 + 名称/缺失提示 + 异常标记 + 删除
            HStack(spacing: 8) {
                Image(systemName: iconInfo.iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconInfo.color)
                    .frame(width: 30, height: 30)
                    .appGlass(.clear.tint(iconInfo.color.opacity(0.15)), in: Circle()) {
                        Circle().fill(iconInfo.color.opacity(0.12))
                    }

                if item.codeMissing {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("编码缺失")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color("error"))
                        Text("系统缺少该指标编码，无法添加")
                            .font(.system(size: 11))
                            .foregroundStyle(Color("text_secondary"))
                    }
                } else {
                    Text(item.name.isEmpty ? item.code : item.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color("text_primary"))
                        .lineLimit(1)
                }

                if !item.codeMissing && hasTag {
                    Text(item.tag)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color("warning"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .glassPillColor(.clear.interactive(), Color("warning").opacity(0.2))
                }

                Spacer(minLength: 0)

                Button(action: { deleteIndicator(item.id) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color("error"))
                        .frame(width: 28, height: 28)
                }
                .appGlass(.clear.tint(Color("error").opacity(0.15)), in: Circle()) {
                    Circle().fill(Color("error").opacity(0.08))
                }
            }

            if item.codeMissing {
                // 缺失编码：突出的选择按钮
                Button(action: { pickContext = .missing(itemId: item.id) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 14))
                        Text("选择系统指标编码")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle(tint: Color("error"), cornerRadius: 10, verticalPadding: 0))
                .frame(height: 38)
            } else {
                // 编码行（可更换）
                HStack(spacing: 8) {
                    Image(systemName: "number")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("text_secondary"))
                    Text("指标编码")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("text_secondary"))
                    Text(item.code)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color("text_primary"))
                    Spacer(minLength: 0)
                    Button(action: { pickContext = .existing(itemId: item.id) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.system(size: 10, weight: .semibold))
                            Text("更换")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(Color.theme(.primary))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    }
                    .glassPillColor(.clear.interactive(), Color.theme(.primary).opacity(0.18))
                }
            }

            // 数值 + 单位
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                TextField("数值", text: bindingFor(item.id, keyPath: \.value))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color("text_primary"))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .frame(minWidth: 64, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .appGlass(.regular.interactive(),
                              in: RoundedRectangle(cornerRadius: 10, style: .continuous)) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppColor.content.opacity(0.6))
                    }

                TextField("单位", text: bindingFor(item.id, keyPath: \.unit))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color("text_secondary"))
                    .textFieldStyle(.plain)
                    .frame(width: 64)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .glassPill(.regular.interactive())

                Spacer(minLength: 0)
            }

            // 参考范围
            HStack(spacing: 8) {
                Image(systemName: "scope")
                    .font(.system(size: 12))
                    .foregroundStyle(Color("text_secondary"))
                Text("参考范围")
                    .font(.system(size: 12))
                    .foregroundStyle(Color("text_secondary"))
                TextField("参考范围", text: bindingFor(item.id, keyPath: \.normal))
                    .font(.system(size: 12))
                    .foregroundStyle(Color("text_secondary"))
                    .textFieldStyle(.plain)
                Spacer(minLength: 0)
            }
            .inputFieldStyle()

            // 状态（可修改）
            statusRow(item)
        }
        .padding(14)
        .glassContainer(.regular.interactive(), cornerRadius: 14)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(item.codeMissing ? Color("error").opacity(0.7) : Color.clear, lineWidth: 1.2)
        )
    }

    // MARK: - 状态选择行
    private func statusRow(_ item: EditableOcrIndicator) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "stethoscope")
                .font(.system(size: 12))
                .foregroundStyle(Color("text_secondary"))
            Text("状态")
                .font(.system(size: 12))
                .foregroundStyle(Color("text_secondary"))
            Spacer(minLength: 0)
            Menu {
                Button("未标记") { setStatus(0, for: item.id) }
                Button("正常") { setStatus(1, for: item.id) }
                Button("偏高") { setStatus(2, for: item.id) }
                Button("偏低") { setStatus(3, for: item.id) }
                Button("异常") { setStatus(4, for: item.id) }
                Button("检出") { setStatus(5, for: item.id) }
                Button("未检出") { setStatus(6, for: item.id) }
            } label: {
                HStack(spacing: 6) {
                    if item.status != 0 {
                        Circle()
                            .fill(HealthStatus.getHealthStatus(indicatorStatus: item.status).color)
                            .frame(width: 8, height: 8)
                    }
                    Text(statusText(item.status))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(statusTextColor(item.status))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(Color("text_secondary"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
            }
            .glassPill(.regular.interactive())
        }
    }

    // 取某个报告对应的可编辑指标
    private func editableIndicatorsFor(reportIndex: Int) -> [EditableOcrIndicator] {
        editableIndicators.filter { $0.reportIndex == reportIndex }
    }

    // 报告标题（tab 展示用）
    private func reportTitle(for reportIndex: Int) -> String {
        guard results.indices.contains(reportIndex) else { return "报告\(reportIndex + 1)" }
        let title = results[reportIndex].fileContyentType ?? ""
        return title.isEmpty ? "报告\(reportIndex + 1)" : title
    }

    // 报告基本信息字段的编辑绑定（结果对象为引用类型，直接写回）
    private func infoBinding(_ result: OcrRecognizeResultDTO, _ keyPath: ReferenceWritableKeyPath<OcrRecognizeInfoDTO, String?>) -> Binding<String> {
        Binding(
            get: {
                guard let info = result.ocrInfo else { return "" }
                return info[keyPath: keyPath] ?? ""
            },
            set: { newValue in
                if result.ocrInfo == nil {
                    result.ocrInfo = OcrRecognizeInfoDTO()
                }
                result.ocrInfo?[keyPath: keyPath] = newValue
            }
        )
    }

    // 测量时间编辑绑定：未设置时显示当前时间，选择后写回报告的 date 字符串
    private func dateBinding(_ result: OcrRecognizeResultDTO) -> Binding<Date> {
        Binding(
            get: {
                result.ocrInfo?.date.flatMap { parseOcrDate($0) } ?? Date()
            },
            set: { date in
                if result.ocrInfo == nil {
                    result.ocrInfo = OcrRecognizeInfoDTO()
                }
                result.ocrInfo?.date = formatOcrDate(date)
            }
        )
    }

    // 从选择 sheet 回调：按上下文应用选中的指标
    private func handleIndicatorPicked(_ meta: HealthIndicatorMetaItem, context: OcrIndicatorPickContext) {
        guard let code = meta.indicatorCode, !code.isEmpty else { return }
        switch context {
        case .existing(let itemId), .missing(let itemId):
            if let index = editableIndicators.firstIndex(where: { $0.id == itemId }) {
                editableIndicators[index].code = code
                editableIndicators[index].name = meta.indicatorName ?? ""
                editableIndicators[index].unit = meta.unit ?? ""
            }
        case .new(let reportIndex):
            // 每个报告只允许添加一次，防止重复添加
            guard !addedIndicatorReports.contains(reportIndex) else { return }
            let newItem = EditableOcrIndicator(
                id: ULIDUtils.generate(),
                reportIndex: reportIndex,
                code: code,
                name: meta.indicatorName ?? "",
                value: "",
                unit: meta.unit ?? "",
                normal: "",
                tag: ""
            )
            editableIndicators.append(newItem)
            addedIndicatorReports.insert(reportIndex)
        }
    }

    // 状态文本（0 未标记，其余走 HealthStatus 枚举映射）
    private func statusText(_ status: Int16) -> String {
        guard status != 0 else { return "未标记" }
        return HealthStatus.getHealthStatus(indicatorStatus: status).text
    }

    // 状态文字颜色（未标记用次级色，其余跟随状态色）
    private func statusTextColor(_ status: Int16) -> Color {
        guard status != 0 else { return Color("text_secondary") }
        let healthStatus = HealthStatus.getHealthStatus(indicatorStatus: status)
        return healthStatus == .normal ? Color.green : healthStatus.textColor
    }

    // 更新状态并同步异常标记文案
    private func setStatus(_ value: Int16, for id: String) {
        guard let index = editableIndicators.firstIndex(where: { $0.id == id }) else { return }
        editableIndicators[index].status = value
        editableIndicators[index].tag = value == 0 ? "" : statusText(value)
    }

    // 删除单个指标
    private func deleteIndicator(_ id: String) {
        editableIndicators.removeAll { $0.id == id }
    }

    // 生成指标 TextField 的编辑绑定
    private func bindingFor(_ id: String, keyPath: WritableKeyPath<EditableOcrIndicator, String>) -> Binding<String> {
        Binding(
            get: {
                if let index = editableIndicators.firstIndex(where: { $0.id == id }) {
                    return editableIndicators[index][keyPath: keyPath]
                }
                return ""
            },
            set: { newValue in
                if let index = editableIndicators.firstIndex(where: { $0.id == id }) {
                    editableIndicators[index][keyPath: keyPath] = newValue
                }
            }
        )
    }

    // MARK: - 数据辅助

    private var hasUploadedFileIds: Bool {
        !uploadedFileIds.isEmpty
    }

    private var canStartRecognize: Bool {
        // 已有上传成功的文件 id（重试）可直接识别；否则需要有图片且未在上传
        (hasUploadedFileIds || !imageAttachments.isEmpty) && !isUploadingImages
    }

    // MARK: - 操作

    /// 使用当前页面的本地弹窗（SubPopManager）展示简单提示，
    /// 避免在 sheet 内部使用全局弹窗 PopManager.shared 被遮挡到页面背后。
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

    /// 批量保存 OCR 识别出的指标（复用 /api/users/healthindicator/add 接口）
    private func saveResults() {
        guard !isSaving else { return }
        guard !editableIndicators.isEmpty else {
            showLocalPop(title: "提示", description: "没有可保存的指标")
            return
        }

        let fileIds: [String]? = uploadedFileIds.isEmpty ? nil : uploadedFileIds

        // 缺失编码检查：有数值但无编码的项无法入库，需先选择系统指标
        if let missingItem = editableIndicators.first(where: { !$0.value.isEmpty && $0.codeMissing }) {
            let title = reportTitle(for: missingItem.reportIndex)
            showLocalPop(title: "指标编码缺失", description: "「\(title)」中有指标缺少系统编码，无法添加。请先为该指标选择系统指标编码")
            return
        }

        // 测量时间为必填：先收集各报告的有效时间，任一缺失则拦截提交
        var reportMeasureTimes: [Int: Date] = [:]
        for item in editableIndicators {
            guard !item.code.isEmpty, !item.value.isEmpty else { continue }
            guard reportMeasureTimes[item.reportIndex] == nil else { continue }
            let info = results.indices.contains(item.reportIndex) ? results[item.reportIndex].ocrInfo : nil
            guard let date = parseOcrDate(info?.date) else {
                let title = reportTitle(for: item.reportIndex)
                showLocalPop(title: "请填写测量时间", description: "「\(title)」缺少测量时间，请在基本信息中补充后再保存")
                return
            }
            reportMeasureTimes[item.reportIndex] = date
        }

        var params: [UsersHealthIndicatorAddParam] = []
        for item in editableIndicators {
            // 跳过没有编码或数值的空行
            guard !item.code.isEmpty, !item.value.isEmpty else { continue }
            let info: OcrRecognizeInfoDTO? = results.indices.contains(item.reportIndex) ? results[item.reportIndex].ocrInfo : nil
            let hospitalName: String? = {
                guard let raw = info?.hospitalName, !raw.isEmpty else { return nil }
                return raw
            }()
            params.append(UsersHealthIndicatorAddParam(
                indicatorCode: item.code,
                indicatorValue: item.value,
                referenceRange: item.normal.isEmpty ? nil : item.normal,
                indicatorStatus: item.status == 0 ? nil : item.status,
                hospitalName: hospitalName,
                measureTime: reportMeasureTimes[item.reportIndex] ?? Date(),
                fileId: fileIds,
                otherDesc: item.tag.isEmpty ? nil : item.tag
            ))
        }

        guard !params.isEmpty else {
            showLocalPop(title: "提示", description: "没有可保存的有效指标")
            return
        }

        isSaving = true
        BgResultNetWork<[UsersHealthIndicatorAddParam], [String]>.post(apiUrl(HEALTH_INDICATOR_ADD), params: params, popManager: popManager)
            .complicationHand { (res: [String]?) in
                DispatchQueue.main.async {
                    self.isSaving = false
                    self.showLocalPop(title: "保存成功", description: "已保存 \(params.count) 项指标")
                }
            }
            .errorHandle { _, _ in
                DispatchQueue.main.async {
                    self.isSaving = false
                    self.showLocalPop(title: "提示", description: "保存失败，请重试")
                }
            }
            .responseDecodable()
    }

    // 解析 OCR 返回的时间，兼容多种格式
    private func parseOcrDate(_ dateStr: String?) -> Date? {
        guard let dateStr, !dateStr.isEmpty else { return nil }
        let formats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd",
            "yyyy/M/d HH:mm:ss",
            "yyyy/M/d HH:mm",
            "yyyy/M/d",
        ]
        for format in formats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            if let date = formatter.date(from: dateStr) {
                return date
            }
        }
        return nil
    }

    // 将 Date 格式化为报告 date 字符串（与 JSON 编码策略一致）
    private func formatOcrDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    // OCR 异常标记映射为初始状态（与后端 IndicatorStatus 对应：1正常 2偏高 3偏低 4异常 5检出 6未检出）
    private func initialStatus(from tag: String) -> Int16 {
        if tag.contains("未检出") { return 6 }
        if tag.contains("偏低") || tag.contains("↓") { return 3 }
        if tag.contains("偏高") || tag.contains("↑") { return 2 }
        if tag.contains("检出") { return 5 }
        if tag.contains("异常") { return 4 }
        return 0
    }

    private func handleCameraPhoto(imageData: Data) {
        let attachment = OcrImageAttachment(id: ULIDUtils.generate(), data: imageData)
        imageAttachments.append(attachment)
        // 图片集合变化，缓存的已上传文件 id 失效
        uploadedFileIds = []
    }

    private func loadImages(items: [PhotosPickerItem]) {
        Task {
            var loaded: [OcrImageAttachment] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    loaded.append(OcrImageAttachment(id: ULIDUtils.generate(), data: data))
                }
            }
            DispatchQueue.main.async {
                self.imageAttachments.append(contentsOf: loaded)
                // 图片集合变化，缓存的已上传文件 id 失效
                self.uploadedFileIds = []
            }
        }
    }

    /// 分为两步：先上传图片获取文件 id，再识别。重试识别时复用已上传的文件 id，不再重复上传。
    private func startRecognize() {
        guard canStartRecognize else { return }

        // 已上传成功过：直接复用文件 id 识别，跳过上传
        if hasUploadedFileIds {
            recognize(fileIds: uploadedFileIds)
            return
        }

        isUploadingImages = true

        var files: [FileUploadInfo] = []
        files.reserveCapacity(imageAttachments.count)
        for attachment in imageAttachments {
            files.append(FileUploadInfo(data: attachment.data, fileName: "ocr_\(ULIDUtils.generate()).jpg", mimeType: "image/jpeg"))
        }

        BgResultNetWork<Empty, [FilesDTO]>.upload(apiUrl(FILE_UPLOAD), params: nil, popManager: popManager)
            .complicationHand { (result: [FilesDTO]?) in
                guard let uploaded = result, !uploaded.isEmpty else {
                    self.isUploadingImages = false
                    self.showLocalPop(title: "提示", description: "图片上传失败！")
                    return
                }
                let fileIds = uploaded.compactMap { $0.id }
                self.isUploadingImages = false
                self.uploadedFileIds = fileIds
                // 仅回传与初始传入图片一一对应的 fileId，避免上层把用户在 sheet 内新加图片的
                // fileId 错配到已有报告上。
                let initialFileIds = Array(fileIds.prefix(self.initialImageCount))
                DispatchQueue.main.async {
                    self.onUploadComplete?(initialFileIds)
                }
                self.recognize(fileIds: fileIds)
            }
            .errorHandle { _, _ in
                self.isUploadingImages = false
                self.showLocalPop(title: "提示", description: "图片上传失败！")
            }
            .upload(fileInfos: files)
    }

    /// 调用 OCR 接口
    private func recognize(fileIds: [String]) {
        guard !fileIds.isEmpty else { return }
        isRecognizing = true
        let param = OcrRecognizeParam(fileIds: fileIds, question: kOcrQuestion)

        // 后端 OCR 返回的是 JSON 字符串，所以这里 R 用 String，拿到后再二次解析（兼容数组 / 单个对象）
        BgResultNetWork<OcrRecognizeParam, String>.post(aiUrl(AI_CHAT_OCR), params: param, timeOutForRequest: 300, popManager: popManager)
            .complicationHand { (data: String?) in
                DispatchQueue.main.async {
                    self.isRecognizing = false
                    guard let jsonStr = data, !jsonStr.isEmpty else {
                        self.showLocalPop(title: "提示", description: "识别失败，请重试")
                        return
                    }
                    // 后端可能用 ```json ... ``` 代码围栏包裹返回，先去除再解析
                    let cleaned = OcrRecognizeView.stripMarkdownCodeFence(jsonStr)
                    // 兼容两种返回：多报告为数组，单报告为单个对象
                    let decoder = JSONFormatUtil.defaultInstall
                    var list: [OcrRecognizeResultDTO]? = try? decoder.decodeFromString(cleaned, as: [OcrRecognizeResultDTO].self)
                    if list == nil,
                        let single = try? decoder.decodeFromString(cleaned, as: OcrRecognizeResultDTO.self) {
                        list = [single]
                    }
                    if let list {
                        self.results = list
                        self.selectedReportIndex = 0
                        self.addedIndicatorReports = []
                        self.buidEditableIndicators(from: list)
                    } else {
                        self.results = []
                        self.editableIndicators = []
                        self.showLocalPop(title: "提示", description: "识别结果解析失败，请重试")
                    }
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

    /// 把结果数据转成可编辑数组
    private func buidEditableIndicators(from results: [OcrRecognizeResultDTO]) {
        var list: [EditableOcrIndicator] = []
        for (reportIndex, result) in results.enumerated() {
            if let data = result.ocrInfo?.data {
                for item in data {
                    let tag = item.tag ?? ""
                    list.append(EditableOcrIndicator(
                        id: ULIDUtils.generate(),
                        reportIndex: reportIndex,
                        code: item.code ?? "",
                        name: item.name ?? "",
                        value: item.value ?? "",
                        unit: item.unit ?? "",
                        normal: item.normal ?? "",
                        tag: tag,
                        status: initialStatus(from: tag)
                    ))
                }
            }
        }
        editableIndicators = list
    }

    /// 去除可能包裹 JSON 的 markdown 代码围栏（开头 ```json、结尾 ```）及首尾空白
    private static func stripMarkdownCodeFence(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // 去掉开头的 ``` 语言标记行（如 ```json）
        if text.hasPrefix("```") {
            if let firstLineEnd = text.firstIndex(of: "\n") {
                text = String(text[text.index(after: firstLineEnd)...])
            } else {
                text = text.replacingOccurrences(of: "```", with: "")
            }
        }
        // 去掉结尾的 ```
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasSuffix("```") {
            text = String(text.dropLast(3))
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - 识别过程动效
/// 模拟正在识别输出的过程动画：扫描线在报告上往复移动 + 三个跳动的小点 + 固定提示文案
struct RecognizingAnimationView: View {
    // 扫描线位置（0~1）
    @State private var scanProgress: CGFloat = 0
    // 小点透明度（跳动）
    @State private var dotOpacity: Double = 0.3

    var body: some View {
        VStack(spacing: 16) {
            // 报告图标 + 扫描线
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color("input_bg"))
                    .frame(width: 120, height: 120)

                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.theme(.primary).opacity(0.5))

                // 扫描线
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Color.clear, Color.theme(.primary).opacity(0.9), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: 120, height: 2)
                    .offset(y: -50 + scanProgress * 100)
            }
            .frame(width: 120, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .onAppear {
                withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
                    scanProgress = 1
                }
            }

            // 跳动小点 + 提示文案
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.theme(.primary))
                        .frame(width: 8, height: 8)
                        .opacity(index == 0 ? dotOpacity : 0.3)
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    dotOpacity = 1
                }
            }

            Text("正在识别报告单数据...")
                .font(.system(size: 13))
                .foregroundStyle(Color("text_secondary"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - 图片预览
/// 全屏预览上传的图片。多张图片时左右滑动翻页；单张放大后（scale > 1）可拖动查看细节、捏合缩放、双击放大/还原、旋转。
struct OcrImagePreviewView: View {
    let images: [UIImage]
    let initialIndex: Int

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    @State private var rotations: [Angle] = []

    init(images: [UIImage], initialIndex: Int = 0) {
        self.images = images
        self.initialIndex = initialIndex
        _currentIndex = State(initialValue: initialIndex)
        _rotations = State(initialValue: Array(repeating: .zero, count: images.count))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 多图分页；单图时无需 TabView
            if images.count > 1 {
                TabView(selection: $currentIndex) {
                    ForEach(images.indices, id: \.self) { index in
                        ZoomablePreviewImage(image: images[index], rotation: rotationBinding(for: index)) { dismiss() }
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            } else {
                ZoomablePreviewImage(image: images.first ?? UIImage(), rotation: rotationBinding(for: 0)) { dismiss() }
            }

            // 顶部操作栏（关闭 + 旋转，固定不随图片/翻页变化）
            VStack {
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                    }
                    .appGlass(.regular.interactive(), in: Circle()) {
                        Circle().fill(Color.white.opacity(0.18))
                    }

                    Spacer()

                    // 旋转当前图片 90°
                    Button {
                        let index = min(currentIndex, rotations.count - 1)
                        guard index >= 0 else { return }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            rotations[index] += .degrees(90)
                        }
                    } label: {
                        Image(systemName: "rotate.right")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                    }
                    .appGlass(.regular.interactive(), in: Circle()) {
                        Circle().fill(Color.white.opacity(0.18))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()
            }

            // 页码指示器
            if images.count > 1 {
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(images.indices, id: \.self) { index in
                            Circle()
                                .fill(index == currentIndex ? Color.white : Color.white.opacity(0.35))
                                .frame(width: 7, height: 7)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.5)))
                    .padding(.bottom, 24)
                }
            }
        }
    }

    // 按图片下标提供旋转状态的绑定（翻页后仍保留每页各自的旋转）
    private func rotationBinding(for index: Int) -> Binding<Angle> {
        Binding(
            get: {
                guard rotations.indices.contains(index) else { return .zero }
                return rotations[index]
            },
            set: { newValue in
                if rotations.indices.contains(index) {
                    rotations[index] = newValue
                }
            }
        )
    }
}

// MARK: - 可缩放/拖动的单张预览图
struct ZoomablePreviewImage: View {
    let image: UIImage
    // 旋转角度由父级持有（预览容器统一控制旋转按钮，翻页时不跟随每页闪换）
    @Binding var rotation: Angle
    let onSingleTap: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastMagnification: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            let containerSize = proxy.size
            // 图片在容器内 scaledToFit 后的基础尺寸（未缩放、未旋转）
            let displaySize = scaledFitSize(original: image.size, container: containerSize)

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .rotationEffect(rotation)
                .scaleEffect(scale)
                .offset(clamped(offset, container: containerSize, display: displaySize))
                // 放大后才可平移（未放大时交给分页滑动）；缩放与拖动组合为一个多指手势，避免相互串台
                .gesture(scale > 1.0 ? panAndZoomGesture(containerSize: containerSize, displaySize: displaySize) : nil)
                .contentShape(Rectangle())
                // 双击/单击手势只作用于图片自身，避免拦截旋转按钮
                .gesture(doubleTapGesture.exclusively(before: singleTapGesture))
        }
    }

    // 图片 fitted 到容器后的基础尺寸（保持宽高比）
    private func scaledFitSize(original: CGSize, container: CGSize) -> CGSize {
        guard original.width > 0, original.height > 0, container.width > 0, container.height > 0 else {
            return container
        }
        let widthRatio = container.width / original.width
        let heightRatio = container.height / original.height
        let scale = min(widthRatio, heightRatio)
        return CGSize(width: original.width * scale, height: original.height * scale)
    }

    // 旋转后的包围盒尺寸（对任意角度近似，90° 倍数精确）
    private func rotatedBoundingSize(displaySize: CGSize, scale: CGFloat, rotation: Angle) -> CGSize {
        let w = displaySize.width * scale
        let h = displaySize.height * scale
        let rad = rotation.radians
        let absSin = abs(sin(rad))
        let absCos = abs(cos(rad))
        return CGSize(
            width: w * absCos + h * absSin,
            height: w * absSin + h * absCos
        )
    }

    // 限制 offset，使图片包围盒不越出屏幕（图片边缘贴近屏幕边缘时无法继续拖出）
    private func clamped(_ proposed: CGSize, container: CGSize, display: CGSize) -> CGSize {
        let rotated = rotatedBoundingSize(displaySize: display, scale: scale, rotation: rotation)
        let maxX = max(0, (rotated.width - container.width) / 2)
        let maxY = max(0, (rotated.height - container.height) / 2)
        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }

    // 组合手势：捏合（锚点缩放）+ 拖动（越界钳制），同时响应且互不抢占
    private func panAndZoomGesture(containerSize: CGSize, displaySize: CGSize) -> some Gesture {
        MagnifyGesture()
            .simultaneously(with: DragGesture())
            .onChanged { value in
                if let magnify = value.first {
                    applyMagnification(magnify, container: containerSize, display: displaySize)
                }
                if let drag = value.second {
                    applyDrag(drag, container: containerSize, display: displaySize)
                }
            }
            .onEnded { _ in
                lastMagnification = 1.0
                lastOffset = offset
            }
    }

    // 锚点缩放：以两指起始点为缩放中心，同时修正 offset，保证捏合处内容不动
    private func applyMagnification(_ value: MagnifyGesture.Value, container: CGSize, display: CGSize) {
        let delta = value.magnification / lastMagnification
        lastMagnification = value.magnification

        let oldScale = scale
        scale = min(max(oldScale * delta, 1.0), 5.0)
        let effectiveDelta = scale / oldScale

        // 将手势起始锚点换算为相对容器中心的坐标
        let anchorPoint = CGPoint(
            x: (value.startAnchor.x - 0.5) * container.width,
            y: (value.startAnchor.y - 0.5) * container.height
        )
        let newOffset = CGSize(
            width: anchorPoint.x - effectiveDelta * (anchorPoint.x - offset.width),
            height: anchorPoint.y - effectiveDelta * (anchorPoint.y - offset.height)
        )
        offset = clamped(newOffset, container: container, display: display)
        lastOffset = offset
    }

    // 单指拖动（带边缘约束）
    private func applyDrag(_ value: DragGesture.Value, container: CGSize, display: CGSize) {
        let proposed = CGSize(
            width: lastOffset.width + value.translation.width,
            height: lastOffset.height + value.translation.height
        )
        offset = clamped(proposed, container: container, display: display)
    }

    // 双击放大/还原（还原时同时复位旋转与位移）
    private var doubleTapGesture: some Gesture {
        TapGesture(count: 2).onEnded {
            withAnimation(.spring(response: 0.3)) {
                if scale > 1.0 {
                    scale = 1.0
                    offset = .zero
                    lastOffset = .zero
                    rotation = .zero
                } else {
                    scale = 2.0
                }
            }
        }
    }

    // 单击关闭预览：仅未放大时生效（放大态单指用于看细节，不应退出）
    private var singleTapGesture: some Gesture {
        scale > 1.0 ? nil : TapGesture().onEnded { onSingleTap() }
    }
}
