//
//  AggreenView.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/2/27.
//

import SwiftUI

struct AggreenView: View {
    @Binding var isAgreen: Bool
    @State private var presentedAgreement: AgreementType?

    var body: some View {
        HStack(spacing: 2) {
            Button {
                isAgreen.toggle()
            } label: {
                Image(systemName: isAgreen ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17))
                    .foregroundStyle(isAgreen ? Color.theme(.primary) : AppColor.textSecondary)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.15), value: isAgreen)

            Text("我已阅读并同意")

            Button {
                presentedAgreement = .userAgreement
            } label: {
                Text("《用户协议》")
                    .fontWeight(.bold)
                    .foregroundStyle(Color.theme(.primary))
                    .underline()
            }
            .buttonStyle(.plain)

            Text("和")

            Button {
                presentedAgreement = .privacyPolicy
            } label: {
                Text("《隐私政策》")
                    .fontWeight(.bold)
                    .foregroundStyle(Color.theme(.primary))
                    .underline()
            }
            .buttonStyle(.plain)
        }
        .font(.system(size: 13))
        .frame(maxWidth: .infinity, minHeight: 30, maxHeight: 30, alignment: .leading)
        .padding(.horizontal, 30)
        .padding(.bottom, 10)
        .sheet(item: $presentedAgreement) { type in
            AgreementView(type: type)
        }
    }
}

#Preview {
    @Previewable @State var agreed = false
    return AggreenView(isAgreen: $agreed)
}