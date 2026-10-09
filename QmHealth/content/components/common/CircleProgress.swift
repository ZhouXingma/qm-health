//
//  CircleProgress.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/11/16.
//

import SwiftUI

struct CircleProgress: View {
    var lineWeight:Double = 10.0
    var colors:[Color] = [.color4,.color3]
    @Binding var progress:Double
    @State private var showAnimal = false;
    
    
    var body: some View {
        ZStack(alignment: .top) {
            Circle()
                .trim(from: 0, to: 1)
                .stroke(style: .init(lineWidth: lineWeight, lineCap: .round))
                .fill(Color(.systemGray6))
                .rotationEffect(Angle(degrees: 180))
            Circle()
                .trim(from: 0, to: showAnimal ? progress : 0)
                .stroke(style: .init(lineWidth: lineWeight, lineCap: .round))
                .rotationEffect(Angle(degrees: -90))
                .foregroundStyle(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                .animation(.easeInOut(duration: 2), value: showAnimal)
                .animation(.easeInOut(duration: 2), value: progress)
        }.onAppear() {
            self.showAnimal = true
        }
    }
}

#Preview {
    @Previewable @State var a:Double = 1
    CircleProgress(progress: $a)
}
