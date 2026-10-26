import SwiftUI

/// Khung hiển thị biểu mẫu (Watermark) trực tiếp trên màn hình:
/// - Hỗ trợ **chụm 2 ngón tay (Pinch)** để phóng to / thu nhỏ biểu mẫu
/// - Hỗ trợ **nhấn giữ và kéo (Drag)** để di chuyển biểu mẫu tới bất kỳ vị trí nào trên màn hình
struct WatermarkOverlayView: View {
    @EnvironmentObject var store: WatermarkStore
    let containerSize: CGSize
    let onTapEdit: () -> Void
    let onTapLocation: () -> Void

    @State private var activeDragTranslation: CGSize = .zero
    @State private var activePinchScale: CGFloat = 1.0

    private var effectiveScale: Double {
        let combined = store.watermarkScale * Double(activePinchScale)
        return max(0.5, min(combined, 2.2))
    }

    private var currentDragOffset: CGSize {
        let dx = CGFloat(store.normalizedOffsetX) * max(containerSize.width, 1) + activeDragTranslation.width
        let dy = CGFloat(store.normalizedOffsetY) * max(containerSize.height, 1) + activeDragTranslation.height
        return CGSize(width: dx, height: dy)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(alignment: .bottom, spacing: 8) {
                // KHỐI BIỂU MẪU (Logo Hòa Phát + Giờ 22:26 + Vạch cam + 26/10/2026 + Thứ Hai + Khung mờ Kíp vận hành)
                VStack(alignment: .leading, spacing: 5 * effectiveScale) {
                    // 1. Logo Hòa Phát Gang Thép (đã xóa nền + viền trắng chuẩn mẫu)
                    if store.showLogo {
                        logoView
                    }

                    // 2. Hàng Giờ lớn (22:26) + Vạch cam + Ngày (26/10/2026) & Thứ (Thứ Hai)
                    if store.showTimeBlock {
                        HStack(alignment: .center, spacing: 9 * effectiveScale) {
                            Text(store.timeText)
                                .font(.custom("DINCondensed-Bold", size: 46 * effectiveScale))
                                .foregroundColor(.white)
                                .shadow(color: Color.black.opacity(0.55), radius: 2, x: 0, y: 1)
                                .fixedSize()

                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(store.barColor.swiftUIColor)
                                .frame(width: 2.5 * effectiveScale, height: 34 * effectiveScale)

                            VStack(alignment: .leading, spacing: 4 * effectiveScale) {
                                Text(store.dateText)
                                    .font(.system(size: 13.5 * effectiveScale, weight: .medium))
                                    .foregroundColor(.white.opacity(0.96))
                                    .shadow(color: Color.black.opacity(0.5), radius: 1.5, x: 0, y: 1)

                                Text(store.weekdayText)
                                    .font(.system(size: 13.5 * effectiveScale, weight: .regular))
                                    .foregroundColor(.white.opacity(0.94))
                                    .shadow(color: Color.black.opacity(0.5), radius: 1.5, x: 0, y: 1)
                            }
                        }
                    }

                    // 3. Khung mờ chứa các dòng ghi chú đang bật (Tổ Vận hành - Kíp A X.CT1, văn bản thêm, tọa độ...)
                    let lines = store.activeNoteLines
                    if !lines.isEmpty {
                        VStack(alignment: .leading, spacing: 3.5 * effectiveScale) {
                            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(size: 13.5 * effectiveScale, weight: .regular))
                                    .foregroundColor(.white.opacity(0.95))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.horizontal, 11 * effectiveScale)
                        .padding(.vertical, 7.5 * effectiveScale)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(white: 0.40).opacity(0.76),
                                    Color(white: 0.20).opacity(0.46)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6 * effectiveScale, style: .continuous))
                    }
                }
                .contentShape(Rectangle())
                .offset(currentDragOffset)
                .onTapGesture {
                    onTapEdit()
                }
                .gesture(
                    SimultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                activeDragTranslation = value.translation
                            }
                            .onEnded { value in
                                let w = max(containerSize.width, 1)
                                let h = max(containerSize.height, 1)
                                let newNormX = store.normalizedOffsetX + Double(value.translation.width / w)
                                let newNormY = store.normalizedOffsetY + Double(value.translation.height / h)
                                store.normalizedOffsetX = max(-0.45, min(0.65, newNormX))
                                store.normalizedOffsetY = max(-0.75, min(0.20, newNormY))
                                activeDragTranslation = .zero
                            },
                        MagnificationGesture()
                            .onChanged { scale in
                                activePinchScale = scale
                            }
                            .onEnded { scale in
                                let updated = store.watermarkScale * Double(scale)
                                store.watermarkScale = max(0.5, min(updated, 2.2))
                                activePinchScale = 1.0
                            }
                    )
                )

                Spacer(minLength: 8)

                // Cột nút tác vụ nhanh bên phải: Nút Sửa nhanh (square.and.pencil) & Nút Định vị tâm ngắm
                VStack(spacing: 18) {
                    Button(action: onTapEdit) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 23, weight: .medium))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.6), radius: 2, x: 0, y: 1)
                            .frame(width: 36, height: 36)
                    }

                    Button(action: onTapLocation) {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 22, height: 22)
                            Circle()
                                .fill(Color.white)
                                .frame(width: 6, height: 6)
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 2, height: 30)
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 30, height: 2)
                        }
                        .shadow(color: Color.black.opacity(0.6), radius: 2, x: 0, y: 1)
                        .frame(width: 36, height: 36)
                    }
                }
                .padding(.bottom, 2)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
    }

    @ViewBuilder
    private var logoView: some View {
        switch store.logoStyle {
        case .hoaPhat:
            if let uiImage = UIImage(named: "HoaPhatLogo") {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 22 * effectiveScale)
            } else {
                CustomTextBadgeLogoView(title: "HÒA PHÁT", subtitle: "GANG THÉP", scale: effectiveScale)
            }
        case .customText:
            CustomTextBadgeLogoView(
                title: store.customLogoTitle,
                subtitle: store.customLogoSubtitle,
                scale: effectiveScale
            )
        case .customImage:
            if let customImg = store.customLogoUIImage {
                Image(uiImage: customImg)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 26 * effectiveScale)
            } else {
                CustomTextBadgeLogoView(title: "LOGO", subtitle: "CHỌN ẢNH", scale: effectiveScale)
            }
        case .hidden:
            EmptyView()
        }
    }
}

struct CustomTextBadgeLogoView: View {
    let title: String
    let subtitle: String
    let scale: Double

    private let hpBlue = Color(red: 0.0, green: 0.32, blue: 0.62)

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrowtriangle.up.fill")
                .font(.system(size: 13 * scale, weight: .bold))
                .foregroundColor(hpBlue)
                .frame(width: 18 * scale, height: 18 * scale)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 10.5 * scale, weight: .heavy))
                    .foregroundColor(hpBlue)
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 6.5 * scale, weight: .bold))
                        .foregroundColor(hpBlue.opacity(0.9))
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.white.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: Color.black.opacity(0.35), radius: 1.5, x: 0, y: 1)
    }
}
