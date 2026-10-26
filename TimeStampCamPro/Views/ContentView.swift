import SwiftUI
import AVKit

struct ContentView: View {
    @EnvironmentObject var store: WatermarkStore
    @StateObject private var cameraService = CameraService()
    @StateObject private var locationService = LocationService()
    @StateObject private var capturedStore = CapturedPhotoStore()

    // Chế độ Chụp ảnh hoặc Quay phim (Video)
    @State private var captureMode: CaptureMode = .photo

    // Ảnh người dùng chọn từ Thư viện ("Có sẵn")
    @State private var selectedSourceImage: UIImage? = nil
    @State private var lastExportedImage: UIImage? = nil
    @State private var lastExportedVideoURL: URL? = nil

    // Các sheet & bảng trượt chức năng
    @State private var showPhotoLibraryPicker = false
    @State private var showAppGallerySheet = false
    @State private var showEditWatermarkSheet = false
    @State private var showTemplateDesignerDrawer = false

    // Phóng to / thu nhỏ và kéo ảnh nền khi đang chọn ảnh có sẵn từ máy
    @State private var imageScale: CGFloat = 1.0
    @State private var lastImageScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero
    @State private var lastImageOffset: CGSize = .zero

    @State private var toastMessage: String? = nil
    @State private var isProcessingCapture: Bool = false

    private let zoomLevels: [(label: String, factor: CGFloat)] = [
        ("10", 10.0),
        ("2", 2.0),
        ("1x", 1.0),
        ("0.5", 0.5)
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // 1. THANH ĐIỀU KHIỂN TRÊN CÙNG (Có nút mở bộ sưu tập Ảnh đã chụp để chọn nhiều ảnh & chia sẻ Zalo/Facebook)
                topHeaderBar

                // 2. KHUNG CAMERA / VIDEO / ẢNH ĐÃ CHỌN + BIỂU MẪU KÉO THẢ & CHỤM PHÓNG TO
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

                        // Đồng hồ đếm thời gian quay video (00:00) khi đang quay phim
                        if cameraService.isRecordingVideo {
                            VStack {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 10, height: 10)
                                    Text("REC  \(cameraService.formattedRecordingDuration)")
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.68))
                                .clipShape(Capsule())
                                .padding(.top, 14)
                                Spacer()
                            }
                        }

                        // Nút quay lại Camera trực tiếp nếu đang mở ảnh từ Thư viện ("Có sẵn")
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
                                            Text("Quay lại Camera")
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
                                        store.resetPositionAndScale()
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

                        // Cột nút chọn mức Zoom dọc bên phải (10, 2, 1x, 0.5)
                        HStack {
                            Spacer()
                            zoomSelectorColumn
                                .padding(.trailing, 12)
                                .padding(.bottom, 155)
                        }

                        // KHUNG BIỂU MẪU (Logo Hòa Phát + Giờ 22:26 + 26/10/2026 + Thứ Hai + Tổ Vận hành - Kíp A X.CT1)
                        // Hỗ trợ chụm 2 ngón tay phóng to/thu nhỏ & kéo di chuyển tự do
                        WatermarkOverlayView(
                            containerSize: geo.size,
                            onTapEdit: {
                                showEditWatermarkSheet = true
                            },
                            onTapLocation: {
                                triggerLocationRefresh()
                            }
                        )
                    }
                }

                // 3. THANH CÔNG CỤ DƯỚI CÙNG (Đã xóa nút Tệp theo yêu cầu: chỉ còn Có sẵn | Nút Chụp/Quay | Bản mẫu)
                bottomControlBar
            }

            // 4. BẢNG TRƯỢT "CHỈNH SỬA MẪU" NỬA DƯỚI MÀN HÌNH
            if showTemplateDesignerDrawer {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            showTemplateDesignerDrawer = false
                        }
                    }

                TemplatePickerSheet(
                    locationService: locationService,
                    onClose: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            showTemplateDesignerDrawer = false
                        }
                    }
                )
                .environmentObject(store)
                .transition(.move(edge: .bottom))
                .zIndex(10)
            }
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
        .sheet(isPresented: $showAppGallerySheet) {
            AppPhotoGallerySheet(capturedStore: capturedStore)
        }
        .sheet(isPresented: $showEditWatermarkSheet) {
            EditWatermarkSheet(locationService: locationService)
                .environmentObject(store)
        }
        .onChange(of: selectedSourceImage) { newImg in
            resetImageTransform()
            if newImg != nil {
                captureMode = .photo
            }
        }
    }

    // MARK: - 1. Top Header Bar (Menu | Flash | Nút mở Ảnh đã chụp & Chia sẻ | Xoay Camera)
    private var topHeaderBar: some View {
        HStack(spacing: 0) {
            // Nút Menu 3 gạch bên trái
            Menu {
                Button {
                    showAppGallerySheet = true
                } label: {
                    Label("Ảnh đã chụp & Chia sẻ (\(capturedStore.items.count))", systemImage: "photo.stack.fill")
                }

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        showTemplateDesignerDrawer = true
                    }
                } label: {
                    Label("Chỉnh sửa mẫu (Logo, Text, Tọa độ...)", systemImage: "slider.horizontal.3")
                }

                Button {
                    showEditWatermarkSheet = true
                } label: {
                    Label("Chỉnh sửa Thời gian & Kíp trực", systemImage: "clock.badge.checkmark")
                }

                Button {
                    store.resetPositionAndScale()
                    showToast("Đã đặt lại vị trí & kích thước biểu mẫu")
                } label: {
                    Label("Đặt lại vị trí & phóng đại biểu mẫu", systemImage: "arrow.uturn.backward")
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
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Capsule().fill(Color.black.opacity(0.85)).frame(width: 22, height: 2.2)
                    Capsule().fill(Color.black.opacity(0.85)).frame(width: 17, height: 2.2)
                    Capsule().fill(Color.black.opacity(0.85)).frame(width: 13, height: 2.2)
                }
                .frame(width: 40, height: 40)
            }

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
            .padding(.leading, 8)

            Spacer()

            // Nút mở Bộ sưu tập các ảnh được chụp bằng ứng dụng này (Chọn nhiều ảnh & Chia sẻ Zalo, Facebook...)
            Button {
                showAppGallerySheet = true
            } label: {
                HStack(spacing: 6) {
                    if let firstItem = capturedStore.items.first,
                       let thumb = capturedStore.thumbnailImage(for: firstItem) {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 22, height: 22)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    } else {
                        Image(systemName: "photo.stack.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(red: 0.98, green: 0.42, blue: 0.0))
                    }

                    Text("Ảnh đã chụp")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.black.opacity(0.88))

                    if !capturedStore.items.isEmpty {
                        Text("\(capturedStore.items.count)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(red: 0.98, green: 0.42, blue: 0.0))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.black.opacity(0.15), lineWidth: 1)
                )
            }

            Spacer()

            // Nút Đổi Camera trước / sau ở góc phải
            Button {
                if selectedSourceImage != nil {
                    selectedSourceImage = nil
                    showToast("Đã chuyển sang chế độ Camera trực tiếp")
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

    // MARK: - 3. Bottom Control Bar (Thanh chọn ẢNH / VIDEO + Có sẵn | Nút Chụp/Quay | Bản mẫu — Đã xóa nút Tệp)
    private var bottomControlBar: some View {
        VStack(spacing: 8) {
            // Thanh chuyển đổi chế độ ẢNH / VIDEO
            HStack(spacing: 28) {
                ForEach(CaptureMode.allCases, id: \.self) { mode in
                    Button {
                        guard !cameraService.isRecordingVideo else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            captureMode = mode
                            if mode == .video {
                                selectedSourceImage = nil
                            }
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(mode.rawValue)
                                .font(.system(size: 13, weight: captureMode == mode ? .bold : .medium))
                                .foregroundColor(captureMode == mode ? Color(red: 0.98, green: 0.42, blue: 0.0) : .gray)
                            Circle()
                                .fill(captureMode == mode ? Color(red: 0.98, green: 0.42, blue: 0.0) : Color.clear)
                                .frame(width: 5, height: 5)
                        }
                    }
                }
            }
            .padding(.top, 8)

            HStack(spacing: 0) {
                // Nút 1 (Bên trái): "Có sẵn" (Chọn ảnh từ Thư viện Ảnh)
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
                .disabled(cameraService.isRecordingVideo)

                Spacer()

                // Nút 2 (Ở giữa): Nút Chụp Ảnh / Bắt đầu hoặc Dừng Quay Video
                Button {
                    handleShutterOrRecordAction()
                } label: {
                    ZStack {
                        Circle()
                            .stroke(Color.black, lineWidth: 5.5)
                            .frame(width: 74, height: 74)

                        if captureMode == .video {
                            if cameraService.isRecordingVideo {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.red)
                                    .frame(width: 32, height: 32)
                            } else {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 56, height: 56)
                            }
                        } else {
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
                }
                .disabled(isProcessingCapture)

                Spacer()

                // Nút 3 (Bên phải): "Bản mẫu" -> Bật bảng trượt "Chỉnh sửa mẫu"
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        showTemplateDesignerDrawer = true
                    }
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
                .disabled(cameraService.isRecordingVideo)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(Color.white)
    }

    // MARK: - Khung chờ khi chưa mở camera hoặc chưa chọn ảnh
    private func placeholderCanvas(size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.10, green: 0.12, blue: 0.16),
                    Color(red: 0.04, green: 0.05, blue: 0.08)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 12) {
                Image(systemName: captureMode == .video ? "video.badge.plus" : "photo.badge.plus")
                    .font(.system(size: 42, weight: .light))
                    .foregroundColor(.white.opacity(0.75))

                Text("Chụm 2 ngón tay vào biểu mẫu để phóng to/thu nhỏ\nhoặc nhấn giữ để kéo biểu mẫu tới vị trí bất kỳ")
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
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            showTemplateDesignerDrawer = true
                        }
                    } label: {
                        Label("Chỉnh sửa mẫu", systemImage: "slider.horizontal.3")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.85))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
            }
            .offset(y: -45)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Actions (Lưu ngay vào Thư viện và Bộ sưu tập ứng dụng, KHÔNG hiện bảng hỏi lại)
    private func handleShutterOrRecordAction() {
        // CHẾ ĐỘ 1: QUAY PHIM (VIDEO)
        if captureMode == .video && selectedSourceImage == nil {
            if cameraService.isRecordingVideo {
                isProcessingCapture = true
                showToast("Đang đóng dấu biểu mẫu vào Video...")
                cameraService.stopVideoRecording()
            } else {
                guard cameraService.isAuthorized && cameraService.session.isRunning else {
                    showToast("Cần cấp quyền Camera để quay video trực tiếp.")
                    return
                }
                cameraService.startVideoRecording { rawVideoURL in
                    guard let rawURL = rawVideoURL else {
                        self.isProcessingCapture = false
                        self.showToast("Không thể ghi hình video.")
                        return
                    }
                    WatermarkRenderer.exportWatermarkedVideo(sourceURL: rawURL, store: self.store) { exportedURL, errMsg in
                        guard let finalURL = exportedURL else {
                            self.isProcessingCapture = false
                            self.showToast(errMsg ?? "Lỗi xuất video.")
                            return
                        }
                        self.lastExportedVideoURL = finalURL
                        self.lastExportedImage = nil
                        WatermarkRenderer.saveVideoToPhotoLibrary(finalURL) { _, message in
                            self.isProcessingCapture = false
                            self.showToast(message)
                        }
                    }
                }
            }
            return
        }

        // CHẾ ĐỘ 2: CHỤP ẢNH HOẶC XUẤT ẢNH CÓ SẴN -> LƯU NGAY LẬP TỨC, KHÔNG HỎI LẠI
        isProcessingCapture = true
        lastExportedVideoURL = nil

        if let sourceImage = selectedSourceImage {
            saveAndRecordCapturedPhoto(from: sourceImage)
            return
        }

        if cameraService.isAuthorized && cameraService.session.isRunning {
            cameraService.capturePhoto { captured in
                let raw = captured ?? Self.makeFallbackCanvasImage()
                self.saveAndRecordCapturedPhoto(from: raw)
            }
        } else {
            let fallback = Self.makeFallbackCanvasImage()
            saveAndRecordCapturedPhoto(from: fallback)
        }
    }

    private func saveAndRecordCapturedPhoto(from baseImage: UIImage) {
        let finalImage = WatermarkRenderer.renderWatermarkedImage(baseImage: baseImage, store: store)
        self.lastExportedImage = finalImage

        // 1. Lưu ngay vào Bộ sưu tập ảnh đã chụp của ứng dụng (mở từ nút "Ảnh đã chụp" trên thanh đầu)
        let caption = "\(store.timeText) • \(store.dateText) (\(store.weekdayText)) — \(store.noteLine1)"
        capturedStore.addCapturedPhoto(finalImage, caption: caption)

        // 2. Lưu thẳng vào Thư viện Ảnh hệ thống của iPhone mà không mở hộp thoại hỏi lại
        WatermarkRenderer.saveToPhotoLibrary(finalImage) { _, message in
            self.isProcessingCapture = false
            self.showToast(message)
        }
    }

    private func triggerLocationRefresh() {
        showToast("Đang cập nhật tọa độ & vị trí GPS...")
        locationService.requestCurrentLocation { resolved in
            store.miniMapLocationText = resolved
            store.showMiniMap = true
            if !locationService.currentCoordinates.isEmpty {
                store.coordinatesText = locationService.currentCoordinates
            }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
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
