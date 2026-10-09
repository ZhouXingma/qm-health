//
//  PersonBasicInfoView.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/10/2.
//

import SwiftUI

struct PersonBasicInfoView: View {
    // 环境变量
    @EnvironmentObject var globalModel: GlobalModel
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
    @State private var showTagEditor = false
    
    // 临时编辑数据
    @State private var tempName = ""
    @State private var tempNickname = ""
    @State private var tempGender:Int64 = 1
    @State private var tempJob = ""
    @State private var tempCity = ""
    @State private var selectedDate = Date()
    @State private var tempBlood:Int64? = nil
    @State private var tempBloodRh:Int64? = nil
    @State private var tempNationality:Int64? = nil
    @State private var tempMaritalStatus:Int64? = nil
    
    
    // 患者状态标签
    @State private var statusTag: [String] = []
    @State private var tempStatusTag: [String] = []
    
    

    // 患者头像图片
    private var headImageId:String? {
        get {
            return globalModel.currentUser?.headerImg
        }
    }
    // 头像上传进度（nil=无进度）
    @State private var uploadProgress: Double? = nil
    // 档案完整度
    private var profileCompleteness:Double {
        get {
            return Double(calculateProfileCompleteness()) / 100.0
        }
    }
    var body: some View {
        ZStack {
            // 头像区域
            
            ScrollView(showsIndicators: false) {
                Color.clear.frame(height: 200)
                // 信息卡片
                infoCardsSection
            }
            VStack {
                headerSection
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .onAppear {
            loadUserData()
            loadUserTag()
        }
    }
    // MARK: - 头像区域
    private var headerSection: some View {
        VStack(spacing: 20) {
            // 头像和基本信息
            VStack(spacing: 10) {
                HStack(alignment: .top,spacing: 20) {
                    // 头像
                    HeaderImageSelect(
                        headerImgId: .constant(headImageId),
                        uploadProgress: $uploadProgress
                    ) { (data:Data?) in
                        updateHeaderImage(data)
                    }.frame(width: 80, height: 80)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(globalModel.currentUser?.name ?? "未设置姓名")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color("text_primary"))
                        HStack {
                            Text("昵称：")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color("text_secondary"))
                            Text(globalModel.currentUser?.nickname ?? "")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color("text_secondary"))
                        }
                        HStack(spacing: 8) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(0..<statusTag.count, id: \.self) { i in
                                        PersonStatusTag(
                                            tagText: statusTag[i],
                                            showDeleteButton: false,
                                            onDelete: {
                                                removeTag(at: i)
                                            }
                                        )
                                    }
                                }
                            }
                            Button {
                                showTagEditor = true
                            } label: {
                                Text("+")
                                    .font(.system(size: 14))
                                    .padding(6)
                                    .background {
                                        Circle().fill(Color.theme(.primary))
                                    }
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.top, 5)
                    }.padding(.top, 5)
                }.frame(maxWidth: .infinity, alignment: .leading)
                // 用户名和完整度
                VStack {
                    profileCompletenessView
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
        }
    }
    
    // MARK: - 档案完整度视图
    private var profileCompletenessView: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "person.badge.shield.checkmark.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color.theme(.primary))
                Text("档案完整度")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color("text_primary"))
                Spacer()
                Text("\(calculateProfileCompleteness())%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.theme(.primary))
            }
            LineProgress(lineHeight: 8, colors: [Color.theme(.chart1), Color.theme(.primary)], progress: .constant(profileCompleteness))
                .frame(height: 10)
        }.padding(.top, 20)
    }
    
    // MARK: - 信息卡片区域
    private var infoCardsSection: some View {
        VStack(spacing: 15) {
            // 基本信息卡片
            InfoCard(title: "基本信息", icon: "person.fill", useGlass: true) {
                VStack(spacing: 0) {
                    ClickableInfoRow(
                        icon: "person.text.rectangle",
                        title: "姓名",
                        value: globalModel.currentUser?.name ?? "未设置",
                        showIcon: false,
                        action: { showNameEditor = true }
                    )

                    ClickableInfoRow(
                        icon: "at",
                        title: "昵称",
                        value: globalModel.currentUser?.nickname ?? "未设置",
                        showIcon: false,
                        action: { showNicknameEditor = true }
                    )

                    ClickableInfoRow(
                        icon: "person.fill",
                        title: "性别",
                        value: getGenderText(),
                        showIcon: false,
                        action: { showGenderPicker = true }
                    )


                    ClickableInfoRow(
                        icon: "calendar",
                        title: "生日",
                        value: globalModel.currentUser?.birthday ?? "未设置",
                        showIcon: false,
                        action: { showDatePicker = true }
                    )
                }
            }

            // 详细信息卡片
            InfoCard(title: "详细信息", icon: "info.circle.fill", useGlass: true) {
                VStack(spacing: 0) {
                    ClickableInfoRow(
                        icon: "briefcase.fill",
                        title: "职业",
                        value: globalModel.currentUser?.job ?? "未设置",
                        showIcon: false,
                        action: { showJobEditor = true }
                    )


                    ClickableInfoRow(
                        icon: "location.fill",
                        title: "居住地",
                        value: globalModel.currentUser?.city ?? "未设置",
                        showIcon: false,
                        action: { showCityEditor = true }
                    )


                    ClickableInfoRow(
                        icon: "drop.fill",
                        title: "血型",
                        value: getBloodTypeText(),
                        showIcon: false,
                        action: { showBloodTypePicker = true }
                    )


                    ClickableInfoRow(
                        icon: "heart.fill",
                        title: "婚姻状况",
                        value: getMaritalStatusText(),
                        showIcon: false,
                        action: { showMaritalStatusPicker = true }
                    )


                    ClickableInfoRow(
                        icon: "globe.asia.australia.fill",
                        title: "民族",
                        value: getNationalityText(),
                        showIcon: false,
                        action: { showNationalityPicker = true }
                    )
                }
            }
            
        }.padding(.bottom, 30)
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
            JobSelectSheet(selectedJob: $tempJob) {
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
                saveField([\.blood: tempBlood,\.bloodRh: tempBloodRh])
            }
        }
        .sheet(isPresented: $showNationalityPicker) {
            NationalitySelectSheet(nationality: $tempNationality) {
                saveField(\.nationality, value:tempNationality)
            }
        }
        .sheet(isPresented: $showMaritalStatusPicker) {
            MaritalStatusSelectSheet(maritalStatus: $tempMaritalStatus) {
                saveField(\.maritalStatus, value:tempMaritalStatus)
            }
        }
        .sheet(isPresented: $showTagEditor) {
            PeopleTagAddSheet(statusTags: $tempStatusTag) {
                saveUserStatusTag()
            }
        }
    }
    
    // MARK: - 辅助方法
    
    private func removeTag(at index: Int) {
        guard index < statusTag.count else { return }
        statusTag.remove(at: index)
        // TODO: 这里可以添加保存到服务器的逻辑
    }
    
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
    
    private func loadUserTag() {
        let params = ["tagType":["0"]]
        BgResultNetWork<[String:[String]],UserTagListDTO>.post(apiUrl(USER_TAG_LIST), params: params)
            .complicationHand {(r:UserTagListDTO?) in
                self.statusTag = r?.tagMap["0"] ?? []
                self.tempStatusTag = self.statusTag
            }
            .responseDecodable()
    }
    
    private func updateHeaderImage(_ imageData:Data?) {
        if nil == imageData {
            return
        }
        let user_id =  globalModel.currentUser?.id;
        if nil == user_id {
            return
        }
        let files:[FileUploadInfo] = [
            FileUploadInfo(data: imageData!, fileName:  ULIDUtils.generate()+".jpg", mimeType: "image/jpeg")
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
                PopManager.shared.showSimplePop(title: "提示", description: "头像上传失败！\(msg)")
            }
        }
        .complicationHand { (results:[FilesDTO]?) in
            if results == nil || results!.isEmpty {
                DispatchQueue.main.async {
                    self.uploadProgress = nil
                    PopManager.shared.showSimplePop(title: "提示", description: "头像上传失败！")
                }
                return;
            }
            // 创建用户对象
            let user = UserDTO (
                id:globalModel.currentUser?.id,
                headerImg: results![0].id
            )
            BgResultNetWork<UserDTO,String>
                .post(apiUrl(USER_UPATE), params: user)
                .errorHandle { _, _ in
                    DispatchQueue.main.async {
                        self.uploadProgress = nil
                        PopManager.shared.showSimplePop(title: "提示", description: "头像更新失败！")
                    }
                }
                .complicationHand({ (r:String?) in
                    DispatchQueue.main.async {
                        globalModel.currentUser?.headerImg =  results![0].id
                        globalModel.hasCompletedInitialSetup = true
                        self.uploadProgress = nil
                        PopManager.shared.showSimplePop(title: "提示", description: "头像更新成功")
                    }
                })
                .responseDecodable()
        }.upload(fileInfos: files)
    }
    
    private func saveUserStatusTag() {
        let params = UserTagSaveParam(tagType: "0", tags: self.tempStatusTag);
        BgResultNetWork<UserTagSaveParam,UInt64>.post(apiUrl(USER_TAG_SAVE), params: params)
            .complicationHand {(r:UInt64?) in
                self.statusTag = self.tempStatusTag
            }.responseDecodable()
        
      
    }
    
    private func saveField<T>(_ keyPath: ReferenceWritableKeyPath<UserDTO, T?>, value: T?) {
        saveField([keyPath:value])
    }
    private func saveField<T>(_ v:[ReferenceWritableKeyPath<UserDTO, T?>:T?]) {
        guard let user = globalModel.currentUser else { return }
        for (key,value) in v {
            if nil == value {
                continue
            }
            user[keyPath: key] = value
        }
        BgResultNetWork<UserDTO, String>.post(apiUrl(USER_UPATE), params: user).complicationHand { (r:String?) in
            globalModel.currentUser = user
        }.responseDecodable()
        
        
       
    }
    
    private func calculateProfileCompleteness() -> Int {
        let user = globalModel.currentUser
        return BizCommonFunctions.calculateProfileCompleteness(user: user)
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

// MARK: - 子组件
// 标签
struct PersonStatusTag: View {
    var tagText: String = ""
    var color: Color = Color.theme(.primary)
    var showDeleteButton: Bool = false
    var onDelete: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tagText)
                .font(.system(size: 12))
                .foregroundStyle(.white)
            
            if showDeleteButton {
                Button(action: {
                    onDelete?()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .glassPill(.regular.tint(color))
    }
}

// 信息卡片容器
struct InfoCard<Content: View>: View {
    let title: String
    let icon: String
    let useGlass: Bool
    let content: Content

    init(title: String, icon: String, useGlass: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.useGlass = useGlass
        self.content = content()
    }

    @ViewBuilder
    private var cardContent: some View {
        VStack(spacing: 16) {
            // 卡片标题
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(Color.theme(.primary))

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color("text_primary"))

                Spacer()
            }
            // 卡片内容
            content
        }
    }

    var body: some View {
        cardContent.cardStyle()
    }
}

// 可点击信息行
struct ClickableInfoRow: View {
    let icon: String
    let title: String
    let value: String
    let showIcon: Bool
    let action: () -> Void

    init(icon: String, title: String, value: String, showIcon: Bool = true, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.value = value
        self.showIcon = showIcon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if showIcon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(Color.theme(.primary))
                        .frame(width: 24)
                }

                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color("text_primary"))
                    .frame(width: 80, alignment: .leading)
                Spacer()
                Text(value)
                    .font(.system(size: 14))
                    .foregroundColor(value == "未设置" ? Color("text_secondary") : Color("text_primary"))
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Color("text_secondary"))
            }
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 文本编辑弹窗
struct TextEditorSheet: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                SimpleTextField(placeholder: placeholder, text: $text)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        onSave()
                        dismiss()
                    }.foregroundColor(Color.theme(.primary))
                }
            }
        }
        .sheetAppBackground()
    }
}
// 性别选择
struct SexSelectSheet: View {
    @Binding var sexSelect: Int64
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack {
                    HStack {
                        ForEach(Sex.allCases, id: \.self) { sexOption in
                            Button(action: {
                                sexSelect = sexOption.rawValue
                            }) {
                                HStack(spacing: 8) {
                                    Text(sexOption == .male ? "男" : "女")
                                        .font(.system(size: 14))
                                }
                            }
                            .buttonStyle(GlassSelectButtonStyle(isSelected: sexSelect == sexOption.rawValue))
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .navigationTitle("性别")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        onSave()
                        dismiss()
                    }.foregroundColor(Color.theme(.primary))
                }
            }
        }
        .sheetAppBackground()

    }
}

/// 职业编辑：手动输入 + 常用职业快捷选择（点标签即填入）
struct JobSelectSheet: View {
    @Binding var selectedJob: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    // 常用职业（按类分组）
    private struct JobGroup: Identifiable {
        let name: String
        let jobs: [String]
        var id: String { name }
    }

    private let jobGroups: [JobGroup] = [
        JobGroup(name: "医疗健康", jobs: ["医生", "护士", "药剂师", "康复治疗师", "营养师"]),
        JobGroup(name: "办公文职", jobs: ["教师", "程序员", "工程师", "会计", "公务员", "文员"]),
        JobGroup(name: "服务行业", jobs: ["销售", "司机", "厨师", "理发师", "外卖骑手", "保安", "保洁"]),
        JobGroup(name: "自由/家居", jobs: ["个体经营", "自由职业", "全职妈妈", "农民", "退休", "学生"]),
        JobGroup(name: "其他", jobs: ["无业", "其他"])
    ]

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    SimpleTextField(placeholder: "输入或从下方选择职业", text: $selectedJob)

                    ForEach(jobGroups) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(group.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color("text_secondary"))
                            HFlow(alignment: .top, itemSpacing: 8, rowSpacing: 8) {
                                ForEach(group.jobs, id: \.self) { job in
                                    Button(action: {
                                        selectedJob = job
                                    }) {
                                        Text(job)
                                            .font(.system(size: 14))
                                            .foregroundColor(selectedJob == job ? .white : Color("text_primary"))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 7)
                                            .glassPill(selectedJob == job ? Glass.regular.interactive().tint(AppColor.primary) : Glass.regular.interactive())
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .navigationTitle("编辑职业")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        selectedJob = selectedJob.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave()
                        dismiss()
                    }.foregroundColor(Color.theme(.primary))
                }
            }
        }
        .sheetAppBackground()
    }
}

/// 城市选择
struct CitySelectSheet:View {
    @Binding var selectedCity: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            VStack {
                CitySelect(selectedCity: $selectedCity)
                Spacer()
            }.navigationTitle("居住地")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("保存") {
                            onSave()
                            dismiss()
                        }.foregroundColor(Color.theme(.primary))
                    }
                }
        }
        .sheetAppBackground()
    }
}
/// 日期选择
struct DateSelectSheet:View {
    @Binding var selectedDate: Date
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                DateTimePicker(featureDate: false, initSelectDate:selectedDate) { date in
                    self.selectedDate = date
                }
                Spacer()
            }.padding(.horizontal, 20)
                .padding(.top, 20)
                .navigationTitle("生日")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("保存") {
                            onSave()
                            dismiss()
                        }.foregroundColor(Color.theme(.primary))
                    }
                }
        }
        .sheetAppBackground()
    }
}

// 性别选择
struct BloodTypeSelectSheet: View {
    @Binding var blood:Int64?;
    @Binding var bloodRh:Int64?;
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                HStack {
                    ForEach(BloodType.allCases, id: \.self) { bloodOption in
                        Button(action: {
                            blood = bloodOption.rawValue
                        }) {
                            HStack(spacing: 8) {
                                Text(BloodType(rawValue: bloodOption.rawValue)?.getDesc() ?? "")
                                    .font(.system(size: 14))
                            }
                        }
                        .buttonStyle(GlassSelectButtonStyle(isSelected: blood == bloodOption.rawValue))
                    }
                }.padding(.bottom, 20)
                HStack {
                    ForEach(BloodRhType.allCases, id: \.self) { bloodRhOption in
                        Button(action: {
                            bloodRh = bloodRhOption.rawValue
                        }) {
                            HStack(spacing: 8) {
                                Text(BloodRhType(rawValue: bloodRhOption.rawValue)?.getDesc() ?? "")
                                    .font(.system(size: 14))
                            }
                        }
                        .buttonStyle(GlassSelectButtonStyle(isSelected: bloodRh == bloodRhOption.rawValue))
                    }
                }
                Spacer()
            }.padding(.horizontal, 20)
                .padding(.top, 20)
                .navigationTitle("血型")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("保存") {
                            onSave()
                            dismiss()
                        }.foregroundColor(Color.theme(.primary))
                    }
                }
        }
        .sheetAppBackground()
    }
}

/// 婚姻状况选择
struct MaritalStatusSelectSheet: View {
    @Binding var maritalStatus: Int64?
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            VStack {
                VStack {
                    ScrollView(showsIndicators:false) {
                        ForEach(MaritalStatus.allCases, id:\.self) { maritalStatusOption in
                            Button(action: {
                                maritalStatus = maritalStatusOption.rawValue
                            }) {
                                HStack {
                                    Text(MaritalStatus(rawValue: maritalStatusOption.rawValue)?.getDesc() ?? "")
                                        .font(.system(size: 16))
                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.top, 5)
                            }
                            .buttonStyle(GlassSelectButtonStyle(isSelected: maritalStatus == maritalStatusOption.rawValue, verticalPadding: 15))
                        }
                    }
                }
            }.padding(.horizontal, 20)
                .padding(.top, 20)
                .navigationTitle("婚姻")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("保存") {
                            onSave()
                            dismiss()
                        }.foregroundColor(Color.theme(.primary))
                    }
                }
        }
        .sheetAppBackground()
    }

}

/// 民族选择
struct NationalitySelectSheet: View {
    @Binding var nationality: Int64?
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                VStack {
                    ScrollView(showsIndicators:false) {
                        ForEach(Ethnicity.allCases, id:\.self) { ethnicityOption in
                            Button(action: {
                                nationality = ethnicityOption.rawValue
                            }) {
                                HStack {
                                    Text(Ethnicity(rawValue: ethnicityOption.rawValue)?.getDesc() ?? "")
                                        .font(.system(size: 16))
                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.top, 5)
                            }
                            .buttonStyle(GlassSelectButtonStyle(isSelected: nationality == ethnicityOption.rawValue, verticalPadding: 15))
                        }
                    }
                }
            }.padding(.horizontal, 20)
                .padding(.top, 20)
                .navigationTitle("民族")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("保存") {
                            onSave()
                            dismiss()
                        }.foregroundColor(Color.theme(.primary))
                    }
                }
        }
        .sheetAppBackground()
    }
}


// 标签编辑弹窗
struct PeopleTagAddSheet: View {
    @Binding var statusTags: [String]
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var newTagText = ""
    @State private var predefinedTags = ["怀孕", "哺乳期", "术后恢复期", "运动员", "长期卧床", "残疾", "肥胖", "营养不良", "过敏体质", "近期手术史", "疫苗接种中", "免疫力低下", "药物使用","临终关怀阶段"]
    let fontCount = 10;
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 添加新标签区域
                VStack(alignment: .leading, spacing: 12) {
                    Text("添加新标签")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color("text_primary"))
                    
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            TextField("输入标签名称", text: $newTagText)
                                .font(.system(size: 14))
                                .padding(.horizontal,10)
                                .padding(.vertical,10)
                                .background {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.thinMaterial)
                                }
                            Button("添加") {
                                addNewTag()
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newTagText.count > fontCount ? Color.gray : Color.theme(.primary))
                            )
                            .disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newTagText.count > fontCount)
                        }
                        
                        // 字数显示
                        HStack {
                            Text("\(newTagText.count)/\(fontCount)")
                                .font(.system(size: 12))
                                .foregroundColor(newTagText.count > fontCount ? Color("error") : Color("text_secondary"))
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // 当前标签区域
                if !statusTags.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("当前标签")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color("text_primary"))
                        ScrollView(.vertical, showsIndicators: false) {
                            HFlow(alignment: .top){
                                ForEach(0..<statusTags.count, id: \.self) { index in
                                    PersonStatusTag(
                                        tagText: statusTags[index],
                                        color: Color.theme(.primary),
                                        showDeleteButton: true,
                                        onDelete: {
                                            removeTag(at: index)
                                        }
                                    )
                                }
                            }.frame(maxWidth: .infinity,alignment: .leading)
                        }.frame(maxWidth: .infinity, minHeight: 100, maxHeight: 200,  alignment: .top)
                    }
                    .padding(.horizontal, 20)
                }
                
                // 预设标签区域
                VStack(alignment: .leading, spacing: 12) {
                    Text("常用标签")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color("text_primary"))
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        HFlow(alignment: .top){
                            ForEach(availablePredefinedTags, id: \.self) { tag in
                                Button(action: {
                                    addPredefinedTag(tag)
                                }) {
                                    Text(tag)
                                        .font(.system(size: 14))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .foregroundColor(Color.theme(.primary))
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.theme(.primary), lineWidth: 1)
                                                .fill(Color.theme(.primary).opacity(0.1))
                                        ) .padding(2)
                                }
                            }
                        }.frame(maxWidth: .infinity,alignment: .leading)
                    }.frame(maxWidth: .infinity, minHeight: 100, maxHeight: 200,  alignment: .top)
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationTitle("编辑标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        onSave()
                        dismiss()
                    }
                    .foregroundColor(Color.theme(.primary))
                }
            }
        }
        .sheetAppBackground()
    }

    // 可用的预设标签（排除已添加的）
    private var availablePredefinedTags: [String] {
        predefinedTags.filter { !statusTags.contains($0) }
    }
    
    // 添加新标签
    private func addNewTag() {
        let trimmedText = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty && !statusTags.contains(trimmedText) else { return }
        
        statusTags.append(trimmedText)
        newTagText = ""
    }
    
    // 添加预设标签
    private func addPredefinedTag(_ tag: String) {
        guard !statusTags.contains(tag) else { return }
        statusTags.append(tag)
    }
    
    // 删除标签
    private func removeTag(at index: Int) {
        guard index < statusTags.count else { return }
        statusTags.remove(at: index)
    }
}

#Preview {
    PersonBasicInfoView()
}
