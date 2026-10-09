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

    var body: some View {
        VStack(alignment:.leading, spacing: 0) {
            // 顶部标题区
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading) {
                    Text("Hello!")
                        .font(.system(size:40, weight: .bold))
                        .foregroundStyle(Color.theme(.primary))
                        .padding(.top, 40)
                    Text("欢迎使用青木健康!👏")
                        .font(.system(size: 23))
                        .foregroundStyle(.secondary)
                        .padding(.top, 5)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 请求地址入口（未登录也能用：服务器不通时可调整）
                Button {
                    showApiSettings = true
                } label: {
                    Image(systemName: "network")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.theme(.primary))
                        .frame(width: 38, height: 38)
                }
                .padding(.top, 40)
                .padding(.trailing, 30)
                .accessibilityLabel("请求地址设置")
            }
            .padding(.horizontal, 30)
            .padding(.bottom, AppSpacing.card)

            // Tab 内容（液态玻璃容器）
            VStack(spacing: 0) {
                HStack {
                    tabItem("登录", active: loginModel.loginType == 0) {
                        loginModel.loginType = 0
                    }
                    tabItem("注册", active: loginModel.loginType == 1) {
                        loginModel.loginType = 1
                    }
                }.padding(.bottom, AppSpacing.card)
                TabView(selection: $loginModel.loginType) {
                    PasswordLogin(loginModel: loginModel).tag(0)
                    RegistTabView(loginModel: loginModel).tag(1)
                }.tabViewStyle(.page(indexDisplayMode: .never))
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.bottom, 20)
            .pageCardStyle()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                AppColor.background
                LinearGradient(
                    colors: [AppColor.primary.opacity(0.30),
                             AppColor.secondary.opacity(0.18),
                             Color.clear],
                    startPoint: .top,
                    endPoint: .center
                )
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showApiSettings) {
            ApiSettingsView()
        }
    }

    @ViewBuilder
    private func tabItem(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .center)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(active ? Color.theme(.primary) : Color(.gray))
            RoundedRectangle(cornerRadius: 2)
                .frame(width: 35, height: 4)
                .foregroundStyle(Color.theme(.primary))
                .opacity(active ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: active)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }
}

#Preview {
    Login().preferredColorScheme(.dark)
}
