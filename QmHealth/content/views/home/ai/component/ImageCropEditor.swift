//
//  ImageCropEditor.swift
//  QmHealth
//
//  图片裁剪编辑器（重构版）
//
// MARK: - 设计说明
// 旧版实现同时对图片做 scale / offset / rotation 变换，再把裁剪框反算回图片坐标，
// 数学链路长、误差大，且手势互相抢占，体验很差。
//
// 新版的思路是「图片固定、裁剪框可动」：
// 1. 图片以 aspectFit 固定显示在画布中（displayRect），不做缩放和位移；
// 2. 裁剪框以归一化坐标（相对 displayRect 的 0...1 矩形）保存，与屏幕尺寸无关，
//    旋转屏幕、切换比例都不会错位；
// 3. 单一 DragGesture 根据按下位置判断操作的控制点（四角 / 四边 / 整体移动），
//    避免多个手势互相冲突；
// 4. 输出时直接把归一化矩形映射到 CGImage 像素坐标做 cropping，无中间渲染，零精度损失。

import SwiftUI
import UIKit

// MARK: - 裁剪比例

enum CropAspectRatio: String, CaseIterable, Identifiable {
    case free
    case square
    case ratio4x3
    case ratio3x4
    case ratio16x9
    case ratio9x16

    var id: String { rawValue }

    var title: String {
        switch self {
        case .free: return "自由"
        case .square: return "1:1"
        case .ratio4x3: return "4:3"
        case .ratio3x4: return "3:4"
        case .ratio16x9: return "16:9"
        case .ratio9x16: return "9:16"
        }
    }

    /// 宽 / 高，`nil` 表示自由比例
    var value: CGFloat? {
        switch self {
        case .free: return nil
        case .square: return 1
        case .ratio4x3: return 4.0 / 3.0
        case .ratio3x4: return 3.0 / 4.0
        case .ratio16x9: return 16.0 / 9.0
        case .ratio9x16: return 9.0 / 16.0
        }
    }
}

// MARK: - 控制点

enum CropHandle {
    case topLeft, topRight, bottomLeft, bottomRight
    case top, bottom, left, right
    case move

    var isCorner: Bool {
        switch self {
        case .topLeft, .topRight, .bottomLeft, .bottomRight: return true
        default: return false
        }
    }

    var affectsLeft: Bool {
        self == .topLeft || self == .bottomLeft || self == .left
    }

    var affectsRight: Bool {
        self == .topRight || self == .bottomRight || self == .right
    }

    var affectsTop: Bool {
        self == .topLeft || self == .topRight || self == .top
    }

    var affectsBottom: Bool {
        self == .bottomLeft || self == .bottomRight || self == .bottom
    }
}

// MARK: - 裁剪编辑器

struct ImageCropEditor: View {
    let image: UIImage
    let onComplete: (UIImage) -> Void
    let onCancel: () -> Void

    /// 当前正在编辑的图片（方向已修正，旋转操作会直接生成新图）
    @State private var workingImage: UIImage

    /// 裁剪框（相对图片显示区域的归一化矩形，0...1）
    @State private var cropFraction = CGRect(x: 0, y: 0, width: 1, height: 1)

    /// 画布尺寸
    @State private var canvasSize: CGSize = .zero

    /// 当前锁定的比例
    @State private var aspect: CropAspectRatio = .free

    /// 正在拖拽的控制点
    @State private var activeHandle: CropHandle?

    /// 拖拽开始时的裁剪框（视图坐标）
    @State private var dragStartRect: CGRect = .zero

    // MARK: 常量

    /// 画布留白，保证裁剪框边角可以被手指够到
    private let canvasPadding: CGFloat = 24

    /// 裁剪框最小边长
    private let minCropSide: CGFloat = 60

    /// 角控制点的命中半径
    private let cornerHitRadius: CGFloat = 36

    /// 边控制点的命中厚度
    private let edgeHitThickness: CGFloat = 28

    init(image: UIImage,
         onComplete: @escaping (UIImage) -> Void,
         onCancel: @escaping () -> Void) {
        self.image = image
        self.onComplete = onComplete
        self.onCancel = onCancel
        _workingImage = State(initialValue: image.fixedOrientation())
    }

    // MARK: - 计算属性

    /// 图片在画布中的显示区域
    private var imageRect: CGRect {
        CropGeometry.fitRect(for: workingImage.size, in: canvasSize, padding: canvasPadding)
    }

    /// 裁剪框在画布中的位置
    private var cropRect: CGRect {
        let base = imageRect
        guard base.width > 0, base.height > 0 else { return .zero }
        return CGRect(
            x: base.minX + cropFraction.minX * base.width,
            y: base.minY + cropFraction.minY * base.height,
            width: cropFraction.width * base.width,
            height: cropFraction.height * base.height
        )
    }

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            topBar
            canvas
            bottomBar
        }
        .background(Color.black)
        .ignoresSafeArea()
    }

    // MARK: 顶部栏

    private var topBar: some View {
        HStack {
            Button(action: onCancel) {
                Text("取消")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }

            Spacer()

            Text("裁剪")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            Button {
                if let result = makeCroppedImage() {
                    onComplete(result)
                } else {
                    onComplete(workingImage)
                }
            } label: {
                Text("完成")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.yellow)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 16)
        .background(Color.black)
    }

    // MARK: 画布

    private var canvas: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black

                Image(uiImage: workingImage)
                    .resizable()
                    .frame(width: imageRect.width, height: imageRect.height)
                    .position(x: imageRect.midX, y: imageRect.midY)

                // 裁剪框外的暗化遮罩
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: geometry.size))
                    path.addRect(cropRect)
                }
                .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
                .allowsHitTesting(false)

                CropFrameView(
                    rect: cropRect,
                    showEdgeHandles: aspect.value == nil,
                    activeHandleIsCorner: activeHandle?.isCorner ?? false
                )
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .onAppear { updateCanvasSize(geometry.size) }
            .onChange(of: geometry.size) { _, newValue in
                updateCanvasSize(newValue)
            }
        }
    }

    // MARK: 底部栏

    private var bottomBar: some View {
        VStack(spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CropAspectRatio.allCases) { item in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                applyAspect(item)
                            }
                        } label: {
                            Text(item.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(aspect == item ? .black : .white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(aspect == item ? Color.yellow : Color.white.opacity(0.15))
                                )
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            HStack(spacing: 16) {
                cropToolButton(icon: "rotate.left", title: "旋转") {
                    rotateLeft()
                }
                cropToolButton(icon: "arrow.counterclockwise", title: "重置") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        aspect = .free
                        cropFraction = CGRect(x: 0, y: 0, width: 1, height: 1)
                    }
                }
            }
            .padding(.horizontal, 40)
        }
        .padding(.vertical, 20)
        .padding(.bottom, 20)
        .background(Color.black)
    }

    private func cropToolButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 19))
                Text(title)
                    .font(.system(size: 12))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.15)))
        }
    }

    // MARK: - 手势

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if activeHandle == nil {
                    activeHandle = handle(at: value.startLocation)
                    dragStartRect = cropRect
                }
                guard let handle = activeHandle else { return }
                applyDrag(handle: handle, translation: value.translation)
            }
            .onEnded { _ in
                activeHandle = nil
            }
    }

    /// 根据按下位置判断操作哪个控制点
    private func handle(at point: CGPoint) -> CropHandle {
        let rect = cropRect
        let corners: [(CropHandle, CGPoint)] = [
            (.topLeft, CGPoint(x: rect.minX, y: rect.minY)),
            (.topRight, CGPoint(x: rect.maxX, y: rect.minY)),
            (.bottomLeft, CGPoint(x: rect.minX, y: rect.maxY)),
            (.bottomRight, CGPoint(x: rect.maxX, y: rect.maxY))
        ]

        for (handle, position) in corners {
            if hypot(point.x - position.x, point.y - position.y) <= cornerHitRadius {
                return handle
            }
        }

        // 锁定比例时只允许通过四角调整，避免比例被破坏
        if aspect.value == nil {
            let insideVertical = point.y > rect.minY - edgeHitThickness && point.y < rect.maxY + edgeHitThickness
            let insideHorizontal = point.x > rect.minX - edgeHitThickness && point.x < rect.maxX + edgeHitThickness

            if insideVertical, abs(point.x - rect.minX) <= edgeHitThickness { return .left }
            if insideVertical, abs(point.x - rect.maxX) <= edgeHitThickness { return .right }
            if insideHorizontal, abs(point.y - rect.minY) <= edgeHitThickness { return .top }
            if insideHorizontal, abs(point.y - rect.maxY) <= edgeHitThickness { return .bottom }
        }

        return .move
    }

    private func applyDrag(handle: CropHandle, translation: CGSize) {
        let bounds = imageRect
        guard bounds.width > 0, bounds.height > 0 else { return }

        let newRect: CGRect
        if handle == .move {
            newRect = CropGeometry.moved(dragStartRect, by: translation, in: bounds)
        } else if let ratio = aspect.value {
            newRect = CropGeometry.resizedKeepingRatio(
                dragStartRect,
                handle: handle,
                translation: translation,
                ratio: ratio,
                bounds: bounds,
                minSide: minCropSide
            )
        } else {
            newRect = CropGeometry.resizedFreely(
                dragStartRect,
                handle: handle,
                translation: translation,
                bounds: bounds,
                minSide: minCropSide
            )
        }

        cropFraction = CropGeometry.fraction(of: newRect, in: bounds)
    }

    // MARK: - 操作

    private func updateCanvasSize(_ size: CGSize) {
        guard size != canvasSize else { return }
        canvasSize = size
        // 比例锁定时随画布变化重新居中，保证比例严格正确
        if aspect.value != nil {
            applyAspect(aspect)
        }
    }

    /// 切换比例：生成该比例下最大的居中裁剪框
    private func applyAspect(_ item: CropAspectRatio) {
        aspect = item
        guard let ratio = item.value else { return }
        let bounds = imageRect
        guard bounds.width > 0, bounds.height > 0 else { return }

        var width = bounds.width
        var height = width / ratio
        if height > bounds.height {
            height = bounds.height
            width = height * ratio
        }
        let rect = CGRect(
            x: bounds.midX - width / 2,
            y: bounds.midY - height / 2,
            width: width,
            height: height
        )
        cropFraction = CropGeometry.fraction(of: rect, in: bounds)
    }

    /// 逆时针旋转 90°，直接生成新图，后续裁剪逻辑无需感知旋转
    private func rotateLeft() {
        guard let rotated = workingImage.rotated(by: -.pi / 2) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            workingImage = rotated
            cropFraction = CGRect(x: 0, y: 0, width: 1, height: 1)
            if aspect.value != nil {
                applyAspect(aspect)
            }
        }
    }

    /// 把归一化裁剪框映射到像素坐标并输出
    private func makeCroppedImage() -> UIImage? {
        guard let cgImage = workingImage.cgImage else { return nil }
        let pixelWidth = CGFloat(cgImage.width)
        let pixelHeight = CGFloat(cgImage.height)

        var pixelRect = CGRect(
            x: cropFraction.minX * pixelWidth,
            y: cropFraction.minY * pixelHeight,
            width: cropFraction.width * pixelWidth,
            height: cropFraction.height * pixelHeight
        ).integral

        pixelRect = pixelRect.intersection(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        guard pixelRect.width >= 1, pixelRect.height >= 1,
              let cropped = cgImage.cropping(to: pixelRect) else { return nil }

        return UIImage(cgImage: cropped, scale: workingImage.scale, orientation: .up)
    }
}

// MARK: - 裁剪框视图

private struct CropFrameView: View {
    let rect: CGRect
    let showEdgeHandles: Bool
    let activeHandleIsCorner: Bool

    private let cornerLength: CGFloat = 22
    private let cornerWidth: CGFloat = 3
    private let edgeLength: CGFloat = 28

    var body: some View {
        ZStack {
            Rectangle()
                .stroke(Color.white.opacity(0.9), lineWidth: 1)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)

            // 三分网格线
            Path { path in
                let stepX = rect.width / 3
                let stepY = rect.height / 3
                for index in 1...2 {
                    path.move(to: CGPoint(x: rect.minX + stepX * CGFloat(index), y: rect.minY))
                    path.addLine(to: CGPoint(x: rect.minX + stepX * CGFloat(index), y: rect.maxY))
                    path.move(to: CGPoint(x: rect.minX, y: rect.minY + stepY * CGFloat(index)))
                    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + stepY * CGFloat(index)))
                }
            }
            .stroke(Color.white.opacity(0.35), lineWidth: 0.5)

            // 四角把手
            Path { path in
                // 左上
                path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerLength))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.minX + cornerLength, y: rect.minY))
                // 右上
                path.move(to: CGPoint(x: rect.maxX - cornerLength, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cornerLength))
                // 右下
                path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerLength))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.maxX - cornerLength, y: rect.maxY))
                // 左下
                path.move(to: CGPoint(x: rect.minX + cornerLength, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cornerLength))
            }
            .stroke(Color.white, style: StrokeStyle(lineWidth: cornerWidth, lineCap: .round))
            .scaleEffect(activeHandleIsCorner ? 1.02 : 1.0)

            // 四边把手
            if showEdgeHandles {
                Group {
                    edgeHandle(width: edgeLength, height: cornerWidth)
                        .position(x: rect.midX, y: rect.minY)
                    edgeHandle(width: edgeLength, height: cornerWidth)
                        .position(x: rect.midX, y: rect.maxY)
                    edgeHandle(width: cornerWidth, height: edgeLength)
                        .position(x: rect.minX, y: rect.midY)
                    edgeHandle(width: cornerWidth, height: edgeLength)
                        .position(x: rect.maxX, y: rect.midY)
                }
            }
        }
    }

    private func edgeHandle(width: CGFloat, height: CGFloat) -> some View {
        Capsule()
            .fill(Color.white)
            .frame(width: width, height: height)
    }
}

// MARK: - 裁剪几何计算

enum CropGeometry {

    /// 计算图片按 aspectFit 显示在容器中的区域
    static func fitRect(for imageSize: CGSize, in containerSize: CGSize, padding: CGFloat) -> CGRect {
        let available = CGSize(
            width: containerSize.width - padding * 2,
            height: containerSize.height - padding * 2
        )
        guard available.width > 0, available.height > 0,
              imageSize.width > 0, imageSize.height > 0 else { return .zero }

        let imageAspect = imageSize.width / imageSize.height
        let availableAspect = available.width / available.height

        var size: CGSize
        if imageAspect > availableAspect {
            size = CGSize(width: available.width, height: available.width / imageAspect)
        } else {
            size = CGSize(width: available.height * imageAspect, height: available.height)
        }

        return CGRect(
            x: (containerSize.width - size.width) / 2,
            y: (containerSize.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    /// 视图坐标 -> 归一化坐标
    static func fraction(of rect: CGRect, in bounds: CGRect) -> CGRect {
        guard bounds.width > 0, bounds.height > 0 else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        let result = CGRect(
            x: (rect.minX - bounds.minX) / bounds.width,
            y: (rect.minY - bounds.minY) / bounds.height,
            width: rect.width / bounds.width,
            height: rect.height / bounds.height
        )
        return clampFraction(result)
    }

    private static func clampFraction(_ rect: CGRect) -> CGRect {
        var result = rect
        result.size.width = min(max(result.size.width, 0.01), 1)
        result.size.height = min(max(result.size.height, 0.01), 1)
        result.origin.x = min(max(result.origin.x, 0), 1 - result.size.width)
        result.origin.y = min(max(result.origin.y, 0), 1 - result.size.height)
        return result
    }

    /// 整体移动裁剪框
    static func moved(_ rect: CGRect, by translation: CGSize, in bounds: CGRect) -> CGRect {
        var result = rect
        result.origin.x = min(max(rect.minX + translation.width, bounds.minX), bounds.maxX - rect.width)
        result.origin.y = min(max(rect.minY + translation.height, bounds.minY), bounds.maxY - rect.height)
        return result
    }

    /// 自由比例下调整单边 / 单角
    static func resizedFreely(_ rect: CGRect,
                              handle: CropHandle,
                              translation: CGSize,
                              bounds: CGRect,
                              minSide: CGFloat) -> CGRect {
        var minX = rect.minX
        var maxX = rect.maxX
        var minY = rect.minY
        var maxY = rect.maxY

        if handle.affectsLeft {
            minX = min(max(minX + translation.width, bounds.minX), maxX - minSide)
        }
        if handle.affectsRight {
            maxX = max(min(maxX + translation.width, bounds.maxX), minX + minSide)
        }
        if handle.affectsTop {
            minY = min(max(minY + translation.height, bounds.minY), maxY - minSide)
        }
        if handle.affectsBottom {
            maxY = max(min(maxY + translation.height, bounds.maxY), minY + minSide)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// 锁定比例下调整（以被拖角的对角为锚点）
    static func resizedKeepingRatio(_ rect: CGRect,
                                    handle: CropHandle,
                                    translation: CGSize,
                                    ratio: CGFloat,
                                    bounds: CGRect,
                                    minSide: CGFloat) -> CGRect {
        // 锚点 = 被拖动角的对角
        let anchor: CGPoint
        let dragged: CGPoint
        switch handle {
        case .topLeft:
            anchor = CGPoint(x: rect.maxX, y: rect.maxY)
            dragged = CGPoint(x: rect.minX, y: rect.minY)
        case .topRight:
            anchor = CGPoint(x: rect.minX, y: rect.maxY)
            dragged = CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft:
            anchor = CGPoint(x: rect.maxX, y: rect.minY)
            dragged = CGPoint(x: rect.minX, y: rect.maxY)
        default:
            anchor = CGPoint(x: rect.minX, y: rect.minY)
            dragged = CGPoint(x: rect.maxX, y: rect.maxY)
        }

        let goesRight = dragged.x >= anchor.x
        let goesDown = dragged.y >= anchor.y

        let target = CGPoint(x: dragged.x + translation.width, y: dragged.y + translation.height)

        // 用「取较大值」的方式贴合比例，手感更接近系统相册
        var width = max(abs(target.x - anchor.x), abs(target.y - anchor.y) * ratio)

        // 受可用空间限制
        let availableWidth = goesRight ? bounds.maxX - anchor.x : anchor.x - bounds.minX
        let availableHeight = goesDown ? bounds.maxY - anchor.y : anchor.y - bounds.minY
        width = min(width, availableWidth, availableHeight * ratio)

        // 受最小边长限制
        width = max(width, minSide, minSide * ratio)
        // 若最小边长要求超出可用空间，退回可用空间上限，避免溢出画布
        width = min(width, availableWidth, availableHeight * ratio)

        let height = width / ratio
        let originX = goesRight ? anchor.x : anchor.x - width
        let originY = goesDown ? anchor.y : anchor.y - height

        return CGRect(x: originX, y: originY, width: width, height: height)
    }
}

// MARK: - UIImage 旋转

extension UIImage {

    /// 按弧度旋转图片（内部按 90° 的整数倍使用，负值为视觉上的逆时针）
    func rotated(by radians: CGFloat) -> UIImage? {
        let source = fixedOrientation()
        let originalSize = source.size
        guard originalSize.width > 0, originalSize.height > 0 else { return nil }

        let rotatedSize = CGRect(origin: .zero, size: originalSize)
            .applying(CGAffineTransform(rotationAngle: radians))
            .integral
            .size

        let format = UIGraphicsImageRendererFormat()
        format.scale = source.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: rotatedSize, format: format)
        return renderer.image { context in
            let ctx = context.cgContext
            ctx.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
            ctx.rotate(by: radians)
            source.draw(
                in: CGRect(
                    x: -originalSize.width / 2,
                    y: -originalSize.height / 2,
                    width: originalSize.width,
                    height: originalSize.height
                )
            )
        }
    }
}
