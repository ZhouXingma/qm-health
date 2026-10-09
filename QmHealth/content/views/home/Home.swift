import SwiftUI
import Alamofire

struct Home: View {
    // 环境变量
    @EnvironmentObject var globalModel:GlobalModel;
    // 患者首页
    @State private var homePersonInfoTabViewIndex: Int = 0
    // 首页刷新事件总线（注入给各子组件，监听 refreshTrigger 变化触发 reload）
    @StateObject private var refreshBus = HomeRefreshBus.shared
    var body: some View {
        ZStack {
            // 首页主题内容
            ScrollView(showsIndicators: false) {
                Color.clear.frame(height: 60)
                VStack {
                    // TabView信息
                    TabView(selection: $homePersonInfoTabViewIndex) {
                        PersonBasicInfoTabView().tag(0)
                        DiseaseInfoTabView().tag(1)
                        AllergyInfoTabView().tag(2)
                    }.frame(height: 300)
                        .tabViewStyle(.page(indexDisplayMode: .never))
                    HStack{
                        ForEach(0...2, id:\.self) { index in
                            RoundedRectangle(cornerRadius: 10)
                                .frame(width: index == self.homePersonInfoTabViewIndex ? 16 : 8, height: 6, alignment: .center)
                                .foregroundStyle(index == self.homePersonInfoTabViewIndex ? Color.theme(.primary): Color("divider"))
                                .animation(.easeInOut(duration: 0.33), value: self.homePersonInfoTabViewIndex)
                        }
                    }
                    // 健康任务模块
                    DailyHealthTaskView()

                    // 健康曲线
                    HealthCurveTabView()

                    // 饮水打卡模块
                    WaterIntakeView()

                    // 健康指标模块
                    HealthIndicatorsView()

                    Color.clear.frame(height: 30)
                }
            }.padding(.horizontal, 20)
            // 下拉刷新：通知总线触发刷新 + 给请求预留窗口
            .refreshable {
                await refreshAll()
            }
            
            VStack {
                // 顶部：个人信息 + 消息按钮
                HStack(alignment: .top) {
                    HeaderOfPersonInfo()
                    MessageNotificationView()
                }.padding(.horizontal, 20)
                .background(LinearGradient(colors:[ AppColor.background.opacity(1),
                    AppColor.background.opacity(0.8),
                    AppColor.background.opacity(0)], startPoint: .top, endPoint: .bottom))
                Spacer()
            }

        }
            .glassBackground()
            // 注入给 ScrollView 内的子组件 + 顶部 Header、消息按钮使用
            .environmentObject(refreshBus)
            .onAppear {
                initData()
            }
    }

    // MARK: - 方法
    func initData() {

    }

    /// 下拉刷新：通知所有子组件 reload；用短暂 sleep 让 loading 指示器有展示时间
    func refreshAll() async {
        refreshBus.triggerRefresh()
        try? await Task.sleep(nanoseconds: 600_000_000)
    }


}

struct Home_Previews: PreviewProvider {
    static var previews: some View {
        let globalModel = GlobalModel.shared;
        // 设置当前用户
        globalModel.currentUser = UserDTO(
            id: "01K1B6DDV396NMC01NM3MZ35KS",
            name: "周荥马",
            nickname: "U1753796228",
            gender: 1,
            birthday: "1994-02-16",
            status: 0,
            certification: 1,
            headerImg: "person.circle.fill",
            job: "软件工程师",
            city: "北京市",
            blood: 1, // A型血
            bloodRh: 1, // RH+
            nationality: 1,
            maritalStatus: 1
        );
        return Home().environmentObject(globalModel)
    }
}
