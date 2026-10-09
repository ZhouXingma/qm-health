//
//  CommFunctions.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/6/22.
//
import SwiftUI

// 检查登录情况
func checkLogin(_ globalModel:GlobalModel) {
    let token = TokenUtils.getToken()
    if token != "" {
        globalModel.isLogin = true
    } else {
        globalModel.isLogin = false
    }
}
// 检查用户是否已设置基本信息
func checkUserSetup(_  globalModel:GlobalModel) {
    if !globalModel.isLogin {
        return
    }
    BgResultNetWork<Empty?, UserDTO>.post(apiUrl(USER_GET)).complicationHand { (userDtoOpt:UserDTO?) in
        guard let userDto = userDtoOpt else {
            PopManager.shared.showSimplePop(title: "提示", description: "登录已过期,请重新登录操作")
            globalModel.reset()
            TokenUtils.deleteToken()
            return;
        }
        if nil == userDto.id {
            PopManager.shared.showSimplePop(title: "提示", description: "登录已过期,请重新登录操作")
            globalModel.reset()
            TokenUtils.deleteToken()
            return;
        }
        if nil == userDto.name || nil == userDto.gender || nil == userDto.birthday || nil == userDto.headerImg {
            globalModel.hasCompletedInitialSetup = false;
            return
        }
        DispatchQueue.main.async {
            globalModel.hasCompletedInitialSetup = true;
            globalModel.currentUser = userDto
        }
    }.responseDecodable()
    
    //let userDtoOpt:UserDTO? = BgResultNetWorkUtils.post(apiUrl(USER_GET), "");
    
}
// 隐藏键盘
func hideKeyboard() {
    KeyBoardUtils.toHideKeyboard()
}
// 隐藏底部弹窗
func hideSubPop() {
    SubPopManager.shared.closeSubPop()
}
// 隐藏所有
func hideAll() {
    hideKeyboard()
    hideSubPop()
}
