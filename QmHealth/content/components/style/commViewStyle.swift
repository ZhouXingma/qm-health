//
//  SwiftUIView.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/10/2.
//
//  通用样式表。所有视图样式集中维护。
  //  通过 `AppGlassConfig.shared.enabled` 一键开关液态玻璃效果，UI 实时响应。
//

import SwiftUI

// MARK: - 设计令牌

/// 间距 / 内边距标尺
enum AppSpacing {
    static let compact: CGFloat = 8
    static let regular: CGFloat = 12
    static let card: CGFloat = 16
    static let screen: CGFloat = 16
}

/// 圆角标尺
enum AppRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let card: CGFloat = 20
    static let max: CGFloat = 100
}

/// 首页固定高度卡标尺
enum AppHeight {
    static let infoTabCard: CGFloat = 260
    static let curveCard: CGFloat = 150
}

/// 阴影规格
struct ShadowSpec {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

enum AppShadow {
    static let card = ShadowSpec(color: Color("content_bg").opacity(0.3), radius: 2, x: 0, y: 1)
    static let lift = ShadowSpec(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
}

/// 颜色令牌
enum AppColor {
    static let background = Color("background")
    static let content = Color("content_bg")
    static let input = Color("input_bg")
    static let textPrimary = Color("text_primary")
    static let textSecondary = Color("text_secondary")
    static let divider = Color("divider")
    static let warning = Color("warning")
    static let error = Color("error")
    static let primary = Color.theme(.primary)
    static let secondary = Color.theme(.secondary)
}

// MARK: - 全局配置

/// 液态玻璃效果全局开关（ObservableObject，UI 实时响应）
///
/// - 始终为 `true`：所有 glass 扩展调用 iOS 26 原生 `.glassEffect`（液态玻璃材质）
/// - 项目要求"玻璃效果永远开启，不做关闭操作"，所以即使 `UserDefaults["appGlassEnabled"]`
///   里有遗留的 false 值，init 时也会强制覆盖为 true，不再读取历史设置
///
/// 持有 `@ObservedObject` 的 view 会自动重新求值，但运行时只走玻璃分支。
final class AppGlassConfig: ObservableObject {
    @Published var enabled: Bool {
        didSet {
            // 即便代码内部尝试写入 UserDefaults，也写不进去（保留入口但实际无效）
            UserDefaults.standard.set(enabled, forKey: "appGlassEnabled")
        }
    }

    static let shared = AppGlassConfig()

    private init() {
        // 强制开启，不再读取 UserDefaults 旧值
        self.enabled = true
    }
}

// MARK: - 通用样式修饰符

extension View {
    /// 按规格施加阴影
    func appShadow(_ spec: ShadowSpec) -> some View {
        self.shadow(color: spec.color, radius: spec.radius, x: spec.x, y: spec.y)
    }

    /// 页面背景（整屏铺满 background 色）
    func pageBackground() -> some View {
        self.frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColor.background)
    }
    
    /// 普通卡片样式（不依赖液态玻璃）
    func pageCardStyle() -> some View {
        self.padding(AppSpacing.card)
            .background(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).fill(AppColor.background))
            .appShadow(AppShadow.card)
    }

    /// 普通卡片样式（不依赖液态玻璃）
    func cardStyle() -> some View {
        self.padding(AppSpacing.card)
            .background(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).fill(AppColor.content))
            .appShadow(AppShadow.card)
    }

    /// 普通内容块样式（不依赖液态玻璃）
    func contentStyle() -> some View {
        self.background(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous).fill(AppColor.content))
            .appShadow(AppShadow.card)
    }

    /// 可点击卡片（按压反馈）
    func tappableCard(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            self.contentShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        }
        .buttonStyle(CardPressButtonStyle())
    }
}

// MARK: - 液态玻璃核心封装（持有 @ObservedObject 自动响应开关）

/// 液态玻璃修饰符（带形状）：持有 AppGlassConfig.shared，自动响应开关变化
struct AppGlassWithShapeModifier<Fallback: View>: ViewModifier {
    let glass: Glass
    let shape: AnyShape
    let fallback: Fallback

    @ObservedObject private var config = AppGlassConfig.shared

    init<S: Shape>(glass: Glass, shape: S, fallback: () -> Fallback) {
        self.glass = glass
        self.shape = AnyShape(shape)
        self.fallback = fallback()
    }

    func body(content: Content) -> some View {
        if config.enabled {
            content
                .glassEffect(glass, in: shape)
                .compositingGroup()
                .clipShape(shape)
        } else {
            content.background(fallback)
        }
    }
}

/// 液态玻璃修饰符（无形状，自动用 Capsule）：持有 AppGlassConfig.shared
struct AppGlassEffectModifier<Fallback: View>: ViewModifier {
    let glass: Glass
    let fallback: Fallback

    @ObservedObject private var config = AppGlassConfig.shared

    init(glass: Glass, fallback: () -> Fallback) {
        self.glass = glass
        self.fallback = fallback()
    }

    func body(content: Content) -> some View {
        if config.enabled {
            content.glassEffect(glass)
                .compositingGroup()
        } else {
            content.background(fallback)
        }
    }
}

extension View {
    /// 液态玻璃效果统一入口（带形状）
    ///
    /// 业务代码必须通过本方法（`appGlass` / `appGlassEffect`）调用，不要直接用系统 `.glassEffect`，
    /// 否则无法被 `AppGlassConfig.shared.enabled` 控制。
    func appGlass<S: Shape>(
        _ glass: Glass,
        in shape: S,
        @ViewBuilder fallback: () -> some View = { AppColor.content.opacity(0.6) }
    ) -> some View {
        modifier(AppGlassWithShapeModifier(glass: glass, shape: shape, fallback: fallback))
    }

    /// 液态玻璃效果统一入口（无形状，自动用 Capsule）
    func appGlassEffect(
        _ glass: Glass,
        @ViewBuilder fallback: () -> some View = { AppColor.content.opacity(0.6) }
    ) -> some View {
        modifier(AppGlassEffectModifier(glass: glass, fallback: fallback))
    }
}

// MARK: - 液态玻璃语义扩展

extension View {
    /// 液态玻璃卡片：连续圆角 + 玻璃材质 + 内边距
    func glassCardStyle(
        _ glass: Glass = .regular,
        cornerRadius: CGFloat = AppRadius.card
    ) -> some View {
        self
            .padding(AppSpacing.card)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appGlass(glass, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppColor.content)
                    .appShadow(AppShadow.card)
            }
    }

    /// 液态玻璃容器：只套玻璃材质与形状、不加内边距
    func glassContainer(
        _ glass: Glass = .regular.interactive(),
        cornerRadius: CGFloat = AppRadius.large
    ) -> some View {
        self.appGlass(glass, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(AppColor.content.opacity(0.6))
        }
    }

    /// 液态玻璃胶囊
    func glassPill(_ glass: Glass = .regular.interactive()) -> some View {
        self.appGlassEffect(glass) {
            Capsule().fill(AppColor.content.opacity(0.6))
        }
    }

    /// 液态玻璃胶囊（带 tint）
    func glassPillColor(_ glass: Glass = .regular.interactive(), _ tintColor: Color? = nil) -> some View {
        let resolved = tintColor ?? AppColor.content.opacity(0.5)
        return self.appGlassEffect(glass.tint(resolved)) {
            Capsule().fill(resolved)
        }
    }

    /// 液态玻璃页面背景：动画弥散背景（DiffuseBackground）
    func glassBackground(
        color1: Color = AppColor.primary,
        color2: Color = AppColor.secondary,
        color3: Color = AppColor.primary.opacity(0.6),
        speed: Double = 0.6
    ) -> some View {
        self.modifier(DiffuseGlassBackgroundModifier(
            color1: color1,
            color2: color2,
            color3: color3,
            speed: speed
        ))
    }

    /// 输入框容器样式：常规内边距 + 液态玻璃底 + 中圆角
    func inputFieldStyle() -> some View {
        self.padding(.vertical,AppSpacing.regular)
            .padding(.horizontal,AppSpacing.regular)
            .glassEffect(.regular.interactive())
    }
}

/// 弥散背景修饰符：持有 @State 包装 DiffuseBackground + @ObservedObject 监听玻璃开关
struct DiffuseGlassBackgroundModifier: ViewModifier {
    @State private var c1: Color
    @State private var c2: Color
    @State private var c3: Color
    @State private var spd: Double
    @ObservedObject private var config = AppGlassConfig.shared

    init(color1: Color, color2: Color, color3: Color, speed: Double) {
        self._c1 = State(initialValue: color1)
        self._c2 = State(initialValue: color2)
        self._c3 = State(initialValue: color3)
        self._spd = State(initialValue: speed)
    }

    func body(content: Content) -> some View {
        if config.enabled {
            content.background {
                DiffuseBackground(color1: $c1, color2: $c2, color3: $c3, speed: $spd)
            }
        } else {
            content.background(AppColor.background)
        }
    }
}

// MARK: - 按钮样式

/// 按压反馈（通用）
struct CardPressButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.98

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// 主按钮：主题色玻璃 + 白字，自动响应 disabled 和玻璃开关
struct PrimaryActionButtonStyle: ButtonStyle {
    @ObservedObject private var config = AppGlassConfig.shared
    @Environment(\.isEnabled) private var isEnabled
    var tint: Color = AppColor.primary
    var cornerRadius: CGFloat = AppRadius.max
    var verticalPadding: CGFloat = AppSpacing.regular

    func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.white)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

        let styled: AnyView
        if config.enabled {
            styled = AnyView(
                label.glassEffect(.regular.interactive().tint(tint),
                                  in: RoundedRectangle(cornerRadius: cornerRadius))
            )
        } else {
            styled = AnyView(
                label.background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(tint)
                )
            )
        }

        return styled
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// 带 loading 态的主按钮：loading 时隐藏文字、显示白色 spinner，自动响应 disabled 和玻璃开关
///
/// - **enabled**：品牌色玻璃底 + 白色加粗字
/// - **disabled**：保留品牌色底，整体降低透明度 + 文字降低对比度，仍清晰可识别为主操作
/// - **loading**：隐藏文字（opacity 0）+ 白色 spinner
struct ProcessingActionButtonStyle: ButtonStyle {
    @ObservedObject private var config = AppGlassConfig.shared
    @Environment(\.isEnabled) private var isEnabled
    var isLoading: Bool = false
    var tint: Color = AppColor.primary
    var cornerRadius: CGFloat = AppRadius.max
    var verticalPadding: CGFloat = AppSpacing.regular

    func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity)
            .opacity(isLoading ? 0 : 1)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

        let background: AnyView
        if config.enabled {
            background = AnyView(
                label.glassEffect(.regular.interactive().tint(tint),
                                  in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
        } else {
            background = AnyView(
                label.background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint)
                )
            )
        }

        return background
            .overlay {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
            }
            .opacity(isEnabled ? 1.0 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
/// 次按钮：透明玻璃 + 主文本色，自动响应玻璃开关
struct SecondaryActionButtonStyle: ButtonStyle {
    @ObservedObject private var config = AppGlassConfig.shared
    var tintColor: Color = Color.clear
    var cornerRadius: CGFloat = AppRadius.max
    var verticalPadding: CGFloat = AppSpacing.regular

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        let label = configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(AppColor.textPrimary)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity)

        return Group {
            if config.enabled {
                label.glassEffect(.regular.tint(tintColor), in: shape)   // 去掉 interactive()
            } else {
                label.background(shape.fill(tintColor.opacity(0.6)))
            }
        }
        .contentShape(shape)
        .opacity(configuration.isPressed ? 0.85 : 1.0)                   // 自己的反馈
        .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// 可选项按钮：选中态主题色玻璃，自动响应玻璃开关
struct GlassSelectButtonStyle: ButtonStyle {
    var isSelected: Bool
    var tint: Color = AppColor.primary
    var verticalPadding: CGFloat = AppSpacing.regular
    var cornerRadius: CGFloat = AppRadius.max

    @ObservedObject private var config = AppGlassConfig.shared

    func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

        let glass: Glass = isSelected
            ? Glass.clear.tint(tint)
            : Glass.clear

        let styled: AnyView
        if config.enabled {
            styled = AnyView(
                label.glassEffect(glass,
                                  in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
        } else {
            styled = AnyView(
                label.background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(AppColor.content.opacity(isSelected ? 0.9 : 0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(isSelected ? tint : AppColor.divider, lineWidth: isSelected ? 1.5 : 1)
                        )
                )
            )
        }

        return styled
            .foregroundColor(isSelected ? .white : AppColor.textPrimary)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - 屏幕左边缘返回手势

struct EdgeSwipeBackModifier: ViewModifier {
    var enabled: Bool
    var edgeWidth: CGFloat
    var threshold: CGFloat
    var onDismiss: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    guard enabled else { return }
                    guard value.startLocation.x < edgeWidth else { return }
                    guard value.translation.width > threshold else { return }
                    if let onDismiss {
                        onDismiss()
                    } else {
                        dismiss()
                    }
                }
        )
    }
}

extension View {
    func edgeSwipeBack(
        enabled: Bool = true,
        edgeWidth: CGFloat = 40,
        threshold: CGFloat = 80,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        modifier(
            EdgeSwipeBackModifier(
                enabled: enabled,
                edgeWidth: edgeWidth,
                threshold: threshold,
                onDismiss: onDismiss
            )
        )
    }
}

// MARK: - 编辑弹窗统一背景
extension View {
    func sheetAppBackground() -> some View {
        self
            .background(AppColor.background)
            .toolbarBackground(AppColor.background, for: .navigationBar)
            .presentationDragIndicator(.hidden)
    }
}

// MARK: - 样式预览

#Preview("统一样式示例") {
    VStack(spacing: AppSpacing.regular) {
        Text("统一样式层示例")
            .font(.headline)
            .foregroundStyle(AppColor.textPrimary)

        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            Text("cardStyle 卡片").font(.headline).foregroundStyle(AppColor.textPrimary)
            Text("大圆角(AppRadius.card) + 卡片底色 + 浅阴影，内边距 16")
                .font(.footnote)
                .foregroundStyle(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()

        VStack(alignment: .leading) {
            Text("contentStyle 内容块（中圆角 + 浅阴影）")
                .font(.footnote)
                .foregroundStyle(AppColor.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.regular)
        .contentStyle()

        Text("inputFieldStyle 输入框容器")
            .font(.footnote)
            .foregroundStyle(AppColor.textSecondary)
            .inputFieldStyle()

        Text("tappableCard 可点击卡片（带按压反馈）")
            .font(.footnote)
            .foregroundStyle(AppColor.textPrimary)
            .cardStyle()
            .tappableCard {}

        Button("主按钮") {}
            .buttonStyle(PrimaryActionButtonStyle())

        Button("次按钮") {}
            .buttonStyle(SecondaryActionButtonStyle())

        ZStack {
            LinearGradient(
                colors: [AppColor.primary.opacity(0.25), AppColor.secondary.opacity(0.15), AppColor.background],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: AppSpacing.compact) {
                Text("glassCardStyle 玻璃卡片").font(.headline)
                Text("液态玻璃 + 连续圆角，需半透明背景才有折射")
                    .font(.footnote)
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCardStyle()
        }
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
    }
    .padding(AppSpacing.screen)
    .pageBackground()
}
