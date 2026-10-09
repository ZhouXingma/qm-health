//
//  Index.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/2/28.
//

import SwiftUI

struct Index: View {
    // 环境变量
    @EnvironmentObject var globalModel:GlobalModel;
    // 当前选择的页面
    @State private var currentSelect:Int = 0;
    
    var body: some View {
        NavigationView {
//            ZStack {
//                VStack{
//                    VStack {
//                        if currentSelect == 0 {
//                            Home()
//                        }
//                        if currentSelect == 1 {
//                            MedicalRecordsView()
//                        }
//                        if currentSelect == 2 {
//                            MedicineMainView()
//                        }
//                        if currentSelect == 3 {
//                            PersonalCenter()
//                        }
//                        if currentSelect == 99 {
//                            AiChatMain()
//                        }
//                    }
//                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
//                if globalModel.showSubBar {
//                    SubBar2(currentSelect: $currentSelect)
//                        .padding(.horizontal, 10)
//                }
//            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            VStack {
                if currentSelect != 99 {
                    TabView(selection: $currentSelect) {
                        Tab("", systemImage: "house.fill", value: 0) {
                            Home()
                        }
                        Tab("", systemImage: "heart.text.clipboard.fill", value: 1) {
                            MedicalRecordsView()
                        }
                        Tab("", systemImage: "pill.fill", value: 2) {
                            MedicineMainView()
                        }
                        Tab("", systemImage: "person.fill", value: 3) {
                            PersonalCenter()
                        }
                        if #available(anyAppleOS 27.0, *) {
                            Tab("", systemImage: "sparkles.2", value: 99, role: .prominent) {
                                AiChatMain(selection: $currentSelect)
                            }
                        } else {
                            Tab("", systemImage: "sparkles.2", value: 99, role: .search) {
                                AiChatMain(selection: $currentSelect)
                            }
                        }
                       
                    }.tint(Color.theme(.primary))
                } else {
                    AiChatMain(selection: $currentSelect)
                }
            }
            
             
        }.onAppear() {
            initData();
         }
         .onChange(of: globalModel.pendingAiChatConversationId) { _, newValue in
             if newValue != nil {
                 currentSelect = 99
             }
         }
    }
    
    func initData() {
        // 无需登录
        checkLogin(globalModel);
        // 检查用户是否已设置基本信息
        checkUserSetup(globalModel)
    }
}


struct Index_Previews: PreviewProvider {
    static var previews: some View {
        let globalModel = GlobalModel.shared;
        // 设置当前用户
        globalModel.currentUser = UserDTO(
            id: "01K1B6DDV396NMC01NM3MZ35KS",
            name: "周荥马",
            nickname: "U1753796228",
            gender: 1,
            birthday: "1994-02-16",
            status: 0
        );
        return Index().environmentObject(globalModel)
    }
}
