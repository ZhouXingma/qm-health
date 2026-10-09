//
//  AccountCard.swift
//  QmHealth
//
//  Created by 周荥马 on 2026/1/23.
//

import SwiftUI

// MARK: - 账号卡片组件
struct AccountCard: View {
    let user: UserDTO
    let isCurrentUser: Bool
    let onSwitch: () -> Void
    let onDelete: () -> Void
    
    // 计算年龄
    private var age: Int? {
        guard let birthday = user.birthday else { return nil }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let birthDate = dateFormatter.date(from: birthday) else { return nil }
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
        return ageComponents.year
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // 头像
                PersonHeaderImage(headerImgId: .constant(user.headerImg))
                    .frame(width: 48, height: 48)

                // 用户信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(user.name ?? "未设置姓名")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color("text_primary"))
                            .lineLimit(1)

                        // 性别标签
                        if let gender = user.gender {
                            Image(systemName: gender == 1 ? "person.fill" : "person.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Circle().fill(gender == 1 ? Color.blue : Color.pink))
                        }

                        // 当前账号标签
                        if isCurrentUser {
                            Text("当前")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.theme(.primary)))
                        }
                    }

                    // 年龄和其他信息
                    HStack(spacing: 10) {
                        if let calculatedAge = age {
                            HStack(spacing: 3) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color("text_secondary"))
                                Text("\(calculatedAge)岁")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color("text_secondary"))
                            }
                        }

                        if let city = user.city, !city.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color("text_secondary"))
                                Text(city)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color("text_secondary"))
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                Spacer()

                // 操作按钮
                if !isCurrentUser {
                    Button(action: onSwitch) {
                        Text("切换")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                    }
                    .background(Capsule().fill(Color.theme(.primary)))
                }
            }
            .padding(12)

            // 底部删除按钮（仅非当前账号显示）
            if !isCurrentUser {
                Divider()

                Button(action: onDelete) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .medium))
                        Text("删除账号")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(Color("error"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .fill(AppColor.content)
        )
        .appShadow(AppShadow.card)
    }
}

// MARK: - 添加账号卡片
struct AddAccountCard: View {
    let onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.theme(.primary).opacity(0.12))
                        .frame(width: 48, height: 48)

                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Color.theme(.primary))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("添加新账号")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color("text_primary"))

                    Text("为家人创建健康档案")
                        .font(.system(size: 12))
                        .foregroundColor(Color("text_secondary"))
                }

                Spacer()
            }
            .padding(12)
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .fill(AppColor.content)
        )
        .appShadow(AppShadow.card)
    }
}

#Preview {
    VStack(spacing: 16) {
        // 当前账号示例
        AccountCard(
            user: UserDTO(
                id: "1",
                name: "张三",
                nickname: nil,
                gender: 1,
                birthday: "1990-01-01",
                status: nil,
                certification: nil,
                headerImg: nil,
                job: nil,
                city: "北京"
            ),
            isCurrentUser: true,
            onSwitch: {},
            onDelete: {}
        )
        
        // 其他账号示例
        AccountCard(
            user: UserDTO(
                id: "2",
                name: "李四",
                nickname: nil,
                gender: 2,
                birthday: "1985-05-15",
                status: nil,
                certification: nil,
                headerImg: nil,
                job: nil,
                city: "上海"
            ),
            isCurrentUser: false,
            onSwitch: {},
            onDelete: {}
        )
        
        // 添加账号卡片
        AddAccountCard(onAdd: {})
    }
    .padding(16)
    .background(Color("background"))
}
