//
//  Login.swift
//  qm_health
//
//  Created by 周荥马 on 2025/2/22.
//

import SwiftUI

struct Login: View {
    @EnvironmentObject var globalModel:GlobalModel;
    // 登录页显示提示
    @StateObject private var loginModel = LoginModel();
    // 请求地址设置 sheet（未登录也能访问）
    @State private var showApiSettings: Bool = false;
    // 登录 / 注册切换指示器
    @Namespace private var tabIndicator;

    var body: some View {
        VStack(alignment:.leading, spacing: 0) {
            header
            authPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { authBackground }
        .sheet(isPresented: $showApiSettings) {
            ApiSettingsView()
        }
    }

    // MARK: - 顶部标题区
    private var header: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Hello!")
                    .font(.system(size:40, weight: .bold))
                    .foregroundStyle(Color.theme(.primary))
                Text("欢迎使用青木健康!👏")
                    .font(.system(size: 22))
                    .foregroundStyle(AppColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 请求地址入口（未登录也能用：服务器不通时可调整）
            Button {
                showApiSettings = true
            } label: {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 40, height: 40)
                    .appGlass(.clear.tint(Color.theme(.primary).opacity(0.14)).interactive(), in: Circle()) {
                        Circle().fill(AppColor.content.opacity(0.5))
                    }
                    .overlay {
                        Image(systemName: "network")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.theme(.primary))
                    }
            }
            .accessibilityLabel("请求地址设置")
        }
        .padding(.horizontal, 30)
        .padding(.top, 40)
        .padding(.bottom, AppSpacing.card)
    }

    // MARK: - 登录 / 注册面板
    private var authPanel: some View {
        VStack(spacing: 0) {
            tabBar
                .padding(.top, 18)
                .padding(.bottom, AppSpacing.card)

            TabView(selection: $loginModel.loginType) {
                PasswordLogin(loginModel: loginModel).tag(0)
                RegistTabView(loginModel: loginModel).tag(1)
            }.tabViewStyle(.page(indexDisplayMode: .never))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .authPanelStyle()
    }

    // MARK: - Tab 切换
    private var tabBar: some View {
        HStack(spacing: 4) {
            tabItem("登录", index: 0)
            tabItem("注册", index: 1)
        }
        .padding(4)
        .background(
            Capsule(style:.continuous).fill(Color.theme(.primary).opacity(0.10))
        )
        .padding(.horizontal, AppSpacing.screen)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: loginModel.loginType)
    }

    @ViewBuilder
    private func tabItem(_ title: String, index: Int) -> some View {
        let active = loginModel.loginType == index
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                loginModel.loginType = index
            }
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(active ? Color.theme(.primary) : Color.theme(.primary).opacity(0.55))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    if active {
                        Capsule(style: .continuous)
                            .fill(AppColor.content)
                            .matchedGeometryEffect(id: "authTabIndicator", in: tabIndicator)
                            .appShadow(AppShadow.card)
                    }
                }
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 背景
    private var authBackground: some View {
        ZStack {
            AppColor.background
            LinearGradient(
                colors: [AppColor.primary.opacity(0.34),
                         AppColor.secondary.opacity(0.20),
                         Color.clear],
                startPoint: .top,
                endPoint: .center
            )
            // 顶部两处柔光，让暖色背景有层次而不是一块纯色
            Circle()
                .fill(AppColor.secondary.opacity(0.40))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(x: -110, y: -70)
            Circle()
                .fill(AppColor.primary.opacity(0.22))
                .frame(width: 200, height: 200)
                .blur(radius: 80)
                .offset(x: 130, y: 10)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    Login().preferredColorScheme(.dark)
}
