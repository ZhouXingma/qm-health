//
//  DateTimePickerSheet.swift
//  QmHealth
//
//  Created by 周荥马 on 2026/3/27.
//

import SwiftUI

struct DateTimePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDateTime: String
    @Binding var isPresented: Bool
    
    @State private var selectedDate = Date()
    @State private var selectedHour = 12
    @State private var selectedMinute = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    // 日期选择
                    VStack(alignment: .leading, spacing: 8) {
                        Text("选择日期")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color("text_secondary"))
                        
                        DatePicker(
                            "",
                            selection: $selectedDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .frame(maxHeight: 350)
                    }
                    
                    Divider()
                    
                    // 时间选择
                    VStack(alignment: .leading, spacing: 12) {
                        Text("选择时间")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color("text_secondary"))
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .center, spacing: 8) {
                                Text("时")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color("text_secondary"))
                                
                                Picker("", selection: $selectedHour) {
                                    ForEach(0..<24, id: \.self) { hour in
                                        Text(String(format: "%02d", hour)).tag(hour)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(maxHeight: 150)
                            }
                            
                            VStack(alignment: .center, spacing: 8) {
                                Text("分")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color("text_secondary"))
                                
                                Picker("", selection: $selectedMinute) {
                                    ForEach(0..<60, id: \.self) { minute in
                                        Text(String(format: "%02d", minute)).tag(minute)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(maxHeight: 150)
                            }
                            
                            Spacer()
                        }
                    }
                }
                .padding(16)
                .glassContainer(.regular.interactive(), cornerRadius: 12)
                
                Spacer()
                
                // 确认按钮
                Button {
                    confirmDateTime()
                } label: {
                    Text("确认")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColor.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                }.buttonStyle(SecondaryActionButtonStyle())
            }
            .padding(16)
            .background(Color("background"))
            .navigationTitle("选择时间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isPresented = false
                    }
                    .foregroundStyle(Color("text_secondary"))
                }
            }
        }
    }
    
    private func confirmDateTime() {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        components.hour = selectedHour
        components.minute = selectedMinute
        
        if let finalDate = calendar.date(from: components) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            selectedDateTime = formatter.string(from: finalDate)
            isPresented = false
        }
    }
}
