//
//  EditProfileView.swift
//  QmHealth
//
//  Created by 周荥马 on 2026/1/23.
//

import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var globalModel: GlobalModel
    @Environment(\.dismiss) private var dismiss
    
    // 弹窗状态
    @State private var showGenderPicker = false
    @State private var showBloodTypePicker = false
    @State private var showBloodRhPicker = false
    @State private var showMaritalStatusPicker = false
    @State private var showNationalityPicker = false
    @State private var showDatePicker = false
    @State private var showNameEditor = false
    @State private var showNicknameEditor = false
    @State private var showJobEditor = false
    @State private var showCityEditor = false
    
    // 临时编辑数据
    @State private var tempName = ""
    @State private var tempNickname = ""
    @State private var tempGender: Int64 = 1
    @State private var tempJob = ""
    @State private var tempCity = ""
    @State private var selectedDate = Date()
    @State private var tempBlood: Int64? = nil
    @State private var tempBloodRh: Int64? = nil
    @State private var tempNationality: Int64? = nil
    @State private var tempMaritalStatus: Int64? = nil
    
    // 患者头像图片
    private var headImageId: String? {
        return globalModel.currentUser?.headerImg
    }

    // 头像上传进度（nil=无进度）
    @State private var uploadProgress: Double? = nil

    // 当前页面作用域的 PopManager，让网络回调里的弹窗显示在 sheet 内部
    // 而不是被 PersonalCenter 的 sheet 遮到背后
    @StateObject private var popManager = PopManager()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color("background").ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // 头像区域
                        headerSection
                        
                        // 基本信息卡片
                        basicInfoCard
                        
                        // 详细信息卡片
                        detailInfoCard
                        
                        Color.clear.frame(height: 30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadUserData()
        }
        .withLocalPop(popManager)
        // 弹窗和编辑器
        .sheet(isPresented: $showNameEditor) {
            TextEditorSheet(
                title: "编辑姓名",
                text: $tempName,
                placeholder: "请输入姓名"
            ) {
                saveField(\.name, value: tempName)
            }
        }
        .sheet(isPresented: $showNicknameEditor) {
            TextEditorSheet(
                title: "编辑昵称",
                text: $tempNickname,
                placeholder: "请输入昵称"
            ) {
                saveField(\.nickname, value: tempNickname)
            }
        }
        .sheet(isPresented: $showGenderPicker) {
            SexSelectSheet(sexSelect: $tempGender) {
                saveField(\.gender, value: tempGender)
            }
        }
        .sheet(isPresented: $showDatePicker) {
            DateSelectSheet(selectedDate: $selectedDate) {
                let birthdayStr = DateUtils.formatDate(selectedDate, format: DateUtils.DateFormat.ymd)
                saveField(\.birthday, value: birthdayStr)
            }
        }
        .sheet(isPresented: $showJobEditor) {
            TextEditorSheet(
                title: "编辑职业",
                text: $tempJob,
                placeholder: "请输入职业"
            ) {
                saveField(\.job, value: tempJob)
            }
        }
        .sheet(isPresented: $showCityEditor) {
            CitySelectSheet(selectedCity: $tempCity) {
                saveField(\.city, value: tempCity)
            }
        }
        .sheet(isPresented: $showBloodTypePicker) {
            BloodTypeSelectSheet(blood: $tempBlood, bloodRh: $tempBloodRh) {
                saveField([\.blood: tempBlood, \.bloodRh: tempBloodRh])
            }
        }
        .sheet(isPresented: $showNationalityPicker) {
            NationalitySelectSheet(nationality: $tempNationality) {
                saveField(\.nationality, value: tempNationality)
            }
        }
        .sheet(isPresented: $showMaritalStatusPicker) {
            MaritalStatusSelectSheet(maritalStatus: $tempMaritalStatus) {
                saveField(\.maritalStatus, value: tempMaritalStatus)
            }
        }
    }
    
    // MARK: - 头像区域
    private var headerSection: some View {
        VStack(spacing: 16) {
            HeaderImageSelect(
                headerImgId: .constant(headImageId),
                uploadProgress: $uploadProgress
            ) { (data: Data?) in
                updateHeaderImage(data)
            }
            .frame(width: 90, height: 90)
            
            Text("点击更换头像")
                .font(.system(size: 13))
                .foregroundColor(Color("text_secondary"))
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    // MARK: - 基本信息卡片
    private var basicInfoCard: some View {
        InfoCard(title: "基本信息", icon: "person.fill", useGlass: true) {
            VStack(spacing: 0) {
                ClickableInfoRow(
                    icon: "person.text.rectangle",
                    title: "姓名",
                    value: globalModel.currentUser?.name ?? "未设置",
                    showIcon: false,
                    action: { showNameEditor = true }
                )

                Divider().padding(.leading, 32)

                ClickableInfoRow(
                    icon: "at",
                    title: "昵称",
                    value: globalModel.currentUser?.nickname ?? "未设置",
                    showIcon: false,
                    action: { showNicknameEditor = true }
                )

                Divider().padding(.leading, 32)

                ClickableInfoRow(
                    icon: "person.fill",
                    title: "性别",
                    value: getGenderText(),
                    showIcon: false,
                    action: { showGenderPicker = true }
                )

                Divider().padding(.leading, 32)

                ClickableInfoRow(
                    icon: "calendar",
                    title: "生日",
                    value: globalModel.currentUser?.birthday ?? "未设置",
                    showIcon: false,
                    action: { showDatePicker = true }
                )
            }
        }
    }

    // MARK: - 详细信息卡片
    private var detailInfoCard: some View {
        InfoCard(title: "详细信息", icon: "info.circle.fill", useGlass: true) {
            VStack(spacing: 0) {
                ClickableInfoRow(
                    icon: "briefcase.fill",
                    title: "职业",
                    value: globalModel.currentUser?.job ?? "未设置",
                    showIcon: false,
                    action: { showJobEditor = true }
                )

                Divider().padding(.leading, 32)

                ClickableInfoRow(
                    icon: "location.fill",
                    title: "居住地",
                    value: globalModel.currentUser?.city ?? "未设置",
                    showIcon: false,
                    action: { showCityEditor = true }
                )

                Divider().padding(.leading, 32)

                ClickableInfoRow(
                    icon: "drop.fill",
                    title: "血型",
                    value: getBloodTypeText(),
                    showIcon: false,
                    action: { showBloodTypePicker = true }
                )

                Divider().padding(.leading, 32)

                ClickableInfoRow(
                    icon: "heart.fill",
                    title: "婚姻状况",
                    value: getMaritalStatusText(),
                    showIcon: false,
                    action: { showMaritalStatusPicker = true }
                )

                Divider().padding(.leading, 32)

                ClickableInfoRow(
                    icon: "globe.asia.australia.fill",
                    title: "民族",
                    value: getNationalityText(),
                    showIcon: false,
                    action: { showNationalityPicker = true }
                )
            }
        }
    }
    
    // MARK: - 辅助方法
    private func loadUserData() {
        guard let user = globalModel.currentUser else { return }
        
        tempName = user.name ?? ""
        tempGender = user.gender ?? 1
        tempNickname = user.nickname ?? ""
        tempJob = user.job ?? ""
        tempCity = user.city ?? ""
        tempBlood = user.blood
        tempBloodRh = user.bloodRh
        tempNationality = user.nationality
        tempMaritalStatus = user.maritalStatus
        
        if let birthday = user.birthday {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            selectedDate = formatter.date(from: birthday) ?? Date()
        }
    }
    
    private func updateHeaderImage(_ imageData: Data?) {
        guard let imageData = imageData else { return }
        guard let userId = globalModel.currentUser?.id else { return }

        let files: [FileUploadInfo] = [
            FileUploadInfo(data: imageData, fileName: ULIDUtils.generate() + ".jpg", mimeType: "image/jpeg")
        ]

        uploadProgress = 0

        BgResultNetWork<Empty, [FilesDTO]>.upload(apiUrl(FILE_UPLOAD), params: nil)
            .progressHandleFunc { progress in
                DispatchQueue.main.async {
                    self.uploadProgress = progress.fractionCompleted
                }
            }
            .errorHandle { _, error in
                DispatchQueue.main.async {
                    self.uploadProgress = nil
                    let msg: String
                    switch error {
                    case .timeout(_, let m): msg = m
                    case .network(_, let m): msg = m
                    case .parameter(_, let m): msg = m
                    case .parsing(_, let m): msg = m
                    case .http(_, let m): msg = m
                    case .validation(_, let m): msg = m
                    case .requestError(_, let m): msg = m
                    case .unknown(_, _): msg = "头像上传失败！请稍后重试"
                    }
                    popManager.showSimplePop(title: "提示", description: "头像上传失败！\(msg)")
                }
            }
            .complicationHand { (results: [FilesDTO]?) in
                guard let results = results, !results.isEmpty else {
                    DispatchQueue.main.async {
                        self.uploadProgress = nil
                        popManager.showSimplePop(title: "提示", description: "头像上传失败！")
                    }
                    return
                }

                let user = UserDTO(
                    id: globalModel.currentUser?.id,
                    headerImg: results[0].id
                )

                BgResultNetWork<UserDTO, String>
                    .post(apiUrl(USER_UPATE), params: user)
                    .errorHandle { _, _ in
                        DispatchQueue.main.async {
                            self.uploadProgress = nil
                            popManager.showSimplePop(title: "提示", description: "头像更新失败！")
                        }
                    }
                    .complicationHand { (r: String?) in
                        DispatchQueue.main.async {
                            globalModel.currentUser?.headerImg = results[0].id
                            self.uploadProgress = nil
                            popManager.showSimplePop(title: "提示", description: "头像更新成功")
                        }
                    }
                    .responseDecodable()
            }
            .upload(fileInfos: files)
    }
    
    private func saveField<T>(_ keyPath: ReferenceWritableKeyPath<UserDTO, T?>, value: T?) {
        saveField([keyPath: value])
    }
    
    private func saveField<T>(_ v: [ReferenceWritableKeyPath<UserDTO, T?>: T?]) {
        guard let user = globalModel.currentUser else { return }
        
        for (key, value) in v {
            if value != nil {
                user[keyPath: key] = value
            }
        }
        
        BgResultNetWork<UserDTO, String>.post(apiUrl(USER_UPATE), params: user)
            .complicationHand { (r: String?) in
                globalModel.currentUser = user
            }
            .responseDecodable()
    }
    
    private func getGenderText() -> String {
        guard let gender = globalModel.currentUser?.gender else { return "未设置" }
        let sex = Sex.getByCode(code: gender)
        return sex?.getDesc() ?? "未设置"
    }
    
    private func getBloodTypeText() -> String {
        var bloodStr: String = "未设置"
        if let bloodType = globalModel.currentUser?.blood {
            let btEnum = BloodType.getByCode(code: bloodType)
            bloodStr = btEnum?.getDesc() ?? "未设置"
        }
        var bloodRhStr: String = ""
        if let bloodRh = globalModel.currentUser?.bloodRh {
            let btRh = BloodRhType.getByCode(code: bloodRh)
            bloodRhStr = btRh?.getDesc() ?? ""
        }
        return bloodStr == "未设置" ? "未设置" : "\(bloodStr)\(bloodRhStr)"
    }
    
    private func getMaritalStatusText() -> String {
        guard let status = globalModel.currentUser?.maritalStatus else { return "未设置" }
        let ms = MaritalStatus.getByCode(code: status)
        return ms?.getDesc() ?? "未设置"
    }
    
    private func getNationalityText() -> String {
        guard let nationality = globalModel.currentUser?.nationality else { return "未设置" }
        return Ethnicity.getByCode(code: nationality)?.getDesc() ?? "未设置"
    }
}

#Preview {
    EditProfileView()
        .environmentObject(GlobalModel.shared)
}
