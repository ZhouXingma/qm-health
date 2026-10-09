//
//  MedicineTabHeader.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/12/8.
//

import SwiftUI

// MARK: - 用药子页面头部（标题 + 分页指示器 + 右侧操作按钮）
struct MedicineTabHeader: View {
    @Binding var selectedTab: Int
    @Binding var showAddRecord: Bool
    @Binding var showAddPlanRecord: Bool
    private let titles = ["用药记录", "用药计划"]
    
    var body: some View {
        HStack(spacing: 0) {
            // 左侧占位，保持标题居中
            Color.clear
                .frame(width: 36, height: 36)
            
            Spacer()
            
            // 中间标题和圆点指示器
            VStack(spacing: 8) {
                Text(titles[selectedTab])
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.theme(.primary), Color.theme(.secondary)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                // 圆点指示器
                HStack(spacing: 8) {
                    ForEach(0..<titles.count, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 10)
                            .frame(width: index == selectedTab ? 16 : 8, height: 6)
                            .foregroundStyle(index == selectedTab ? Color.theme(.primary) : Color("divider"))
                            .animation(.easeInOut(duration: 0.25), value: selectedTab)
                    }
                }
            }
            
            Spacer()
            
            // 右侧添加按钮，仅在"用药记录"页展示
            if selectedTab == 0 {
                Button(action: { showAddRecord = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .appGlass(.regular.interactive().tint(Color.theme(.primary)), in: Circle())
                }
            } else if selectedTab == 1 {
                Button(action: { showAddPlanRecord = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .appGlass(.regular.interactive().tint(Color.theme(.primary)), in: Circle())
                }
            } else {
                Color.clear
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}
