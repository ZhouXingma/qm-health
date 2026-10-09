//
//  CameraManager.swift
//  QmHealth
//
//  Created by Kiro on 2026/3/13.
//

import AVFoundation
import UIKit
import Combine

enum PhotoAspectRatio: String, CaseIterable {
    case square = "1:1"
    case standard = "4:3"
    case widescreen = "16:9"
    case fullscreen = "全屏"
    
    var displayName: String {
        return rawValue
    }
    
    var ratio: CGFloat {
        switch self {
        case .square:
            return 1.0
        case .standard:
            return 3.0/4.0
        case .widescreen:
            return 9.0/16.0
        case .fullscreen:
            return 0
        }
    }
}

class CameraManager: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var isSessionRunning = false
    @Published var currentAspectRatio: PhotoAspectRatio = .standard
    @Published var zoomFactor: CGFloat = 1.0
    
    private let captureSession = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private var photoCaptureCompletion: ((UIImage?) -> Void)?
    
    // 用于存储遮罩区域，确保拍照时裁剪正确
    var maskRect: CGRect = .zero
    
    lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()
    
    override init() {
        super.init()
        setupCaptureSession()
    }
    
    // MARK: - 权限管理
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            requestPermission { granted in
                DispatchQueue.main.async {
                    self.isAuthorized = granted
                }
            }
        case .denied, .restricted:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                completion(granted)
            }
        }
    }
    
    // MARK: - 会话管理
    
    private func setupCaptureSession() {
        captureSession.sessionPreset = .photo
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoDeviceInput) else {
            return
        }
        
        captureSession.addInput(videoDeviceInput)
        self.videoDeviceInput = videoDeviceInput
        
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
            if #available(iOS 16.0, *) {
                photoOutput.maxPhotoDimensions = CMVideoDimensions(width: 4032, height: 3024)
            } else {
                photoOutput.isHighResolutionCaptureEnabled = true
            }
        }
    }
    
    func startSession() {
        guard !isSessionRunning else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = self.captureSession.isRunning
            }
        }
    }
    
    func stopSession() {
        guard isSessionRunning else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = self.captureSession.isRunning
            }
        }
    }
    
    // MARK: - 缩放
    
    func setZoomFactor(_ factor: CGFloat) {
        guard let device = videoDeviceInput?.device else { return }
        
        let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 5.0)
        let newZoom = max(1.0, min(factor, maxZoom))
        
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = newZoom
            device.unlockForConfiguration()
            
            DispatchQueue.main.async {
                self.zoomFactor = newZoom
            }
        } catch {
            print("无法设置缩放: \(error)")
        }
    }
    
    // MARK: - 比例管理
    
    func setAspectRatio(_ ratio: PhotoAspectRatio) {
        currentAspectRatio = ratio
    }
    
    // MARK: - 拍照功能
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        var settings = AVCapturePhotoSettings()
        
        if #available(iOS 11.0, *) {
            if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            }
        }
        
        if #available(iOS 16.0, *) {
            settings.maxPhotoDimensions = CMVideoDimensions(width: 4032, height: 3024)
        } else {
            settings.isHighResolutionPhotoEnabled = true
        }
        
        if let videoDevice = videoDeviceInput?.device,
           videoDevice.hasFlash {
            settings.flashMode = .auto
        }
        
        photoCaptureCompletion = completion
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // MARK: - 相机切换
    
    func switchCamera() {
        guard let currentInput = videoDeviceInput else { return }
        
        captureSession.beginConfiguration()
        captureSession.removeInput(currentInput)
        
        let currentPosition = currentInput.device.position
        let newPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
        
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
              let newInput = try? AVCaptureDeviceInput(device: newDevice),
              captureSession.canAddInput(newInput) else {
            captureSession.addInput(currentInput)
            captureSession.commitConfiguration()
            return
        }
        
        captureSession.addInput(newInput)
        videoDeviceInput = newInput
        
        // 重置缩放
        zoomFactor = 1.0
        
        captureSession.commitConfiguration()
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer { photoCaptureCompletion = nil }
        
        if let error = error {
            print("拍照错误: \(error)")
            photoCaptureCompletion?(nil)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              var image = UIImage(data: imageData) else {
            photoCaptureCompletion?(nil)
            return
        }
        
        // 修正图片方向
        image = image.fixedOrientation()
        
        // 根据比例裁剪 - 使用存储的遮罩区域
        let croppedImage = cropImageBasedOnMask(image)
        photoCaptureCompletion?(croppedImage)
    }
    
    private func cropImageBasedOnMask(_ image: UIImage) -> UIImage {
        guard currentAspectRatio != .fullscreen else { return image }
        
        // 获取预览层的实际显示区域
        let previewLayerBounds = previewLayer.bounds
        
        // 计算遮罩在预览层中的相对位置
        let maskInPreview = maskRect
        
        // 将预览层坐标转换为图片坐标
        let imageSize = image.size
        
        // 计算预览层中实际显示的图片区域（考虑 resizeAspectFill）
        let previewAspect = previewLayerBounds.width / previewLayerBounds.height
        let imageAspect = imageSize.width / imageSize.height
        
        var visibleImageSize: CGSize
        var visibleImageOrigin: CGPoint
        
        if imageAspect > previewAspect {
            // 图片更宽，上下填满，左右裁剪
            visibleImageSize = CGSize(
                width: imageSize.height * previewAspect,
                height: imageSize.height
            )
            visibleImageOrigin = CGPoint(
                x: (imageSize.width - visibleImageSize.width) / 2,
                y: 0
            )
        } else {
            // 图片更高，左右填满，上下裁剪
            visibleImageSize = CGSize(
                width: imageSize.width,
                height: imageSize.width / previewAspect
            )
            visibleImageOrigin = CGPoint(
                x: 0,
                y: (imageSize.height - visibleImageSize.height) / 2
            )
        }
        
        // 计算遮罩在图片中的位置
        let scaleX = visibleImageSize.width / previewLayerBounds.width
        let scaleY = visibleImageSize.height / previewLayerBounds.height
        
        let cropRect = CGRect(
            x: visibleImageOrigin.x + maskInPreview.origin.x * scaleX,
            y: visibleImageOrigin.y + maskInPreview.origin.y * scaleY,
            width: maskInPreview.width * scaleX,
            height: maskInPreview.height * scaleY
        )
        
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            return image
        }
        
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

// MARK: - UIImage Extension

extension UIImage {
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up {
            return self
        }
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? self
    }
}
