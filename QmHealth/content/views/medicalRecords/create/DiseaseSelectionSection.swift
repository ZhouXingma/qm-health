import SwiftUI

// MARK: - 疾病选择部分
struct DiseaseSelectionSection: View {
    @Binding var selectedDiseases: [SelectedDisease]
    @State private var showDiseaseSelection = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.theme(.primary))

                Text("关联疾病")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color("text_primary"))

                Spacer()

                // 计数
                if !selectedDiseases.isEmpty {
                    Text("\(selectedDiseases.count) 项")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.theme(.primary))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                }
            }

            if selectedDiseases.isEmpty {
                // 空状态
                Button(action: { showDiseaseSelection = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("添加关联疾病")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Color.theme(.primary))
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(SecondaryActionButtonStyle())
            } else {
                // 已选择的疾病列表
                VStack(spacing: 8) {
                    ForEach(selectedDiseases, id: \.id) { disease in
                        DiseaseSelectionTag(
                            disease: disease,
                            onRemove: {
                                selectedDiseases.removeAll { $0.id == disease.id }
                            }
                        )
                    }

                    // 添加更多按钮
                    Button(action: { showDiseaseSelection = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .semibold))
                            Text("添加更多")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(Color.theme(.primary))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
        }
        .cardStyle()
        .sheet(isPresented: $showDiseaseSelection) {
            DiseaseSelectionView(
                onConfirm: { diseases in
                    selectedDiseases = diseases
                },
                initialSelectedDiseases: selectedDiseases
            )
        }
    }
}

// MARK: - 疾病选择标签
struct DiseaseSelectionTag: View {
    let disease: SelectedDisease
    let onRemove: () -> Void

    var diseaseSeverity: DiseaseSeverity {
        if let severity = disease.severity {
            return DiseaseSeverity.getByCode(code: severity) ?? DiseaseSeverity.mild
        }
        return DiseaseSeverity.mild
    }

    var diseaseStatus: DiseaseStatus {
        if let status = disease.status {
            return DiseaseStatus.getByCode(code: status) ?? DiseaseStatus.stable
        }
        return DiseaseStatus.stable
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(disease.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color("text_primary"))

                    // 严重程度标签 - 玻璃药丸
                    HStack(spacing: 2) {
                        Image(systemName: diseaseSeverity.icon)
                            .font(.system(size: 9))
                        Text(diseaseSeverity.displayName)
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .glassPillColor(.regular.interactive(), Color(diseaseSeverity.color).opacity(0.7))
                }

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(diseaseStatus.color))
                        .frame(width: 5, height: 5)

                    Text(diseaseStatus.displayName)
                        .font(.system(size: 10))
                        .foregroundStyle(Color("text_secondary"))
                }
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color("text_secondary").opacity(0.5))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .glassCardStyle()
    }
}

#Preview {
    @Previewable @State var diseases: [SelectedDisease] = []
    return DiseaseSelectionSection(selectedDiseases: $diseases)
}
