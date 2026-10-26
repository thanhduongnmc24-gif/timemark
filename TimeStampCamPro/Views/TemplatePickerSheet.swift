import SwiftUI

/// Màn hình quản lý "Bản mẫu" (Presets) khi bấm nút "Bản mẫu" ở góc dưới bên phải
struct TemplatePickerSheet: View {
    @EnvironmentObject var store: WatermarkStore
    @Environment(\.presentationMode) private var presentationMode
    @State private var newPresetName: String = ""

    var body: some View {
        NavigationView {
            List {
                Section(
                    header: Text("Chọn bản mẫu có sẵn"),
                    footer: Text("Chạm vào một bản mẫu để áp dụng ngay bố cục logo, màu vạch ngăn cách và nội dung ghi chú.")
                ) {
                    ForEach(store.presets) { preset in
                        Button {
                            store.applyPreset(preset)
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(preset.barColor.swiftUIColor)
                                    .frame(width: 5, height: 42)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(preset.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(preset.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer()

                                if store.noteLine1 == preset.noteLine1 && store.logoStyle == preset.logoStyle {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.title3)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete { offsets in
                        store.presets.remove(atOffsets: offsets)
                    }
                }

                Section(header: Text("Lưu thiết lập hiện tại thành Bản mẫu mới")) {
                    HStack {
                        TextField("Tên bản mẫu (VD: Kíp B - Lò cao 2)", text: $newPresetName)
                        Button("Lưu mẫu") {
                            store.saveCurrentAsPreset(name: newPresetName)
                            newPresetName = ""
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newPresetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Bản mẫu đóng dấu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đóng") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
