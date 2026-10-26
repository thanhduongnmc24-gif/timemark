import SwiftUI

/// Khung hiển thị Watermark trực tiếp trên màn hình giống hệt ảnh mẫu Hòa Phát Gang Thép
struct WatermarkOverlayView: View {
    @EnvironmentObject var store: WatermarkStore
    let onTapEdit: () -> Void
    let onTapLocation: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Khối bên trái: Logo + Giờ/Ngày/Thứ + Khung mờ ghi chú Tổ vận hành
            VStack(alignment: .leading, spacing: 5) {
                // 1. Logo (Hòa Phát Gang Thép / Tùy chỉnh)
                logoView

                // 2. Hàng Giờ lớn (21:55) + Vạch cam + Ngày (26/10/2026) & Thứ (Thứ Hai)
                HStack(alignment: .center, spacing: 9) {
                    Text(store.timeText)
                        .font(.custom("DINCondensed-Bold", size: 46 * store.watermarkScale))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.55), radius: 2, x: 0, y: 1)
                        .fixedSize()

                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(store.barColor.swiftUIColor)
                        .frame(width: 2.5, height: 34 * store.watermarkScale)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.dateText)
                            .font(.system(size: 13.5 * store.watermarkScale, weight: .medium))
                            .foregroundColor(.white.opacity(0.96))
                            .shadow(color: Color.black.opacity(0.5), radius: 1.5, x: 0, y: 1)

                        Text(store.weekdayText)
                            .font(.system(size: 13.5 * store.watermarkScale, weight: .regular))
                            .foregroundColor(.white.opacity(0.94))
                            .shadow(color: Color.black.opacity(0.5), radius: 1.5, x: 0, y: 1)
                    }
                }

                // 3. Khung mờ chứa dòng ghi chú Tổ vận hành / Kíp / Địa điểm
                if hasNoteContent {
                    VStack(alignment: .leading, spacing: 3) {
                        if !store.noteLine1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(store.noteLine1)
                                .font(.system(size: 13.5 * store.watermarkScale, weight: .regular))
                                .foregroundColor(.white.opacity(0.95))
                        }
                        if !store.noteLine2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(store.noteLine2)
                                .font(.system(size: 12.5 * store.watermarkScale, weight: .regular))
                                .foregroundColor(.white.opacity(0.90))
                        }
                        if store.showLocationLine && !store.locationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 10 * store.watermarkScale))
                                Text(store.locationText)
                                    .font(.system(size: 12 * store.watermarkScale, weight: .regular))
                            }
                            .foregroundColor(.white.opacity(0.90))
                        }
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7.5)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(white: 0.42).opacity(0.75),
                                Color(white: 0.22).opacity(0.45)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onTapEdit()
            }

            Spacer(minLength: 8)

            // Cột nút bên phải: Nút Sửa nhanh (square.and.pencil) & Nút Định vị tâm ngắm (scope)
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
        .padding(.bottom, 12)
    }

    private var hasNoteContent: Bool {
        !store.noteLine1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !store.noteLine2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        (store.showLocationLine && !store.locationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @ViewBuilder
    private var logoView: some View {
        switch store.logoStyle {
        case .hoaPhat:
            if let uiImage = UIImage(named: "HoaPhatLogo") {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 25 * store.watermarkScale)
            } else {
                CustomTextBadgeLogoView(title: "HOA PHAT", subtitle: "GANG THÉP", scale: store.watermarkScale)
            }
        case .customText:
            CustomTextBadgeLogoView(
                title: store.customLogoTitle,
                subtitle: store.customLogoSubtitle,
                scale: store.watermarkScale
            )
        case .customImage:
            if let customImg = store.customLogoUIImage {
                Image(uiImage: customImg)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 28 * store.watermarkScale)
            } else {
                CustomTextBadgeLogoView(title: "LOGO", subtitle: "CHỌN ẢNH", scale: store.watermarkScale)
            }
        case .hidden:
            EmptyView()
        }
    }
}

/// Logo dạng huy hiệu viền trắng + chữ xanh giống logo Hòa Phát khi người dùng đổi tên công ty
struct CustomTextBadgeLogoView: View {
    let title: String
    let subtitle: String
    let scale: Double

    private let hpBlue = Color(red: 0.0, green: 0.40, blue: 0.70)

    var body: some View {
        HStack(spacing: 4) {
            // Biểu tượng tam giác 3 mũi tên xanh Hòa Phát
            ZStack {
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: 13 * scale, weight: .bold))
                    .foregroundColor(hpBlue)
            }
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
