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
    // 患者状态标签
    @State private var statusTag: [String] = []
    // 患者头像图片
    private var headImageId:String? {
        get {
            return globalModel.currentUser?.headerImg
        }
    }
    var body: some View {
        // 基本头像和基本信息
        HStack(alignment: .top) {
            NavigationLink {
                PersonInfoDetail()
            } label: {
                PersonHeaderImage(headerImgId: .constant(headImageId))
                    .frame(width: 45, height: 45)
            }
            VStack(alignment: .leading){
                HStack {
                    Text(globalModel.currentUser?.name ?? "未设置用户名").font(.system(size: 16, weight: .bold))
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
