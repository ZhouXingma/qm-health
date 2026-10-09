import SwiftUI
import UIKit

struct WeightManagerDetail: View {
    @Environment(\.dismiss) private var dismiss
    @State var tabIndex = 0;
    @State var addHealthCurvePlan = false;
    @State var tabTitles:[String] = ["总览","计划"]
    
    var body: some View {
        VStack(spacing: 10) {
            pageHeader
                .padding(.horizontal, 20)
                .padding(.top, 10)
//            TabSelectTitle(tabIndex: $tabIndex, tabTitles: tabTitles, bgColor: Color("content_bg"))
//                .padding(.horizontal, 20)
           
            VStack {
                // TabView信息
                TabView(selection: $tabIndex) {
                    HealthCurveOverview().tag(0)
                    HealthCurvePlan(showPlanForm: $addHealthCurvePlan).tag(1)
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color("background"))
        .toolbar(.hidden)
    }
    
    private var pageHeader: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.theme(.primary))
                    .frame(width: 32, height: 32)
                    .glassPill()
            }
            Spacer()
            VStack {
                Text("健康曲线.\(getPageTitle())")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color("text_primary"))
                HStack {
                    ForEach(0..<tabTitles.count, id:\.self) { index in
                        RoundedRectangle(cornerRadius: 10)
                            .frame(width: index == self.tabIndex ? 16 : 8, height: 6, alignment: .center)
                            .foregroundStyle(index == self.tabIndex ? Color.theme(.primary): Color("divider"))
                            .animation(.easeInOut(duration: 0.33), value: self.tabIndex)
                    }
                }
            }
            Spacer()
            // 占位符保持居中
            if self.tabIndex != 0 {
                Button(action: {
                    if self.tabIndex == 1 {
                        self.addHealthCurvePlan = true
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
    
    func getPageTitle() -> String {
        tabTitles[tabIndex]
    }
}

 // MARK: - Preview

#Preview {
    WeightManagerDetail()
}
