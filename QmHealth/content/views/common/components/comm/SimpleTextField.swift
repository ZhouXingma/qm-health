//
//  SimpleTextField.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/9/17.
//

import SwiftUI

struct SimpleTextField: View {
    var placeholder: String = ""
    @Binding var text: String
    
    var body: some View {
        VStack {
            TextField(placeholder, text: $text)
                .font(.system(size: 16))
                .inputFieldStyle()
        }
    }
}

struct SimpleTextField_Previews: PreviewProvider {
    static var previews: some View {
        @State var text:String = ""
        return SimpleTextField(placeholder: "请输入",text: $text)
    }
}
