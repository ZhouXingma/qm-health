import SwiftUI
import PDFKit

// MARK: - 报告文件查看器

struct ReportFileViewer: View {
    @Environment(\.dismiss) var dismiss
    let reportFiles: [ReportFile]
    let initialIndex: Int

    @State private var currentIndex: Int
    @State private var isLoadingPDF = false
    @State private var pdfData: Data?
    @State private var rotations: [Angle] = []

    init(reportFiles: [ReportFile], initialIndex: Int) {
        self.reportFiles = reportFiles
        self.initialIndex = initialIndex
        _currentIndex = State(initialValue: initialIndex)
        _rotations = State(initialValue: Array(repeating: .zero, count: reportFiles.count))
    }

    private var currentFile: ReportFile {
        reportFiles[currentIndex]
    }

    var body: some View {
        NavigationView {
            ZStack {
                // 与 OCR 预览一致：沉浸式黑色背景
                Color.black.ignoresSafeArea()

                // 主内容区域
                TabView(selection: $currentIndex) {
                    ForEach(reportFiles.indices, id: \.self) { index in
                        ReportContentView(
                            reportFile: reportFiles[index],
                            pdfData: index == currentIndex ? $pdfData : .constant(nil),
                            isLoadingPDF: index == currentIndex ? $isLoadingPDF : .constant(false),
                            rotation: rotationBinding(for: index)
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: currentIndex) { newIndex in
                    // 加载新的 PDF（如果需要）
                    if reportFiles[newIndex].type == .pdf {
                        loadPDFData(for: reportFiles[newIndex])
                    }
                }

                // 底部指示器和文件名
                ReportViewerBottomIndicator(
                    currentFile: currentFile,
                    currentIndex: currentIndex,
                    totalCount: reportFiles.count
                )
            }
            .navigationTitle("\(currentIndex + 1) / \(reportFiles.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }

                // 旋转当前图片（仅图片文件显示）
                ToolbarItem(placement: .primaryAction) {
                    if currentFile.type == .image {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                rotations[currentIndex] += .degrees(90)
                            }
                        } label: {
                            Image(systemName: "rotate.right")
                        }
                    }
                }
            }
        }
        .onAppear {
            if currentFile.type == .pdf && pdfData == nil {
                loadPDFData(for: currentFile)
            }
        }
    }

    // 按文件下标提供旋转状态绑定（翻页后保留每页各自的旋转）
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
    
    private func loadPDFData(for reportFile: ReportFile) {
        guard reportFile.type == .pdf else { return }
        
        // 重置 PDF 数据
        pdfData = nil
        
        guard let fileId = reportFile.uploadedFileId else {
            // 本地 PDF 文件
            if let url = reportFile.url {
                pdfData = try? Data(contentsOf: url)
            }
            return
        }
        
        // 从服务器下载 PDF
        isLoadingPDF = true
        let urlString = apiUrl(FILE_LOAD) + "/\(fileId)"
        
        BgResultNetWork<Empty, Data>(urlString, method: .get)
            .complicationHand { (data: Data?) in
                DispatchQueue.main.async {
                    self.pdfData = data
                    self.isLoadingPDF = false
                }
            }
            .errorHandle { (result, error) in
                DispatchQueue.main.async {
                    self.isLoadingPDF = false
                    print("下载 PDF 失败: \(error)")
                }
            }
            .response()
    }
}

// 报告内容视图（单个文件）
struct ReportContentView: View {
    let reportFile: ReportFile
    @Binding var pdfData: Data?
    @Binding var isLoadingPDF: Bool
    @Binding var rotation: Angle

    var body: some View {
        Group {
            if reportFile.type == .image {
                // 图片查看器（复用 OCR 的交互：未放大禁拖动、放大后可拖动/缩放/双击）
                if let image = reportFile.thumbnail {
                    ZoomablePreviewImage(image: image, rotation: $rotation, onSingleTap: {})
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.white.opacity(0.5))

                        Text("无法加载图片")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                // PDF 查看器
                PDFViewer(reportFile: reportFile, pdfData: $pdfData, isLoading: $isLoadingPDF)
            }
        }
    }
}

// 底部指示器
struct ReportViewerBottomIndicator: View {
    let currentFile: ReportFile
    let currentIndex: Int
    let totalCount: Int
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 12) {
                // 文件名
                Text(currentFile.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.7))
                    )
                
                // 页码指示器
                if totalCount > 1 {
                    HStack(spacing: 8) {
                        ForEach(0..<totalCount, id: \.self) { index in
                            Circle()
                                .fill(index == currentIndex ? Color.white : Color.white.opacity(0.4))
                                .frame(width: 8, height: 8)
                                .animation(.easeInOut(duration: 0.2), value: currentIndex)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.7))
                    )
                }
            }
            .padding(.bottom, 40)
        }
    }
}

// PDF 查看器
struct PDFViewer: View {
    let reportFile: ReportFile
    @Binding var pdfData: Data?
    @Binding var isLoading: Bool
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text("加载中...")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                }
            } else if let data = pdfData {
                PDFKitView(data: data)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("无法加载 PDF")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                    
                    if reportFile.uploadedFileId != nil {
                        Text("请检查网络连接")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
        }
    }
}

// PDFKit 视图包装器
struct PDFKitView: UIViewRepresentable {
    let data: Data
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        if let document = PDFDocument(data: data) {
            pdfView.document = document
        }
    }
}
