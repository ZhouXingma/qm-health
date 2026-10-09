import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - 报告文件相关组件

// 报告文件区域
struct ReportFilesSection: View {
    @Binding var reportFiles: [ReportFile]
    let onAddImage: () -> Void
    let onAddFile: () -> Void
    let onViewReport: (Int) -> Void
    let onEditReport: (Int) -> Void
    // OCR 识别回调（传入后，当存在图片报告时显示「OCR识别」按钮；仅识别图片）
    var onOcrRecognize: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                SectionHeader(title: "检查报告", icon: "doc.text.fill")

                Spacer()

                if onOcrRecognize != nil, reportFiles.contains(where: { $0.type == .image }) {
                    Button(action: { onOcrRecognize?() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "text.viewfinder")
                                .font(.system(size: 15, weight: .semibold))
                            Text("OCR识别")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(Color.theme(.primary))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(Color.theme(.primary).opacity(0.1))
                        )
                        .overlay(
                            Capsule().stroke(Color.theme(.primary).opacity(0.4), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Menu {
                    Button(action: onAddImage) {
                        Label("选择图片", systemImage: "photo")
                    }
                    
                    Button(action: onAddFile) {
                        Label("选择PDF", systemImage: "doc.fill")
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("添加")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [Color.theme(.primary), Color.theme(.primary).opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: Color.theme(.primary).opacity(0.3), radius: 6, x: 0, y: 3)
                }
            }.padding(.bottom, 5)
            
            if reportFiles.isEmpty {
                EmptyReportView(onAddImage: onAddImage, onAddFile: onAddFile)
            } else {
                VStack(spacing: 10) {
                    ForEach(reportFiles.indices, id: \.self) { index in
                        ReportFileRow(
                            reportFile: reportFiles[index],
                            onView: { onViewReport(index) },
                            onEdit: { onEditReport(index) },
                            onDelete: { reportFiles.remove(at: index) }
                        )
                    }
                }
                .cardStyle()
            }
        }
    }
}

// 空报告视图
struct EmptyReportView: View {
    let onAddImage: () -> Void
    let onAddFile: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.image")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(Color("text_secondary").opacity(0.3))
            
            Text("暂无检查报告")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color("text_secondary"))
            
            Text("支持添加图片或PDF格式的报告")
                .font(.system(size: 13))
                .foregroundColor(Color("text_secondary").opacity(0.7))
            
            HStack(spacing: 12) {
                Button(action: onAddImage) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo")
                            .font(.system(size: 14, weight: .semibold))
                        Text("选择图片")
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
                
                Button(action: onAddFile) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("选择PDF")
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
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .cardStyle()
    }
}

// 报告文件项行
struct ReportFileRow: View {
    let reportFile: ReportFile
    let onView: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onView) {
            HStack(spacing: 14) {
                // 文件图标或缩略图
                ReportFileThumbnail(reportFile: reportFile)
                
                VStack(alignment: .leading, spacing: 6) {
                    // 显示名称（可编辑）
                    Text(reportFile.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color("text_primary"))
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: reportFile.type == .image ? "photo" : "doc")
                                .font(.system(size: 11))
                            Text(reportFile.type == .image ? "图片" : "PDF")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(Color("text_secondary"))
                        
                        if let size = reportFile.size {
                            Text("•")
                                .font(.system(size: 13))
                                .foregroundColor(Color("text_secondary"))
                            
                            Text(formatFileSize(size))
                                .font(.system(size: 13))
                                .foregroundColor(Color("text_secondary"))
                        }
                    }
                }
                
                Spacer()
                
                // 编辑按钮
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color.theme(.primary).opacity(0.7))
                }
                .buttonStyle(PlainButtonStyle())
                
                // 删除按钮
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
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// 报告文件缩略图
struct ReportFileThumbnail: View {
    let reportFile: ReportFile
    
    var body: some View {
        Group {
            if reportFile.type == .image, let image = reportFile.thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.theme(.primary).opacity(0.15), Color.theme(.primary).opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: reportFile.type == .image ? "photo.fill" : "doc.text.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(Color.theme(.primary))
                }
            }
        }
    }
}

// MARK: - 文件选择器

// 图片选择器
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var reportFiles: [ReportFile]
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 0 // 允许多选
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            
            for result in results {
                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                    if let image = object as? UIImage {
                        DispatchQueue.main.async {
                            let reportFile = ReportFile(
                                name: "图片报告_\(Date().formatted(date: .numeric, time: .shortened))",
                                displayName: "图片报告_\(Date().formatted(date: .numeric, time: .shortened))",
                                type: .image,
                                thumbnail: image,
                                size: nil
                            )
                            self?.parent.reportFiles.append(reportFile)
                        }
                    }
                }
            }
        }
    }
}

// PDF文档选择器
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var reportFiles: [ReportFile]
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.dismiss()
            
            for url in urls {
                // 获取文件大小
                let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64
                
                let reportFile = ReportFile(
                    name: url.lastPathComponent,
                    displayName: url.deletingPathExtension().lastPathComponent,
                    type: .pdf,
                    url: url,
                    size: fileSize
                )
                parent.reportFiles.append(reportFile)
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}

// MARK: - 编辑报告名称视图
struct EditReportNameView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var reportFile: ReportFile
    @State private var editedName: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                Color("background").ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // 文件预览
                    ReportFilePreview(reportFile: reportFile)
                    
                    // 编辑区域
                    ReportNameEditor(editedName: $editedName, isTextFieldFocused: $isTextFieldFocused)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
            .navigationTitle("编辑报告名称")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        reportFile.displayName = editedName.isEmpty ? reportFile.name : editedName
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(editedName.isEmpty)
                }
            }
            .onAppear {
                editedName = reportFile.displayName
                isTextFieldFocused = true
            }
        }
    }
}

// 报告文件预览
struct ReportFilePreview: View {
    let reportFile: ReportFile
    
    var body: some View {
        VStack(spacing: 16) {
            Group {
                if reportFile.type == .image, let image = reportFile.thumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [Color.theme(.primary).opacity(0.2), Color.theme(.primary).opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 48, weight: .medium))
                            .foregroundColor(Color.theme(.primary))
                    }
                }
            }
            
            VStack(spacing: 4) {
                Text("原始文件名")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text_secondary"))
                
                Text(reportFile.name)
                    .font(.system(size: 14))
                    .foregroundColor(Color("text_primary"))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 20)
    }
}

// 报告名称编辑器
struct ReportNameEditor: View {
    @Binding var editedName: String
    @FocusState.Binding var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("报告名称")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color("text_primary"))
                
                Spacer()
                
                Text("\(editedName.count)/50")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text_secondary"))
            }
            
            TextField("请输入报告名称", text: $editedName)
                .font(.system(size: 15))
                .padding(14)
                .appGlass(.regular.interactive(), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .focused($isTextFieldFocused)
                .onChange(of: editedName) { newValue in
                    if newValue.count > 50 {
                        editedName = String(newValue.prefix(50))
                    }
                }
            
            // 快捷选项
            VStack(alignment: .leading, spacing: 8) {
                Text("常用名称")
                    .font(.system(size: 13))
                    .foregroundColor(Color("text_secondary"))
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["血常规", "尿常规", "心电图", "B超检查", "CT报告", "核磁共振", "X光片"], id: \.self) { name in
                            Button(action: {
                                editedName = name
                            }) {
                                Text(name)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.theme(.primary))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.theme(.primary).opacity(0.1))
                                    )
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .cardStyle()
    }
}
