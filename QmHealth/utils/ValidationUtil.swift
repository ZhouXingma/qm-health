//
//  ValidationUtil.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/2/27.
//

import Foundation

// 密码验证失败类型
enum PasswordValidationError: String, Error {
    case tooShort = "密码至少要大于6位"
    case missingLetterAndNumber = "密码要求有字母和数字"
    case missingUppercase = "密码至少要有一个大写字母"
}

class ValidationUtil {
    
    // 验证中国手机号
    static func isValidPhoneNumber(_ phoneNumber: String) -> Bool {
        let phoneRegex = "^1[3-9]\\d{9}$"  // 中国手机号正则表达式
        let phoneTest = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phoneTest.evaluate(with: phoneNumber)
    }
    
    // 验证邮箱格式
    static func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"  // 邮箱正则表达式
        let emailTest = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailTest.evaluate(with: email)
    }
    
    // 验证密码
    static func validatePassword(_ password: String) -> Result<Bool, PasswordValidationError> {
        // 密码至少6位
        guard password.count >= 6 else {
            return .failure(.tooShort)
        }
        
        // 必须包含至少一个字母和一个数字
        let letterAndNumberRegex = ".*[a-zA-Z].*[0-9].*|.*[0-9].*[a-zA-Z].*"  // 包含字母和数字
        let letterAndNumberTest = NSPredicate(format: "SELF MATCHES %@", letterAndNumberRegex)
        guard letterAndNumberTest.evaluate(with: password) else {
            return .failure(.missingLetterAndNumber)
        }
        
        // 至少包含一个大写字母
        let uppercaseRegex = ".*[A-Z].*"  // 包含大写字母
        let uppercaseTest = NSPredicate(format: "SELF MATCHES %@", uppercaseRegex)
        guard uppercaseTest.evaluate(with: password) else {
            return .failure(.missingUppercase)
        }
        
        // 密码符合所有规则
        return .success(true)
    }
}
