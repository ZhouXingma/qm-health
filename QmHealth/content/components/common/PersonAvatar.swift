//
//  PersonAvatar.swift
//  QmHealth
//
//  就诊人头像组件：统一的头像展示 + 本地缓存。
//  - 缓存 key 取头像请求地址的路径部分（去掉 http://host:port 前缀），命中缓存直接本地加载，不发网络请求
//  - 未命中才请求网络，成功后写入本地缓存
//  - 展示尺寸由外部 frame 决定（也可用 size 参数固定）
//

import SwiftUI

struct PersonAvatar: View {
    /// 头像 id（服务端文件 id），为空时显示占位
    let headerImgId: String?
    /// 本地预览图（如刚裁剪完、还没上传成功的头像），优先于缓存和网络
    var previewData: Data? = nil
    /// 无头像时的占位样式
    var placeholderStyle: PlaceholderStyle = .plain
    /// 固定尺寸；nil 表示由外部 frame 决定
    var size: CGFloat? = nil

    enum PlaceholderStyle {
        /// 单独一个人像图标
        case plain
        /// 带玻璃底的圆形占位
        case glass
    }

    @State private var imageData: Data?
    @State private var isLoading = false

    private var displayData: Data? { previewData ?? imageData }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let data = displayData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipShape(Circle())
                } else {
                    placeholder(side: min(geometry.size.width, geometry.size.height))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(width: size, height: size)
        .onAppear {
            load()
        }
        .onChange(of: headerImgId) { _, _ in
            load()
        }
    }

    // MARK: - 占位

    @ViewBuilder
    private func placeholder(side: CGFloat) -> some View {
        switch placeholderStyle {
        case .plain:
            ZStack {
                Circle()
                    .fill(Color.clear)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)

                Image(systemName: "person.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .foregroundColor(Color.theme(.chart1))
                    .clipShape(Circle())
            }
            .frame(width: side, height: side)

        case .glass:
            Circle()
                .fill(Color.clear)
                .frame(width: side, height: side)
                .appGlass(.clear.tint(Color.theme(.primary).opacity(0.18)), in: Circle()) {
                    Circle().fill(Color.theme(.primary).opacity(0.15))
                }
                .overlay(
                    Group {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: side * 0.5))
                                .foregroundColor(Color.theme(.primary))
                        }
                    }
                )
        }
    }

    // MARK: - 加载

    private func load() {
        guard let id = headerImgId, !id.isEmpty else {
            imageData = nil
            return
        }

        let url = AvatarCache.url(for: id)

        // 命中本地缓存：直接加载，不发请求
        if let cached = AvatarCache.cachedData(for: url), UIImage(data: cached) != nil {
            imageData = cached
            return
        }

        isLoading = true
        BgResultNetWork<Empty, Data>(url, method: .get)
            .complicationHand { (data: Data?) in
                if let data, UIImage(data: data) != nil {
                    AvatarCache.store(data, for: url)
                    imageData = data
                }
                isLoading = false
            }
            .errorHandle { _, _ in
                isLoading = false
            }
            .response()
    }
}
