import SwiftUI

enum TemplateDetailField: Identifiable {
    case logo
    case timeAndDate
    case mainNote
    case customText(UUID)
    case addCustomText
    case avatarBadge
    case miniMap
    case coordinates
    case altitude
    case compass
    case tagRow

    var id: String {
        switch self {
        case .logo: return "logo"
        case .timeAndDate: return "timeAndDate"
        case .mainNote: return "mainNote"
        case .customText(let uuid): return "customText_\(uuid.uuidString)"
        case .addCustomText: return "addCustomText"
        case .avatarBadge: return "avatarBadge"
        case .miniMap: return "miniMap"
        case .coordinates: return "coordinates"
        case .altitude: return "altitude"
        case .compass: return "compass"
        case .tagRow: return "tagRow"
        }
    }
}

/// Giao diện bảng trượt "Chỉnh sửa mẫu" giống hệt ảnh chụp màn hình `image_79402a.png`
/// Hiện ở nửa dưới màn hình để người dùng vừa bật/tắt Logo, Text, Giờ, Tọa độ... vừa nhìn thấy biểu mẫu phía trên thay đổi trực tiếp
struct TemplatePickerSheet: View {
    @EnvironmentObject var store: WatermarkStore
    @ObservedObject var locationService: LocationService
    let onClose: () -> Void

    @State private var activeDetail: TemplateDetailField? = nil
    @State private var showColorPopover: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // 1. THANH TIÊU ĐỀ: "Chỉnh sửa mẫu" | Nút "Chia sẻ" | Nút "X"
            HStack(spacing: 12) {
                Text("Chỉnh sửa mẫu")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.black.opacity(0.88))

                Spacer()

                Button {
                    store.resetPositionAndScale()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrowshape.turn.up.right.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Chia sẻ")
                            .font(.system(size: 13.5, weight: .medium))
                    }
                    .foregroundColor(.black.opacity(0.75))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black.opacity(0.75))
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // 2. DANH SÁCH CÁC MỤC TRONG BẢN MẪU (Cuộn mượt, có công tắc bật/tắt + mũi tên ">" để sửa nội dung)
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    // Mục 1: Ảnh thẻ
                    templateRow(
                        isOn: $store.showAvatarBadge,
                        title: "Ảnh thẻ",
                        hasChevron: true
                    ) {
                        activeDetail = .avatarBadge
                    }

                    // Mục 2: Mã ảnh: xác minh tính xác thực
                    templateRow(
                        isOn: $store.showPhotoVerifyCode,
                        title: "Mã ảnh: xác minh tính xác thực",
                        hasChevron: false,
                        onTapRow: nil
                    )

                    // Mục 3: Bản đồ
                    templateRow(
                        isOn: $store.showMiniMap,
                        title: "Bản đồ",
                        hasChevron: true
                    ) {
                        activeDetail = .miniMap
                    }

                    // Mục 4: Tọa độ
                    templateRow(
                        isOn: $store.showCoordinates,
                        title: "Tọa độ",
                        hasChevron: true
                    ) {
                        activeDetail = .coordinates
                    }

                    // Mục 5: Độ cao
                    templateRow(
                        isOn: $store.showAltitude,
                        title: "Độ cao",
                        hasChevron: true
                    ) {
                        activeDetail = .altitude
                    }

                    // Mục 6: Phương hướng
                    templateRow(
                        isOn: $store.showCompassDirection,
                        title: "Phương hướng",
                        hasChevron: false,
                        onTapRow: nil
                    )

                    // Mục 7: Thẻ
                    templateRow(
                        isOn: $store.showTagRow,
                        title: "Thẻ",
                        hasChevron: true
                    ) {
                        activeDetail = .tagRow
                    }

                    // Mục 8 (Đang bật xanh như ảnh mẫu): Tổ Vận hành - Kíp A X.CT1
                    templateRow(
                        isOn: $store.showMainNote,
                        title: store.noteLine1.isEmpty ? "Tổ Vận hành – Kíp A X.CT1" : store.noteLine1,
                        hasChevron: true
                    ) {
                        activeDetail = .mainNote
                    }

                    // Mục 9: Logo thương hiệu (Hòa Phát Gang Thép / Logo tùy chỉnh / Ảnh từ máy)
                    templateRow(
                        isOn: $store.showLogo,
                        title: "Logo: \(store.logoStyle.rawValue)",
                        hasChevron: true
                    ) {
                        activeDetail = .logo
                    }

                    // Mục 10: Thời gian & Ngày tháng (22:26 | 26/10/2026 Thứ Hai)
                    templateRow(
                        isOn: $store.showTimeBlock,
                        title: "Thời gian: \(store.timeText) – \(store.dateText) (\(store.weekdayText))",
                        hasChevron: true
                    ) {
                        activeDetail = .timeAndDate
                    }

                    // Các mục Văn bản (Text) người dùng tự thiết kế thêm
                    ForEach($store.customTextItems) { $item in
                        templateRow(
                            isOn: $item.isEnabled,
                            title: item.title.isEmpty ? "Văn bản tùy chỉnh" : item.title,
                            hasChevron: true
                        ) {
                            activeDetail = .customText(item.id)
                        }
                    }

                    // Nút "+ Thêm mục văn bản (Text) mới vào bản mẫu"
                    Button {
                        activeDetail = .addCustomText
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                            Text("Thêm mục Văn bản (Text) mới...")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.blue)
                            Spacer()
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                    }

                    // Nút đặt lại vị trí & kích thước biểu mẫu nếu đã kéo/phóng to
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            store.resetPositionAndScale()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.uturn.backward.circle")
                                .font(.system(size: 15))
                            Text("Đặt lại vị trí & kích thước mặc định (Tỉ lệ: \(Int(store.watermarkScale * 100))%)")
                                .font(.system(size: 13.5, weight: .medium))
                            Spacer()
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                    }
                }
            }
            .frame(maxHeight: 330)

            // Hộp chọn màu nhanh khi bấm nút "Màu"
            if showColorPopover {
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(AccentBarColorOption.allCases) { opt in
                            Button {
                                store.barColor = opt
                            } label: {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(opt.swiftUIColor)
                                        .frame(width: 16, height: 16)
                                        .overlay(Circle().stroke(Color.black.opacity(0.2), lineWidth: 1))
                                    Text(opt.rawValue)
                                        .font(.system(size: 12.5, weight: store.barColor == opt ? .bold : .regular))
                                        .foregroundColor(.black.opacity(0.85))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    store.barColor == opt
                                        ? Color.blue.opacity(0.15)
                                        : Color(.systemGray6)
                                )
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }

            Divider()

            // 3. THANH NÚT DƯỚI CÙNG: Nút "Màu" (viền trắng) & Nút "Xong" (nền xanh dương lớn) giống hệt ảnh mẫu
            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showColorPopover.toggle()
                    }
                } label: {
                    Text("Màu")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black.opacity(0.85))
                        .frame(width: 105, height: 46)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color(.systemGray4), lineWidth: 1.2)
                        )
                }

                Button(action: onClose) {
                    Text("Xong")
                        .font(.system(size: 16.5, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color(red: 0.05, green: 0.58, blue: 0.98))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: -3)
        .sheet(item: $activeDetail) { detail in
            TemplateFieldEditorModal(field: detail, locationService: locationService)
                .environmentObject(store)
        }
    }

    @ViewBuilder
    private func templateRow(
        isOn: Binding<Bool>,
        title: String,
        hasChevron: Bool,
        onTapRow: (() -> Void)?
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(Color(red: 0.20, green: 0.78, blue: 0.35))

                Button {
                    if let action = onTapRow {
                        action()
                    } else {
                        isOn.wrappedValue.toggle()
                    }
                } label: {
                    HStack {
                        Text(title)
                            .font(.system(size: 15.5, weight: .regular))
                            .foregroundColor(isOn.wrappedValue ? .black.opacity(0.88) : .gray)
                            .lineLimit(1)
                        Spacer()
                        if hasChevron {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(.systemGray3))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)

            Divider()
                .padding(.leading, 82)
        }
    }
}

/// Cửa sổ chỉnh sửa chi tiết khi người dùng bấm vào từng dòng trong bảng "Chỉnh sửa mẫu"
struct TemplateFieldEditorModal: View {
    @EnvironmentObject var store: WatermarkStore
    let field: TemplateDetailField
    @ObservedObject var locationService: LocationService
    @Environment(\.presentationMode) private var presentationMode

    @State private var newTextValue: String = ""
    @State private var showLogoImagePicker: Bool = false
    @State private var pickedLogoImage: UIImage? = nil

    private let weekdays = [
        "Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy", "Chủ Nhật"
    ]

    var body: some View {
        NavigationView {
            Form {
                switch field {
                case .mainNote:
                    Section(header: Text("Nội dung Tổ vận hành / Kíp trực")) {
                        TextField("Nhập nội dung (VD: Tổ Vận hành - Kíp A X.CT1)", text: $store.noteLine1)
                        Toggle("Hiển thị trên biểu mẫu", isOn: $store.showMainNote)
                    }
                    Section(header: Text("Chọn nhanh Kíp trực có sẵn")) {
                        ForEach(store.quickNotes, id: \.self) { note in
                            Button {
                                store.noteLine1 = note
                                store.showMainNote = true
                                presentationMode.wrappedValue.dismiss()
                            } label: {
                                HStack {
                                    Text(note)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if store.noteLine1 == note {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }

                case .logo:
                    Section(header: Text("Thiết lập Logo thương hiệu")) {
                        Toggle("Hiển thị Logo trên biểu mẫu", isOn: $store.showLogo)
                        Picker("Loại Logo", selection: $store.logoStyle) {
                            ForEach(LogoStyle.allCases) { style in
                                Text(style.rawValue).tag(style)
                            }
                        }
                        if store.logoStyle == .customText {
                            TextField("Dòng chính (VD: HÒA PHÁT)", text: $store.customLogoTitle)
                            TextField("Dòng phụ (VD: GANG THÉP)", text: $store.customLogoSubtitle)
                        } else if store.logoStyle == .customImage {
                            Toggle("Tự động xóa nền trắng của ảnh Logo", isOn: $store.removeWhiteBgForCustomLogo)
                            Button {
                                showLogoImagePicker = true
                            } label: {
                                Label("Chọn ảnh Logo từ Thư viện", systemImage: "photo.badge.plus")
                            }
                        }
                    }

                case .timeAndDate:
                    Section(header: Text("Thiết lập Giờ & Ngày tháng")) {
                        Toggle("Hiển thị khối Giờ & Ngày tháng", isOn: $store.showTimeBlock)
                        Toggle("Tự động chạy theo giờ thực tế", isOn: $store.useRealTime)

                        if !store.useRealTime {
                            DatePicker(
                                "Chọn trên lịch",
                                selection: $store.selectedDate,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .environment(\.locale, Locale(identifier: "vi_VN"))

                            HStack {
                                Text("Giờ (HH:mm)")
                                Spacer()
                                TextField("22:26", text: $store.timeText)
                                    .multilineTextAlignment(.trailing)
                            }
                            HStack {
                                Text("Ngày (dd/MM/yyyy)")
                                Spacer()
                                TextField("26/10/2026", text: $store.dateText)
                                    .multilineTextAlignment(.trailing)
                            }
                            Picker("Thứ trong tuần", selection: $store.weekdayText) {
                                ForEach(weekdays, id: \.self) { d in
                                    Text(d).tag(d)
                                }
                            }
                        }
                    }

                case .customText(let id):
                    if let idx = store.customTextItems.firstIndex(where: { $0.id == id }) {
                        Section(header: Text("Chỉnh sửa mục Văn bản (Text)")) {
                            TextField("Nhập nội dung văn bản...", text: $store.customTextItems[idx].title)
                            Toggle("Hiển thị dòng này", isOn: $store.customTextItems[idx].isEnabled)
                            Button(role: .destructive) {
                                store.customTextItems.remove(at: idx)
                                presentationMode.wrappedValue.dismiss()
                            } label: {
                                Label("Xóa mục văn bản này", systemImage: "trash")
                            }
                        }
                    }

                case .addCustomText:
                    Section(header: Text("Thêm mục Văn bản (Text) mới vào bản mẫu")) {
                        TextField("Nhập nội dung (VD: Khu vực Lò cao 1 / Người chụp...)", text: $newTextValue)
                        Button("Thêm vào bản mẫu") {
                            let trimmed = newTextValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                store.customTextItems.append(CustomTextItem(title: trimmed, isEnabled: true))
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                        .disabled(newTextValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                case .avatarBadge:
                    Section(header: Text("Ảnh thẻ / Thông tin nhân sự")) {
                        Toggle("Bật mục Ảnh thẻ", isOn: $store.showAvatarBadge)
                        TextField("Họ tên / Mã nhân viên", text: $store.avatarBadgeTitle)
                    }

                case .miniMap:
                    Section(header: Text("Địa điểm / Bản đồ")) {
                        Toggle("Bật địa điểm", isOn: $store.showMiniMap)
                        TextField("Nhập địa chỉ công trường / nhà máy", text: $store.miniMapLocationText)
                        Button("Lấy địa chỉ GPS hiện tại") {
                            locationService.requestCurrentLocation { addr in
                                store.miniMapLocationText = addr
                                store.showMiniMap = true
                            }
                        }
                    }

                case .coordinates:
                    Section(header: Text("Tọa độ GPS")) {
                        Toggle("Bật tọa độ", isOn: $store.showCoordinates)
                        TextField("Nhập tọa độ", text: $store.coordinatesText)
                        Button("Cập nhật tọa độ thực tế") {
                            locationService.requestCurrentLocation { _ in
                                if !locationService.currentCoordinates.isEmpty {
                                    store.coordinatesText = locationService.currentCoordinates
                                }
                                store.showCoordinates = true
                            }
                        }
                    }

                case .altitude:
                    Section(header: Text("Độ cao")) {
                        Toggle("Bật độ cao", isOn: $store.showAltitude)
                        TextField("Nhập độ cao (VD: Độ cao: 18.5 m)", text: $store.altitudeText)
                    }

                case .compass:
                    Section(header: Text("Phương hướng")) {
                        Toggle("Bật phương hướng", isOn: $store.showCompassDirection)
                        TextField("Nhập phương hướng", text: $store.compassDirectionText)
                    }

                case .tagRow:
                    Section(header: Text("Thẻ (Tags)")) {
                        Toggle("Bật dòng thẻ", isOn: $store.showTagRow)
                        TextField("Nhập thẻ (VD: #CaTrực #KípA)", text: $store.tagRowText)
                    }
                }
            }
            .navigationTitle("Thiết kế mục bản mẫu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        presentationMode.wrappedValue.dismiss()
                    }
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
