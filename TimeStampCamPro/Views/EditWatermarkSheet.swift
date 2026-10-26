import SwiftUI

/// Màn hình chỉnh sửa nhanh thời gian, ngày tháng, thứ, tổ vận hành / kíp và logo
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
                Section(header: Text("Thời gian & Ngày tháng trên ảnh")) {
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
                            TextField("21:55", text: $store.timeText)
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
                            store.timeText = "21:55"
                            store.dateText = "26/10/2026"
                            store.weekdayText = "Thứ Hai"
                        } label: {
                            Label("Mẫu 21:55 (26/10)", systemImage: "sparkles")
                                .font(.subheadline.weight(.medium))
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 2)
                }

                // MỤC 2: NỘI DUNG TỔ VẬN HÀNH / KÍP TRỰC / GHI CHÚ
                Section(
                    header: Text("Nội dung khung mờ (Tổ / Kíp / Công việc)"),
                    footer: Text("Chạm vào các mẫu bên dưới để đổi nhanh giữa Kíp A, Kíp B, Kíp C, Kíp D hoặc tự gõ nội dung bất kỳ.")
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dòng ghi chú chính:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Ví dụ: Tổ Vận hành - Kíp A X.CT1", text: $store.noteLine1)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dòng ghi chú phụ (bỏ trống nếu chỉ cần 1 dòng như ảnh mẫu):")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Ví dụ: Khu vực Lò cao số 1 / Bàn giao ca", text: $store.noteLine2)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Chọn nhanh Kíp
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(store.quickNotes, id: \.self) { item in
                                Button {
                                    store.noteLine1 = item
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
                        TextField("Thêm mẫu ghi chú mới vào danh sách...", text: $newQuickNote)
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

                // MỤC 3: ĐỊA ĐIỂM & TỌA ĐỘ GPS
                Section(header: Text("Định vị GPS & Hướng la bàn")) {
                    Toggle("Hiển thị thêm dòng Vị trí GPS trong khung mờ", isOn: $store.showLocationLine)

                    if store.showLocationLine {
                        TextField("Địa chỉ hoặc tọa độ GPS", text: $store.locationText)
                        Button {
                            locationService.requestCurrentLocation { resolved in
                                store.locationText = resolved
                            }
                        } label: {
                            HStack {
                                Image(systemName: "location.circle.fill")
                                Text(locationService.isFetching ? "Đang lấy vị trí GPS..." : "Cập nhật vị trí hiện tại tự động")
                            }
                        }
                    }

                    Toggle("Hiện thanh xanh dương nhạt (D →) bên dưới", isOn: $store.showDirectionBanner)
                    if store.showDirectionBanner {
                        HStack {
                            Text("Ký hiệu hướng trên thanh xanh")
                            Spacer()
                            Picker("", selection: $store.directionBannerCode) {
                                ForEach(["D", "B", "N", "T", "ĐB", "ĐN", "TB", "TN"], id: \.self) { code in
                                    Text("\(code) →").tag(code)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        Toggle("Ghép luôn thanh xanh (D →) vào file ảnh xuất ra", isOn: $store.includeBottomBannerInExport)
                    }
                }

                // MỤC 4: LOGO & MÀU SẮC
                Section(header: Text("Logo & Kiểu dáng bản mẫu")) {
                    Picker("Kiểu Logo phía trên giờ", selection: $store.logoStyle) {
                        ForEach(LogoStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }

                    if store.logoStyle == .customText {
                        TextField("Dòng chữ lớn (VD: HOA PHAT)", text: $store.customLogoTitle)
                        TextField("Dòng chữ nhỏ (VD: GANG THÉP)", text: $store.customLogoSubtitle)
                    } else if store.logoStyle == .customImage {
                        Button {
                            showLogoImagePicker = true
                        } label: {
                            Label("Chọn ảnh Logo PNG từ Thư viện", systemImage: "photo.badge.plus")
                        }
                    }

                    Picker("Màu vạch dọc ngăn cách", selection: $store.barColor) {
                        ForEach(AccentBarColorOption.allCases) { colorOpt in
                            Text(colorOpt.rawValue).tag(colorOpt)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Kích thước chữ Watermark")
                            Spacer()
                            Text("\(Int(store.watermarkScale * 100))%")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $store.watermarkScale, in: 0.80...1.25, step: 0.05)
                    }
                }
            }
            .navigationTitle("Tùy chỉnh đóng dấu")
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
