//
//  AllergyInfoEditSheet.swift
//  QmHealth
//  过敏源详情编辑页面 - 使用 TabView 分离过敏信息和过敏记录
//
//  Created by 周荥马 on 2025/10/12.
//

import SwiftUI

struct AllergyInfoEditSheet: View {
    @Binding var userAllergy: UserAllergy?
    var onUpdate: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var isNewAllergyInfo: Bool = true
    @ObservedObject private var allergyEditorInfo = AllergyEditorInfo()
    @State private var tabIndex = 0
    @State private var showCreateRecordSheet = false
    
    var body: some View {
        VStack {
            navigationHeader
            TabView(selection: $tabIndex) {
                // 第一个标签页：过敏信息编辑
                AllergyInfoTab(
                    allergyEditorInfo: allergyEditorInfo,
                    isNewAllergyInfo: isNewAllergyInfo,
                    onDelete: { deleteAllergyInfo(allergyEditorInfo.id) }
                ).tag(0)

                // 第二个标签页：过敏记录（仅已保存的过敏源显示，新增时没有记录可添加）
                if !isNewAllergyInfo {
                    AllergyRecordsTab(allergyId: allergyEditorInfo.id)
                        .tag(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .onChange(of: tabIndex, { oldValue, newValue in
            KeyBoardUtils.toHideKeyboard()
        })
        .background(Color("background"))
        .background(ignoresSafeAreaEdges: .all)
        .sheet(isPresented: $showCreateRecordSheet) {
            CreateAllergyRecordSheet(
                allergyId: allergyEditorInfo.id,
                onRecordCreated: {
                    // 刷新记录列表
                }
            )
        }
        .onAppear {
            initData()
        }
    }
    
    var navigationHeader: some View {
        HStack {
            NavigationHeader(
                left: {
                    if #available(iOS 26.0, *) {
                        Button {
                            dismiss()
                        } label: {
                            Text("取消")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.gray)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .appGlassEffect(.clear.interactive())
                    } else {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color.theme(.primary))
                                .frame(width: 40, height: 40)
                                .background(Color("content_bg"))
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                        }
                    }
                },
                center: {
                    VStack(spacing: 8) {
                        Text(tabIndex == 0 ? "编辑过敏源" : "过敏记录")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color("text_primary"))
                        HStack(spacing: 8) {
                            ForEach(0..<(isNewAllergyInfo ? 1 : 2), id: \.self) { index in
                                RoundedRectangle(cornerRadius: 10)
                                    .frame(width: tabIndex == index ? 16 : 8, height: 6)
                                    .foregroundStyle(tabIndex == index ? Color.theme(.primary) : Color("divider"))
                                    .animation(.easeInOut(duration: 0.33), value: tabIndex)
                            }
                        }
                    }
                },
                right: {
                    if tabIndex == 0 {
                        if #available(iOS 26.0, *) {
                            Button {
                                saveAllergyInfo()
                                onUpdate?()
                            } label: {
                                Text("保存")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.theme(.primary))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .appGlassEffect(.clear.interactive())
                        } else {
                            Button(action: {
                                saveAllergyInfo()
                                onUpdate?()
                            }) {
                                Image(systemName: "tray.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Color.theme(.primary))
                                    .frame(width: 40, height: 40)
                                    .background(Color("content_bg"))
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                            }
                        }
                    } else {
                        if #available(iOS 26.0, *) {
                            Button {
                                showCreateRecordSheet = true
                            } label: {
                                Text("添加")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.theme(.primary))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .appGlassEffect(.clear.interactive())
                        } else {
                            Button(action: {
                                showCreateRecordSheet = true
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Color.theme(.primary))
                                    .frame(width: 40, height: 40)
                                    .background(Color("content_bg"))
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                            }
                        }
                    }
                }
            )
        }
    }
    
    // MARK: - 数据初始化
    private func initData() {
        initForm()
    }
    
    private func initForm() {
        if let allergy = userAllergy {
            allergyEditorInfo.id = allergy.id ?? ""
            allergyEditorInfo.name = allergy.name ?? ""
            allergyEditorInfo.severity = allergy.severity ?? 1
            allergyEditorInfo.treatment = allergy.treatment ?? ""
            allergyEditorInfo.remarks = allergy.remarks ?? ""
            isNewAllergyInfo = false
        } else {
            isNewAllergyInfo = true
        }
    }
    
    // MARK: - 数据操作
    private func saveAllergyInfo() {
        var allergy = UserAllergy()
        allergy.name = StringUtils.emptyStr2DefaultStr(allergyEditorInfo.name, defaultValue: nil)
        allergy.severity = allergyEditorInfo.severity
        allergy.treatment = StringUtils.emptyStr2DefaultStr(allergyEditorInfo.treatment, defaultValue: nil)
        allergy.remarks = StringUtils.emptyStr2DefaultStr(allergyEditorInfo.remarks, defaultValue: nil)
        if !allergyEditorInfo.id.isEmpty {
            allergy.id = allergyEditorInfo.id
        }
        BgResultNetWork<UserAllergy, String>.post(apiUrl(ALLERGY_SAVEORUPDATE), params: allergy)
            .complicationHand { (r: String?) in
                if let onUpdateFunc = onUpdate {
                    onUpdateFunc()
                }
                dismiss()
            }
            .responseDecodable()
    }
    
    private func deleteAllergyInfo(_ id: String?) {
        if let id_r = id {
            let param = ["id": id_r]
            BgResultNetWork<[String: String], UInt64>.post(apiUrl(ALLERGY_DELETE), params: param)
                .complicationHand { (r: UInt64?) in
                    if let onUpdateFunc = onUpdate {
                        onUpdateFunc()
                    }
                    dismiss()
                }
                .responseDecodable()
        }
    }
}
