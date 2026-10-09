//
//  SwitchAccountView.swift
//  QmHealth
//
//  Created by 周荥马 on 2026/1/23.
//

import SwiftUI

struct SwitchAccountView: View {
    @EnvironmentObject var globalModel: GlobalModel
    @Environment(\.dismiss) private var dismiss
    
    // 模拟账号列表（实际应该从后端获取）
    @State private var accounts: [UserDTO] = []
    @State private var showAddAccount = false
    @State private var showDeleteConfirm = false
    @State private var accountToDelete: UserDTO?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color("background").ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // 顶部提示
                        infoTipSection
                        
                        // 当前账号
                        if let currentUser = globalModel.currentUser {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("当前账号")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color("text_secondary"))
                                    .padding(.horizontal, 4)
                                
                                AccountCard(
                                    user: currentUser,
                                    isCurrentUser: true,
                                    onSwitch: {},
                                    onDelete: {}
                                )
                            }
                        }
                        
                        // 其他账号
                        if !accounts.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("其他账号")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color("text_secondary"))
                                    .padding(.horizontal, 4)
                                
                                ForEach(accounts, id: \.id) { account in
                                    AccountCard(
                                        user: account,
                                        isCurrentUser: false,
                                        onSwitch: {
                                            switchToAccount(account)
                                        },
                                        onDelete: {
                                            accountToDelete = account
                                            showDeleteConfirm = true
                                        }
                                    )
                                }
                            }
                        }
                        
                        // 添加账号卡片
                        AddAccountCard {
                            showAddAccount = true
                        }
                        
                        Color.clear.frame(height: 30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .navigationTitle("切换账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadAccounts()
        }
        .sheet(isPresented: $showAddAccount, onDismiss: {
            // 添加账号页面关闭后重新加载账号列表
            loadAccounts()
        }) {
            AddAccountView()
                .environmentObject(globalModel)
        }
        .alert("删除账号", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let account = accountToDelete {
                    deleteAccount(account)
                }
            }
        } message: {
            if let accountName = accountToDelete?.name {
                Text("确定要删除账号「\(accountName)」吗？删除后该账号的所有数据将被清除。")
            } else {
                Text("确定要删除该账号吗？删除后该账号的所有数据将被清除。")
            }
        }
    }
    
    // MARK: - 顶部提示区域
    private var infoTipSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: "info.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("账号管理")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color("text_primary"))

                Text("您可以为家人创建多个健康档案，方便管理")
                    .font(.system(size: 12))
                    .foregroundColor(Color("text_secondary"))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .fill(Color.blue.opacity(0.08))
        )
        .appShadow(AppShadow.card)
    }
    
    // MARK: - 数据操作方法
    private func loadAccounts() {
        // 从TokenUtils获取所有已登录账号
        let accountInfos = TokenUtils.getAllAccounts()
        
        // 转换为UserDTO列表（排除当前账号）
        let currentAccount = TokenUtils.getCurrentAccount()
        
        print("currentAccount:\(try? JSONFormatUtil.defaultInstall.encodeToString(currentAccount))")
        print("accountInfos:\(try? JSONFormatUtil.defaultInstall.encodeToString(accountInfos))")
        
        accounts = accountInfos
            .filter { $0.account != currentAccount }
            .compactMap { accountInfo in
                // 优先显示userName，如果没有则显示nickname
                let displayName = accountInfo.userName ?? accountInfo.nickname
                
                let user = UserDTO(
                    id: accountInfo.userId,
                    name: displayName,
                    nickname: accountInfo.nickname,
                    gender: nil,
                    birthday: nil,
                    status: nil,
                    certification: nil,
                    headerImg: accountInfo.headerImg,
                    job: nil,
                    city: nil
                )
                return user
            }
    }
    
    private func switchToAccount(_ account: UserDTO) {
        guard let userId = account.id else { return }
        
        // 查找对应的账号信息
        let allAccountInfos = TokenUtils.getAllAccounts()
        guard let accountInfo = allAccountInfos.first(where: { $0.userId == userId }) else {
            print("未找到账号信息")
            return
        }
        
        // 切换账号
        let success = TokenUtils.switchAccount(accountInfo.account)
        
        if success {
            // 重新加载用户信息
            BgResultNetWork<Empty?, UserDTO>.post(apiUrl(USER_GET))
                .complicationHand { [self] (userDto: UserDTO?) in
                    guard let userDto = userDto else {
                        DispatchQueue.main.async {
                            PopManager.shared.showSimplePop(title: "提示", description: "切换账号失败")
                        }
                        return
                    }
                    
                    DispatchQueue.main.async {
                        // 更新全局用户信息
                        globalModel.currentUser = userDto

                        // 通知首页刷新：切完账户后首页各子模块需要重新拉数据，并清掉旧账户的脏 state
                        HomeRefreshBus.shared.triggerRefresh()

                        // 更新账号信息缓存
                        TokenUtils.updateAccountInfo(
                            account: accountInfo.account,
                            userName: userDto.name,
                            headerImg: userDto.headerImg
                        )

                        // 关闭页面
                        dismiss()
                    }
                }
                .errorHandle { (result, error) in
                    DispatchQueue.main.async {
                        PopManager.shared.showSimplePop(title: "提示", description: "切换账号失败：\(error)")
                    }
                }
                .responseDecodable()
        } else {
            PopManager.shared.showSimplePop(title: "提示", description: "账号token已失效，请重新登录")
        }
    }
    
    private func deleteAccount(_ account: UserDTO) {
        guard let userId = account.id else { return }
        
        // 查找对应的账号信息
        let allAccountInfos = TokenUtils.getAllAccounts()
        guard let accountInfo = allAccountInfos.first(where: { $0.userId == userId }) else {
            return
        }
        
        // 删除账号
        TokenUtils.deleteToken(for: accountInfo.account)
        
        // 从列表中移除
        accounts.removeAll { $0.id == userId }
    }
}

#Preview {
    SwitchAccountView()
        .environmentObject(GlobalModel.shared)
}
