//
//  PersonalCenter.swift
//  QmHealth
//
//  Created by 周荥马 on 2026/1/23.
//

import SwiftUI

struct PersonalCenter: View {
    @EnvironmentObject var globalModel: GlobalModel
    @State private var showEditProfile = false
    @State private var showAccountSwitch = false
    @State private var showDisplaySettings = false
    @State private var showGeneralSettings = false
    @State private var showHelpFeedback = false
    @State private var showLogoutConfirm = false
    @State private var isLoggingOut = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // 用户信息卡片
                UserProfileCard(
                    showEditProfile: $showEditProfile,
                    showAccountSwitch: $showAccountSwitch
                )
                .environmentObject(globalModel)

                // 设置选项
                SettingsSection(
                    showDisplaySettings: $showDisplaySettings,
                    showGeneralSettings: $showGeneralSettings,
                    showHelpFeedback: $showHelpFeedback
                )

                // 退出账号
                LogoutButton(isLoading: isLoggingOut) {
                    showLogoutConfirm = true
                }

                Color.clear.frame(height: 30)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .pageBackground()
        .ignoresSafeArea(.all, edges: .bottom)
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
                .environmentObject(globalModel)
        }
        .sheet(isPresented: $showAccountSwitch) {
            SwitchAccountView()
                .environmentObject(globalModel)
        }
        .sheet(isPresented: $showDisplaySettings) {
            DisplaySettingsView()
        }
        .sheet(isPresented: $showGeneralSettings) {
            GeneralSettingsView()
        }
        .sheet(isPresented: $showHelpFeedback) {
            HelpFeedbackView()
        }
        .alert("确认退出", isPresented: $showLogoutConfirm) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) {
                performLogout()
            }
        } message: {
            Text("确定要退出当前账号吗？")
        }
    }

    /// 退出当前账号：
    /// 1) 调 /api/users/logout（**仅当服务端确认后才继续本地切换/退出**）
    /// 2) 本地删除当前账号
    /// 3) 如果还有别的账号 → 切到最近登录的另一个，并拉新用户信息
    ///    如果没别的账号 → 跳回登录页
    ///
    /// 关键约束：服务端接口报错（网络错误/4xx/5xx）时**不**继续切账号逻辑。
    /// 因为本地存的 token 是否仍有效服务端说了算（可能是过期 token 被服务端拒绝），
    /// 此时切换会带着无效 token 走到 USER_GET，必然再失败，体验更差。
    private func performLogout() {
        guard !isLoggingOut else { return }
        isLoggingOut = true

        let current = TokenUtils.getCurrentAccount()

        BgResultNetWork<Empty, String>(apiUrl(USER_LOGOUT), method: .post)
            .complicationHand { _ in
                // 服务端确认 → 继续本地切账号/退出
                proceedLocalLogout(current: current)
            }
            .errorHandle { _, _ in
                // 服务端未确认 → 不切账号，提示用户后停住
                DispatchQueue.main.async {
                    isLoggingOut = false
                    PopManager.shared.showSimplePop(
                        title: "退出失败",
                        description: "无法连接服务器，请检查网络后重试"
                    )
                }
            }
            .responseDecodable()
    }

    /// 服务端已确认 logout 后的本地处理：删当前账号 → 切到下一个 或 跳登录页
    ///
    /// 切账号逻辑做到零等待：
    /// 1) 立即调 `switchAccount(next)` + 从 AccountInfo 构造 minimal UserDTO 写到 currentUser + isLogin=true
    ///    让 UI 立刻显示下一个账号（用本地缓存的 userName/headerImg/nickname）
    /// 2) 异步调 USER_GET 拉最新数据，成功后覆盖 currentUser（头像、昵称等可能有更新）
    /// 3) USER_GET 失败也不退回登录页（切账号已成功，token 有效），仅日志记录
    ///
    /// 没其他账号才跳登录页。
    private func proceedLocalLogout(current: String?) {
        // 拿到所有账号，移除当前账号
        var remaining = TokenUtils.getAllAccounts()
        remaining.removeAll { $0.account == current }

        if let next = remaining.first {
            // 还有别的账号 → 立即切换（不等网络）
            //
            // 关键：先删当前账号的本地存储（AccountInfo + Keychain token），
            // 否则 getAllAccounts() 还会包含刚退出的账号，B 进切换账号页时
            // "其他账号"列表里会残留 A（A 已 logout，A 的 token 在服务端已失效，
            // 切到 A 必然失败，体验差）。
            // logout 流程一定有当前账号（用户正在登出的就是这个），所以 force-unwrap 安全。
            if let currentAccount = current {
                TokenUtils.deleteToken(for: currentAccount)
            }

            _ = TokenUtils.switchAccount(next.account)

            // 用本地 AccountInfo 构造 minimal UserDTO，立刻显示下一个账号
            let immediateUser = UserDTO(
                id: next.userId,
                name: next.userName,
                nickname: next.nickname,
                gender: nil,
                birthday: nil,
                status: nil,
                certification: nil,
                headerImg: next.headerImg,
                job: nil,
                city: nil
            )
            DispatchQueue.main.async {
                globalModel.currentUser = immediateUser
                globalModel.isLogin = true
                isLoggingOut = false
                // 通知首页刷新：切完账户后首页各子模块需要重新拉数据，并清掉旧账户的脏 state
                HomeRefreshBus.shared.triggerRefresh()
                // 退出成功 + 已切换到另一个账号，给用户明确反馈
                PopManager.shared.showSimplePop(
                    title: "退出成功",
                    description: "已为您切换至 \(next.userName ?? next.nickname ?? next.account)"
                )
            }

            // 异步拉服务端最新数据，成功后覆盖（头像/昵称可能有更新）
            BgResultNetWork<Empty?, UserDTO>.post(apiUrl(USER_GET))
                .complicationHand { (userDtoOpt: UserDTO?) in
                    DispatchQueue.main.async {
                        // 拉到了就用服务端数据覆盖；UI 已经在用户（immediateUser），
                        // 没拉到也不会再退回登录页
                        if let user = userDtoOpt {
                            globalModel.currentUser = user
                            // 再次触发刷新，避免 immediateUser 是本地占位数据期间已有子模块按旧 ID 缓存了请求
                            HomeRefreshBus.shared.triggerRefresh()
                        }
                    }
                }
                .errorHandle { _, _ in
                    // 不退回登录页（已切成功），保持当前 immediateUser 显示
                    print("[退出账号] 切到 \(next.account) 后拉 USER_GET 失败，用本地缓存数据")
                }
                .responseDecodable()
        } else {
            // 没有别的账号 → 清当前账号 + 跳登录页
            TokenUtils.deleteToken()
            DispatchQueue.main.async {
                globalModel.currentUser = nil
                globalModel.isLogin = false
                isLoggingOut = false
                // 退出成功（无其他账号可切），给用户明确反馈
                PopManager.shared.showSimplePop(
                    title: "退出成功",
                    description: "已退出当前账号，请重新登录"
                )
            }
        }
    }
}

// MARK: - 退出账号按钮
struct LogoutButton: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(AppColor.error)
                        .scaleEffect(0.85)
                } else {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(isLoading ? "正在退出..." : "退出账号")
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundColor(AppColor.error)
            .frame(maxWidth: .infinity)
        }
        .disabled(isLoading)
        .buttonStyle(SecondaryActionButtonStyle())
    }
}

// MARK: - 用户信息卡片
struct UserProfileCard: View {
    @EnvironmentObject var globalModel: GlobalModel
    @Binding var showEditProfile: Bool
    @Binding var showAccountSwitch: Bool
    
    // 计算年龄
    private var age: Int? {
        guard let birthday = globalModel.currentUser?.birthday else { return nil }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let birthDate = dateFormatter.date(from: birthday) else { return nil }
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
        return ageComponents.year
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部：头像和基本信息
            HStack(spacing: 16) {
                // 头像
                PersonHeaderImage(headerImgId: .constant(globalModel.currentUser?.headerImg))
                    .frame(width: 70, height: 70)
                
                // 用户信息
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(globalModel.currentUser?.name ?? "未设置姓名")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundColor(Color("text_primary"))
                        
                        // 性别标签
                        if let gender = globalModel.currentUser?.gender {
                            Image(systemName: gender == 1 ? "person.fill" : "person.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                                .padding(5)
                                .background(
                                    Circle()
                                        .fill(gender == 1 ? Color.blue : Color.pink)
                                )
                        }
                    }
                    
                    // 年龄和其他信息
                    HStack(spacing: 10) {
                        if let calculatedAge = age {
                            HStack(spacing: 3) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color("text_secondary"))
                                Text("\(calculatedAge)岁")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color("text_secondary"))
                            }
                        }
                        
                        if let city = globalModel.currentUser?.city, !city.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color("text_secondary"))
                                Text(city)
                                    .font(.system(size: 13))
                                    .foregroundColor(Color("text_secondary"))
                            }
                        }
                    }
                }
                
                Spacer()
            }.padding(.bottom, 10)
            
            // 分隔线
            Divider()
            
            // 底部：操作按钮
            HStack(spacing: 0) {
                // 编辑资料按钮
                Button(action: { showEditProfile = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text("编辑资料")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(Color.theme(.primary))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                
                // 竖线分隔
                Rectangle()
                    .fill(Color("divider"))
                    .frame(width: 1)
                    .padding(.vertical, 8)
                
                // 切换账号按钮
                Button(action: { showAccountSwitch = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 15, weight: .semibold))
                        Text("切换账号")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(Color.theme(.primary))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
        .cardStyle()
    }
}

// MARK: - 健康数据统计
struct HealthStatsSection: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.theme(.primary))
                
                Text("健康数据")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color("text_primary"))
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            HStack(spacing: 12) {
                // 就诊记录数
                HealthStatCard(
                    icon: "cross.case.fill",
                    title: "就诊记录",
                    value: "12",
                    color: Color.theme(.primary)
                )
                
                // 预约提醒数
                HealthStatCard(
                    icon: "calendar.badge.clock",
                    title: "预约提醒",
                    value: "3",
                    color: .orange
                )
                
                // 报告单数
                HealthStatCard(
                    icon: "doc.text.fill",
                    title: "报告单",
                    value: "8",
                    color: .blue
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color("content_bg"))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// 健康统计卡片
struct HealthStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color("text_primary"))
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(Color("text_secondary"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - 功能菜单
struct FunctionMenuSection: View {
    var body: some View {
        VStack(spacing: 0) {
            MenuItemRow(
                icon: "pills.fill",
                title: "用药记录",
                iconColor: .green,
                showDivider: false
            )
        }
        .background(Color("content_bg"))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - 设置选项
struct SettingsSection: View {
    @Binding var showDisplaySettings: Bool
    @Binding var showGeneralSettings: Bool
    @Binding var showHelpFeedback: Bool

    var body: some View {
        VStack(spacing: 0) {
            MenuItemRow(
                icon: "eye.fill",
                title: "显示设置",
                iconColor: .blue,
                showDivider: true,
                action: { showDisplaySettings = true }
            )

            MenuItemRow(
                icon: "gearshape.fill",
                title: "通用设置",
                iconColor: .gray,
                showDivider: true,
                action: { showGeneralSettings = true }
            )

            // 暂时隐藏"隐私与安全"入口
//            MenuItemRow(
//                icon: "lock.shield.fill",
//                title: "隐私与安全",
//                iconColor: .red,
//                showDivider: true
//            )

            MenuItemRow(
                icon: "questionmark.circle.fill",
                title: "帮助与反馈",
                iconColor: .green,
                showDivider: false,
                action: { showHelpFeedback = true }
            )
        }
        .cardStyle()
    }
}

// MARK: - 菜单项行
struct MenuItemRow: View {
    let icon: String
    let title: String
    let iconColor: Color
    let showDivider: Bool
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                action?()
            }) {
                HStack(spacing: 12) {
                    // 图标
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(iconColor.opacity(0.12))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(iconColor)
                    }
                    
                    // 标题
                    Text(title)
                        .font(.system(size: 15))
                        .foregroundColor(Color("text_primary"))
                    
                    Spacer()
                    
                    // 箭头
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color("text_secondary").opacity(0.5))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            if showDivider {
                Divider()
                    .padding(.leading, 58)
            }
        }
    }
}

#Preview {
    PersonalCenter()
        .environmentObject(GlobalModel.shared)
}
