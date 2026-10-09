//
//  PopIconType.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/2/24.
//
import SwiftUI

enum PopIconEnum {
    case type1
    case type2
    case type3
    case warn
    func iconName() -> String {
        switch(self) {
        case .type1:
            return "smiling_face_with_smiling_eyes_3d";
        case .type2:
            return "crying_face_3d";
        case .type3:
            return "face_holding_back_tears_3d";
        case .warn:
            return "warning_3d";
        }
    }
}
