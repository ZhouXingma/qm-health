//
//  PortraitVideoView.swift
//  QmHealth
//  个人肖像动画播放：静音、无缝循环、滚出屏幕自动暂停
//

import SwiftUI
import AVFoundation

struct PortraitVideoView: View {
    let assetName: String

    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?
    @State private var isAvailable = true

    var body: some View {
        ZStack {
            if let player {
                PortraitPlayerLayerView(player: player)
            }
            if !isAvailable {
                placeholder
            }
        }
        .onAppear {
            preparePlayerIfNeeded()
            player?.play()
        }
        .onDisappear {
            player?.pause()
        }
        .onScrollVisibilityChange(threshold: 0.05) { visible in
            if visible {
                player?.play()
            } else {
                player?.pause()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            player?.pause()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            player?.play()
        }
        .onChange(of: assetName) { _, _ in
            rebuildPlayer()
        }
        .accessibilityHidden(true)
    }

    private func rebuildPlayer() {
        player?.pause()
        player = nil
        looper = nil
        isAvailable = true
        preparePlayerIfNeeded()
        player?.play()
    }

    private func preparePlayerIfNeeded() {
        guard player == nil else { return }
        // PortraitVideoView 只接收素材名，切换素材时由外部替换视图实例
        guard let url = PortraitAnimation.url(assetName: assetName) else {
            isAvailable = false
            return
        }
        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer()
        queuePlayer.isMuted = true
        queuePlayer.actionAtItemEnd = .advance
        looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        player = queuePlayer
        isAvailable = true
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.theme(.primary).opacity(0.16), Color.theme(.secondary).opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "person.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color.theme(.primary).opacity(0.5))
        }
    }
}

private struct PortraitPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PortraitPlayerUIView {
        let view = PortraitPlayerUIView()
        view.backgroundColor = .clear
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PortraitPlayerUIView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }

    static func dismantleUIView(_ uiView: PortraitPlayerUIView, coordinator: ()) {
        uiView.playerLayer.player?.pause()
        uiView.playerLayer.player = nil
    }
}

private final class PortraitPlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}
