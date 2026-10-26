//
//  HeaderOfPersonInfo.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/9/15.
//

import SwiftUI

struct HeaderOfPersonInfo: View {
    // 环境变量
    @EnvironmentObject var globalModel:GlobalModel;
    // 首页刷新事件总线
    @EnvironmentObject var refreshBus: HomeRefreshBus;
    // 姓名后显示年龄
    var showsAge: Bool = false
    // 支持在「姓名 / 昵称」之间切换
    var allowsNameToggle: Bool = false
    // 名称展示偏好（仅在支持切换时生效）
    @AppStorage("home2.displayNickname") private var showNickname: Bool = false
    // 患者状态标签
    @State private var statusTag: [String] = []
    // 患者头像图片
    private var headImageId:String? {
        get {
            return globalModel.currentUser?.headerImg
        }
    }
    // 当前展示的名称：昵称为空时回退到姓名
    private var displayName: String {
        if allowsNameToggle, showNickname,
           let nickname = globalModel.currentUser?.nickname,
           !nickname.isEmpty {
            return nickname
        }
        return globalModel.currentUser?.name ?? "未设置用户名"
    }
    // 年龄文案（仅在 showsAge 时展示）
    private var ageText: String? {
        guard showsAge,
              let age = PortraitAnimation.age(from: globalModel.currentUser?.birthday) else {
            return nil
        }
        return "\(age)岁"
    }
    var body: some View {
        // 基本头像和基本信息
        HStack(alignment: .top) {
            NavigationLink {
                PersonInfoDetail()
            } label: {
                PersonAvatar(headerImgId: headImageId)
                    .frame(width: 45, height: 45)
            }
            VStack(alignment: .leading){
                HStack(spacing: 6) {
                    nameView
                    if let ageText {
                        Text(ageText)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.theme(.primary))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.theme(.primary).opacity(0.12)))
                    }
                }.padding(.top, 2)
                ScrollView([.horizontal], showsIndicators: false) {
                    HStack {
                        ForEach(0..<statusTag.count, id: \.self) { i in
                            PersonStatusTag(tagText: statusTag[i])
                        }
                    }
                }.padding(.top, -5)

            }.padding(.leading, 2)
            Spacer()
        }.padding(.bottom, 5)
            .onAppear{
                loadUserTag()
            }
            .onChange(of: refreshBus.refreshTrigger) { _, _ in
                loadUserTag()
            }
    }

    // MARK: - 姓名
    @ViewBuilder
    private var nameView: some View {
        if allowsNameToggle {
            Menu {
                Picker("显示名称", selection: $showNickname) {
                    Text("显示姓名").tag(false)
                    Text("显示昵称").tag(true)
                }
                .pickerStyle(.inline)
            } label: {
                HStack(spacing: 4) {
                    Text(displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color("text_primary"))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color("text_secondary"))
                }
            }
        } else {
            Text(displayName).font(.system(size: 16, weight: .bold))
        }
    }

    
    // MARK: - 子组件
    // 标签
    struct PersonStatusTag: View {
        var tagText:String = ""
        var color:Color = Color.theme(.primary)
        var body: some View {
            Text("\(tagText)")
                .font(.system(size: 12))
                .padding(.horizontal,10)
                .padding(.vertical,3)
                .foregroundStyle(.white)
                .glassPill(.regular.interactive().tint(color))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
        }
    }
    
    // MARK: - 辅助方法
    private func loadUserTag() {
        // 先清空旧账户的标签，避免接口返回 nil/空数组时仍展示上一个账号的 tag
        self.statusTag = []
        let params = ["tagType":["0"]]
        BgResultNetWork<[String:[String]],UserTagListDTO>.post(apiUrl(USER_TAG_LIST), params: params)
            .complicationHand {(r:UserTagListDTO?) in
                self.statusTag = r?.tagMap["0"] ?? []
            }
            .responseDecodable()
    }
}

#Preview {
    HeaderOfPersonInfo()
}
