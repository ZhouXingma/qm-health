//
//  LineProgress.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/9/14.
//

import SwiftUI

struct LineProgress: View {
    var lineHeight:Double = 10.0
    var colors:[Color] = [.color4]
    @Binding var progress:Double
    @State private var showAnimal = false;
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 轨道：液态玻璃
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(AppColor.divider)
                    .frame(height: lineHeight)

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LinearGradient(
                        colors: colors,
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: showAnimal ? geometry.size.width * progress : 0, height: lineHeight)
                    .animation(.easeInOut(duration: 2), value: showAnimal)
                    .animation(.easeInOut(duration: 2), value: progress)
            }
        }.onAppear() {
                showAnimal = true
            }
    }
}

struct LineProgressPreView: PreviewProvider {
   
    static var previews: some View {
        
        let globalModel = GlobalModel.shared;
        @State var a:Double = 0.8
        return LineProgress(progress: $a).environmentObject(globalModel)
    }
}
