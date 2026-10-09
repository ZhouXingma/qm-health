//
//  ImageMosaicEditor.swift
//  QmHealth
//
//  图片马赛克 / 模糊涂抹编辑器（重构版）
//
// MARK: - 设计说明
// 旧版每画一笔都要走一次「生成蒙版 -> CIPixellate -> CIBlendWithMask -> 出图」的全量渲染，
// 手指抬起后才看到效果，大图上会明显卡顿，且蒙版坐标依赖当时的容器尺寸，布局变化就错位。
//
// 新版改成「预处理 + 图层蒙版」：
// 1. 进入编辑器时一次性生成整张图的马赛克版本和模糊版本（后台线程，带 loading）；
// 2. 画布上叠两层 UIImageView：底层原图，上层效果图，上层的 layer.mask 由手指轨迹组成，
//    涂抹即时可见，全程没有图像重算，随手划都跟手；
// 3. 笔迹按「相对图片显示区域的归一化坐标」保存，与屏幕尺寸无关，旋转/布局变化不会错位；
// 4. 点击完成时才按笔迹一次性合成输出图，输出使用原图分辨率。

import SwiftUI
import UIKit
import CoreImage

// MARK: - 效果类型

enum MosaicEffectKind: String, CaseIterable, Identifiable {
    case pixellate
    case blur

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pixellate: return "马赛克"
        case .blur: return "模糊"
        }
    }

    var icon: String {
        switch self {
        case .pixellate: return "squareshape.split.3x3"
        case .blur: return "drop.fill"
        }
    }
}

// MARK: - 笔迹

struct MosaicStroke: Identifiable, Equatable {
    let id = UUID()
    /// 归一化坐标（相对图片显示区域，0...1）
    var points: [CGPoint]
    /// 归一化线宽（相对图片显示区域宽度）
    var widthFraction: CGFloat
}

// MARK: - 编辑器视图

struct ImageMosaicEditor: View {
    let image: UIImage
    let onComplete: (UIImage) -> Void
    let onCancel: () -> Void

    @StateObject private var model: MosaicEditorModel

    init(image: UIImage,
         onComplete: @escaping (UIImage) -> Void,
         onCancel: @escaping () -> Void) {
        self.image = image
        self.onComplete = onComplete
        self.onCancel = onCancel
        _model = StateObject(wrappedValue: MosaicEditorModel(image: image))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            canvas
            bottomBar
        }
        .background(Color.black)
        .ignoresSafeArea()
        .onAppear { model.prepare() }
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

            Text("涂抹遮挡")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            Button {
                onComplete(model.export())
            } label: {
                Text("完成")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(model.isReady ? .yellow : .gray)
            }
            .disabled(!model.isReady)
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 16)
        .background(Color.black)
    }

    // MARK: 画布

    private var canvas: some View {
        ZStack {
            Color.black

            MosaicCanvasRepresentable(model: model)

            if !model.isReady {
                VStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)
                    Text("正在准备...")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                }
            } else if model.strokes.isEmpty {
                Text("用手指涂抹需要遮挡的区域")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.45)))
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: 底部栏

    private var bottomBar: some View {
        VStack(spacing: 18) {
            // 效果切换
            HStack(spacing: 10) {
                ForEach(MosaicEffectKind.allCases) { kind in
                    Button {
                        model.setEffect(kind)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: kind.icon)
                                .font(.system(size: 12, weight: .semibold))
                            Text(kind.title)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(model.effect == kind ? .black : .white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(model.effect == kind ? Color.yellow : Color.white.opacity(0.15))
                        )
                    }
                }

                Spacer()

                // 颗粒度 / 模糊强度
                HStack(spacing: 8) {
                    ForEach(MosaicIntensity.allCases) { level in
                        Button {
                            model.setIntensity(level)
                        } label: {
                            Text(level.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(model.intensity == level ? .yellow : .white.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().fill(
                                        model.intensity == level
                                        ? Color.yellow.opacity(0.18)
                                        : Color.white.opacity(0.08)
                                    )
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, 20)

            // 笔刷大小
            VStack(spacing: 6) {
                HStack {
                    Text("笔刷粗细")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text("\(Int(model.brushSize))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                }
                HStack(spacing: 10) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.5))
                    Slider(value: $model.brushSize, in: 12...80)
                        .tint(.yellow)
                    Image(systemName: "circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 20)

            // 撤销 / 清除
            HStack(spacing: 16) {
                mosaicToolButton(icon: "arrow.uturn.backward", title: "撤销", enabled: model.canUndo) {
                    model.undo()
                }
                mosaicToolButton(icon: "trash", title: "清除", enabled: model.canUndo) {
                    model.clear()
                }
            }
            .padding(.horizontal, 40)
        }
        .padding(.vertical, 18)
        .padding(.bottom, 20)
        .background(Color.black)
    }

    private func mosaicToolButton(icon: String,
                                  title: String,
                                  enabled: Bool,
                                  action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 19))
                Text(title)
                    .font(.system(size: 12))
            }
            .foregroundColor(enabled ? .white : .white.opacity(0.35))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.15)))
        }
        .disabled(!enabled)
    }
}

// MARK: - 强度档位

enum MosaicIntensity: String, CaseIterable, Identifiable {
    case light
    case medium
    case strong

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: return "弱"
        case .medium: return "中"
        case .strong: return "强"
        }
    }

    /// 马赛克格子边长占图片短边的比例
    var pixelRatio: CGFloat {
        switch self {
        case .light: return 1.0 / 60.0
        case .medium: return 1.0 / 35.0
        case .strong: return 1.0 / 20.0
        }
    }

    /// 模糊半径占图片短边的比例
    var blurRatio: CGFloat {
        switch self {
        case .light: return 1.0 / 80.0
        case .medium: return 1.0 / 45.0
        case .strong: return 1.0 / 25.0
        }
    }
}

// MARK: - 编辑器状态

final class MosaicEditorModel: ObservableObject {

    /// 方向已修正的原图
    let originalImage: UIImage

    /// 当前效果图（原图整体施加效果后的结果，通过蒙版局部显示）
    @Published private(set) var effectImage: UIImage?

    /// 效果图是否已经准备好
    @Published private(set) var isReady: Bool = false

    /// 已完成的笔迹
    @Published private(set) var strokes: [MosaicStroke] = []

    /// 当前效果类型
    @Published private(set) var effect: MosaicEffectKind = .pixellate

    /// 当前强度
    @Published private(set) var intensity: MosaicIntensity = .medium

    /// 笔刷粗细（视图点）
    @Published var brushSize: CGFloat = 32

    /// 笔迹版本号，画布据此判断是否需要重建蒙版
    @Published private(set) var revision: Int = 0

    var canUndo: Bool { !strokes.isEmpty }

    private let processor = MosaicImageProcessor()
    private var processToken = UUID()

    init(image: UIImage) {
        self.originalImage = image.fixedOrientation()
    }

    // MARK: 效果图准备

    func prepare() {
        guard effectImage == nil else { return }
        regenerateEffectImage()
    }

    func setEffect(_ kind: MosaicEffectKind) {
        guard kind != effect else { return }
        effect = kind
        regenerateEffectImage()
    }

    func setIntensity(_ level: MosaicIntensity) {
        guard level != intensity else { return }
        intensity = level
        regenerateEffectImage()
    }

    private func regenerateEffectImage() {
        let token = UUID()
        processToken = token
        isReady = false

        let source = originalImage
        let kind = effect
        let level = intensity

        processor.process(image: source, kind: kind, intensity: level) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.processToken == token else { return }
                self.effectImage = result ?? source
                self.isReady = true
                self.revision += 1
            }
        }
    }

    // MARK: 笔迹

    func appendStroke(points: [CGPoint], widthFraction: CGFloat) {
        guard !points.isEmpty else { return }
        strokes.append(MosaicStroke(points: points, widthFraction: widthFraction))
        revision += 1
    }

    func undo() {
        guard !strokes.isEmpty else { return }
        strokes.removeLast()
        revision += 1
    }

    func clear() {
        guard !strokes.isEmpty else { return }
        strokes.removeAll()
        revision += 1
    }

    // MARK: 输出

    /// 按笔迹把效果图合成到原图上，输出保持原图分辨率
    func export() -> UIImage {
        guard !strokes.isEmpty, let effectImage else { return originalImage }
        return MosaicImageProcessor.compose(
            base: originalImage,
            effect: effectImage,
            strokes: strokes
        ) ?? originalImage
    }
}

// MARK: - 画布桥接

struct MosaicCanvasRepresentable: UIViewRepresentable {
    @ObservedObject var model: MosaicEditorModel

    func makeUIView(context: Context) -> MosaicCanvasUIView {
        let view = MosaicCanvasUIView()
        view.onStrokeFinished = { [weak model] points, widthFraction in
            model?.appendStroke(points: points, widthFraction: widthFraction)
        }
        return view
    }

    func updateUIView(_ uiView: MosaicCanvasUIView, context: Context) {
        uiView.brushSize = model.brushSize
        uiView.isDrawingEnabled = model.isReady
        uiView.apply(
            baseImage: model.originalImage,
            effectImage: model.effectImage,
            strokes: model.strokes,
            revision: model.revision
        )
    }
}

// MARK: - 画布

final class MosaicCanvasUIView: UIView {

    /// 当前笔刷粗细（视图点）
    var brushSize: CGFloat = 32

    /// 效果图未就绪前禁止涂抹
    var isDrawingEnabled: Bool = false

    /// 一笔画完的回调（归一化点集 + 归一化线宽）
    var onStrokeFinished: (([CGPoint], CGFloat) -> Void)?

    private let baseImageView = UIImageView()
    private let effectImageView = UIImageView()

    /// 效果图的透明度蒙版：用一张位图承载笔迹，行为确定、无缠绕规则问题
    private let maskLayer = CALayer()

    private var strokes: [MosaicStroke] = []
    private var appliedRevision: Int = -1
    private var imageSize: CGSize = .zero

    /// 正在绘制中的笔迹（归一化坐标）
    private var livePoints: [CGPoint] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        clipsToBounds = true

        baseImageView.contentMode = .scaleAspectFit
        effectImageView.contentMode = .scaleAspectFit
        addSubview(baseImageView)
        addSubview(effectImageView)

        maskLayer.contentsGravity = .resize
        maskLayer.contentsScale = 1
        effectImageView.layer.mask = maskLayer

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        addGestureRecognizer(pan)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
    }

    // MARK: 状态同步

    func apply(baseImage: UIImage, effectImage: UIImage?, strokes: [MosaicStroke], revision: Int) {
        var needsMaskRebuild = false

        if baseImageView.image !== baseImage {
            baseImageView.image = baseImage
            imageSize = baseImage.size
            setNeedsLayout()
        }
        if effectImageView.image !== effectImage {
            effectImageView.image = effectImage
        }
        if revision != appliedRevision {
            appliedRevision = revision
            self.strokes = strokes
            needsMaskRebuild = true
        }
        if needsMaskRebuild {
            rebuildMask()
        }
    }

    // MARK: 布局

    /// 图片实际显示区域
    private var displayRect: CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              bounds.width > 0, bounds.height > 0 else { return bounds }

        let imageAspect = imageSize.width / imageSize.height
        let boundsAspect = bounds.width / bounds.height

        var size: CGSize
        if imageAspect > boundsAspect {
            size = CGSize(width: bounds.width, height: bounds.width / imageAspect)
        } else {
            size = CGSize(width: bounds.height * imageAspect, height: bounds.height)
        }

        return CGRect(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let rect = displayRect
        baseImageView.frame = rect
        effectImageView.frame = rect
        maskLayer.frame = effectImageView.bounds
        rebuildMask()
    }

    // MARK: 蒙版

    /// 把已完成的笔迹 + 正在画的笔迹渲染成一张 alpha 位图作为蒙版
    private func rebuildMask() {
        let rect = displayRect
        guard rect.width > 1, rect.height > 1 else { return }

        maskLayer.frame = effectImageView.bounds

        var all = strokes
        if !livePoints.isEmpty {
            all.append(MosaicStroke(points: livePoints, widthFraction: brushSize / rect.width))
        }

        guard !all.isEmpty else {
            maskLayer.contents = nil
            return
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: rect.size, format: format)
        let mask = renderer.image { context in
            let ctx = context.cgContext
            ctx.setStrokeColor(UIColor.black.cgColor)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            for stroke in all {
                guard let path = strokePath(stroke, in: rect.size) else { continue }
                ctx.setLineWidth(max(1, stroke.widthFraction * rect.width))
                ctx.addPath(path)
                ctx.strokePath()
            }
        }

        maskLayer.contents = mask.cgImage
    }

    /// 归一化点集 -> 视图坐标路径
    private func strokePath(_ stroke: MosaicStroke, in size: CGSize) -> CGPath? {
        guard let first = stroke.points.first else { return nil }
        let path = CGMutablePath()
        path.move(to: CGPoint(x: first.x * size.width, y: first.y * size.height))

        if stroke.points.count == 1 {
            // 单点也要留下一个圆点
            path.addLine(to: CGPoint(x: first.x * size.width + 0.1, y: first.y * size.height))
        } else {
            for point in stroke.points.dropFirst() {
                path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
            }
        }
        return path
    }

    // MARK: 手势

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard isDrawingEnabled else { return }
        let rect = displayRect
        guard rect.width > 0, rect.height > 0 else { return }

        let location = gesture.location(in: self)
        let normalized = normalize(location, in: rect)

        switch gesture.state {
        case .began:
            livePoints = [normalized]
            rebuildMask()

        case .changed:
            // 过滤过密的点，减少路径节点
            if let last = livePoints.last {
                let dx = (normalized.x - last.x) * rect.width
                let dy = (normalized.y - last.y) * rect.height
                if hypot(dx, dy) < 1.5 { return }
            }
            livePoints.append(normalized)
            rebuildMask()

        case .ended, .cancelled, .failed:
            finishLiveStroke(in: rect)

        default:
            break
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard isDrawingEnabled else { return }
        let rect = displayRect
        guard rect.width > 0, rect.height > 0 else { return }

        let normalized = normalize(gesture.location(in: self), in: rect)
        onStrokeFinished?([normalized], brushSize / rect.width)
    }

    private func finishLiveStroke(in rect: CGRect) {
        guard !livePoints.isEmpty else { return }
        let points = livePoints
        let widthFraction = brushSize / rect.width
        // 先把这一笔并入已完成列表，等 SwiftUI 回传时用相同内容覆盖，避免中间闪一下
        strokes.append(MosaicStroke(points: points, widthFraction: widthFraction))
        livePoints = []
        rebuildMask()
        onStrokeFinished?(points, widthFraction)
    }

    private func normalize(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max((point.x - rect.minX) / rect.width, 0), 1),
            y: min(max((point.y - rect.minY) / rect.height, 0), 1)
        )
    }
}

// MARK: - 图像处理

final class MosaicImageProcessor {

    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private let queue = DispatchQueue(label: "com.qmhealth.mosaic.process", qos: .userInitiated)

    /// 生成整张图的效果版本
    func process(image: UIImage,
                 kind: MosaicEffectKind,
                 intensity: MosaicIntensity,
                 completion: @escaping (UIImage?) -> Void) {
        queue.async {
            completion(MosaicImageProcessor.makeEffectImage(image: image, kind: kind, intensity: intensity))
        }
    }

    static func makeEffectImage(image: UIImage,
                                kind: MosaicEffectKind,
                                intensity: MosaicIntensity) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let input = CIImage(cgImage: cgImage)
        let shortSide = min(input.extent.width, input.extent.height)

        var output: CIImage?
        switch kind {
        case .pixellate:
            let filter = CIFilter(name: "CIPixellate")
            filter?.setValue(input, forKey: kCIInputImageKey)
            filter?.setValue(max(4, shortSide * intensity.pixelRatio), forKey: kCIInputScaleKey)
            filter?.setValue(CIVector(x: input.extent.midX, y: input.extent.midY), forKey: kCIInputCenterKey)
            output = filter?.outputImage
        case .blur:
            let filter = CIFilter(name: "CIGaussianBlur")
            // 先做边缘延展，避免高斯模糊后四周出现透明羽化
            filter?.setValue(input.clampedToExtent(), forKey: kCIInputImageKey)
            filter?.setValue(max(3, shortSide * intensity.blurRatio), forKey: kCIInputRadiusKey)
            output = filter?.outputImage
        }

        guard let output,
              let result = ciContext.createCGImage(output, from: input.extent) else { return nil }

        return UIImage(cgImage: result, scale: image.scale, orientation: .up)
    }

    /// 按笔迹把效果图裁剪合成到原图上
    static func compose(base: UIImage, effect: UIImage, strokes: [MosaicStroke]) -> UIImage? {
        let size = base.size
        guard size.width > 0, size.height > 0 else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = base.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            let ctx = context.cgContext
            let fullRect = CGRect(origin: .zero, size: size)
            base.draw(in: fullRect)

            for stroke in strokes {
                guard let path = strokePath(stroke, in: size) else { continue }
                // 逐笔裁剪绘制，避免多笔路径合并时的缠绕规则问题
                ctx.saveGState()
                ctx.addPath(path)
                ctx.clip()
                effect.draw(in: fullRect)
                ctx.restoreGState()
            }
        }
    }

    /// 把归一化笔迹展开成可用于裁剪的实心区域
    private static func strokePath(_ stroke: MosaicStroke, in size: CGSize) -> CGPath? {
        guard let first = stroke.points.first else { return nil }
        let lineWidth = max(1, stroke.widthFraction * size.width)

        let path = CGMutablePath()
        path.move(to: CGPoint(x: first.x * size.width, y: first.y * size.height))
        if stroke.points.count == 1 {
            path.addLine(to: CGPoint(x: first.x * size.width + 0.1, y: first.y * size.height))
        } else {
            for point in stroke.points.dropFirst() {
                path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
            }
        }

        return path.copy(strokingWithWidth: lineWidth, lineCap: .round, lineJoin: .round, miterLimit: 1)
    }
}
