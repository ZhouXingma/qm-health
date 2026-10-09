//
//  MetricTile.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/10/15.
//

import SwiftUI

struct MetricTile: View {
    @Binding var value: String
    @Binding var trend: Trend?
    @Binding var lastUpdateDate: Date?
    var icon: String
    var title: String
    var unit: String?
    var onClient: (() -> Void)? = nil
   
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(AppColor.primary)
                    }
                   
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))
                
                Spacer()
                
                trendIcon
            }
            VStack {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(value)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color("text_primary"))
                    if let unit_r = unit {
                        Text(unit_r)
                            .font(.footnote)
                            .foregroundStyle(Color("text_secondary"))
                    }
                    Spacer()
                }.frame(maxHeight: .infinity, alignment: .center)
                HStack {
                    if let lastUpdateDateValue = lastUpdateDate {
                        Text(formattedDateTime(lastUpdateDateValue))
                            .font(.caption2)
                            .foregroundStyle(Color("text_secondary"))
                    }
                    Spacer()
                }
            }
            
        }.frame(height: 100)
        .frame(maxWidth: .infinity, alignment: .top)
        .contentShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .onTapGesture {
            onClient?()
        }
        .cardStyle()
    }
    
    
    var trendIcon : some View {
        HStack {
            if let trendValue = trend {
                Image(systemName: trendValue.icon)
                    .font(.caption)
                    .foregroundStyle(trendValue.color)
                    .padding(6)
                    .background(trendValue.color.opacity(0.12), in: Circle())
            }
        }
    }
    
    // MARK: - 辅助方法
    private func formattedDateTime(_ date: Date) -> String {
        return DateUtils.formatDate(date, format: DateUtils.DateFormat.ymdhms)
    }
}

#Preview {
    @Previewable @State var value:String = "23";
    @Previewable @State var trend:Trend? = .down;
    @Previewable @State var lastUpdateDate: Date? = Date()
    return MetricTile(value: $value, trend: $trend,lastUpdateDate:$lastUpdateDate, icon: "arrow.up.and.down", title: "身高", unit: "cm");
}
