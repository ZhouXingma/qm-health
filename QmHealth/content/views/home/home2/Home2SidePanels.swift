//
//  Home2SidePanels.swift
//  QmHealth
//  Home2 肖像浮层：左侧「基本信息 + 过敏源」，右侧「疾病」
//

import SwiftUI

struct Home2SidePanels: View {
    @EnvironmentObject var globalModel: GlobalModel
    @EnvironmentObject var refreshBus: HomeRefreshBus

    @State private var diseases: [DiseaseInfo] = []
    @State private var allergies: [UserAllergy] = []

    @State private var showDiseaseList = false
    @State private var showAllergyList = false
    // 列表页内部的编辑弹层开关
    @State private var diseaseEditorPresented = false
    @State private var allergyEditorPresented = false

    /// 浮层最多展示的条目，其余折叠为 +N
    private let maxDiseases = 6
    private let maxAllergies = 4
    private let leftWidth: CGFloat = 118
    private let rightWidth: CGFloat = 112

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if !basicInfoItems.isEmpty || !allergies.isEmpty {
                VStack(spacing: 10) {
                    if !basicInfoItems.isEmpty {
                        basicInfoPanel
                    }
                    if !allergies.isEmpty {
                        allergyPanel
                    }
                }
                .frame(width: leftWidth)
            }

            Spacer(minLength: 0)

            if !diseases.isEmpty {
                diseasePanel
                    .frame(width: rightWidth)
            }
        }
        .onAppear { loadAll() }
        .onChange(of: refreshBus.refreshTrigger) { _, _ in loadAll() }
    }

    // MARK: - 基本信息（左上）

    private var basicInfoPanel: some View {
        panelChrome(icon: "person.text.rectangle", tint: Color.theme(.primary), title: "基本信息") {
            ForEach(Array(basicInfoItems.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 4) {
                    Text(item.label)
                        .font(.system(size: 9))
                        .foregroundStyle(Color("text_secondary"))
                        .frame(width: 32, alignment: .leading)
                    Text(item.value)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color("text_primary"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: - 过敏源（左下，点击打开过敏源列表）

    private var allergyPanel: some View {
        Button {
            showAllergyList = true
        } label: {
            panel(
                icon: "exclamationmark.triangle.fill",
                tint: Color("warning"),
                title: "过敏源",
                count: allergies.count
            ) {
                ForEach(Array(allergies.prefix(maxAllergies).enumerated()), id: \.offset) { _, allergy in
                    let severity = AllergySeverity.getByCode(code: allergy.severity ?? 1) ?? .mild
                    panelRow(name: allergy.name ?? "未命名", tint: severity.color)
                }
                if allergies.count > maxAllergies {
                    moreText(allergies.count - maxAllergies)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("打开过敏源列表")
        .sheet(isPresented: $showAllergyList, onDismiss: { loadAllergies() }) {
            NavigationStack {
                AllegyInfoListView(showingAllegyInfoDetail: $allergyEditorPresented)
                    .navigationTitle("过敏源列表")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("关闭") {
                                showAllergyList = false
                            }
                        }
                    }
            }
            .presentationBackground(AppColor.background)
        }
    }

    // MARK: - 疾病（右，点击打开疾病列表）

    private var diseasePanel: some View {
        Button {
            showDiseaseList = true
        } label: {
            panel(
                icon: "heart.text.square.fill",
                tint: Color("error"),
                title: "疾病",
                count: diseases.count
            ) {
                ForEach(Array(diseases.prefix(maxDiseases).enumerated()), id: \.offset) { _, disease in
                    let severity = DiseaseSeverity.getByCode(code: disease.severity ?? 1) ?? .mild
                    panelRow(name: disease.name ?? "未命名", tint: severity.color)
                }
                if diseases.count > maxDiseases {
                    moreText(diseases.count - maxDiseases)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("打开疾病列表")
        .sheet(isPresented: $showDiseaseList, onDismiss: { loadDiseases() }) {
            NavigationStack {
                DiseaseListView(showingDiseaseDetail: $diseaseEditorPresented)
                    .navigationTitle("疾病列表")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("关闭") {
                                showDiseaseList = false
                            }
                        }
                    }
            }
            .presentationBackground(AppColor.background)
        }
    }

    // MARK: - 通用浮层

    private func panelChrome<Content: View>(
        icon: String,
        tint: Color,
        title: String,
        trailing: AnyView = AnyView(EmptyView()),
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))
                Spacer(minLength: 0)
                trailing
            }
            content()
        }
        .padding(9)
        .glassContainer(.regular, cornerRadius: 16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    private func panel<Content: View>(
        icon: String,
        tint: Color,
        title: String,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        panelChrome(
            icon: icon,
            tint: tint,
            title: title,
            trailing: AnyView(
                Text("\(count)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.theme(.primary))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.theme(.primary).opacity(0.12))
                    .clipShape(Capsule())
            )
        ) {
            content()
        }
    }

    private func panelRow(name: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(tint)
                .frame(width: 5, height: 5)
            Text(name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color("text_primary"))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private func moreText(_ count: Int) -> some View {
        Text("+\(count) 项")
            .font(.system(size: 10))
            .foregroundStyle(Color("text_secondary"))
    }

    // MARK: - 基本信息字段（缺失的字段不显示）

    private var basicInfoItems: [(label: String, value: String)] {
        guard let user = globalModel.currentUser else { return [] }
        var items: [(label: String, value: String)] = []

        if let blood = bloodText(user) {
            items.append(("血型", blood))
        }
        if let nationality = nationalityText(user.nationality) {
            items.append(("民族", nationality))
        }
        if let job = trimmed(user.job) {
            items.append(("职业", job))
        }
        if let city = trimmed(user.city) {
            items.append(("居住地", city))
        }
        return items
    }

    private func bloodText(_ user: UserDTO) -> String? {
        guard let blood = user.blood else { return nil }
        let type = BloodType.getByCode(code: blood)?.getDesc() ?? ""
        let rh = user.bloodRh.flatMap { BloodRhType.getByCode(code: $0)?.getDesc() } ?? ""
        let text = "\(type)\(rh)"
        return text.isEmpty ? nil : text
    }

    private func nationalityText(_ code: Int64?) -> String? {
        guard let code else { return nil }
        switch code {
        case 1: return "汉族"
        case 2: return "蒙古族"
        case 3: return "回族"
        case 4: return "藏族"
        case 5: return "维吾尔族"
        default: return "其他"
        }
    }

    private func trimmed(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }

    // MARK: - 数据

    private func loadAll() {
        loadDiseases()
        loadAllergies()
    }

    private func loadDiseases() {
        BgResultNetWork<Empty, [DiseaseInfo]>.post(apiUrl(DISEASE_LIST_NOT_RECOVERED), params: nil)
            .complicationHand { (infos: [DiseaseInfo]?) in
                diseases = infos ?? []
            }
            .responseDecodable()
    }

    private func loadAllergies() {
        BgResultNetWork<Empty, [UserAllergy]>.post(apiUrl(ALLERGY_LIST), params: nil)
            .complicationHand { (infos: [UserAllergy]?) in
                allergies = infos ?? []
            }
            .responseDecodable()
    }
}

#Preview {
    Home2SidePanels()
        .environmentObject(GlobalModel.shared)
        .environmentObject(HomeRefreshBus.shared)
        .padding()
        .glassBackground()
}
