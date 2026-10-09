//
//  InitialProfileSetupView.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/3/20.
//

import SwiftUI
import PhotosUI

struct InitialProfileSetupView: View {
    // MARK: 环境变量
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var globalModel: GlobalModel
    
    // MARK: 状态变量
    @State private var name: String = ""
    @State private var sex: Sex = .male
    @State private var birthday: String = "2000-01-01"
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isLoading: Bool = false
    @State private var showDefaultHead: Bool = false
    @State private var selectBirthdayTemp:String = "2000-01-01"

    
    // MARK: 视图构建
    var body: some View {
        ZStack {
            Color("background")
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // 欢迎标题
                welcomeHeader
            
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 30) {
                        // 头像选择
                        avatarSection
                        // 基本信息表单
                        VStack(spacing: 16) {
                           CustomTextField(icon: "person.fill", title: "姓名", text: $name, placeholder: "请输入您的姓名")
                           sexSection
                           birthdaySection
                        }
                        .padding(.horizontal, 20)
                        
                        // 开始使用按钮
                        startButton
                    }
                    .padding(.top, 20)
                }
            }
        }
        .onAppear() {
            initData()
        }
        .onChange(of: selectedItem) { oldItem, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    selectedImageData = data
                }
            }
        }
    }
    
    // MARK: - 组件视图
    // 欢迎标题
    private var welcomeHeader: some View {
        VStack(spacing: 10) {
            Text("欢迎使用健康管理")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Color.theme(.primary))
                .padding(.top, 40)
            
            Text("请设置您的基本信息，以便为您提供个性化的健康服务")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .padding(.bottom, 10)
        }
    }
    
    // 头像选择区域
    private var avatarSection: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                // 首先放置一个白色圆形作为背景
                Circle()
                    .fill(Color("background"))
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                
                if let selectedImageData,
                   let image = UIImage(data: selectedImageData) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .foregroundColor(.gray.opacity(0.7))
                        .clipShape(Circle())
                }
                
                // 添加白色边框
                Circle()
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 80, height: 80)
                
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Circle()
                        .fill(Color.theme(.primary))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1)
                }
                .offset(x: 5, y: 5)
            }
            .padding(.vertical, 10)
            
            // 默认头像选择区域
            VStack(spacing: 10) {
                HStack {
                    Text("或选择")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Button {
                        hideAll();
                        showDefaultHead.toggle()
                    } label: {
                        Text("默认头像")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.theme(.primary))
                        
                    }
                }
                
                if showDefaultHead {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(DEFAULT_HEAD_IMG.indices, id: \.self) { index in
                                Button {
                                    KeyBoardUtils.toHideKeyboard()
                                    selectDefaultAvatar(index: index)
                                } label: {
                                    Image(DEFAULT_HEAD_IMG[index])
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 60, height: 60)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: 2)
                                        )
                                        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 5)
                    }
                }
            }
        }
    }
    // 生日选择
    private var birthdaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("生日")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.gray)
            HStack(spacing: 30) {
                Button {
                    showSelectBirthday()
                } label: {
                    HStack{
                        Image(systemName: "birthday.cake.fill")
                            .foregroundColor(Color.theme(.primary).opacity(0.7))
                            .frame(width: 14)
                        Text("\(birthday)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.theme(.primary))
                    }.padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color("input_bg"))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                }
            }
        }
    }
    
    // 选择默认头像
    private func selectDefaultAvatar(index: Int) {
        if let image = UIImage(named: DEFAULT_HEAD_IMG[index]),
           let imageData = image.pngData() {
            self.selectedImageData = imageData
            self.selectedItem = nil
        }
    }
    
    // 性别选择
    private var sexSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("性别")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.gray)
            
            HStack(spacing: 30) {
                ForEach(Sex.allCases, id: \.self) { sexOption in
                    Button(action: {
                        KeyBoardUtils.toHideKeyboard()
                        withAnimation(.spring()) {
                            sex = sexOption
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: sexOption == .male ? "figure.stand" : "figure.stand.dress")
                                .font(.system(size: 14))
                            
                            Text(sexOption == .male ? "男" : "女")
                                .font(.system(size: 14))
                        }
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(sex == sexOption ? Color.theme(.primary).opacity(0.15) : Color("content_bg"))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(sex == sexOption ? Color.theme(.primary) : Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .foregroundColor(sex == sexOption ? Color.theme(.primary) : .gray)
                    }
                }
            }
        }
    }
    
    // 开始使用按钮
    private var startButton: some View {
        Button(action: {
            saveProfile()
        }) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(.trailing, 10)
                }
                
                Text("开始使用")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.theme(.primary))
            )
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .disabled(isLoading)
    }

    
    // MARK: - 辅助方法
    // 初始化数据
    func initData() {
        checkUserSetup(globalModel)
    }
    

    // 现实选择生日
    private func showSelectBirthday() {
        KeyBoardUtils.toHideKeyboard()
        SubPopManager.shared.showCustomSubPop(customAction: { birthday = selectBirthdayTemp}) {
            DateTimePicker(featureDate: false, initSelectDate: DateUtils.stringToDate(birthday, format: DateUtils.DateFormat.ymd)) { date in
                selectBirthdayTemp = DateUtils.formatDate(date, format: DateUtils.DateFormat.ymd)
            }
        }
    }
   // 保存用户信息
    private func saveProfile() {
        KeyBoardUtils.toHideKeyboard()
        // 验证必填信息
        if StringUtils.isBlank(name) {
            PopManager.shared.showSimplePop(title: "提示", description: "姓名不能为空")
            return
        }
        if nil == selectedImageData {
            PopManager.shared.showSimplePop(title: "提示", description: "请选择头像")
            return
        }
        isLoading = true
        let files:[FileUploadInfo] = [
            FileUploadInfo(data: selectedImageData!, fileName:  ULIDUtils.generate()+".jpg", mimeType: "image/jpeg")
        ]
        BgResultNetWork<Empty,[FilesDTO]>.upload(apiUrl(FILE_UPLOAD), params: nil)
        .complicationHand { (results:[FilesDTO]?) in
            if results == nil || results!.isEmpty {
                self.isLoading = false
                PopManager.shared.showSimplePop(title: "提示", description: "头像上传失败！")
                return;
            }
            // 创建用户对象
            
            var user = UserDTO (
                name: name,
                gender: sex.rawValue,
                birthday: birthday,
                headerImg: results![0].id
                
            )
            BgResultNetWork<UserDTO, String>
                .post(apiUrl(USER_UPATE), params: user)
                .complicationHand({ (r:String?) in
                    DispatchQueue.main.async {
                        globalModel.currentUser?.name =  name
                        globalModel.currentUser?.gender =  sex.rawValue
                        globalModel.currentUser?.birthday =  birthday
                        globalModel.currentUser?.headerImg =  results![0].id
                        globalModel.hasCompletedInitialSetup = true
                        self.isLoading = false
                    }
                })
                .finalHandleFunc { _ in
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                }
                .responseDecodable()
                
        }
        .finalHandleFunc { _ in
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }.upload(fileInfos: files)
       
       
    }
}
