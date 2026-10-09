//
//  OcrIndicatorSelectView.swift
//  QmHealth
//
//  Created by 周荥马 on 2026/8/27.
//

import SwiftUI

// 供 OCR 识别页复用的指标选择 sheet：可搜索的分组列表，选中的指标通过 onSelect 回调返回
struct OcrIndicatorSelectView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (HealthIndicatorMetaItem) -> Void

    @State private var searchText: String = ""
    @State private var isLoading: Bool = false
    @State private var indicatorGroups: [HealthIndicatorMetaGroup] = []
    @State private var loadError: String? = nil
    @FocusState private var isSearchFocused: Bool
    // 是否已选中过（防止双击重复回调/重复添加）
    @State private var hasSelected: Bool = false

    private var filteredGroups: [HealthIndicatorMetaGroup] {
        guard !searchText.isEmpty else { return indicatorGroups }
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if keyword.isEmpty { return indicatorGroups }
        return indicatorGroups.compactMap { group in
            let items = group.indicators.filter { item in
                (item.indicatorName?.localizedCaseInsensitiveContains(keyword) ?? false) ||
                (item.indicatorCode?.localizedCaseInsensitiveContains(keyword) ?? false) ||
                (item.description?.localizedCaseInsensitiveContains(keyword) ?? false)
            }
            return items.isEmpty ? nil : HealthIndicatorMetaGroup(categoryCode: group.categoryCode, categoryName: group.categoryName, indicators: items)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "选择指标")
                .padding(.bottom, 16)

            // 搜索框
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color("text_secondary"))

                TextField("搜索指标名称、代码或描述", text: $searchText)
                    .font(.system(size: 14))
                    .foregroundStyle(Color("text_primary"))
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .focused($isSearchFocused)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color("text_secondary"))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .appGlass(.regular.interactive(),
                      in: RoundedRectangle(cornerRadius: 10, style: .continuous)) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppColor.input)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(Color.theme(.primary))
                    Text("正在加载指标...")
                        .font(.system(size: 14))
                        .foregroundColor(Color("text_secondary"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = loadError {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 40))
                        .foregroundColor(Color("text_secondary").opacity(0.6))
                    Text("加载失败")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color("text_primary"))
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(Color("text_secondary"))
                    Button("重新加载") {
                        loadIndicators()
                    }
                    .buttonStyle(PrimaryActionButtonStyle(cornerRadius: 20, verticalPadding: 8))
                    .frame(width: 120)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredGroups.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(Color("text_secondary").opacity(0.6))
                    Text("未找到相关指标")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color("text_primary"))
                    Text("尝试更换搜索关键词")
                        .font(.system(size: 13))
                        .foregroundColor(Color("text_secondary"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        ForEach(filteredGroups, id: \.categoryCode) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.stack.3d.up.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color.theme(.primary))
                                    Text(group.categoryName)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color("text_primary"))
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.top, 10)

                                VStack(spacing: 0) {
                                    ForEach(group.indicators, id: \.indicatorCode) { item in
                                        Button(action: {
                                            guard !hasSelected else { return }
                                            hasSelected = true
                                            onSelect(item)
                                            dismiss()
                                        }) {
                                            HStack(alignment: .top, spacing: 10) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    HStack(spacing: 6) {
                                                        Text(item.indicatorName ?? "")
                                                            .font(.system(size: 16, weight: .medium))
                                                            .foregroundColor(Color("text_primary"))
                                                            .lineLimit(1)
                                                        if let unit = item.unit, !unit.isEmpty {
                                                            Text(unit)
                                                                .font(.system(size: 11))
                                                                .foregroundColor(Color("text_secondary"))
                                                        }
                                                    }

                                                    if let desc = item.description, !desc.isEmpty {
                                                        Text(desc)
                                                            .font(.system(size: 12))
                                                            .foregroundColor(Color("text_secondary"))
                                                            .lineLimit(2)
                                                    }

                                                    if let code = item.indicatorCode {
                                                        Text(code)
                                                            .font(.system(size: 11))
                                                            .foregroundColor(Color("text_secondary").opacity(0.8))
                                                    }
                                                }
                                                Spacer()

                                                Chip(text: item.resultTypeText, color: item.resultTypeColor)
                                                    .font(.system(size: 12, weight: .medium))
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                        }

                                        if item.indicatorCode != group.indicators.last?.indicatorCode {
                                            Divider()
                                                .padding(.leading, 12)
                                        }
                                    }
                                }
                                .glassContainer(.regular.interactive(), cornerRadius: 14)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
            }
        }
        .sheetAppBackground()
        .onAppear {
            if indicatorGroups.isEmpty {
                loadIndicators()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isSearchFocused = true
            }
        }
    }

    private func loadIndicators() {
        isLoading = true
        loadError = nil

        BgResultNetWork<Empty?, [HealthIndicatorMetaGroup]>.post(apiUrl(HEALTH_INDICATOR_META_LIST))
            .complicationHand { data in
                indicatorGroups = data ?? []
            }
            .errorHandle { _, error in
                switch error {
                case .timeout(_, let message),
                     .network(_, let message),
                     .parameter(_, let message),
                     .parsing(_, let message),
                     .http(_, let message),
                     .validation(_, let message),
                     .requestError(_, let message),
                     .unknown(_, let message):
                    loadError = message
                }
            }
            .finalHandleFunc { _ in
                isLoading = false
            }
            .responseDecodable()
    }
}