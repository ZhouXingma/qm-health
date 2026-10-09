//
//  PasswordLogin.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/2/27.
//

import SwiftUI

struct PasswordLogin: View {
    // 登录的账号
    @State private var account: String = ""
    // 登录的密码
    @State private var password: String = ""
    // 是否显示密码
    @State private var showPassword: Bool = false;
    // 是否同意协议
    @State private var isAgreen: Bool = false
    // 是否在登录操作中
    @State private var loginHandleIn = false;
    // 信息
    @ObservedObject var loginModel:LoginModel
    // 环境变量
    @EnvironmentObject var globalModel:GlobalModel;

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.regular) {
                HStack(spacing: AppSpacing.compact) {
                    TextField("手机号/邮箱", text: $account)
                        .padding(.horizontal, AppSpacing.compact)
                }
                .frame(maxWidth:.infinity, alignment: .leading)
                .inputFieldStyle()
                .padding(.horizontal, AppSpacing.screen)

                HStack(spacing: AppSpacing.compact) {
                    if showPassword {
                        TextField("输入密码", text: $password)
                            .textContentType(.oneTimeCode)
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.never)
                            .padding(.leading, AppSpacing.compact)
                    } else {
                        SecureField("输入密码", text: $password)
                            .textContentType(.oneTimeCode)
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.never)
                            .padding(.leading, AppSpacing.compact)
                    }
                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye" : "eye.slash")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.black)
                            .padding(.trailing, AppSpacing.compact)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth:.infinity, alignment: .leading)
                .inputFieldStyle()

                .padding(.horizontal, AppSpacing.screen)

                AggreenView(isAgreen: $isAgreen)

                Button {
                    login()
                } label: {
                    HStack(spacing: AppSpacing.compact) {
                        if loginHandleIn {
                            ProgressView().tint(.white)
                        }
                        Text("登录")
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(loginButtonIsDisable())
                .opacity(loginButtonIsDisable() ? 0.5 : 1.0)
                .padding(.horizontal, AppSpacing.screen)
                .padding(.top, AppSpacing.compact)
            }
            .padding(.bottom, AppSpacing.card)
        }.onChange(of: loginModel.loginType) { oldValue, newValue in
            if newValue != 0 {
                account = "";
                password = "";
                isAgreen = false;
            }
        }
    }

    // 登录按钮是否禁用
    func loginButtonIsDisable() -> Bool {
        // 账户为空
        return StringUtils.isBlank(account) || password.count == 0 || !isAgreen || loginHandleIn
    }

    // 登录操作
    func login() {
        KeyBoardUtils.toHideKeyboard();
        loginHandleIn = true;
        // 1、密码加密
        let passwordMd5 = EncryptionUtil.md5(password);
        let param:[String: String] = ["account": account, "password": passwordMd5]

        // 如果后端返回的是LoginResponse对象
        BgResultNetWork<[String: String], LoginResponse>.post(apiUrl(USER_LOGIN), params: param)
            .complicationHand { [self] (response: LoginResponse?) in
                if let response = response {
                    DispatchQueue.main.async {
                        // 保存token和账号信息
                        let success = TokenUtils.saveToken(
                            account,
                            response.token,
                            userId: response.userId,
                            userName: response.userName,
                            nickname: response.nickname,
                            headerImg: response.headerImg
                        )

                        if success {
                            globalModel.isLogin = true
                        }
                    }
                }
            }
            .finalHandleFunc { _ in
                DispatchQueue.main.async {
                    self.loginHandleIn = false
                }
            }
            .responseDecodable()

        // 如果后端只返回token字符串，使用下面的代码
        /*
        BgResultNetWork<[String: String], String>.post(apiUrl(USER_LOGIN), params: param)
            .complicationHand { [self] (token: String?) in
                if let token = token {
                    DispatchQueue.main.async {
                        // 先保存token（userId暂时用account代替）
                        let success = TokenUtils.saveToken(
                            account,
                            token,
                            userId: account,  // 如果后端没返回userId，暂时用account
                            userName: nil,
                            headerImg: nil
                        )

                        if success {
                            globalModel.isLogin = true
                        }
                    }
                }
            }
            .finalHandleFunc { _ in
                DispatchQueue.main.async {
                    self.loginHandleIn = false
                }
            }
            .responseDecodable()
        */
    }

}
