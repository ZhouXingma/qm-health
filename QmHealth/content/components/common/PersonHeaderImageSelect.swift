//
//  HeaderImageSelect.swift
//  QmHealth
//
//  Created by 周荥马 on 2025/10/1.
//

import SwiftUI
import PhotosUI

struct HeaderImageSelect: View {
    // 头像id
    @Binding var headerImgId: String?
    // 上传进度（nil=无进度，0~1=上传中）
    @Binding var uploadProgress: Double?
    // 回调：把裁剪后的图片 Data 交给外部处理上传
    let saveOrUpdateHeader: (Data?) -> Void
    // 头像信息
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    // 裁剪编辑器状态
    @State private var editingImage: UIImage?
    @State private var showCropEditor = false


    var body: some View {
        GeometryReader { geometry in
            let width = geometry.frame(in: .local).width
            let height = geometry.frame(in: .local).height
            ZStack(alignment: .center) {
                // 首先放置一个白色圆形作为背景
                Circle()
                    .fill(Color("background").opacity(0.6))
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
                .frame(width: width, height: height, alignment: .center)
                .foregroundColor(Color.theme(.chart1))
                .clipShape(Circle())
                // 上传进度蒙层 + 圆形进度条
                if let progress = uploadProgress {
                    uploadOverlay(width: width, height: height, progress: progress)
                }
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Circle()
                        .fill(Color.theme(.primary))
                        .frame(width: width/2, height: height/2)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1)
                }
                .offset(x: width/3, y: height/3)
                .disabled(uploadProgress != nil)
            }.onAppear {
                loadHeadImage()
            }.onChange(of: headerImgId) { oldValue, newValue in
                loadHeadImage()
            }.onChange(of: selectedItem) { oldItem, newItem in
                Task {
                    guard let data = try? await newItem?.loadTransferable(type: Data.self),
                          let rawImage = UIImage(data: data) else { return }
                    // 修正方向后再交给裁剪器，避免方向错误的图片显示旋转
                    let normalized = rawImage.fixedOrientation()
                    await MainActor.run {
                        editingImage = normalized
                        showCropEditor = true
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCropEditor) {
            if let image = editingImage {
                ImageCropEditor(
                    image: image,
                    onComplete: { croppedImage in
                        let data = croppedImage.jpegData(compressionQuality: 0.9)
                        editingImage = nil
                        showCropEditor = false
                        if let data {
                            selectedImageData = data
                            saveOrUpdateHeader(data)
                        }
                    },
                    onCancel: {
                        editingImage = nil
                        showCropEditor = false
                    }
                )
            }
        }
    }

    // MARK: - 上传进度覆盖层
    private func uploadOverlay(width: CGFloat, height: CGFloat, progress: Double) -> some View {
        let size = min(width, height)
        let clamped = max(0, min(progress, 1))
        let percentText = "\(Int(clamped * 100))%"
        return ZStack {
            Circle()
                .fill(Color.black.opacity(0.4))
                .frame(width: width, height: height)
            Circle()
                .stroke(Color.white.opacity(0.25), lineWidth: 3)
                .frame(width: size * 0.78, height: size * 0.78)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: size * 0.78, height: size * 0.78)
                .animation(.easeInOut(duration: 0.2), value: clamped)
            Text(percentText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
        }
        .allowsHitTesting(true)
        .transition(.opacity)
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
