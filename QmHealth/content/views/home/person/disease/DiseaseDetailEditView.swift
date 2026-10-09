//
//  DiseaseDetailEditView.swift
//  QmHealth
//  疾病详情编辑页面 - 使用 TabView 分离疾病信息和就诊记录
//
//  Created by 周荥马 on 2025/10/2.
//

import SwiftUI

struct DiseaseDetailEditView: View {
    @Binding var diseaseInfo: DiseaseInfo?
    var onUpdate: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var isNewDisease: Bool = false
    @ObservedObject private var diseaseEditorInfo = DiseaseEditorInfo()
    private let subPopManager = SubPopManager()
    @State private var tabIndex = 0
    
    var body: some View {
        VStack {
            navigationHeader
            TabView(selection: $tabIndex) {
               
                // 第一个标签页：疾病信息
                DiseaseInfoTab(
                    diseaseEditorInfo: diseaseEditorInfo,
                    isNewDisease: isNewDisease,
                    subPopManager: subPopManager,
                    onDelete: { deleteDisease(diseaseEditorInfo.id) }
                ).tag(0)
                
                // 第二个标签页：就诊记录
                MedicalRecordsTab(diseaseId: diseaseEditorInfo.id)
                    .tag(1)
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .onChange(of: tabIndex, { oldValue, newValue in
            KeyBoardUtils.toHideKeyboard()
        })
        .withLocalSubPop(subPopManager)
        .background(Color("background"))
        .background(ignoresSafeAreaEdges: .all)
        .onAppear {
            initData()
        }
    }
    
    var navigationHeader : some View {
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
                        }.padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .appGlassEffect(.clear.interactive())
                    } else {
                        // Fallback on earlier versions
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
                        Text(tabIndex == 0 ? "编辑疾病" : "就诊记录")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color("text_primary"))
                        HStack(spacing: 8) {
                            ForEach(0...1, id:\.self) { index in
                                RoundedRectangle(cornerRadius: 10)
                                    .frame(width: tabIndex == index ? 16 : 8, height: 6)
                                    .foregroundStyle(tabIndex == index ? Color.theme(.primary): Color("divider"))
                                    .animation(.easeInOut(duration: 0.33), value: tabIndex)
                            }

                        }
                    }
                },
                right: {
                    if tabIndex == 0 {
                        if #available(iOS 26.0, *) {
                            Button {
                                saveDisease()
                                onUpdate?()
                            } label: {
                                Text("保存")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.theme(.primary))
                            }.padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .appGlassEffect(.clear.interactive())
                        } else {
                            // Fallback on earlier versions
                            Button(action: {
                                saveDisease()
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
                        Color.clear.frame(width: 40, height: 40)
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
        if let disease = diseaseInfo {
            let a = DiseaseInfoTransform.trans2EditorInfo(info: disease)
            self.diseaseEditorInfo.id = a.id
            self.diseaseEditorInfo.name = a.name
            self.diseaseEditorInfo.firstVisitTime = a.firstVisitTime
            self.diseaseEditorInfo.severity = a.severity
            self.diseaseEditorInfo.status = a.status
            self.diseaseEditorInfo.doctor = a.doctor
            self.diseaseEditorInfo.hospital = a.hospital
            self.diseaseEditorInfo.followupVisitTime = a.followupVisitTime
            self.diseaseEditorInfo.treatment = a.treatment
            self.diseaseEditorInfo.remarks = a.remarks
            self.isNewDisease = false
        } else {
            self.isNewDisease = true
        }
    }
    
    // MARK: - 数据操作
    
    private func saveDisease() {
        let diseaseInfo = DiseaseInfoTransform.trans2Info(editorInfo: diseaseEditorInfo)
        BgResultNetWork<DiseaseInfo, String>.post(apiUrl(DISEASE_SAVEORUPDATE), params: diseaseInfo)
            .complicationHand { (r: String?) in
                if let onUpdateFunc = onUpdate {
                    onUpdateFunc()
                }
                dismiss()
            }
            .responseDecodable()
    }
    
    private func deleteDisease(_ id: String?) {
        if let id_r = id {
            let param = ["id": id_r]
            BgResultNetWork<[String: String], UInt64>.post(apiUrl(DISEASE_DELETE), params: param)
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
