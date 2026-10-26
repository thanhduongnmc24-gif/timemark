import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: WatermarkStore
    @StateObject private var cameraService = CameraService()
    @StateObject private var locationService = LocationService()

    // Ảnh người dùng chọn từ Thư viện ("Có sẵn") hoặc ứng dụng Tệp ("Tệp")
    // Khi nil -> Hiển thị Camera trực tiếp
    @State private var selectedSourceImage: UIImage? = nil
    @State private var lastExportedImage: UIImage? = nil

    // Các sheet chức năng
    @State private var showPhotoLibraryPicker = false
    @State private var showDocumentFilePicker = false
    @State private var showEditWatermarkSheet = false
    @State private var showTemplatePickerSheet = false
    @State private var showShareSheet = false
    @State private var showPreviewExportSheet = false

    // Phóng to / thu nhỏ và kéo ảnh khi đang ở chế độ chọn ảnh có sẵn
    @State private var imageScale: CGFloat = 1.0
    @State private var lastImageScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero
    @State private var lastImageOffset: CGSize = .zero

    // Thông báo trạng thái nhanh (Toast)
    @State private var toastMessage: String? = nil
    @State private var isProcessingCapture: Bool = false

    private let zoomLevels: [(label: String, factor: CGFloat)] = [
        ("10", 10.0),
        ("2", 2.0),
        ("1x", 1.0),
        ("0.5", 0.5)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 1. THANH ĐIỀU KHIỂN TRÊN CÙNG (TOP BAR TRẮNG GIỐNG HỆT ẢNH MẪU)
            topHeaderBar

            // 2. KHUNG CAMERA TRỰC TIẾP HOẶC ẢNH ĐÃ CHỌN + LỚP PHỦ WATERMARK
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    Color.black

                    // Nền Camera hoặc Ảnh đã chọn
                    if let chosenImage = selectedSourceImage {
                        Image(uiImage: chosenImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .scaleEffect(imageScale)
                            .offset(imageOffset)
                            .clipped()
                            .gesture(
                                SimultaneousGesture(
                                    MagnificationGesture()
                                        .onChanged { val in
                                            imageScale = max(1.0, min(lastImageScale * val, 5.0))
                                        }
                                        .onEnded { _ in
                                            lastImageScale = imageScale
                                        },
                                    DragGesture()
                                        .onChanged { val in
                                            imageOffset = CGSize(
                                                width: lastImageOffset.width + val.translation.width,
                                                height: lastImageOffset.height + val.translation.height
                                            )
                                        }
                                        .onEnded { _ in
                                            lastImageOffset = imageOffset
                                        }
                                )
                            )
                    } else if cameraService.isAuthorized {
                        CameraPreviewView(session: cameraService.session)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    } else {
                        // Khung chờ khi chưa cấp quyền camera hoặc chạy trên máy ảo
                        placeholderCanvas(size: geo.size)
                    }

                    // Lớp phủ bóng tối nhẹ dưới đáy để nổi bật chữ trắng
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.0),
                            Color.black.opacity(0.42)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geo.size.height * 0.36)
                    .allowsHitTesting(false)

                    // Thanh trượt nút chọn mức Zoom dọc bên phải (10, 2, 1x, 0.5)
                    HStack {
                        Spacer()
                        zoomSelectorColumn
                            .padding(.trailing, 12)
                            .padding(.bottom, 155)
                    }

                    // Nút chuyển nhanh về Camera trực tiếp nếu đang mở ảnh từ Thư viện/Tệp
                    if selectedSourceImage != nil {
                        VStack {
                            HStack {
                                Button {
                                    withAnimation {
                                        selectedSourceImage = nil
                                        resetImageTransform()
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "camera.fill")
                                        Text("Quay lại chụp trực tiếp")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Color.black.opacity(0.65))
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                                }
                                Spacer()

                                Button {
                                    resetImageTransform()
                                } label: {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.caption.weight(.bold))
                                        .padding(8)
                                        .background(Color.black.opacity(0.65))
                                        .foregroundColor(.white)
                                        .clipShape(Circle())
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.top, 12)
                            Spacer()
                        }
                    }

                    // Khung Watermark (Logo Hòa Phát + 21:55 + 26/10/2026 + Thứ Hai + Tổ Vận hành - Kíp A X.CT1)
                    WatermarkOverlayView(
                        onTapEdit: {
                            showEditWatermarkSheet = true
                        },
                        onTapLocation: {
                            triggerLocationRefresh()
                        }
                    )
                }
            }

            // 3. THANH XANH DƯƠNG NHẠT "D ->" BÊN DƯỚI KHUNG ẢNH
            if store.showDirectionBanner {
                directionBannerBar
            }

            // 4. THANH CÔNG CỤ DƯỚI CÙNG (CÓ SẴN | TỆP | NÚT CHỤP LỚN | BẢN MẪU)
            bottomControlBar
        }
        .overlay(alignment: .top) {
            if let msg = toastMessage {
                Text(msg)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.82))
                    .clipShape(Capsule())
                    .shadow(radius: 4)
                    .padding(.top, 64)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showPhotoLibraryPicker) {
            PhotoLibraryPicker(selectedImage: $selectedSourceImage)
        }
        .sheet(isPresented: $showDocumentFilePicker) {
            DocumentImagePicker(selectedImage: $selectedSourceImage)
        }
        .sheet(isPresented: $showEditWatermarkSheet) {
            EditWatermarkSheet(locationService: locationService)
                .environmentObject(store)
        }
        .sheet(isPresented: $showTemplatePickerSheet) {
            TemplatePickerSheet()
                .environmentObject(store)
        }
        .sheet(isPresented: $showPreviewExportSheet) {
            if let exported = lastExportedImage {
                ExportedImagePreviewSheet(
                    image: exported,
                    onSaveAgain: {
                        WatermarkRenderer.saveToPhotoLibrary(exported) { _, message in
                            showToast(message)
                        }
                    },
                    onShare: {
                        showPreviewExportSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showShareSheet = true
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let exported = lastExportedImage {
                ShareSheetView(items: [exported])
            }
        }
        .onChange(of: selectedSourceImage) { _ in
            resetImageTransform()
        }
    }

    // MARK: - 1. Top Header Bar (Giống hệt ảnh chụp màn hình)
    private var topHeaderBar: some View {
        HStack(spacing: 0) {
            // Nút Menu 3 gạch bên trái
            Menu {
                Button {
                    showEditWatermarkSheet = true
                } label: {
                    Label("Chỉnh sửa Thời gian & Ghi chú", systemImage: "clock.badge.checkmark")
                }

                Button {
                    showTemplatePickerSheet = true
                } label: {
                    Label("Đổi Bản mẫu (Presets)", systemImage: "doc.text.image")
                }

                Button {
                    store.useRealTime.toggle()
                    if store.useRealTime {
                        store.setNow()
                        showToast("Đã bật đồng hồ thời gian thực")
                    } else {
                        showToast("Đã chuyển sang chế độ tự điền thời gian")
                    }
                } label: {
                    Label(
                        store.useRealTime ? "Tắt giờ tự động (Chỉnh tay)" : "Bật tự động nhảy giờ thực",
                        systemImage: store.useRealTime ? "pause.circle" : "play.circle"
                    )
                }

                if lastExportedImage != nil {
                    Button {
                        showPreviewExportSheet = true
                    } label: {
                        Label("Xem lại ảnh vừa xuất", systemImage: "photo")
                    }
                }
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Capsule().fill(Color.black.opacity(0.85)).frame(width: 22, height: 2.2)
                    Capsule().fill(Color.black.opacity(0.85)).frame(width: 17, height: 2.2)
                    Capsule().fill(Color.black.opacity(0.85)).frame(width: 13, height: 2.2)
                }
                .frame(width: 40, height: 40)
            }

            Spacer(minLength: 6)

            // Nút Đèn Flash
            Button {
                cameraService.toggleFlash()
                showToast(cameraService.isFlashOn ? "Đã bật đèn Flash" : "Đã tắt đèn Flash")
            } label: {
                Image(systemName: cameraService.isFlashOn ? "bolt.fill" : "bolt.slash")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.black.opacity(0.85))
                    .frame(width: 40, height: 40)
            }

            Spacer(minLength: 8)

            // Huy hiệu giữa: "Xác minh Ảnh" kèm khiên tích và chấm đỏ
            Button {
                showEditWatermarkSheet = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.black.opacity(0.85))
                        Text(store.verificationBadgeText)
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundColor(.black.opacity(0.88))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(
                        Capsule()
                            .stroke(Color.black.opacity(0.55), lineWidth: 1.1)
                    )

                    Circle()
                        .fill(Color(red: 0.92, green: 0.20, blue: 0.18))
                        .frame(width: 8, height: 8)
                        .offset(x: 1, y: -1)
                }
            }

            Spacer(minLength: 8)

            // Biểu tượng tai nghe hỗ trợ kèm badge số 1 đỏ
            Button {
                showEditWatermarkSheet = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "headphones")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.black.opacity(0.85))
                        .frame(width: 36, height: 36)

                    Text("1")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)
                        .background(Color(red: 0.92, green: 0.25, blue: 0.20))
                        .clipShape(Circle())
                        .offset(x: 3, y: -1)
                }
            }

            Spacer(minLength: 6)

            // Nút Đổi Camera trước / sau
            Button {
                if selectedSourceImage != nil {
                    selectedSourceImage = nil
                    showToast("Đã chuyển sang chế độ chụp Camera")
                } else {
                    cameraService.switchCamera()
                }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.black.opacity(0.85))
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white)
    }

    // MARK: - 2. Zoom Selector Column (10, 2, 1x, 0.5)
    private var zoomSelectorColumn: some View {
        VStack(spacing: 12) {
            ForEach(zoomLevels, id: \.label) { item in
                let isSelected = abs(cameraService.currentZoomFactor - item.factor) < 0.1
                Button {
                    if selectedSourceImage != nil {
                        withAnimation(.spring(response: 0.25)) {
                            imageScale = max(1.0, min(item.factor, 4.0))
                            lastImageScale = imageScale
                            if item.factor <= 1.0 {
                                imageOffset = .zero
                                lastImageOffset = .zero
                            }
                        }
                        cameraService.currentZoomFactor = item.factor
                    } else {
                        cameraService.setZoom(factor: item.factor)
                    }
                } label: {
                    Text(item.label)
                        .font(.system(size: isSelected ? 13 : 11.5, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: isSelected ? 36 : 26, height: isSelected ? 36 : 26)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(isSelected ? 0.95 : 0.0), lineWidth: 1.5)
                        )
                }
            }
        }
    }

    // MARK: - 3. Direction Banner Bar (Thanh xanh dương nhạt "D ->")
    private var directionBannerBar: some View {
        Button {
            // Chạm vào thanh xanh để đổi nhanh ký hiệu hướng (D ->, B ->, N ->, T ->)
            let list = ["D", "B", "N", "T", "ĐB", "ĐN", "TB", "TN"]
            if let idx = list.firstIndex(of: store.directionBannerCode) {
                store.directionBannerCode = list[(idx + 1) % list.count]
            } else {
                store.directionBannerCode = "D"
            }
        } label: {
            HStack(spacing: 8) {
                Text(store.directionBannerCode)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.48))
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 0.22, green: 0.42, blue: 0.65))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(Color(red: 0.85, green: 0.93, blue: 0.99))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 4. Bottom Control Bar (Có sẵn | Tệp | Nút chụp lớn | Bản mẫu)
    private var bottomControlBar: some View {
        HStack(spacing: 0) {
            // Nút 1: "Có sẵn" (Chọn ảnh từ Thư viện Ảnh)
            Button {
                showPhotoLibraryPicker = true
            } label: {
                VStack(spacing: 6) {
                    ZStack {
                        if let previewThumb = lastExportedImage ?? selectedSourceImage {
                            Image(uiImage: previewThumb)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 36, height: 36)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .stroke(Color.black.opacity(0.6), lineWidth: 1.2)
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color(.systemGray6))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundColor(.black.opacity(0.8))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .stroke(Color.black.opacity(0.65), lineWidth: 1.2)
                                )
                        }
                    }
                    Text("Có sẵn")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.black.opacity(0.75))
                }
                .frame(width: 68)
            }

            // Nút 2: "Tệp" (Mở ảnh từ ứng dụng Tệp / iCloud Drive)
            Button {
                showDocumentFilePicker = true
            } label: {
                VStack(spacing: 6) {
                    ZStack {
                        Image(systemName: "folder")
                            .font(.system(size: 24, weight: .regular))
                            .foregroundColor(.black.opacity(0.85))
                        Image(systemName: "cloud")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black.opacity(0.85))
                            .offset(y: 2)
                    }
                    .frame(width: 36, height: 36)

                    Text("Tệp")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.black.opacity(0.75))
                }
                .frame(width: 58)
            }

            Spacer()

            // Nút 3 (Ở giữa): Nút Chụp Ảnh / Xuất Ảnh Đóng Dấu Thời Gian
            Button {
                handleShutterOrExportAction()
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.black, lineWidth: 5.5)
                        .frame(width: 74, height: 74)

                    Circle()
                        .fill(isProcessingCapture ? Color(.systemGray4) : Color.white)
                        .frame(width: 62, height: 62)

                    if selectedSourceImage != nil {
                        VStack(spacing: 1) {
                            Image(systemName: "arrow.down.to.line")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black.opacity(0.8))
                            Text("LƯU")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundColor(.black.opacity(0.75))
                        }
                    }
                }
            }
            .disabled(isProcessingCapture)

            Spacer()

            // Khoảng đệm cân xứng bên phải để nút chụp nằm đúng tâm màn hình
            Color.clear
                .frame(width: 58, height: 1)

            // Nút 4 (Bên phải): "Bản mẫu" (Mở danh sách mẫu hoặc chỉnh sửa thời gian/ghi chú)
            Button {
                showTemplatePickerSheet = true
            } label: {
                VStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.black.opacity(0.85), lineWidth: 1.8)
                            .frame(width: 28, height: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            Spacer()
                            Capsule()
                                .fill(Color.black.opacity(0.85))
                                .frame(width: 14, height: 2)
                            Capsule()
                                .fill(Color.black.opacity(0.85))
                                .frame(width: 9, height: 2)
                        }
                        .padding(5)
                        .frame(width: 28, height: 28, alignment: .bottomLeading)
                    }
                    .frame(width: 36, height: 36)

                    Text("Bản mẫu")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.black.opacity(0.75))
                }
                .frame(width: 68)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(Color.white)
    }

    // MARK: - Khung nền mặc định khi chưa mở camera hoặc chưa chọn ảnh
    private func placeholderCanvas(size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.14, green: 0.16, blue: 0.22),
                    Color(red: 0.06, green: 0.07, blue: 0.10)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 12) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 42, weight: .light))
                    .foregroundColor(.white.opacity(0.75))

                Text("Chọn ảnh từ 'Có sẵn' hoặc 'Tệp'\nhoặc cấp quyền Camera để chụp trực tiếp")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 28)

                HStack(spacing: 12) {
                    Button {
                        showPhotoLibraryPicker = true
                    } label: {
                        Label("Chọn ảnh Có sẵn", systemImage: "photo.on.rectangle")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.18))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }

                    Button {
                        showEditWatermarkSheet = true
                    } label: {
                        Label("Sửa giờ & Kíp", systemImage: "square.and.pencil")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.85))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
            }
            .offset(y: -40)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Actions
    private func handleShutterOrExportAction() {
        isProcessingCapture = true

        // Trường hợp 1: Đang mở một ảnh có sẵn từ Thư viện hoặc Tệp -> Ghép watermark và lưu ngay
        if let sourceImage = selectedSourceImage {
            let finalImage = WatermarkRenderer.renderWatermarkedImage(baseImage: sourceImage, store: store)
            self.lastExportedImage = finalImage
            WatermarkRenderer.saveToPhotoLibrary(finalImage) { _, message in
                self.isProcessingCapture = false
                self.showToast(message)
                self.showPreviewExportSheet = true
            }
            return
        }

        // Trường hợp 2: Đang ở chế độ Camera trực tiếp -> Chụp ảnh hoặc tạo ảnh nền mẫu nếu không có camera
        if cameraService.isAuthorized && cameraService.session.isRunning {
            cameraService.capturePhoto { captured in
                let raw = captured ?? Self.makeFallbackCanvasImage()
                let finalImage = WatermarkRenderer.renderWatermarkedImage(baseImage: raw, store: store)
                self.lastExportedImage = finalImage
                WatermarkRenderer.saveToPhotoLibrary(finalImage) { _, message in
                    self.isProcessingCapture = false
                    self.showToast(message)
                    self.showPreviewExportSheet = true
                }
            }
        } else {
            let fallback = Self.makeFallbackCanvasImage()
            let finalImage = WatermarkRenderer.renderWatermarkedImage(baseImage: fallback, store: store)
            self.lastExportedImage = finalImage
            WatermarkRenderer.saveToPhotoLibrary(finalImage) { _, message in
                self.isProcessingCapture = false
                self.showToast(message)
                self.showPreviewExportSheet = true
            }
        }
    }

    private func triggerLocationRefresh() {
        showToast("Đang cập nhật tọa độ & vị trí GPS...")
        locationService.requestCurrentLocation { resolved in
            store.locationText = resolved
            store.showLocationLine = true
            store.directionBannerCode = locationService.headingSymbol
            showToast("Đã gắn vị trí: \(resolved)")
        }
    }

    private func resetImageTransform() {
        imageScale = 1.0
        lastImageScale = 1.0
        imageOffset = .zero
        lastImageOffset = .zero
    }

    private func showToast(_ text: String) {
        withAnimation {
            toastMessage = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            withAnimation {
                if toastMessage == text {
                    toastMessage = nil
                }
            }
        }
    }

    private static func makeFallbackCanvasImage() -> UIImage {
        let size = CGSize(width: 1080, height: 1440)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor(red: 0.12, green: 0.15, blue: 0.20, alpha: 1.0).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}

/// Màn hình xem trước ảnh vừa đóng dấu xong (cho phép chia sẻ qua Zalo/Telegram hoặc lưu lại)
struct ExportedImagePreviewSheet: View {
    let image: UIImage
    let onSaveAgain: () -> Void
    let onShare: () -> Void
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                Text("Ảnh đã được tự động lưu vào Thư viện Ảnh trên iPhone của bạn.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                HStack(spacing: 14) {
                    Button(action: onSaveAgain) {
                        Label("Lưu thêm bản nữa", systemImage: "square.and.arrow.down")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)

                    Button(action: onShare) {
                        Label("Chia sẻ (Zalo / Tin nhắn)", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Ảnh đã đóng dấu")
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
