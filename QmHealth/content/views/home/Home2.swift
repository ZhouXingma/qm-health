//
//  Home2.swift
//  QmHealth
//  Home2 首页：固定顶部信息，通栏肖像，疾病/过敏浮层在左右上角，上滑进入今日模块
//

import SwiftUI

struct Home2: View {
    @EnvironmentObject var globalModel: GlobalModel
    @StateObject private var refreshBus = HomeRefreshBus.shared
    /// 冷启动时系统会恢复上次滚动位置，首次出现时拉回顶部
    @State private var didResetScroll = false

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        Color.clear
                            .frame(height: 0)
                            .id("home2.top")

                        // 通栏个人肖像动画（9:16 原比例），疾病 / 过敏源浮在左右上角
                        ZStack(alignment: .top) {
                            PortraitHeroView(user: globalModel.currentUser, width: geo.size.width)

                            Home2SidePanels()
                                .padding(.horizontal, 14)
                                .padding(.top, 14)
                        }

                        // 上滑后展示：今日任务、健康曲线、饮水、指标
                        VStack(spacing: 20) {
                            DailyHealthTaskView()
                            HealthCurveTabView()
                            WaterIntakeView()
                            HealthIndicatorsView()

                            Color.clear.frame(height: 110)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                    }
                    .padding(.top, 0)
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    headerBar
                }
                .refreshable {
                    await refreshAll()
                }
                .onAppear {
                    guard !didResetScroll else { return }
                    didResetScroll = true
                    DispatchQueue.main.async {
                        proxy.scrollTo("home2.top", anchor: .top)
                    }
                }
            }
        }
        .glassBackground()
        .environmentObject(refreshBus)
    }

    /// 固定顶部：液态玻璃条，内容从下方滚过
    private var headerBar: some View {
        HStack(alignment: .top, spacing: 8) {
            HeaderOfPersonInfo(showsAge: true, allowsNameToggle: true)
            MessageNotificationView()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .appGlass(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous)) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppColor.content.opacity(0.82))
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    /// 下拉刷新：通知所有子组件 reload；用短暂 sleep 让 loading 指示器有展示时间
    private func refreshAll() async {
        refreshBus.triggerRefresh()
        try? await Task.sleep(nanoseconds: 600_000_000)
    }
}

#Preview {
    let globalModel = GlobalModel.shared
    globalModel.currentUser = UserDTO(
        id: "01K1B6DDV396NMC01NM3MZ35KS",
        name: "周荥马",
        nickname: "U1753796228",
        gender: 1,
        birthday: "1994-02-16",
        status: 0,
        certification: 1,
        headerImg: "person.circle.fill",
        job: "软件工程师",
        city: "北京市",
        blood: 1,
        bloodRh: 1,
        nationality: 1,
        maritalStatus: 1
    )
    return Home2().environmentObject(globalModel)
}
