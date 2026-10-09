//
//  SwiftUIView.swift
//  QmHealth
//  患者头像信息
//
//  Created by 周荥马 on 2025/9/13.
//

import SwiftUI

struct PersonHeaderImage: View {
    // 头像id
    @Binding var headerImgId: String?
    // 头像信息
    @State private var selectedImageData: Data?
    
    var body: some View {
        ZStack(alignment: .center) {
            // 首先放置一个圆形作为背景
            Circle()
                .fill(Color.clear)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            Group {
                if let selectedImageData,
                   let image = UIImage(data: selectedImageData) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
            }
            .foregroundColor(Color.theme(.chart1))
            .clipShape(Circle())
        }.onAppear {
            loadHeadImage()
        }.onChange(of: headerImgId) { oldValue, newValue in
            loadHeadImage()
        }
    }
    
    func loadHeadImage() {
        if let headerImgIdStr = headerImgId {
            let url = apiUrl(FILE_LOAD + "/\(headerImgIdStr)");
            BgResultNetWork<Empty, Data>(url, method: .get)
                .complicationHand { (data:Data?) in
                    if nil != data {
                        self.selectedImageData = data
                    }
                }
                .finalHandleFunc { _ in
                    
                }.response()
        } else {
            self.selectedImageData = nil
        }
    }
}
