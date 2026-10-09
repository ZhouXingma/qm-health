//
//  MedicineMainView.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/12/8.
//

import SwiftUI

struct MedicineMainView: View {
    // 当前所在的子标签：0 = 用药记录，1 = 用药计划
    @State private var selectedTab = 0
    // 是否显示添加用药记录弹窗（放在页头右侧按钮，只在"用药记录"页展示）
    @State private var showAddRecord = false
    @State private var showAddPlanRecord = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题 + 分页指示器（左右滑动切换）
            MedicineTabHeader(selectedTab: $selectedTab, showAddRecord: $showAddRecord, showAddPlanRecord: $showAddPlanRecord)

            TabView(selection: $selectedTab) {
                MedicineRecordsTabView(showAddRecord: $showAddRecord)
                    .tag(0)

                MedicinePlanTabView(showAddPlanRecord: $showAddPlanRecord)
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .glassBackground()
        .ignoresSafeArea(.all, edges: .bottom)
    }
}

#Preview {
    MedicineMainView()
        .preferredColorScheme(.light)
}
