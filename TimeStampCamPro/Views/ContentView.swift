import SwiftUI
import AVKit
import UIKit

struct ContentView: View {
    @EnvironmentObject var store: WatermarkStore
    @StateObject private var cameraService = CameraService()
    @StateObject private var locationService = LocationService()
    @StateObject private var capturedStore = CapturedPhotoStore()

    // Chế độ Chụp ảnh hoặc Quay phim (Video)
    @State private var captureMode: CaptureMode = .photo

    // Ảnh người dùng chọn từ Thư viện ("Có sẵn")
    @State private var selectedSourceImage: UIImage? = nil

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
    @State private var shutterFlashOpacity: Double = 0.0
    @State private var currentViewportSize: CGSize = CGSize(width: 390, height: 520)

    private static let renderQueue = DispatchQueue(label: "com.timestampcam.pro.watermark.render", qos: .userInitiated)
    private static let hapticLight = UIImpactFeedbackGenerator(style: .light)
    private static let hapticMedium = UIImpactFeedbackGenerator(style: .medium)

    private let zoomLevels: [(label: String, factor: CGFloat)] = [
        ("10", 10.0),
        ("2", 2.0),
        ("1x", 1.0),
        ("0.5", 0.5)
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // 1. THANH ĐIỀU KHIỂN TRÊN CÙNG (Menu | Flash | Tỉ lệ 3:4, 9:16, Full, 1:1 | Ảnh đã chụp | Đổi Camera)
                topHeaderBar

                // 2. KHUNG CAMERA / VIDEO / ẢNH ĐÃ CHỌN THEO ĐÚNG TỈ LỆ (3:4, 9:16, Full, 1:1)
                GeometryReader { geo in
                    let activeSize = store.aspectRatio.targetSize(fitting: geo.size)

                    ZStack {
                        Color.black

                        // Khung hình thực tế theo tỉ lệ 3:4, 9:16, Full hoặc 1:1 nằm chính giữa
                        ZStack(alignment: .bottom) {
                            if let chosenImage = selectedSourceImage {
                                Image(uiImage: chosenImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: activeSize.width, height: activeSize.height)
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
                                    .frame(width: activeSize.width, height: activeSize.height)
                                    .clipped()
                            } else {
                                placeholderCanvas(size: activeSize)
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
                            .frame(width: activeSize.width, height: activeSize.height * 0.36)
                            .allowsHitTesting(false)

                            // Cột nút chọn mức Zoom dọc bên phải (10, 2, 1x, 0.5)
                            HStack {
                                Spacer()
                                zoomSelectorColumn
                                    .padding(.trailing, 12)
                                    .padding(.bottom, min(145, activeSize.height * 0.32))
                            }
                            .frame(width: activeSize.width, height: activeSize.height)

                            // KHUNG BIỂU MẪU (Logo Hòa Phát + Giờ + Ngày + Thứ + Tổ Vận hành) bám theo đúng khung tỉ lệ
                            WatermarkOverlayView(
                                containerSize: activeSize,
                                onTapEdit: {
                                    Self.hapticLight.impactOccurred()
                                    showEditWatermarkSheet = true
                                },
                                onTapLocation: {
                                    Self.hapticLight.impactOccurred()
                                    triggerLocationRefresh()
                                }
                            )
                            .frame(width: activeSize.width, height: activeSize.height, alignment: .bottom)

                            // Hiệu ứng nháy màn trập tức thì khi bấm chụp ảnh (0ms phản hồi thị giác)
                            Color.white
                                .opacity(shutterFlashOpacity)
                                .frame(width: activeSize.width, height: activeSize.height)
                                .allowsHitTesting(false)
                        }
                        .frame(width: activeSize.width, height: activeSize.height)
                        .clipped()

                        // Thanh nổi phía trên cùng của khung Camera: Đồng hồ quay Video & Nút Quay lại Camera
                        VStack(spacing: 8) {
                            if cameraService.isRecordingVideo {
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
                                .padding(.top, 10)
                            }

                            if selectedSourceImage != nil {
                                HStack {
                                    Button {
                                        Self.hapticLight.impactOccurred()
                                        selectedSourceImage = nil
                                        resetImageTransform()
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
                                        Self.hapticLight.impactOccurred()
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
                                .padding(.top, 10)
                            }

                            Spacer()
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .onAppear {
                        currentViewportSize = activeSize
                    }
                    .onChange(of: activeSize) { newSize in
                        currentViewportSize = newSize
                    }
                }

                // 3. THANH CÔNG CỤ DƯỚI CÙNG (Chọn nhanh 3:4 | 9:16 | Full | 1:1 + Chế độ ẢNH/VIDEO + Có sẵn | Nút Chụp | Bản mẫu)
                bottomControlBar
            }

            // 4. BẢNG TRƯỢT "CHỈNH SỬA MẪU" NỬA DƯỚI MÀN HÌNH
            if showTemplateDesignerDrawer {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showTemplateDesignerDrawer = false
                    }

                TemplatePickerSheet(
                    locationService: locationService,
                    onClose: {
                        showTemplateDesignerDrawer = false
                    }
                )
                .environmentObject(store)
                .zIndex(10)
            }
        }
        .overlay(alignment: .top) {
            if let msg = toastMessage {
                Text(msg)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Color.black.opacity(0.82))
                    .clipShape(Capsule())
                    .padding(.top, 58)
                    .allowsHitTesting(false)
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

    // MARK: - 1. Top Header Bar (Menu | Flash | Tỉ lệ khung hình | Nút mở Ảnh đã chụp & Chia sẻ | Xoay Camera)
    private var topHeaderBar: some View {
        HStack(spacing: 6) {
            // Nút Menu 3 gạch bên trái
            Menu {
                Button {
                    showAppGallerySheet = true
                } label: {
                    Label("Ảnh đã chụp & Chia sẻ (\(capturedStore.items.count))", systemImage: "photo.stack.fill")
                }

                Button {
                    showTemplateDesignerDrawer = true
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
                    Capsule().fill(Color.black.opacity(0.85)).frame(width: 20, height: 2.2)
                    Capsule().fill(Color.black.opacity(0.85)).frame(width: 15, height: 2.2)
                    Capsule().fill(Color.black.opacity(0.85)).frame(width: 11, height: 2.2)
                }
                .frame(width: 36, height: 38)
                .contentShape(Rectangle())
            }

            // Nút Đèn Flash (Phản hồi tức thì)
            Button {
                Self.hapticLight.impactOccurred()
                cameraService.toggleFlash()
                showToast(cameraService.isFlashOn ? "Flash: Bật" : "Flash: Tắt")
            } label: {
                Image(systemName: cameraService.isFlashOn ? "bolt.fill" : "bolt.slash")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(cameraService.isFlashOn ? Color(red: 0.98, green: 0.42, blue: 0.0) : .black.opacity(0.85))
                    .frame(width: 36, height: 38)
                    .contentShape(Rectangle())
            }

            // Nút chuyển nhanh tỉ lệ khung hình Camera (3:4 -> 9:16 -> Full -> 1:1) chỉ với 1 chạm
            Button {
                Self.hapticLight.impactOccurred()
                cycleAspectRatio()
            } label: {
                Text(store.aspectRatio.rawValue)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black.opacity(0.88))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.black.opacity(0.25), lineWidth: 1)
                    )
            }

            Spacer(minLength: 4)

            // Nút mở Bộ sưu tập các ảnh được chụp bằng ứng dụng (Chọn nhiều ảnh & Chia sẻ Zalo, Facebook...)
            Button {
                Self.hapticLight.impactOccurred()
                showAppGallerySheet = true
            } label: {
                HStack(spacing: 6) {
                    if let thumb = capturedStore.latestThumbnail {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 22, height: 22)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    } else {
                        Image(systemName: "photo.stack.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(red: 0.98, green: 0.42, blue: 0.0))
                    }

                    Text("Ảnh đã chụp")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.black.opacity(0.88))
                        .lineLimit(1)

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
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.black.opacity(0.15), lineWidth: 1)
                )
            }

            Spacer(minLength: 4)

            // Nút Đổi Camera trước / sau ở góc phải
            Button {
                Self.hapticLight.impactOccurred()
                if selectedSourceImage != nil {
                    selectedSourceImage = nil
                    showToast("Đã chuyển sang Camera")
                } else {
                    cameraService.switchCamera()
                }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundColor(.black.opacity(0.85))
                    .frame(width: 36, height: 38)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white)
    }

    // MARK: - 2. Zoom Selector Column (10, 2, 1x, 0.5)
    private var zoomSelectorColumn: some View {
        VStack(spacing: 10) {
            ForEach(zoomLevels, id: \.label) { item in
                let isSelected = abs(cameraService.currentZoomFactor - item.factor) < 0.1
                Button {
                    Self.hapticLight.impactOccurred()
                    if selectedSourceImage != nil {
                        imageScale = max(1.0, min(item.factor, 4.0))
                        lastImageScale = imageScale
                        if item.factor <= 1.0 {
                            imageOffset = .zero
                            lastImageOffset = .zero
                        }
                        cameraService.currentZoomFactor = item.factor
                    } else {
                        cameraService.setZoom(factor: item.factor)
                    }
                } label: {
                    Text(item.label)
                        .font(.system(size: isSelected ? 13 : 11.5, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: isSelected ? 36 : 28, height: isSelected ? 36 : 28)
                        .background(Color.black.opacity(0.48))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(isSelected ? 0.95 : 0.0), lineWidth: 1.5)
                        )
                }
            }
        }
    }

    // MARK: - 3. Bottom Control Bar (Thanh chọn nhanh kích thước 3:4 | 9:16 | Full | 1:1 + ẢNH/VIDEO + Có sẵn | Nút Chụp | Bản mẫu)
    private var bottomControlBar: some View {
        VStack(spacing: 6) {
            // Hàng nút chọn kích thước khung hình Camera trực tiếp 1 chạm (3:4, 9:16, Full, 1:1) + Chế độ ẢNH / VIDEO
            HStack(spacing: 8) {
                // Bộ chọn nhanh tỉ lệ khung hình: 3:4 | 9:16 | Full | 1:1
                HStack(spacing: 4) {
                    ForEach(CameraAspectRatio.allCases) { ratio in
                        let isSelected = store.aspectRatio == ratio
                        Button {
                            Self.hapticLight.impactOccurred()
                            store.aspectRatio = ratio
                        } label: {
                            Text(ratio.rawValue)
                                .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .white : .black.opacity(0.75))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(
                                    isSelected
                                        ? Color(red: 0.98, green: 0.42, blue: 0.0)
                                        : Color(.systemGray6)
                                )
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer()

                // Chuyển đổi chế độ ẢNH / VIDEO
                HStack(spacing: 14) {
                    ForEach(CaptureMode.allCases, id: \.self) { mode in
                        Button {
                            guard !cameraService.isRecordingVideo else { return }
                            Self.hapticLight.impactOccurred()
                            captureMode = mode
                            if mode == .video {
                                selectedSourceImage = nil
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Text(mode.rawValue)
                                    .font(.system(size: 12.5, weight: captureMode == mode ? .bold : .medium))
                                    .foregroundColor(captureMode == mode ? Color(red: 0.98, green: 0.42, blue: 0.0) : .gray)
                                Circle()
                                    .fill(captureMode == mode ? Color(red: 0.98, green: 0.42, blue: 0.0) : Color.clear)
                                    .frame(width: 4, height: 4)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            HStack(spacing: 0) {
                // Nút 1 (Bên trái): "Có sẵn" (Chọn ảnh từ Thư viện Ảnh)
                Button {
                    Self.hapticLight.impactOccurred()
                    showPhotoLibraryPicker = true
                } label: {
                    VStack(spacing: 5) {
                        ZStack {
                            if let previewThumb = selectedSourceImage ?? capturedStore.latestThumbnail {
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
                    .contentShape(Rectangle())
                }
                .disabled(cameraService.isRecordingVideo)

                Spacer()

                // Nút 2 (Ở giữa): Nút Chụp Ảnh / Bắt đầu hoặc Dừng Quay Video (Không khóa nút, bấm ăn ngay)
                Button {
                    handleShutterOrRecordAction()
                } label: {
                    ZStack {
                        Circle()
                            .stroke(Color.black, lineWidth: 5.5)
                            .frame(width: 72, height: 72)

                        if captureMode == .video {
                            if cameraService.isRecordingVideo {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.red)
                                    .frame(width: 30, height: 30)
                            } else {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 54, height: 54)
                            }
                        } else {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 60, height: 60)

                            if selectedSourceImage != nil {
                                VStack(spacing: 1) {
                                    Image(systemName: "arrow.down.to.line")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(.black.opacity(0.8))
                                    Text("LƯU")
                                        .font(.system(size: 9, weight: .heavy))
                                        .foregroundColor(.black.opacity(0.75))
                                }
                            }
                        }
                    }
                }

                Spacer()

                // Nút 3 (Bên phải): "Bản mẫu" -> Bật bảng trượt "Chỉnh sửa mẫu" tức thì
                Button {
                    Self.hapticLight.impactOccurred()
                    showTemplateDesignerDrawer = true
                } label: {
                    VStack(spacing: 5) {
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
                    .contentShape(Rectangle())
                }
                .disabled(cameraService.isRecordingVideo)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
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
                    .font(.system(size: 38, weight: .light))
                    .foregroundColor(.white.opacity(0.75))

                Text("Chụm 2 ngón tay vào biểu mẫu để phóng to/thu nhỏ\nhoặc nhấn giữ để kéo biểu mẫu tới vị trí bất kỳ")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 24)

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
                        showTemplateDesignerDrawer = true
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
            .offset(y: -30)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Actions (Phản hồi 0ms, xử lý và lưu ảnh hoàn toàn ở luồng nền)
    private func cycleAspectRatio() {
        let all = CameraAspectRatio.allCases
        if let idx = all.firstIndex(of: store.aspectRatio) {
            let nextIdx = (idx + 1) % all.count
            store.aspectRatio = all[nextIdx]
        } else {
            store.aspectRatio = .ratio3x4
        }
        showToast("Khung hình: \(store.aspectRatio.rawValue)")
    }

    private func triggerShutterFlash() {
        Self.hapticMedium.impactOccurred()
        shutterFlashOpacity = 0.65
        withAnimation(.easeOut(duration: 0.14)) {
            shutterFlashOpacity = 0.0
        }
    }

    private func handleShutterOrRecordAction() {
        let snapshot = WatermarkRenderSnapshot(from: store)
        let viewportSize = currentViewportSize

        // CHẾ ĐỘ 1: QUAY PHIM (VIDEO)
        if captureMode == .video && selectedSourceImage == nil {
            Self.hapticMedium.impactOccurred()
            if cameraService.isRecordingVideo {
                showToast("Đang lưu Video...")
                cameraService.stopVideoRecording()
            } else {
                guard cameraService.isAuthorized && cameraService.session.isRunning else {
                    showToast("Cần cấp quyền Camera để quay video.")
                    return
                }
                cameraService.startVideoRecording { rawVideoURL in
                    guard let rawURL = rawVideoURL else {
                        self.showToast("Không thể ghi hình video.")
                        return
                    }
                    WatermarkRenderer.exportWatermarkedVideo(sourceURL: rawURL, snapshot: snapshot) { exportedURL, errMsg in
                        guard let finalURL = exportedURL else {
                            self.showToast(errMsg ?? "Lỗi xuất video.")
                            return
                        }
                        WatermarkRenderer.saveVideoToPhotoLibrary(finalURL) { _, message in
                            self.showToast(message)
                        }
                    }
                }
            }
            return
        }

        // CHẾ ĐỘ 2: CHỤP ẢNH HOẶC XUẤT ẢNH CÓ SẴN -> NHÁY MÀN TRẬP TỨC THÌ & XỬ LÝ NGẦM 100%
        triggerShutterFlash()

        if let sourceImage = selectedSourceImage {
            processAndSavePhotoInBackground(baseImage: sourceImage, snapshot: snapshot, viewportSize: viewportSize)
            return
        }

        if cameraService.isAuthorized && cameraService.session.isRunning {
            cameraService.capturePhoto { captured in
                let raw = captured ?? Self.makeFallbackCanvasImage(for: snapshot.aspectRatio, viewportSize: viewportSize)
                self.processAndSavePhotoInBackground(baseImage: raw, snapshot: snapshot, viewportSize: viewportSize)
            }
        } else {
            Self.renderQueue.async {
                let fallback = Self.makeFallbackCanvasImage(for: snapshot.aspectRatio, viewportSize: viewportSize)
                self.processAndSavePhotoInBackground(baseImage: fallback, snapshot: snapshot, viewportSize: viewportSize)
            }
        }
    }

    private func processAndSavePhotoInBackground(
        baseImage: UIImage,
        snapshot: WatermarkRenderSnapshot,
        viewportSize: CGSize
    ) {
        Self.renderQueue.async {
            // 1. Cắt ảnh theo đúng tỉ lệ (3:4, 9:16, Full, 1:1) và đóng dấu thời gian trong 1 lượt vẽ duy nhất
            let finalImage = WatermarkRenderer.renderWatermarkedImage(
                baseImage: baseImage,
                snapshot: snapshot,
                viewportSize: viewportSize
            )

            // 2. Lưu vào Bộ sưu tập ảnh đã chụp của ứng dụng (trên luồng nền)
            let caption = "\(snapshot.timeText) • \(snapshot.dateText) (\(snapshot.weekdayText)) — \(snapshot.activeNoteLines.first ?? "")"
            self.capturedStore.addCapturedPhotoAsync(finalImage, caption: caption)

            // 3. Lưu thẳng vào Thư viện Ảnh hệ thống của iPhone
            WatermarkRenderer.saveToPhotoLibrary(finalImage) { _, message in
                self.showToast(message)
            }
        }
    }

    private func triggerLocationRefresh() {
        showToast("Đang cập nhật vị trí GPS...")
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
        toastMessage = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if toastMessage == text {
                toastMessage = nil
            }
        }
    }

    private static func makeFallbackCanvasImage(for ratio: CameraAspectRatio, viewportSize: CGSize) -> UIImage {
        let aspect = max(0.3, min(ratio.numericAspect(fallbackContainerSize: viewportSize), 3.0))
        let width: CGFloat = 1080
        let height: CGFloat = round(width / aspect)
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            UIColor(red: 0.12, green: 0.15, blue: 0.20, alpha: 1.0).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}
