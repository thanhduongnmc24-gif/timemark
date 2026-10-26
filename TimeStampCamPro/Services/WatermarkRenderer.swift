import UIKit
import Photos

enum WatermarkRenderer {
    /// Ghép khung đóng dấu thời gian (Logo + Giờ lớn + Vạch dọc + Ngày/Thứ + Khung mờ ghi chú) trực tiếp lên ảnh gốc
    static func renderWatermarkedImage(baseImage: UIImage, store: WatermarkStore) -> UIImage {
        let normalized = baseImage.normalizedUpOrientation()
        let imgSize = normalized.size
        guard imgSize.width > 0 && imgSize.height > 0 else { return baseImage }

        // Tính chiều cao thanh xanh D -> ở dưới nếu người dùng bật tùy chọn xuất kèm thanh D ->
        let bannerHeight: CGFloat = store.includeBottomBannerInExport ? round(imgSize.width * 0.115) : 0
        let totalSize = CGSize(width: imgSize.width, height: imgSize.height + bannerHeight)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = normalized.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: totalSize, format: format)
        return renderer.image { ctx in
            let cgContext = ctx.cgContext

            // 1. Vẽ ảnh gốc
            normalized.draw(in: CGRect(origin: .zero, size: imgSize))

            // 2. Vẽ lớp phủ bóng mờ nhẹ ở đáy ảnh để chữ trắng luôn nổi bật rõ nét trên mọi nền sáng/tối
            let gradientHeight = imgSize.height * 0.34
            let gradientRect = CGRect(x: 0, y: imgSize.height - gradientHeight, width: imgSize.width, height: gradientHeight)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [
                UIColor.black.withAlphaComponent(0.0).cgColor,
                UIColor.black.withAlphaComponent(0.45).cgColor
            ] as CFArray
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
                cgContext.saveGState()
                cgContext.addRect(gradientRect)
                cgContext.clip()
                cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: gradientRect.minY),
                    end: CGPoint(x: 0, y: gradientRect.maxY),
                    options: []
                )
                cgContext.restoreGState()
            }

            // 3. Hệ số tỉ lệ theo chiều rộng ảnh (chuẩn hóa với màn hình 375pt)
            let userScale = CGFloat(max(0.75, min(store.watermarkScale, 1.35)))
            let unit = (imgSize.width / 375.0) * userScale
            let leftMargin = 16.0 * (imgSize.width / 375.0)
            let bottomMargin = 14.0 * (imgSize.width / 375.0)

            var currentBottomY = imgSize.height - bottomMargin

            // 4. Vẽ khung mờ (pill box) chứa ghi chú Tổ vận hành / Kíp / Địa điểm
            var noteLines: [String] = []
            if !store.noteLine1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                noteLines.append(store.noteLine1)
            }
            if !store.noteLine2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                noteLines.append(store.noteLine2)
            }
            if store.showLocationLine && !store.locationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                noteLines.append(store.locationText)
            }

            if !noteLines.isEmpty {
                let noteFont = UIFont.systemFont(ofSize: 13.5 * unit, weight: .regular)
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineSpacing = 3.0 * unit

                let fullNoteText = noteLines.joined(separator: "\n")
                let noteAttributes: [NSAttributedString.Key: Any] = [
                    .font: noteFont,
                    .foregroundColor: UIColor.white.withAlphaComponent(0.95),
                    .paragraphStyle: paragraphStyle
                ]

                let maxNoteWidth = imgSize.width * 0.78
                let boundingRect = (fullNoteText as NSString).boundingRect(
                    with: CGSize(width: maxNoteWidth, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: noteAttributes,
                    context: nil
                )

                let padH = 11.0 * unit
                let padV = 7.5 * unit
                let boxWidth = min(maxNoteWidth + padH * 2, max(boundingRect.width + padH * 2.4, 165.0 * unit))
                let boxHeight = ceil(boundingRect.height) + padV * 2
                let boxRect = CGRect(
                    x: leftMargin,
                    y: currentBottomY - boxHeight,
                    width: boxWidth,
                    height: boxHeight
                )

                // Vẽ nền xám mờ chuyển sắc nhẹ giống hệt ảnh chụp màn hình
                let pillPath = UIBezierPath(roundedRect: boxRect, cornerRadius: 5.5 * unit)
                cgContext.saveGState()
                cgContext.addPath(pillPath.cgPath)
                cgContext.clip()
                let boxColors = [
                    UIColor(white: 0.42, alpha: 0.72).cgColor,
                    UIColor(white: 0.22, alpha: 0.42).cgColor
                ] as CFArray
                if let boxGrad = CGGradient(colorsSpace: colorSpace, colors: boxColors, locations: [0.0, 1.0]) {
                    cgContext.drawLinearGradient(
                        boxGrad,
                        start: CGPoint(x: boxRect.minX, y: boxRect.midY),
                        end: CGPoint(x: boxRect.maxX, y: boxRect.midY),
                        options: []
                    )
                } else {
                    UIColor(white: 0.3, alpha: 0.65).setFill()
                    pillPath.fill()
                }
                cgContext.restoreGState()

                // Vẽ chữ trong khung mờ
                let textDrawRect = CGRect(
                    x: boxRect.minX + padH,
                    y: boxRect.minY + padV,
                    width: boxRect.width - padH * 2,
                    height: boxRect.height - padV * 2
                )
                (fullNoteText as NSString).draw(in: textDrawRect, withAttributes: noteAttributes)

                currentBottomY = boxRect.minY - (8.0 * unit)
            }

            // 5. Vẽ khối Giờ lớn (21:55) + Vạch dọc cam + Ngày (26/10/2026) & Thứ (Thứ Hai)
            let timeFont = Self.condensedTimeFont(size: 46.0 * unit)
            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.55)
            shadow.shadowOffset = CGSize(width: 0, height: 1.2 * unit)
            shadow.shadowBlurRadius = 2.5 * unit

            let timeAttributes: [NSAttributedString.Key: Any] = [
                .font: timeFont,
                .foregroundColor: UIColor.white,
                .shadow: shadow
            ]
            let timeString = store.timeText as NSString
            let timeSize = timeString.size(withAttributes: timeAttributes)

            let rowHeight = max(timeSize.height, 44.0 * unit)
            let rowTopY = currentBottomY - rowHeight

            // Vẽ chuỗi giờ 21:55
            let timeRect = CGRect(
                x: leftMargin,
                y: rowTopY + (rowHeight - timeSize.height) * 0.5,
                width: ceil(timeSize.width) + 4.0 * unit,
                height: ceil(timeSize.height)
            )
            timeString.draw(in: timeRect, withAttributes: timeAttributes)

            // Vẽ vạch dọc màu cam (hoặc màu người dùng chọn)
            let dividerX = timeRect.maxX + (8.0 * unit)
            let dividerHeight = rowHeight * 0.76
            let dividerY = rowTopY + (rowHeight - dividerHeight) * 0.5
            let dividerRect = CGRect(
                x: dividerX,
                y: dividerY,
                width: max(2.2 * unit, 2.0),
                height: dividerHeight
            )
            let dividerPath = UIBezierPath(roundedRect: dividerRect, cornerRadius: 1.2 * unit)
            store.barColor.uiColor.setFill()
            dividerPath.fill()

            // Vẽ Ngày (trên) và Thứ (dưới) bên phải vạch cam
            let dateX = dividerRect.maxX + (9.0 * unit)
            let dateFont = UIFont.systemFont(ofSize: 13.5 * unit, weight: .medium)
            let weekdayFont = UIFont.systemFont(ofSize: 13.5 * unit, weight: .regular)

            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: dateFont,
                .foregroundColor: UIColor.white.withAlphaComponent(0.96),
                .shadow: shadow
            ]
            let weekdayAttributes: [NSAttributedString.Key: Any] = [
                .font: weekdayFont,
                .foregroundColor: UIColor.white.withAlphaComponent(0.94),
                .shadow: shadow
            ]

            let dateStr = store.dateText as NSString
            let weekdayStr = store.weekdayText as NSString
            let dateSize = dateStr.size(withAttributes: dateAttributes)
            let weekdaySize = weekdayStr.size(withAttributes: weekdayAttributes)

            let topDateY = dividerY - (1.0 * unit)
            let bottomWeekdayY = dividerY + dividerHeight - weekdaySize.height + (1.0 * unit)

            dateStr.draw(at: CGPoint(x: dateX, y: topDateY), withAttributes: dateAttributes)
            weekdayStr.draw(at: CGPoint(x: dateX, y: bottomWeekdayY), withAttributes: weekdayAttributes)

            currentBottomY = rowTopY - (5.0 * unit)

            // 6. Vẽ Logo phía trên số giờ (Logo Hòa Phát Gang Thép / Logo chữ tùy chỉnh / Ảnh logo từ máy)
            switch store.logoStyle {
            case .hoaPhat:
                if let hpImage = UIImage(named: "HoaPhatLogo") {
                    let targetH = 26.0 * unit
                    let aspect = hpImage.size.width / max(hpImage.size.height, 1.0)
                    let targetW = targetH * aspect
                    let logoRect = CGRect(
                        x: leftMargin,
                        y: currentBottomY - targetH,
                        width: targetW,
                        height: targetH
                    )
                    hpImage.draw(in: logoRect)
                } else {
                    Self.drawCustomBadgeLogo(
                        in: cgContext,
                        title: "HOA PHAT",
                        subtitle: "GANG THÉP",
                        leftX: leftMargin,
                        bottomY: currentBottomY,
                        unit: unit
                    )
                }

            case .customText:
                Self.drawCustomBadgeLogo(
                    in: cgContext,
                    title: store.customLogoTitle,
                    subtitle: store.customLogoSubtitle,
                    leftX: leftMargin,
                    bottomY: currentBottomY,
                    unit: unit
                )

            case .customImage:
                if let customImg = store.customLogoUIImage {
                    let targetH = 30.0 * unit
                    let aspect = customImg.size.width / max(customImg.size.height, 1.0)
                    let targetW = min(targetH * aspect, imgSize.width * 0.55)
                    let logoRect = CGRect(
                        x: leftMargin,
                        y: currentBottomY - targetH,
                        width: targetW,
                        height: targetH
                    )
                    customImg.draw(in: logoRect)
                }

            case .hidden:
                break
            }

            // 7. Tùy chọn: Vẽ thanh xanh dương nhạt "D ->" ở dưới đáy ảnh nếu người dùng bật
            if store.includeBottomBannerInExport && bannerHeight > 0 {
                let bannerRect = CGRect(x: 0, y: imgSize.height, width: imgSize.width, height: bannerHeight)
                UIColor(red: 0.85, green: 0.93, blue: 0.99, alpha: 1.0).setFill()
                UIRectFill(bannerRect)

                let dirFont = UIFont.systemFont(ofSize: 16.0 * (imgSize.width / 375.0), weight: .bold)
                let dirColor = UIColor(red: 0.14, green: 0.28, blue: 0.45, alpha: 1.0)
                let dirText = "\(store.directionBannerCode)  →" as NSString
                let dirSize = dirText.size(withAttributes: [.font: dirFont])
                let dirPoint = CGPoint(
                    x: (imgSize.width - dirSize.width) * 0.5,
                    y: imgSize.height + (bannerHeight - dirSize.height) * 0.5
                )
                dirText.draw(at: dirPoint, withAttributes: [
                    .font: dirFont,
                    .foregroundColor: dirColor
                ])
            }
        }
    }

    private static func condensedTimeFont(size: CGFloat) -> UIFont {
        let candidates = [
            "DINCondensed-Bold",
            "AvenirNextCondensed-DemiBold",
            "AvenirNextCondensed-Bold",
            "HelveticaNeue-CondensedBold"
        ]
        for name in candidates {
            if let font = UIFont(name: name, size: size) {
                return font
            }
        }
        return UIFont.monospacedDigitSystemFont(ofSize: size * 0.85, weight: .bold)
    }

    private static func drawCustomBadgeLogo(
        in cgContext: CGContext,
        title: String,
        subtitle: String,
        leftX: CGFloat,
        bottomY: CGFloat,
        unit: CGFloat
    ) {
        let titleFont = UIFont.systemFont(ofSize: 12.0 * unit, weight: .heavy)
        let subFont = UIFont.systemFont(ofSize: 7.0 * unit, weight: .bold)
        let hpBlue = UIColor(red: 0.0, green: 0.40, blue: 0.70, alpha: 1.0)

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: hpBlue
        ]
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: subFont,
            .foregroundColor: hpBlue
        ]

        let tSize = (title as NSString).size(withAttributes: titleAttrs)
        let sSize = (subtitle as NSString).size(withAttributes: subAttrs)
        let badgeH = 24.0 * unit
        let iconW = 24.0 * unit
        let badgeW = iconW + max(tSize.width, sSize.width) + 14.0 * unit
        let badgeRect = CGRect(x: leftX, y: bottomY - badgeH, width: badgeW, height: badgeH)

        let pill = UIBezierPath(roundedRect: badgeRect, cornerRadius: 6.0 * unit)
        UIColor.white.withAlphaComponent(0.95).setFill()
        pill.fill()

        // Vẽ biểu tượng tam giác xanh bên trái
        let triPath = UIBezierPath()
        triPath.move(to: CGPoint(x: badgeRect.minX + 12.0 * unit, y: badgeRect.minY + 4.0 * unit))
        triPath.addLine(to: CGPoint(x: badgeRect.minX + 21.0 * unit, y: badgeRect.maxY - 4.0 * unit))
        triPath.addLine(to: CGPoint(x: badgeRect.minX + 3.0 * unit, y: badgeRect.maxY - 4.0 * unit))
        triPath.close()
        hpBlue.setFill()
        triPath.fill()

        let textX = badgeRect.minX + iconW + 2.0 * unit
        (title as NSString).draw(at: CGPoint(x: textX, y: badgeRect.minY + 1.5 * unit), withAttributes: titleAttrs)
        if !subtitle.isEmpty {
            (subtitle as NSString).draw(at: CGPoint(x: textX, y: badgeRect.minY + 13.5 * unit), withAttributes: subAttrs)
        }
    }

    /// Lưu ảnh đã đóng dấu vào Thư viện Ảnh (Photos) của iPhone
    static func saveToPhotoLibrary(_ image: UIImage, completion: @escaping (Bool, String) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    completion(false, "Chưa cấp quyền lưu vào Thư viện Ảnh. Hãy kiểm tra trong Cài đặt > Quyền riêng tư.")
                }
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        completion(true, "Đã lưu ảnh đóng dấu thời gian vào Thư viện Ảnh!")
                    } else {
                        completion(false, error?.localizedDescription ?? "Không thể lưu ảnh.")
                    }
                }
            }
        }
    }
}
