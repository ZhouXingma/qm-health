//
//  PortraitHeroView.swift
//  QmHealth
//  Home2 通栏肖像：按用户年龄 / 性别匹配 9:16 动画
//

import SwiftUI

struct PortraitHeroView: View {
    @Environment(\.colorScheme) private var colorScheme
    let user: UserDTO?
    /// 通栏宽度（视频按 9:16 等比撑满）
    let width: CGFloat

    private var age: Int? {
        PortraitAnimation.age(from: user?.birthday)
    }

    private var assetName: String {
        PortraitAnimation.assetName(age: age, gender: user?.gender)
    }

    var body: some View {
        let height = width * 16 / 9

        PortraitVideoView(assetName: assetName)
            .frame(width: width, height: height)
            .overlay {
                // 暗色模式下压一点亮度，避免整块浅色视频过于刺眼
                Color.black.opacity(colorScheme == .dark ? 0.08 : 0)
                    .allowsHitTesting(false)
            }
            .mask(
                // 上下淡出，让通栏肖像与页面底色自然衔接
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.05),
                        .init(color: .black, location: 0.88),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(maxWidth: .infinity)
    }
}

#Preview {
    PortraitHeroView(
        user: UserDTO(
            id: "preview",
            name: "周荥马",
            gender: 1,
            birthday: "1994-02-16",
            city: "北京市",
            blood: 1,
            bloodRh: 1
        ),
        width: 402
    )
    .glassBackground()
}
