//
//  CitySelect.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/9/18.
//

import SwiftUI

struct CitySelect: View {
    @Binding var selectedCity: String
    @State private var searchText = ""
    @State private var cityGroups: [CityGroup] = []
    @Environment(\.dismiss) private var dismiss
    
    // 过滤后的城市组
    private var filteredCityGroups: [CityGroup] {
        if searchText.isEmpty {
            return cityGroups
        } else {
            return cityGroups.compactMap { group in
                let filteredCities = group.city.filter { city in
                    return city.name.localizedCaseInsensitiveContains(searchText) || city.py.lowercased().contains(searchText.lowercased()) || city.pys.lowercased().contains(searchText.lowercased());
                }
                return filteredCities.isEmpty ? nil : CityGroup(group: group.group, city: filteredCities)
            }
        }
    }
    
    var body: some View {
        VStack {
            VStack {
                // 搜索栏
                SearchBar(text: $searchText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                
                // 城市列表
               
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        ForEach(filteredCityGroups) { group in
                            VStack {
                                GroupHeader(letter: group.group)
                                VStack {
                                    ForEach(group.city, id: \.self.name) { city in
                                        CityRow(
                                            cityName: city.name,
                                            isSelected: selectedCity == city.name
                                        ) {
                                            selectedCity = city.name
                                            // 这里可以添加选择城市后的回调
                                            dismiss()
                                        }
                                    }
                                }.padding(20)
                                    .glassContainer(.regular.interactive(), cornerRadius: 20)
                                
                            }.padding(.horizontal, 30)
                        }
                    }
                    // 右侧字母索引
                    .overlay(
                        AlphabetIndex(
                            letters: filteredCityGroups.map { $0.group },
                            onLetterTapped: { letter in
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(letter, anchor: .top)
                                }
                            }
                        ),
                        alignment: .trailing
                    )
                }
            }
        }
        
        .onAppear {
            loadCityData()
        }
    }
    
    // 加载城市数据
    private func loadCityData() {
        guard let url = Bundle.main.url(forResource: "city", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let groups = try? JSONDecoder().decode([CityGroup].self, from: data) else {
            print("Failed to load city data")
            return
        }
        cityGroups = groups
    }
}

// 搜索栏组件
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("搜索城市", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .inputFieldStyle()
    }
}

// 分组标题
struct GroupHeader: View {
    let letter: String
    
    var body: some View {
        HStack {
            Text(letter)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Color("text_primary"))
            Spacer()
        }
        .padding(.vertical, 4)
        .id(letter) // 用于滚动定位
    }
}

// 城市行
struct CityRow: View {
    let cityName: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            Text(cityName)
                .font(.body)
                .foregroundColor(Color("text_primary"))
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(AppColor.primary)
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// 字母索引
struct AlphabetIndex: View {
    let letters: [String]
    let onLetterTapped: (String) -> Void
    
    var body: some View {
        VStack(spacing: 2) {
            ForEach(letters, id: \.self) { letter in
                Button(action: {
                    onLetterTapped(letter)
                }) {
                    Text(letter)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColor.primary)
                        .frame(width: 20, height: 20)
                }
            }
        }
        .padding(.trailing, 8)
        .padding(.vertical, 20)
    }
}



// 城市数据模型
struct CityGroup: Codable, Identifiable {
    let id = UUID()
    let group: String
    let city: [City]
    
    private enum CodingKeys: String, CodingKey {
        case group, city
    }
}

struct City : Codable {
    let name: String
    let py: String
    let pys: String
}


struct CitySelect_Previews: PreviewProvider {
    static var previews: some View {
        @State var city:String = "杭州"
        return CitySelect(selectedCity: $city);
    }
}
