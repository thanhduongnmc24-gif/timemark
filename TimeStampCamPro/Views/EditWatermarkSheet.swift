import SwiftUI

/// Màn hình chỉnh sửa nhanh khi người dùng chạm vào nút cây bút (square.and.pencil)
struct EditWatermarkSheet: View {
    @EnvironmentObject var store: WatermarkStore
    @ObservedObject var locationService: LocationService
    @Environment(\.presentationMode) private var presentationMode

    @State private var showLogoImagePicker = false
    @State private var pickedLogoImage: UIImage? = nil
    @State private var newQuickNote: String = ""

    private let weekdays = [
        "Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy", "Chủ Nhật"
    ]

    var body: some View {
        NavigationView {
            Form {
                // MỤC 1: CHỈNH THỜI GIAN & NGÀY THÁNG
                Section(header: Text("Thời gian & Ngày tháng")) {
                    Toggle("Tự động chạy theo giờ thực tế", isOn: $store.useRealTime)

                    if !store.useRealTime {
                        DatePicker(
                            "Chọn nhanh bằng lịch",
                            selection: $store.selectedDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .environment(\.locale, Locale(identifier: "vi_VN"))

                        HStack {
                            Text("Giờ hiển thị (HH:mm)")
                                .foregroundColor(.secondary)
                            Spacer()
                            TextField("22:26", text: $store.timeText)
                                .multilineTextAlignment(.trailing)
                                .font(.system(.body, design: .monospaced))
                        }

                        HStack {
                            Text("Ngày hiển thị")
                                .foregroundColor(.secondary)
                            Spacer()
                            TextField("26/10/2026", text: $store.dateText)
                                .multilineTextAlignment(.trailing)
                                .font(.system(.body, design: .monospaced))
                        }

                        Picker("Thứ trong tuần", selection: $store.weekdayText) {
                            ForEach(weekdays, id: \.self) { day in
                                Text(day).tag(day)
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            store.useRealTime = false
                            store.setNow()
                        } label: {
                            Label("Lấy giờ hiện tại", systemImage: "clock.arrow.circlepath")
                                .font(.subheadline.weight(.medium))
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button {
                            store.useRealTime = false
                            store.timeText = "22:26"
                            store.dateText = "26/10/2026"
                            store.weekdayText = "Thứ Hai"
                        } label: {
                            Label("Mẫu 22:26 (26/10)", systemImage: "sparkles")
                                .font(.subheadline.weight(.medium))
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 2)
                }

                // MỤC 2: NỘI DUNG TỔ VẬN HÀNH / KÍP TRỰC
                Section(
                    header: Text("Nội dung Tổ / Kíp / Ghi chú"),
                    footer: Text("Bạn cũng có thể chụm 2 ngón tay trực tiếp vào biểu mẫu trên màn hình Camera để phóng to/thu nhỏ hoặc kéo di chuyển sang vị trí bất kỳ.")
                ) {
                    TextField("Ví dụ: Tổ Vận hành - Kíp A X.CT1", text: $store.noteLine1)
                        .textFieldStyle(.roundedBorder)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(store.quickNotes, id: \.self) { item in
                                Button {
                                    store.noteLine1 = item
                                    store.showMainNote = true
                                } label: {
                                    Text(item)
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            store.noteLine1 == item
                                                ? Color.blue
                                                : Color(.systemGray5)
                                        )
                                        .foregroundColor(store.noteLine1 == item ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    HStack {
                        TextField("Thêm mẫu ghi chú mới...", text: $newQuickNote)
                            .font(.subheadline)
                        Button("Thêm") {
                            let trimmed = newQuickNote.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty && !store.quickNotes.contains(trimmed) {
                                store.quickNotes.insert(trimmed, at: 0)
                                store.noteLine1 = trimmed
                                newQuickNote = ""
                            }
                        }
                        .disabled(newQuickNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                // MỤC 3: LOGO & TỈ LỆ BIỂU MẪU
                Section(header: Text("Logo & Vị trí biểu mẫu")) {
                    Toggle("Hiển thị Logo", isOn: $store.showLogo)
                    Picker("Kiểu Logo", selection: $store.logoStyle) {
                        ForEach(LogoStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }

                    if store.logoStyle == .customText {
                        TextField("Dòng chữ lớn (VD: HÒA PHÁT)", text: $store.customLogoTitle)
                        TextField("Dòng chữ nhỏ (VD: GANG THÉP)", text: $store.customLogoSubtitle)
                    } else if store.logoStyle == .customImage {
                        Toggle("Tự động xóa nền trắng của ảnh Logo", isOn: $store.removeWhiteBgForCustomLogo)
                        Button {
                            showLogoImagePicker = true
                        } label: {
                            Label("Chọn ảnh Logo từ Thư viện", systemImage: "photo.badge.plus")
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Độ phóng đại biểu mẫu")
                            Spacer()
                            Text("\(Int(store.watermarkScale * 100))%")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $store.watermarkScale, in: 0.50...2.00, step: 0.05)
                    }

                    Button("Đặt lại vị trí & kích thước mặc định") {
                        store.resetPositionAndScale()
                    }
                }
            }
            .navigationTitle("Chỉnh sửa nhanh")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xong") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.headline)
                }
            }
            .sheet(isPresented: $showLogoImagePicker) {
                PhotoLibraryPicker(selectedImage: $pickedLogoImage)
            }
            .onChange(of: pickedLogoImage) { newImg in
                if let img = newImg, let data = img.pngData() {
                    store.customLogoImageData = data
                }
            }
        }
    }
}
