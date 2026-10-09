//
//  AddAccountView.swift
//  QmHealth
//
//  Created by 周荥马 on 2026/1/23.
//

import SwiftUI

struct AddAccountView: View {
    @EnvironmentObject var globalModel: GlobalModel
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var loginModel = LoginModel()
    @StateObject private var popManager = PopManager()
    @State private var selectedTab = 0  // 0: 登录, 1: 注册
    
    var body: some View {
        NavigationView {
            ZStack {
                // 渐变背景
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.theme(.primary).opacity(0.05),
                        Color("background")
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 顶部装饰和Tab切换
                    VStack(spacing: 20) {
                        // 图标装饰
                        ZStack {
                            Circle()
                                .fill(Color.theme(.primary).opacity(0.12))
                                .frame(width: 80, height: 80)

                            Image(systemName: "person.2.badge.gearshape")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundColor(Color.theme(.primary))
                        }
                        .padding(.top, 20)
                        
                        Text("添加家人账号")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color("text_primary"))
                        
                        Text("为家人创建或登录健康档案")
                            .font(.system(size: 14))
                            .foregroundColor(Color("text_secondary"))
                        
                        // Tab选择器
                        tabSelector
                    }
                    .padding(.bottom, 10)
                    
                    // 内容区域
                    TabView(selection: $selectedTab) {
                        // 登录页面
                        AddAccountLoginView(
                            loginModel: loginModel,
                            popManager: popManager,
                            onSuccess: { userId in
                                switchToAccount(userId)
                                dismiss()
                            }
                        )
                        .tag(0)
                        .environmentObject(globalModel)
                        
                        // 注册页面
                        AddAccountRegisterView(
                            loginModel: loginModel,
                            popManager: popManager,
                            onSuccess: { userId in
                                switchToAccount(userId)
                                dismiss()
                            }
                        )
                        .tag(1)
                        .environmentObject(globalModel)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                            Text("关闭")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(Color.theme(.primary))
                    }
                }
            }
        }
        .withLocalPop(popManager)
        .onChange(of: selectedTab) { oldValue, newValue in
            loginModel.loginType = newValue
        }
    }
    
    // MARK: - Tab选择器
    private var tabSelector: some View {
        HStack(spacing: 12) {
            // 登录Tab
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    selectedTab = 0
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 14, weight: .semibold))
                    Text("已有账号")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(selectedTab == 0 ? .white : Color.theme(.primary))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(selectedTab == 0 ? Color.theme(.primary) : Color.clear)
                )
                .overlay(
                    Capsule().stroke(selectedTab == 0 ? Color.clear : Color.theme(.primary), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())

            // 注册Tab
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    selectedTab = 1
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text("创建新账号")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(selectedTab == 1 ? .white : Color.theme(.primary))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(selectedTab == 1 ? Color.theme(.primary) : Color.clear)
                )
                .overlay(
                    Capsule().stroke(selectedTab == 1 ? Color.clear : Color.theme(.primary), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
    }
    
    private func switchToAccount(_ userId: String) {
        // 查找对应的账号信息
        let allAccountInfos = TokenUtils.getAllAccounts()
        guard let accountInfo = allAccountInfos.first(where: { $0.userId == userId }) else {
            print("未找到账号信息111")
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
    
}

// MARK: - 添加账号登录视图
struct AddAccountLoginView: View {
    @EnvironmentObject var globalModel: GlobalModel
    @ObservedObject var loginModel: LoginModel
    @ObservedObject var popManager: PopManager
    let onSuccess: (_ account:String) -> Void
    
    @State private var account: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var isAgreen: Bool = false
    @State private var loginHandleIn = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // 表单卡片
                VStack(spacing: 16) {
                    // 账号输入
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color.theme(.primary))
                            Text("账号")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color("text_secondary"))
                        }

                        TextField("手机号或邮箱", text: $account)
                            .font(.system(size: 16))
                            .inputFieldStyle()
                    }

                    // 密码输入
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color.theme(.primary))
                            Text("密码")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color("text_secondary"))
                        }

                        HStack {
                            if showPassword {
                                TextField("请输入密码", text: $password)
                                    .font(.system(size: 16))
                                    .textContentType(.oneTimeCode)
                                    .autocorrectionDisabled(true)
                                    .textInputAutocapitalization(.never)
                            } else {
                                SecureField("请输入密码", text: $password)
                                    .font(.system(size: 16))
                                    .textContentType(.oneTimeCode)
                                    .autocorrectionDisabled(true)
                                    .textInputAutocapitalization(.never)
                            }

                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.fill" : "eye.slash.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color("text_secondary"))
                            }
                        }
                        .inputFieldStyle()
                    }
                }
                .cardStyle()

                // 协议
                AggreenView(isAgreen: $isAgreen)
                    .padding(.horizontal, 20)

                // 登录按钮
                Button(action: login) {
                    Text("登录并添加").foregroundStyle(loginButtonIsDisable() ? AppColor.secondary : AppColor.primary)
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .disabled(loginButtonIsDisable())
                .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.top, 20)
            .padding(.horizontal,20)
        }
        .onChange(of: loginModel.loginType) { oldValue, newValue in
            if newValue != 0 {
                account = ""
                password = ""
                isAgreen = false
            }
        }
    }
    
    private func loginButtonIsDisable() -> Bool {
        return StringUtils.isBlank(account) || password.count == 0 || !isAgreen || loginHandleIn
    }
    
    private func login() {
        KeyBoardUtils.toHideKeyboard()
        loginHandleIn = true
        
        let passwordMd5 = EncryptionUtil.md5(password)
        let param: [String: String] = ["account": account, "password": passwordMd5]
        
        BgResultNetWork<[String: String], LoginResponse>.post(apiUrl(USER_LOGIN), params: param)
            .complicationHand { [self] (response: LoginResponse?) in
                if let response = response {
                    DispatchQueue.main.async {
                        let success = TokenUtils.saveToken(
                            account,
                            response.token,
                            userId: response.userId,
                            userName: response.userName,
                            nickname: response.nickname,
                            headerImg: response.headerImg
                        )
                        
                        if success {
                            popManager.showSimplePop(title: "成功", description: "账号添加成功")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                onSuccess(response.userId)
                            }
                        }
                    }
                }
            }
            .errorHandle { [self] (result, error) in
                DispatchQueue.main.async {
                    let errorMessage: String
                    switch error {
                    case .timeout(_, let msg): errorMessage = msg
                    case .network(_, let msg): errorMessage = msg
                    case .parameter(_, let msg): errorMessage = msg
                    case .parsing(_, let msg): errorMessage = msg
                    case .http(_, let msg): errorMessage = msg
                    case .validation(_, let msg): errorMessage = msg
                    case .requestError(_, let msg): errorMessage = msg
                    case .unknown(_, let msg): errorMessage = msg
                    }
                    popManager.showSimplePop(title: "登录失败", description: errorMessage)
                }
            }
            .finalHandleFunc { _ in
                DispatchQueue.main.async {
                    self.loginHandleIn = false
                }
            }
            .responseDecodable()
    }
}

// MARK: - 添加账号注册视图
struct AddAccountRegisterView: View {
    @EnvironmentObject var globalModel: GlobalModel
    @ObservedObject var loginModel: LoginModel
    @ObservedObject var popManager: PopManager
    let onSuccess: (_ userId:String) -> Void
    
    @State private var registAccount: String = ""
    @State private var registPassword1: String = ""
    @State private var registPassword2: String = ""
    @State private var showPassword: Bool = false
    @State private var isAgreen: Bool = false
    @State private var registHandleIn: Bool = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // 表单卡片
                VStack(spacing: 16) {
                    // 账号输入
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color.theme(.primary))
                            Text("账号")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color("text_secondary"))
                        }

                        TextField("手机号或邮箱", text: $registAccount)
                            .font(.system(size: 16))
                            .inputFieldStyle()
                    }

                    // 密码输入
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color.theme(.primary))
                            Text("设置密码")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color("text_secondary"))
                        }

                        HStack {
                            if showPassword {
                                TextField("请设置密码", text: $registPassword1)
                                    .font(.system(size: 16))
                                    .textContentType(.oneTimeCode)
                                    .autocorrectionDisabled(true)
                                    .textInputAutocapitalization(.never)
                            } else {
                                SecureField("请设置密码", text: $registPassword1)
                                    .font(.system(size: 16))
                                    .textContentType(.oneTimeCode)
                                    .autocorrectionDisabled(true)
                                    .textInputAutocapitalization(.never)
                            }

                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.fill" : "eye.slash.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color("text_secondary"))
                            }
                        }
                        .inputFieldStyle()
                    }

                    // 确认密码
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color.theme(.primary))
                            Text("确认密码")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color("text_secondary"))
                        }

                        HStack {
                            if showPassword {
                                TextField("请再次输入密码", text: $registPassword2)
                                    .font(.system(size: 16))
                                    .textContentType(.oneTimeCode)
                                    .autocorrectionDisabled(true)
                                    .textInputAutocapitalization(.never)
                            } else {
                                SecureField("请再次输入密码", text: $registPassword2)
                                    .font(.system(size: 16))
                                    .textContentType(.oneTimeCode)
                                    .autocorrectionDisabled(true)
                                    .textInputAutocapitalization(.never)
                            }

                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.fill" : "eye.slash.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color("text_secondary"))
                            }
                        }
                        .inputFieldStyle()
                    }
                }
                .cardStyle()

                // 协议
                AggreenView(isAgreen: $isAgreen)
                    .padding(.horizontal, 20)
                
                // 注册按钮
                Button(action: regist) {
                    Text("注册并添加").foregroundStyle(registerButtonIsDisable() ? AppColor.secondary : AppColor.primary)
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .disabled(registerButtonIsDisable())
                .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.top, 20)
            .padding(.horizontal,20)
        }
        .onChange(of: loginModel.loginType) { oldValue, newValue in
            if newValue != 1 {
                registAccount = ""
                registPassword1 = ""
                registPassword2 = ""
                isAgreen = false
            }
        }
    }
    
    private func registerButtonIsDisable() -> Bool {
        return StringUtils.isBlank(registAccount) || registPassword1.count == 0 || registPassword2.count == 0 || !isAgreen || registHandleIn
    }
    
    private func regist() {
        KeyBoardUtils.toHideKeyboard()
        registHandleIn = true
        
        if !ValidationUtil.isValidPhoneNumber(registAccount) && !ValidationUtil.isValidEmail(registAccount) {
            popManager.showSimplePop(title: "温馨提示", description: "账号必须是手机号或者邮箱")
            registHandleIn = false
            return
        }
        
        if registPassword1 != registPassword2 {
            popManager.showSimplePop(title: "温馨提示", description: "两遍输入的密码不一致")
            registHandleIn = false
            return
        }
        
        let validatePasswordResult = ValidationUtil.validatePassword(registPassword1)
        switch validatePasswordResult {
        case .failure(let e):
            popManager.showSimplePop(title: "抱歉！", description: e.rawValue)
            registHandleIn = false
            return
        case .success(_):
            break
        }
        
        let password = EncryptionUtil.md5(registPassword1)
        var param: [String: String] = [:]
        param["account"] = registAccount
        param["password"] = password
        
        BgResultNetWork<[String: String], LoginResponse>.post(apiUrl(USER_REGISTER), params: param)
            .complicationHand { [self] (response: LoginResponse?) in
                if let response = response {
                    let success = TokenUtils.saveToken(
                        registAccount,
                        response.token,
                        userId: response.userId,
                        userName: response.userName,
                        nickname: response.nickname,
                        headerImg: response.headerImg
                    )
                    
                    if success {
                        DispatchQueue.main.async {
                            popManager.showSimplePop(title: "成功", description: "注册成功，账号已添加")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                onSuccess(response.userId)
                            }
                        }
                    }
                }
            }
            .errorHandle { [self] (result, error) in
                DispatchQueue.main.async {
                    let errorMessage: String
                    switch error {
                    case .timeout(_, let msg): errorMessage = msg
                    case .network(_, let msg): errorMessage = msg
                    case .parameter(_, let msg): errorMessage = msg
                    case .parsing(_, let msg): errorMessage = msg
                    case .http(_, let msg): errorMessage = msg
                    case .validation(_, let msg): errorMessage = msg
                    case .requestError(_, let msg): errorMessage = msg
                    case .unknown(_, let msg): errorMessage = msg
                    }
                    popManager.showSimplePop(title: "注册失败", description: errorMessage)
                }
            }
            .finalHandleFunc { (br: BgResult<LoginResponse>?) in
                DispatchQueue.main.async {
                    self.registHandleIn = false
                }
            }
            .responseDecodable()
    }
}

#Preview {
    AddAccountView()
        .environmentObject(GlobalModel.shared)
}
