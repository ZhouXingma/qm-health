//
//  PersonBasicInfoTabView.swift
//  QmHealth
//  个人基本信息
//
//  Created by 周荥马 on 2025/9/14.
//

import SwiftUI

struct PersonBasicInfoTabView: View {
    @EnvironmentObject var globalModel: GlobalModel
    private var profileCompleteness:Double {
        get {
            return Double(calculateProfileCompleteness()) / 100.0
        }
    }
    var body: some View {
        VStack(spacing: 16) {
            // 档案完整度进度条
            VStack(spacing: 10) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "person.badge.shield.checkmark.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.theme(.primary))
                        Text("档案完整度")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color("text_primary"))
                    }
                    Spacer()
                    Text("\(calculateProfileCompleteness())%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.theme(.primary))
                }
                // 进度条
                LineProgress(lineHeight: 8, colors: [Color.theme(.chart1), Color.theme(.primary)], progress: .constant(profileCompleteness))
                    .frame(height: 8)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            ScrollView(showsIndicators:false) {
                // 基本信息卡片组
                VStack(spacing: 12) {
                    // 第一行：个人基础信息
                    HStack(spacing: 12) {
                        PersonalInfoCard(
                            icon: "person.fill",
                            title: "性别",
                            value: getGenderText(),
                            subtitle: "生理性别",
                            color: Color.theme(.chart2)
                        )
                        
                        PersonalInfoCard(
                            icon: "calendar",
                            title: "年龄",
                            value: getAgeText(),
                            subtitle: "周岁",
                            color: Color.theme(.chart3)
                        )
                    }
                    
                    // 第二行：血型和地区信息
                    HStack(spacing: 12) {
                        PersonalInfoCard(
                            icon: "drop.fill",
                            title: "血型",
                            value: getBloodTypeText(globalModel.currentUser?.blood, globalModel.currentUser?.bloodRh),
                            subtitle: "ABO血型系统",
                            color: .red
                        )
                        
                        PersonalInfoCard(
                            icon: "location.fill",
                            title: "居住地",
                            value: globalModel.currentUser?.city ?? "未设置",
                            subtitle: "当前城市",
                            color: .blue
                        )
                    }
                    
                    // 第三行：职业和认证状态
                    HStack(spacing: 12) {
                        PersonalInfoCard(
                            icon: "briefcase.fill",
                            title: "职业",
                            value: globalModel.currentUser?.job ?? "未设置",
                            subtitle: "工作领域",
                            color: .green
                        )
                        
                        PersonalInfoCard(
                            icon: getCertificationIcon(),
                            title: "认证状态",
                            value: getCertificationText(),
                            subtitle: "实名认证",
                            color: getCertificationColor()
                        )
                    }
                    
                    // 第四行：婚姻状况和民族
                    HStack(spacing: 12) {
                        PersonalInfoCard(
                            icon: "heart.fill",
                            title: "婚姻状况",
                            value: getMaritalStatusText(),
                            subtitle: "家庭状态",
                            color: Color.theme(.chart4)
                        )
                        
                        PersonalInfoCard(
                            icon: "globe.asia.australia.fill",
                            title: "民族",
                            value: getNationalityText(),
                            subtitle: "民族信息",
                            color: .orange
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .cardStyle()
    }
    
    // MARK: - 子组件
    // 个人信息卡片组件
    struct PersonalInfoCard: View {
        let icon: String
        let title: String
        let value: String
        let subtitle: String
        let color: Color
        
        var body: some View {
            VStack(spacing: 8) {
                // 图标和标题
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(color)
                        .frame(width: 18)
                    
                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color("text_secondary"))
                    
                    Spacer()
                }
                
                // 主要值
                HStack {
                    Text(value)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color("text_primary"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer()
                }
                
                // 副标题
                HStack {
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundStyle(Color("text_secondary").opacity(0.7))
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .appGlass(.clear, in:RoundedRectangle(cornerRadius: AppRadius.medium))
            
//            .padding(.horizontal, 12)
//            .padding(.vertical, 10)
//            .background {
//                RoundedRectangle(cornerRadius: 12)
//                    .fill(Color("input_bg"))
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 12)
//                            .stroke(color.opacity(0.2), lineWidth: 1)
//                    )
//            }
        }
    }
    
    // MARK: - 处理方法
    
    // 计算档案完整度
    private func calculateProfileCompleteness() -> Int {
        let user = globalModel.currentUser
        return BizCommonFunctions.calculateProfileCompleteness(user: user)
    }
    
    // 获取性别文本
    private func getGenderText() -> String {
        guard let gender = globalModel.currentUser?.gender else { return "未设置" }
        let sex = Sex.getByCode(code: gender)
        return sex?.getDesc() ?? "未设置"
    }
    
    // 获取年龄文本
    private func getAgeText() -> String {
        guard let birthday = globalModel.currentUser?.birthday else { return "未知" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let birthDate = formatter.date(from: birthday) else { return "未知" }
        
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
        return "\(ageComponents.year ?? 0)岁"
    }
    
    // 获取血型文本
    private func getBloodTypeText(_ bloodTypeOpt:Int64?,_  bloodTypeRhOpt:Int64?) -> String {
        var bloodStr: String = "未知"
        if let bloodType = bloodTypeOpt {
            let btEnum = BloodType.getByCode(code: bloodType)
            bloodStr = btEnum?.getDesc() ?? "未知"
        }
        var bloodRhStr:String = ""
        if let bloodRh = bloodTypeRhOpt {
            let btRh = BloodRhType.getByCode(code: bloodRh)
            bloodRhStr = btRh?.getDesc() ?? ""
        }
        return "\(bloodStr)\(bloodRhStr)"
    }
    
    // 获取认证状态文本
    private func getCertificationText() -> String {
        guard let certification = globalModel.currentUser?.certification else { return "未认证" }
        return certification == 1 ? "已认证" : "未认证"
    }
    
    // 获取认证图标
    private func getCertificationIcon() -> String {
        guard let certification = globalModel.currentUser?.certification else { return "xmark.shield" }
        return certification == 1 ? "checkmark.shield.fill" : "xmark.shield"
    }
    
    // 获取认证颜色
    private func getCertificationColor() -> Color {
        guard let certification = globalModel.currentUser?.certification else { return Color("error") }
        return certification == 1 ? .green : Color("error")
    }
    
    // 获取婚姻状况文本
    private func getMaritalStatusText() -> String {
        guard let status = globalModel.currentUser?.maritalStatus else { return "未设置" }
        let ms = MaritalStatus.getByCode(code: status);
        return ms?.getDesc() ?? "未设置"
    }
    
    // 获取民族文本
    private func getNationalityText() -> String {
        guard let nationality = globalModel.currentUser?.nationality else { return "未设置" }
        switch nationality {
        case 1: return "汉族"
        case 2: return "蒙古族"
        case 3: return "回族"
        case 4: return "藏族"
        case 5: return "维吾尔族"
        default: return "其他"
        }
    }
    
    
}

#Preview {
    PersonBasicInfoTabView()
}
