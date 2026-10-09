//
//  RegisterView.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/2/27.
//

import SwiftUI

struct RegistTabView: View {
    // 注册的账号
    @State private var registAccount:String = ""
    // 注册的密码
    @State private var registPassword1:String = ""
    // 注册的确认密码
    @State private var registPassword2:String = ""
    // 是否显示密码
    @State private var showPassword:Bool = false
    // 是否同意协议
    @State private var isAgreen: Bool = false
    // 注册是否在处理中
    @State private var registHandleIn: Bool = false
    // 信息
    @ObservedObject var loginModel:LoginModel
    // 环境变量
    @EnvironmentObject var globalModel:GlobalModel;

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.regular) {
                HStack(spacing: AppSpacing.compact) {
                    TextField("手机号/邮箱", text: $registAccount)
                        .padding(.horizontal, AppSpacing.compact)
                }
                .frame(maxWidth:.infinity, alignment: .leading)
                .inputFieldStyle()
                .padding(.horizontal, AppSpacing.screen)

                HStack(spacing: AppSpacing.compact) {
                    if showPassword {
                        TextField("输入密码", text: $registPassword1)
                            .textContentType(.oneTimeCode)
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.never)
                            .padding(.leading, AppSpacing.compact)
                    } else {
                        SecureField("输入密码", text: $registPassword1)
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

                HStack(spacing: AppSpacing.compact) {
                    if showPassword {
                        TextField("确认密码", text: $registPassword2)
                            .textContentType(.oneTimeCode)
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.never)
                            .padding(.leading, AppSpacing.compact)
                    } else {
                        SecureField("确认密码", text: $registPassword2)
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
                    regist()
                } label: {
                    HStack(spacing: AppSpacing.compact) {
                        if registHandleIn {
                            ProgressView().tint(.white)
                        }
                        Text("注册")
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(registerButtonIsDisable())
                .opacity(registerButtonIsDisable() ? 0.5 : 1.0)
                .padding(.horizontal, AppSpacing.screen)
                .padding(.top, AppSpacing.compact)
            }
            .padding(.bottom, AppSpacing.card)
        }.onChange(of: loginModel.loginType) { oldValue, newValue in
                if newValue != 1 {
                    registAccount = "";
                    registPassword1 = "";
                    registPassword2 = "";
                    isAgreen = false;
                }
            }
    }

    // 登录按钮是否禁用
    func registerButtonIsDisable() -> Bool {
        // 账户为空
        return StringUtils.isBlank(registAccount) || registPassword1.count == 0 || registPassword2.count == 0 || !isAgreen || registHandleIn
    }
    // 进行注册
    func regist() {
        KeyBoardUtils.toHideKeyboard()
        registHandleIn = true
        let popInfoTitle = "抱歉！"
        // 1、验证信息
        if !ValidationUtil.isValidPhoneNumber(registAccount) && !ValidationUtil.isValidEmail(registAccount) {
            PopManager.shared.showSimplePop(title: "温馨提示", description: "账号必须是手机号或者邮箱")
            registHandleIn = false
            return
        }
        if registPassword1 != registPassword2 {
            PopManager.shared.showSimplePop(title: "温馨提示", description: "两遍输入的密码不一致")
            registHandleIn = false
            return
        }
        let validatePasswordResult = ValidationUtil.validatePassword(registPassword1);
        switch validatePasswordResult {
        case .failure(let e):
            PopManager.shared.showSimplePop(title: popInfoTitle, description: e.rawValue)
            registHandleIn = false
            return
        case .success(_):
            break
        }
        // 2、密码进行加密
        let password = EncryptionUtil.md5(registPassword1);
        var param:[String:String] = [:]
        param["account"] = registAccount
        param["password"] = password

        BgResultNetWork<[String:String],LoginResponse>.post(apiUrl(USER_REGISTER), params:param).finalHandleFunc { (br:BgResult<LoginResponse>?) in
            DispatchQueue.main.async {
                self.registHandleIn = false
                checkLogin(globalModel)
            }
        }.complicationHand { (r:LoginResponse?) in
            if let response = r {
                let _ = TokenUtils.saveToken(
                    registAccount,
                    response.token,
                    userId: response.userId,
                    userName: response.userName,
                    nickname: response.nickname,
                    headerImg: response.headerImg
                )

            }
        }.responseDecodable()
    }
}
