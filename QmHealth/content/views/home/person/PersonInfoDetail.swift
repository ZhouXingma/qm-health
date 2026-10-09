//
//  PersonInfoDetail.swift
//  QmHealth
//  患者详细信息编辑页面
//
//  Created by 周荥马 on 2025/9/15.
//

import SwiftUI

struct PersonInfoDetail: View {
    
    @Environment(\.dismiss) private var dismiss
    // 患者信息
    @State private var personInfoTabViewIndex: Int = 0
    // 添加患者疾病页面
    @State private var showingDiseaseDetail = false
    // 添加患者过敏原页面
    @State private var showingAllegyInfoDetail = false
    // 添加家族史页面
    @State private var showingFamilyHistoryDetail = false
    // 添加档案信息页面
    @State private var showingProfileInfoDetail = false
    
    
    var body: some View {
        ZStack {
            // 返回按钮和标题
            VStack {
                pageHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                // TabView信息
                TabView(selection: $personInfoTabViewIndex) {
                    PersonBasicInfoView().tag(0)
                    DiseaseListView(showingDiseaseDetail: $showingDiseaseDetail).tag(1)
                    AllegyInfoListView(showingAllegyInfoDetail: $showingAllegyInfoDetail).tag(2)
                    FamilyHistoryListView(showingFamilyHistoryDetail: $showingFamilyHistoryDetail).tag(3)
                    ProfileInfoListView(showingProfileInfoDetail: $showingProfileInfoDetail).tag(4)
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    // 第一个 Tab 无法触发系统返回手势（page 样式会吞掉滑动手势），这里手动补一个边缘返回
                    .edgeSwipeBack(enabled: personInfoTabViewIndex == 0)
                Spacer();
            }
        }.toolbar(.hidden)
            .pageBackground()
            
    }
    // MARK: - 辅助耶main
    // 页面头部信息
    private var pageHeader: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.theme(.primary))
                    .frame(width: 32, height: 32)
                    .glassPill()
            }
            Spacer()
            VStack {
                Text(getPageTitle())
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color("text_primary"))
                HStack {
                    ForEach(0...4, id:\.self) { index in
                        RoundedRectangle(cornerRadius: 10)
                            .frame(width: index == self.personInfoTabViewIndex ? 16 : 8, height: 6, alignment: .center)
                            .foregroundStyle(index == self.personInfoTabViewIndex ? Color.theme(.primary): Color("divider"))
                            .animation(.easeInOut(duration: 0.33), value: self.personInfoTabViewIndex)
                    }
                }
            }
            Spacer()
            // 占位符保持居中
            if self.personInfoTabViewIndex != 0 {
                Button(action: {
                    if self.personInfoTabViewIndex == 1 {
                        self.showingDiseaseDetail = true
                    } else if self.personInfoTabViewIndex == 2 {
                        self.showingAllegyInfoDetail = true
                    } else if self.personInfoTabViewIndex == 3 {
                        self.showingFamilyHistoryDetail = true
                    } else if self.personInfoTabViewIndex == 4 {
                        self.showingProfileInfoDetail = true
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color.theme(.primary))
                        .frame(width: 32, height: 32)
                        .glassPill()
                }
            } else {
                Color.clear
                    .frame(width: 32, height: 32)
            }
           
        }
    }
    
    
    // MARK: - 辅助方法
    private func getPageTitle() -> String {
        if self.personInfoTabViewIndex == 0 {
            return "基本信息"
        }
        if self.personInfoTabViewIndex == 1 {
            return "疾病管理"
        }
        if self.personInfoTabViewIndex == 2 {
            return "过敏源"
        }
        if self.personInfoTabViewIndex == 3 {
            return "家族史"
        }
        if self.personInfoTabViewIndex == 4 {
            return "档案信息"
        }
        return "个人档案"
    }
}
    
    
#Preview {
    PersonInfoDetail()
        .environmentObject(GlobalModel.shared)
}
