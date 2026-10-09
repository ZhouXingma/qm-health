import SwiftUI

struct GlassEffectDemo: View {
    @State private var selectedTab: Int = 0
    
    var body: some View {
        ZStack {
            // 丰富的渐变背景（为了让外面的液态玻璃展现出色彩折射）
            LinearGradient(
                colors: [
                    Color(red: 0.85, green: 0.9, blue: 0.95),
                    Color(red: 0.95, green: 0.85, blue: 0.9),
                    Color(red: 0.9, green: 0.9, blue: 0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                // 顶部页码
                Text(String(format: "%02d", selectedTab + 1))
                    .font(.system(size: 60, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 30)
                    .padding(.top, 50)
                
                Spacer()
                
                // 核心液态玻璃卡片
                GlassCardView(selectedTab: $selectedTab)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - 核心玻璃卡片 (单层液态玻璃，内部光影切分)
struct GlassCardView: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        VStack(spacing: 0) {
            // 内容切换区
            Group {
                switch selectedTab {
                case 0: ECommerceView()
                case 1: FitnessView()
                case 2: SettingsView()
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 420)
            
            // 内部层级分割 (使用半透明白色线模拟玻璃切片)
            Rectangle()
                .fill(Color.white.opacity(0.4))
                .frame(height: 1)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            
            // 自定义底部导航栏
            CustomTabBar(selectedTab: $selectedTab)
                .padding(.top, 5)
                .padding(.bottom, 15)
        }
        // ⭐️ 唯一一次液态玻璃应用
        .appGlass(.regular, in: .rect(cornerRadius: 45, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 45, style: .continuous))
        
        // 内部边缘高光 (模拟内部玻璃厚度)
        .overlay(
            RoundedRectangle(cornerRadius: 45, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.8), .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 30, x: 0, y: 15)
    }
}

// MARK: - 页面 1：电商 (Design 01)
struct ECommerceView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Crush Contrast").font(.title2).bold()
                    Text("€165,95").font(.title3).foregroundStyle(.secondary)
                }
                Spacer()
                // 模拟模特图 (用渐变块代替，避免外部资源)
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearGradient(colors: [Color.cyan.opacity(0.4), Color.blue.opacity(0.2)], startPoint: .top, endPoint: .bottom))
                    Image(systemName: "person.fill")
                        .resizable()
                        .scaledToFit()
                        .padding()
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(width: 100, height: 80)
            }
            .padding(20)
            // ⭐️ 绝对不用 Material，使用透明底色 + 高光
            .background(Color.white.opacity(0.3), in: RoundedRectangle(cornerRadius: 25))
            .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.white.opacity(0.6), lineWidth: 1))
            
            HStack(spacing: 15) {
                CategoryButton(icon: "figure.walk", title: "Pants")
                CategoryButton(icon: "eyeglasses", title: "Glasses")
                CategoryButton(icon: "tshirt", title: "Shirts")
                CategoryButton(icon: "tshirt.fill", title: "Shorts")
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 20)
    }
}

// MARK: - 页面 2：健身 (Design 02)
struct FitnessView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading) {
                    Text("October 20, 2025").font(.caption).foregroundStyle(.secondary)
                    Text("Welcome Back, Chloe").font(.title2).bold()
                }
                Spacer()
                Circle().fill(Color.gray).frame(width: 40).overlay(Image(systemName: "person.crop.circle"))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            VStack(alignment: .leading) {
                Text("Your Goal").font(.caption).foregroundStyle(.secondary)
                Text("413 kcal").font(.largeTitle).bold().foregroundStyle(.orange)
                
                ZStack {
                    // 模拟折线
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 50))
                        path.addCurve(to: CGPoint(x: 300, y: 20), control1: CGPoint(x: 100, y: 10), control2: CGPoint(x: 200, y: 60))
                    }
                    .stroke(Color.orange, lineWidth: 3)
                    
                    Circle().fill(Color.orange).frame(width: 10).offset(x: 140, y: -15)
                    Text("163 Kcal").font(.caption2).offset(x: 140, y: -35)
                }
                .frame(height: 80)
                .padding(.top, 20)
            }
            .padding(20)
            // ⭐️ 绝对不用 Material，使用透明底色 + 高光
            .background(Color.white.opacity(0.3), in: RoundedRectangle(cornerRadius: 25))
            .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.white.opacity(0.6), lineWidth: 1))
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - 页面 3：设置 (Design 03)
struct SettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button("Back") {}.buttonStyle(.bordered).clipShape(Capsule())
                Spacer()
                Circle().fill(Color.gray).frame(width: 40).overlay(Image(systemName: "person.crop.circle"))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            ZStack {
                Circle().fill(Color.orange.opacity(0.2)).frame(width: 120)
                Image(systemName: "bell.badge.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50)
                    .foregroundStyle(Color.orange)
            }
            .padding(.top, 20)
            
            Text("Setup Updates").font(.title3).bold()
            Text("To get the latest update properly, make sure to apply the necessary configurations.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            
            Spacer()
        }
    }
}

// MARK: - 辅助视图：分类按钮
struct CategoryButton: View {
    let icon: String
    let title: String
    
    var body: some View {
        VStack {
            Image(systemName: icon).font(.title3)
            Text(title).font(.caption2)
        }
        .frame(width: 70, height: 70)
        // ⭐️ 绝对不用 Material，使用透明底色 + 高光
        .background(Color.white.opacity(0.3), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.7), lineWidth: 1))
    }
}

// MARK: - 自定义玻璃底栏
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack {
            TabButton(icon: "house.fill", title: "Home", isSelected: selectedTab == 0) { selectedTab = 0 }
            TabButton(icon: "chart.line.uptrend.xyaxis", title: "Analyze", isSelected: selectedTab == 1) { selectedTab = 1 }
            
            ZStack {
                Circle().fill(Color.black).frame(width: 60, height: 60)
                Image(systemName: "plus").foregroundStyle(.white).font(.title2)
            }
            .offset(y: -25)
            .onTapGesture { selectedTab = 2 }
            
            TabButton(icon: "bell.badge.fill", title: "Updates", isSelected: selectedTab == 2) { selectedTab = 2 }
            TabButton(icon: "square.stack.3d.up", title: "Projects", isSelected: selectedTab == 3) { selectedTab = 3 }
        }
        .padding(.horizontal, 30)
        // 底部区域使用伪渐变来透出外面的光线，形成玻璃底部的厚重感
        .background(
            LinearGradient(
                colors: [.white.opacity(0), .white.opacity(0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - 辅助视图：底栏按钮
struct TabButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                Text(title).font(.caption)
            }
            .foregroundStyle(isSelected ? Color.black : Color.gray)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    GlassEffectDemo()
}
