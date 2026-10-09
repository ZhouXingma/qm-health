//
//  CircleProgress.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/9/13.
//

import SwiftUI

struct SemicircleProgress: View {
    var lineWeight:Double = 10.0
    var colors:[Color] = [.color4,.color3]
    @Binding var progress:Double
    @State private var showAnimal = false;
    
    
    var body: some View {
        ZStack(alignment: .top) {
            Circle()
                .trim(from: 0, to: 0.5)
                .stroke(style: .init(lineWidth: lineWeight, lineCap: .round))
                .fill(Color(.systemGray6))
                .rotationEffect(Angle(degrees: 180))
            Circle()
                .trim(from: 0, to: showAnimal ? 0.5 * progress : 0)
                .stroke(style: .init(lineWidth: lineWeight, lineCap: .round))
                .rotationEffect(Angle(degrees: -180))
                .foregroundStyle(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                .animation(.easeInOut(duration: 2), value: showAnimal)
                .animation(.easeInOut(duration: 2), value: progress)
        }.onAppear() {
            self.showAnimal = true
        }
    }
}

struct SemicircleProgressPreView: PreviewProvider {
   
    static var previews: some View {
        let globalModel = GlobalModel.shared;
        @State var a:Double = 1
        return SemicircleProgress(progress: $a).environmentObject(globalModel)
    }
}
