//
//  CameraView.swift
//  QmHealth
//
//  Created by Kiro on 2026/3/13.
//

import SwiftUI
import AVFoundation
import Photos

// MARK: - 主相机视图

struct CameraView: View {
    @Binding var isPresented: Bool
    var onPhotoTaken: ((Data) -> Void)?
    
    @StateObject private var cameraManager = CameraManager()
    @State private var capturedImage: UIImage?
    @State private var showingImagePreview = false
    @State private var showingPermissionAlert = false
    @State private var isFlashOn = false
    @State private var showingAspectRatioSelector = false
    @State private var showingCropView = false
    @State private var showingMosaicView = false
    @State private var editingImage: UIImage?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if cameraManager.isAuthorized {
                if showingCropView, let image = editingImage {
                    ImageCropEditor(
                        image: image,
                        onComplete: { croppedImage in
                            capturedImage = croppedImage
                            editingImage = croppedImage
                            showingCropView = false
                        },
                        onCancel: {
                            showingCropView = false
                        }
                    )
                    .transition(.move(edge: .trailing))
                } else if showingMosaicView, let image = editingImage {
                    ImageMosaicEditor(
                        image: image,
                        onComplete: { mosaicImage in
                            capturedImage = mosaicImage
                            editingImage = mosaicImage
                            showingMosaicView = false
                        },
                        onCancel: {
                            showingMosaicView = false
                        }
                    )
                    .transition(.move(edge: .trailing))
                } else if showingImagePreview, let image = capturedImage {
                    PhotoPreviewView(
                        image: image,
                        onCancel: {
                            isPresented = false
                        },
                        onRetake: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingImagePreview = false
                                capturedImage = nil
                            }
                            cameraManager.startSession()
                        },
                        onCrop: {
                            editingImage = image
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingCropView = true
                            }
                        },
                        onMosaic: {
                            editingImage = image
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingMosaicView = true
                            }
                        },
                        onConfirm: {
                            if let imageData = image.jpegData(compressionQuality: 0.8) {
                                saveToPhotoLibrary(image: image)
                                onPhotoTaken?(imageData)
                            }
                            isPresented = false
                        }
                    )
                } else {
                    CameraCapturingView(
                        cameraManager: cameraManager,
                        isFlashOn: $isFlashOn,
                        showingAspectRatioSelector: $showingAspectRatioSelector,
                        onClose: {
                            isPresented = false
                        },
                        onCapture: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            
                            cameraManager.capturePhoto { image in
                                if let image = image {
                                    capturedImage = image
                                    editingImage = image
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showingImagePreview = true
                                    }
                                    cameraManager.stopSession()
                                }
                            }
                        }
                    )
                }
            } else {
                PermissionRequestView(
                    onRequestPermission: {
                        cameraManager.requestPermission { granted in
                            if !granted {
                                showingPermissionAlert = true
                            }
                        }
                    },
                    onCancel: {
                        isPresented = false
                    }
                )
            }
        }
        .ignoresSafeArea(.all)
        .onAppear {
            cameraManager.checkPermission()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .alert("相机权限", isPresented: $showingPermissionAlert) {
            Button("设置") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("取消", role: .cancel) {
                isPresented = false
            }
        } message: {
            Text("请在设置中允许访问相机权限")
        }
    }
    
    private func saveToPhotoLibrary(image: UIImage) {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
            }
        }
    }
}

// MARK: - 相机拍照界面

struct CameraCapturingView: View {
    @ObservedObject var cameraManager: CameraManager
    @Binding var isFlashOn: Bool
    @Binding var showingAspectRatioSelector: Bool
    let onClose: () -> Void
    let onCapture: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 相机预览（使用 UIKit 实现，支持手势）
                CameraPreviewContainer(cameraManager: cameraManager)
                    .ignoresSafeArea()
                
                // 遮罩层
                CameraOverlayView(
                    cameraManager: cameraManager,
                    containerSize: geometry.size
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
                
                // 控制层
                VStack(spacing: 0) {
                    CameraTopBar(
                        isFlashOn: $isFlashOn,
                        currentAspectRatio: cameraManager.currentAspectRatio,
                        zoomFactor: cameraManager.zoomFactor,
                        onClose: onClose,
                        onFlashToggle: {
                            isFlashOn.toggle()
                        },
                        onSwitchCamera: {
                            cameraManager.switchCamera()
                        },
                        onAspectRatioTap: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingAspectRatioSelector.toggle()
                            }
                        }
                    )
                    
                    Spacer()
                    
                    if showingAspectRatioSelector {
                        AspectRatioSelectorView(
                            currentRatio: cameraManager.currentAspectRatio,
                            onRatioSelected: { ratio in
                                cameraManager.setAspectRatio(ratio)
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showingAspectRatioSelector = false
                                }
                            }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        Button(action: onCapture) {
                            ZStack {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 70, height: 70)
                                
                                Circle()
                                    .stroke(.white, lineWidth: 4)
                                    .frame(width: 80, height: 80)
                            }
                        }
                        .buttonStyle(CaptureButtonStyle())
                        
                        Spacer()
                    }
                    .padding(.bottom, 50)
                }
            }
        }
    }
}

// MARK: - 相机预览容器（UIKit）

struct CameraPreviewContainer: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView(cameraManager: cameraManager)
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.updateLayout()
    }
}

class CameraPreviewUIView: UIView {
    let cameraManager: CameraManager
    var lastZoomScale: CGFloat = 1.0
    
    init(cameraManager: CameraManager) {
        self.cameraManager = cameraManager
        super.init(frame: .zero)
        
        backgroundColor = .black
        
        // 添加预览层
        let previewLayer = cameraManager.previewLayer
        layer.addSublayer(previewLayer)
        
        // 添加捏合手势
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        addGestureRecognizer(pinchGesture)
        
        // 启动相机
        DispatchQueue.main.async {
            self.cameraManager.startSession()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayout()
    }
    
    func updateLayout() {
        cameraManager.previewLayer.frame = bounds
    }
    
    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            lastZoomScale = cameraManager.zoomFactor
        case .changed:
            let newZoom = lastZoomScale * gesture.scale
            cameraManager.setZoomFactor(newZoom)
        case .ended, .cancelled, .failed:
            lastZoomScale = cameraManager.zoomFactor
        default:
            break
        }
    }
}

// MARK: - 相机遮罩层

struct CameraOverlayView: View {
    @ObservedObject var cameraManager: CameraManager
    let containerSize: CGSize
    
    var body: some View {
        GeometryReader { geometry in
            let maskFrame = calculateMaskFrame(in: geometry.size)
            
            if cameraManager.currentAspectRatio != .fullscreen {
                // 只显示四角标记
                CornerMarks(frame: maskFrame)
            }
        }
        .onAppear {
            updateMaskRect()
        }
        .onChange(of: cameraManager.currentAspectRatio) { _ in
            updateMaskRect()
        }
    }
    
    private func calculateMaskFrame(in containerSize: CGSize) -> CGRect {
        guard cameraManager.currentAspectRatio != .fullscreen else {
            return CGRect(origin: .zero, size: containerSize)
        }
        
        let targetRatio = cameraManager.currentAspectRatio.ratio
        let containerRatio = containerSize.width / containerSize.height
        
        var maskSize: CGSize
        
        if targetRatio > containerRatio {
            maskSize = CGSize(
                width: containerSize.width,
                height: containerSize.width / targetRatio
            )
        } else {
            maskSize = CGSize(
                width: containerSize.height * targetRatio,
                height: containerSize.height
            )
        }
        
        let origin = CGPoint(
            x: (containerSize.width - maskSize.width) / 2,
            y: (containerSize.height - maskSize.height) / 2
        )
        
        return CGRect(origin: origin, size: maskSize)
    }
    
    private func updateMaskRect() {
        let maskFrame = calculateMaskFrame(in: containerSize)
        cameraManager.maskRect = maskFrame
    }
}

// MARK: - 四角标记

struct CornerMarks: View {
    let frame: CGRect
    let cornerLength: CGFloat = 25
    let cornerWidth: CGFloat = 3
    
    var body: some View {
        ZStack {
            // 左上
            Path { path in
                path.move(to: CGPoint(x: frame.minX, y: frame.minY + cornerLength))
                path.addLine(to: CGPoint(x: frame.minX, y: frame.minY))
                path.addLine(to: CGPoint(x: frame.minX + cornerLength, y: frame.minY))
            }
            .stroke(Color.white, lineWidth: cornerWidth)
            
            // 右上
            Path { path in
                path.move(to: CGPoint(x: frame.maxX, y: frame.minY + cornerLength))
                path.addLine(to: CGPoint(x: frame.maxX, y: frame.minY))
                path.addLine(to: CGPoint(x: frame.maxX - cornerLength, y: frame.minY))
            }
            .stroke(Color.white, lineWidth: cornerWidth)
            
            // 左下
            Path { path in
                path.move(to: CGPoint(x: frame.minX, y: frame.maxY - cornerLength))
                path.addLine(to: CGPoint(x: frame.minX, y: frame.maxY))
                path.addLine(to: CGPoint(x: frame.minX + cornerLength, y: frame.maxY))
            }
            .stroke(Color.white, lineWidth: cornerWidth)
            
            // 右下
            Path { path in
                path.move(to: CGPoint(x: frame.maxX, y: frame.maxY - cornerLength))
                path.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY))
                path.addLine(to: CGPoint(x: frame.maxX - cornerLength, y: frame.maxY))
            }
            .stroke(Color.white, lineWidth: cornerWidth)
        }
    }
}

// MARK: - 顶部控制栏

struct CameraTopBar: View {
    @Binding var isFlashOn: Bool
    let currentAspectRatio: PhotoAspectRatio
    let zoomFactor: CGFloat
    let onClose: () -> Void
    let onFlashToggle: () -> Void
    let onSwitchCamera: () -> Void
    let onAspectRatioTap: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.black.opacity(0.5)))
                }
                
                Spacer()
                
                Button(action: onAspectRatioTap) {
                    Text(currentAspectRatio.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.black.opacity(0.5)))
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button(action: onSwitchCamera) {
                        Image(systemName: "camera.rotate")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.black.opacity(0.5)))
                    }
                    
                    Button(action: onFlashToggle) {
                        Image(systemName: isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(isFlashOn ? .yellow : .white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.black.opacity(0.5)))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            
            // 缩放指示器
            if zoomFactor > 1.0 {
                Text(String(format: "%.1fx", zoomFactor))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.black.opacity(0.5)))
                    .transition(.opacity)
            }
        }
    }
}

// MARK: - 比例选择器

struct AspectRatioSelectorView: View {
    let currentRatio: PhotoAspectRatio
    let onRatioSelected: (PhotoAspectRatio) -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            ForEach(PhotoAspectRatio.allCases, id: \.self) { ratio in
                Button(action: { onRatioSelected(ratio) }) {
                    VStack(spacing: 4) {
                        RatioIconView(ratio: ratio)
                            .frame(width: 32, height: 32)
                            .foregroundColor(currentRatio == ratio ? .yellow : .white)
                        
                        Text(ratio.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(currentRatio == ratio ? .yellow : .white.opacity(0.8))
                    }
                }
                .buttonStyle(PressButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Capsule().fill(.black.opacity(0.5)))
    }
}

// MARK: - 比例图标

struct RatioIconView: View {
    let ratio: PhotoAspectRatio
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .stroke(lineWidth: 2)
                .aspectRatio(iconAspectRatio, contentMode: .fit)
        }
    }
    
    private var iconAspectRatio: CGFloat {
        switch ratio {
        case .square:
            return 1.0
        case .standard:
            return 3.0/4.0
        case .widescreen:
            return 9.0/16.0
        case .fullscreen:
            return 9.0/16.0
        }
    }
}

// MARK: - 照片预览视图

struct PhotoPreviewView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onRetake: () -> Void
    let onCrop: () -> Void
    let onMosaic: () -> Void
    let onConfirm: () -> Void
    
    @State private var imageScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 顶部控制栏
                HStack {
                    Button(action: onCancel) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                            Text("取消")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.black.opacity(0.5)))
                    }
                    
                    Spacer()
                    
                    Button(action: onRetake) {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.rotate")
                                .font(.system(size: 14, weight: .semibold))
                            Text("重拍")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.black.opacity(0.5)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 10)
                .background(Color.black)
                
                // 图片显示区域（中间可滚动区域）
                GeometryReader { imageGeometry in
                    ZStack {
                        Color.black
                        
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(imageScale)
                            .offset(imageOffset)
                            .gesture(
                                SimultaneousGesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            imageScale = max(1.0, min(value, 3.0))
                                        }
                                        .onEnded { _ in
                                            if imageScale <= 1.0 {
                                                withAnimation(.spring()) {
                                                    imageScale = 1.0
                                                    imageOffset = .zero
                                                    lastOffset = .zero
                                                }
                                            }
                                        },
                                    DragGesture()
                                        .onChanged { value in
                                            if imageScale > 1.0 {
                                                let newOffset = CGSize(
                                                    width: lastOffset.width + value.translation.width,
                                                    height: lastOffset.height + value.translation.height
                                                )
                                                
                                                // 计算图片实际尺寸
                                                let imageSize = calculateImageSize(in: imageGeometry.size)
                                                let scaledImageSize = CGSize(
                                                    width: imageSize.width * imageScale,
                                                    height: imageSize.height * imageScale
                                                )
                                                
                                                // 计算最大允许偏移
                                                let maxOffsetX = max(0, (scaledImageSize.width - imageGeometry.size.width) / 2)
                                                let maxOffsetY = max(0, (scaledImageSize.height - imageGeometry.size.height) / 2)
                                                
                                                // 限制偏移范围
                                                imageOffset = CGSize(
                                                    width: max(-maxOffsetX, min(maxOffsetX, newOffset.width)),
                                                    height: max(-maxOffsetY, min(maxOffsetY, newOffset.height))
                                                )
                                            }
                                        }
                                        .onEnded { _ in
                                            lastOffset = imageOffset
                                            if imageScale <= 1.0 {
                                                withAnimation(.spring()) {
                                                    imageOffset = .zero
                                                    lastOffset = .zero
                                                }
                                            }
                                        }
                                )
                            )
                            .onTapGesture(count: 2) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    if imageScale > 1.0 {
                                        imageScale = 1.0
                                        imageOffset = .zero
                                        lastOffset = .zero
                                    } else {
                                        imageScale = 2.0
                                    }
                                }
                            }
                    }
                    .clipped() // 关键：裁剪超出区域的内容
                }
                
                // 底部编辑工具栏
                VStack(spacing: 20) {
                    // 提示文字
                    Text("双击缩放图片")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                    
                    // 编辑工具按钮
                    HStack(spacing: 50) {
                        PhotoEditButton(
                            icon: "crop",
                            title: "裁剪",
                            action: onCrop
                        )
                        
                        PhotoEditButton(
                            icon: "mosaic",
                            title: "马赛克",
                            action: onMosaic
                        )
                    }
                    
                    // 确认按钮
                    Button(action: onConfirm) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .bold))
                            Text("确认使用")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(RoundedRectangle(cornerRadius: 25).fill(Color.green))
                    }
                    .padding(.horizontal, 40)
                    .buttonStyle(PressButtonStyle())
                }
                .padding(.top, 10)
                .padding(.bottom, 50)
                .background(Color.black)
            }
            .background(Color.black)
        }
        .ignoresSafeArea()
    }
    
    // 计算图片在容器中的实际尺寸
    private func calculateImageSize(in containerSize: CGSize) -> CGSize {
        let imageAspectRatio = image.size.width / image.size.height
        let containerAspectRatio = containerSize.width / containerSize.height
        
        if imageAspectRatio > containerAspectRatio {
            // 图片更宽，以宽度为准
            let width = containerSize.width
            let height = width / imageAspectRatio
            return CGSize(width: width, height: height)
        } else {
            // 图片更高，以高度为准
            let height = containerSize.height
            let width = height * imageAspectRatio
            return CGSize(width: width, height: height)
        }
    }
}

// MARK: - 照片编辑按钮

struct PhotoEditButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(.black.opacity(0.5))
                        .frame(width: 52, height: 52)
                    
                    if icon == "mosaic" {
                        MosaicIcon()
                            .frame(width: 22, height: 22)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PressButtonStyle())
    }
}

// MARK: - 马赛克图标

struct MosaicIcon: View {
    var body: some View {
        VStack(spacing: 1.5) {
            HStack(spacing: 1.5) {
                Rectangle().frame(width: 4, height: 4)
                Rectangle().frame(width: 4, height: 4)
                Rectangle().frame(width: 4, height: 4)
                Rectangle().frame(width: 4, height: 4)
            }
            HStack(spacing: 1.5) {
                Rectangle().frame(width: 4, height: 4)
                Rectangle().frame(width: 4, height: 4)
                Rectangle().frame(width: 4, height: 4)
                Rectangle().frame(width: 4, height: 4)
            }
            HStack(spacing: 1.5) {
                Rectangle().frame(width: 4, height: 4)
                Rectangle().frame(width: 4, height: 4)
                Rectangle().frame(width: 4, height: 4)
                Rectangle().frame(width: 4, height: 4)
            }
        }
    }
}

// MARK: - 权限请求视图

struct PermissionRequestView: View {
    let onRequestPermission: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 40) {
            HStack {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.black.opacity(0.5)))
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            
            Spacer()
            
            VStack(spacing: 40) {
                ZStack {
                    Circle()
                        .fill(.black.opacity(0.3))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "camera.fill")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 16) {
                    Text("需要相机权限")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("请允许访问相机以拍摄照片")
                        .font(.system(size: 17))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                VStack(spacing: 16) {
                    Button(action: onRequestPermission) {
                        HStack {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("允许访问相机")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(RoundedRectangle(cornerRadius: 28).fill(.white))
                    }
                    .buttonStyle(PressButtonStyle())
                    
                    Button(action: onCancel) {
                        Text("暂不允许")
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(PressButtonStyle())
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
}

// MARK: - 按钮样式

struct CaptureButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct PressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var isPresented = true
    CameraView(isPresented: $isPresented) { imageData in
        print("照片已拍摄，大小：\(imageData.count) bytes")
    }
}
