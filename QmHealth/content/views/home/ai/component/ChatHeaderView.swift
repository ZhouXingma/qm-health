//
//  ChatHeaderView.swift
//  QmHealth
//
//  Created by 周荥马 on 2026/2/10.
//

import SwiftUI

// 聊天顶部导航栏
struct ChatHeaderView: View {
    @EnvironmentObject var globalModel: GlobalModel
    @State private var selectedPersonName: String = ""
    @Binding var showPersonSelector: Bool
    @Binding var showHistorySidebar: Bool
    @Binding var currentSelect: Int
    
    var body: some View {
        HStack(spacing: 12) {
            HStack {
                VStack {
                    Image(systemName: "house.fill")
                        .font(.system(size: 20))
                        .padding(.bottom, 1)
                        .foregroundStyle(Color("text_primary"))
                }
                .frame(minWidth: 30, minHeight: 30)
                .padding(8)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation {
                        currentSelect = 0;
                    }
                }
                .appGlassEffect(.regular.interactive())
            }.padding(.leading, 10)

            Spacer()

            // 中间：就诊人选择器
            Button {
                showPersonSelector = true
            } label: {
                HStack(spacing: 6) {
                    // 显示头像或默认图标
                    if let headerImg = globalModel.currentUser?.headerImg, !headerImg.isEmpty {
                        AsyncPersonAvatar(headerImgId: headerImg, size: 24)
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.theme(.primary))
                    }

                    Text(selectedPersonName.isEmpty ? "选择就诊人" : selectedPersonName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color("text_primary"))

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(Color("text_secondary"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .glassPill()
            }

            Spacer()

            // 右侧：历史记录按钮
            Button {
                showHistorySidebar = true
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(Color("text_primary"))
            }
            .frame(minWidth: 30, minHeight: 30)
            .padding(8)
            .appGlassEffect(.regular.interactive())
            .padding(.trailing, 16)

        }
        .padding(.top, 50)
        .padding(.vertical, 12)
        .background(
            Color("background")
                .opacity(0.95)
                .background(.ultraThinMaterial)
        )
        .onAppear {
            updateSelectedPersonName()
        }
        .onChange(of: globalModel.currentUser?.id) { _, _ in
            updateSelectedPersonName()
        }
    }
    
    private func updateSelectedPersonName() {
        if let user = globalModel.currentUser {
            selectedPersonName = user.name ?? user.nickname ?? "未命名"
        } else {
            selectedPersonName = ""
        }
    }
}

// 就诊人选择器弹窗
struct PersonSelectorSheet: View {
    @EnvironmentObject var globalModel: GlobalModel
    @Binding var isPresented: Bool
    @State private var accounts: [UserDTO] = []
    @State private var showAddAccount = false
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color("background").ignoresSafeArea()
                
                if isLoading {
                    ProgressView("加载中...")
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            // 顶部提示
                            infoTipSection
                            
                            // 当前就诊人
                            if let currentUser = globalModel.currentUser {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("当前就诊人")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color("text_secondary"))
                                        .padding(.horizontal, 4)
                                    
                                    PersonAccountCard(
                                        user: currentUser,
                                        isCurrentUser: true,
                                        onSwitch: {},
                                        onDelete: {}
                                    )
                                }
                            }
                            
                            // 其他就诊人
                            if !accounts.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("其他就诊人")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color("text_secondary"))
                                        .padding(.horizontal, 4)
                                    
                                    ForEach(accounts, id: \.id) { account in
                                        PersonAccountCard(
                                            user: account,
                                            isCurrentUser: false,
                                            onSwitch: {
                                                switchToAccount(account)
                                            },
                                            onDelete: {}
                                        )
                                    }
                                }
                            }
                            
                            // 添加就诊人卡片
                            AddPersonCard {
                                showAddAccount = true
                            }
                            
                            Color.clear.frame(height: 30)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                }
            }
            .navigationTitle("选择就诊人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            loadAccounts()
        }
        .sheet(isPresented: $showAddAccount, onDismiss: {
            loadAccounts()
        }) {
            AddAccountView()
                .environmentObject(globalModel)
        }
        .presentationDetents([.large])
    }
    
    // MARK: - 顶部提示区域
    private var infoTipSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 40, height: 40)
                    .appGlass(.clear.tint(Color.blue.opacity(0.2)), in: Circle()) {
                        Circle().fill(Color.blue.opacity(0.15))
                    }

                Image(systemName: "person.2.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("就诊人管理")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color("text_primary"))

                Text("为不同家庭成员创建档案，AI 将基于对应档案提供建议")
                    .font(.system(size: 12))
                    .foregroundColor(Color("text_secondary"))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
        .appGlass(.clear.tint(Color.blue.opacity(0.12)),
                  in: RoundedRectangle(cornerRadius: 12, style: .continuous)) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.blue.opacity(0.08))
        }
    }
    
    // MARK: - 数据操作方法
    private func loadAccounts() {
        let accountInfos = TokenUtils.getAllAccounts()
        let currentAccount = TokenUtils.getCurrentAccount()
        
        accounts = accountInfos
            .filter { $0.account != currentAccount }
            .compactMap { accountInfo in
                let displayName = accountInfo.userName ?? accountInfo.nickname
                
                return UserDTO(
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
            }
    }
    
    private func switchToAccount(_ account: UserDTO) {
        guard let userId = account.id else { return }
        
        let allAccountInfos = TokenUtils.getAllAccounts()
        guard let accountInfo = allAccountInfos.first(where: { $0.userId == userId }) else {
            PopManager.shared.showSimplePop(title: "提示", description: "未找到账号信息")
            return
        }
        
        let success = TokenUtils.switchAccount(accountInfo.account)
        
        if success {
            isLoading = true
            
            BgResultNetWork<Empty?, UserDTO>.post(apiUrl(USER_GET))
                .complicationHand { (userDto: UserDTO?) in
                    DispatchQueue.main.async {
                        isLoading = false
                        
                        guard let userDto = userDto else {
                            PopManager.shared.showSimplePop(title: "提示", description: "切换就诊人失败")
                            return
                        }
                        
                        globalModel.currentUser = userDto

                        // 通知首页刷新：切完账户后首页各子模块需要重新拉数据，并清掉旧账户的脏 state
                        HomeRefreshBus.shared.triggerRefresh()

                        TokenUtils.updateAccountInfo(
                            account: accountInfo.account,
                            userName: userDto.name,
                            headerImg: userDto.headerImg
                        )

                        isPresented = false
                    }
                }
                .errorHandle { (result, error) in
                    DispatchQueue.main.async {
                        isLoading = false
                        PopManager.shared.showSimplePop(title: "提示", description: "切换就诊人失败：\(error)")
                    }
                }
                .responseDecodable()
        } else {
            PopManager.shared.showSimplePop(title: "提示", description: "账号token已失效，请重新登录")
        }
    }
}

// MARK: - 就诊人账号卡片
struct PersonAccountCard: View {
    let user: UserDTO
    let isCurrentUser: Bool
    let onSwitch: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // 头像
            if let headerImg = user.headerImg, !headerImg.isEmpty {
                AsyncPersonAvatar(headerImgId: headerImg, size: 50)
            } else {
                ZStack {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 50, height: 50)
                        .appGlass(.clear.tint(Color.theme(.primary).opacity(0.18)), in: Circle()) {
                            Circle().fill(Color.theme(.primary).opacity(0.15))
                        }

                    Image(systemName: "person.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color.theme(.primary))
                }
            }

            // 用户信息
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(user.name ?? user.nickname ?? "未命名")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color("text_primary"))

                    if isCurrentUser {
                        Text("当前")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .glassPillColor(.clear.interactive(), Color.theme(.primary))
                    }
                }

                if let nickname = user.nickname, user.name != nickname {
                    Text(nickname)
                        .font(.system(size: 13))
                        .foregroundColor(Color("text_secondary"))
                }
            }

            Spacer()

            // 操作按钮
            if !isCurrentUser {
                Button {
                    onSwitch()
                } label: {
                    Text("切换")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.theme(.primary))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .glassPillColor(.clear.interactive(), Color.theme(.primary).opacity(0.12))
            }
        }
        .padding(14)
        .glassContainer(cornerRadius: 12)
    }
}

// MARK: - 添加就诊人卡片
struct AddPersonCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 50, height: 50)
                        .appGlass(.clear.tint(Color.theme(.primary).opacity(0.18)), in: Circle()) {
                            Circle().fill(Color.theme(.primary).opacity(0.15))
                        }

                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(Color.theme(.primary))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("添加就诊人")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color("text_primary"))

                    Text("为家人创建新的健康档案")
                        .font(.system(size: 13))
                        .foregroundColor(Color("text_secondary"))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Color("text_secondary"))
            }
            .padding(14)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .glassContainer(cornerRadius: 12)
        }
    }
}

// MARK: - 异步加载头像组件
struct AsyncPersonAvatar: View {
    let headerImgId: String
    let size: CGFloat

    @State private var imageData: Data?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: size, height: size)
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
                                    .font(.system(size: size * 0.5))
                                    .foregroundColor(Color.theme(.primary))
                            }
                        }
                    )
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: headerImgId) { _, _ in
            loadImage()
        }
        .id(headerImgId) // 添加 id 确保当 headerImgId 改变时重新创建视图
    }
    
    private func loadImage() {
        guard !headerImgId.isEmpty else { 
            imageData = nil
            return 
        }
        
        isLoading = true
        let url = apiUrl(FILE_LOAD + "/\(headerImgId)")
        
        BgResultNetWork<Empty, Data>(url, method: .get)
            .complicationHand { (data: Data?) in
                DispatchQueue.main.async {
                    self.imageData = data
                    self.isLoading = false
                }
            }
            .errorHandle { _, _ in
                DispatchQueue.main.async {
                    self.imageData = nil
                    self.isLoading = false
                }
            }
            .response()
    }
}

#Preview {
    @Previewable @State var selection:Int = 0
    ChatHeaderView(showPersonSelector: .constant(false), showHistorySidebar: .constant(false), currentSelect: $selection)
        .environmentObject(GlobalModel.shared)
}
