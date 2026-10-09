//
//  KeyBoardUtils.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/2/25.
//

import UIKit

struct KeyBoardUtils {
    static func toHideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

