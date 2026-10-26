import UIKit
import AVFoundation
import Photos

enum WatermarkRenderer {
    /// Tạo ảnh trong suốt chỉ chứa riêng khối biểu mẫu (Logo + Giờ/Ngày/Thứ + Khung mờ ghi chú)
    /// Dùng chung cho cả việc đóng dấu lên Ảnh (`UIImage`) và gắn lớp phủ lên Video (`CALayer`)
    static func renderWatermarkStampImage(canvasSize: CGSize, store: WatermarkStore) -> UIImage {
        guard canvasSize.width > 0 && canvasSize.height > 0 else { return UIImage() }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { ctx in
            let cgContext = ctx.cgContext
            let colorSpace = CGColorSpaceCreateDeviceRGB()

            // Hệ số phóng to/thu nhỏ do người dùng chụm 2 ngón tay (0.5x ... 2.2x)
            let userScale = CGFloat(max(0.5, min(store.watermarkScale, 2.2)))
            let unit = (canvasSize.width / 375.0) * userScale

            // Tính vị trí gốc trái-dưới cộng thêm độ lệch kéo thả (normalizedOffsetX, normalizedOffsetY)
            let baseLeftX = 16.0 * (canvasSize.width / 375.0)
            let baseBottomY = canvasSize.height - (16.0 * (canvasSize.width / 375.0))

            let deltaX = CGFloat(store.normalizedOffsetX) * canvasSize.width
            let deltaY = CGFloat(store.normalizedOffsetY) * canvasSize.height

            let leftMargin = max(8.0, min(canvasSize.width * 0.82, baseLeftX + deltaX))
            var currentBottomY = max(canvasSize.height * 0.12, min(canvasSize.height - 8.0, baseBottomY + deltaY))

            // 1. Vẽ khung mờ chứa các dòng ghi chú đang bật (Tổ vận hành - Kíp A X.CT1, Tọa độ, Độ cao...)
            let noteLines = store.activeNoteLines
            if !noteLines.isEmpty {
                let noteFont = UIFont.systemFont(ofSize: 13.5 * unit, weight: .regular)
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineSpacing = 3.5 * unit

                let fullNoteText = noteLines.joined(separator: "\n")
                let noteAttributes: [NSAttributedString.Key: Any] = [
                    .font: noteFont,
                    .foregroundColor: UIColor.white.withAlphaComponent(0.96),
                    .paragraphStyle: paragraphStyle
                ]

                let maxNoteWidth = max(140.0 * unit, canvasSize.width - leftMargin - 16.0)
                let boundingRect = (fullNoteText as NSString).boundingRect(
                    with: CGSize(width: maxNoteWidth, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: noteAttributes,
                    context: nil
                )

                let padH = 11.0 * unit
                let padV = 7.5 * unit
                let boxWidth = min(maxNoteWidth, max(boundingRect.width + padH * 2.3, 165.0 * unit))
                let boxHeight = ceil(boundingRect.height) + padV * 2
                let boxRect = CGRect(
                    x: leftMargin,
                    y: currentBottomY - boxHeight,
                    width: boxWidth,
                    height: boxHeight
                )

                let pillPath = UIBezierPath(roundedRect: boxRect, cornerRadius: 5.5 * unit)
                cgContext.saveGState()
                cgContext.addPath(pillPath.cgPath)
                cgContext.clip()
                let boxColors = [
                    UIColor(white: 0.40, alpha: 0.76).cgColor,
                    UIColor(white: 0.20, alpha: 0.46).cgColor
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

                let textDrawRect = CGRect(
                    x: boxRect.minX + padH,
                    y: boxRect.minY + padV,
                    width: boxRect.width - padH * 2,
                    height: boxRect.height - padV * 2
                )
                (fullNoteText as NSString).draw(in: textDrawRect, withAttributes: noteAttributes)

                currentBottomY = boxRect.minY - (8.0 * unit)
            }

            // 2. Vẽ khối Giờ lớn (22:26) + Vạch dọc cam + Ngày (26/10/2026) & Thứ (Thứ Hai)
            if store.showTimeBlock {
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

                let timeRect = CGRect(
                    x: leftMargin,
                    y: rowTopY + (rowHeight - timeSize.height) * 0.5,
                    width: ceil(timeSize.width) + 4.0 * unit,
                    height: ceil(timeSize.height)
                )
                timeString.draw(in: timeRect, withAttributes: timeAttributes)

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
                let weekdaySize = weekdayStr.size(withAttributes: weekdayAttributes)

                let topDateY = dividerY - (1.0 * unit)
                let bottomWeekdayY = dividerY + dividerHeight - weekdaySize.height + (1.0 * unit)

                dateStr.draw(at: CGPoint(x: dateX, y: topDateY), withAttributes: dateAttributes)
                weekdayStr.draw(at: CGPoint(x: dateX, y: bottomWeekdayY), withAttributes: weekdayAttributes)

                currentBottomY = rowTopY - (6.0 * unit)
            }

            // 3. Vẽ Logo phía trên số giờ (Logo Hòa Phát Gang Thép đã xóa nền có viền trắng)
            if store.showLogo {
                switch store.logoStyle {
                case .hoaPhat:
                    if let hpImage = UIImage(named: "HoaPhatLogo") {
                        let targetH = 22.0 * unit
                        let aspect = hpImage.size.width / max(hpImage.size.height, 1.0)
                        let targetW = targetH * aspect
                        let logoRect = CGRect(
                            x: leftMargin,
                            y: currentBottomY - targetH,
                            width: targetW,
                            height: targetH
                        )
                        hpImage.draw(in: logoRect)
                    }

                case .customText:
                    Self.drawCustomBadgeLogo(
                        title: store.customLogoTitle,
                        subtitle: store.customLogoSubtitle,
                        leftX: leftMargin,
                        bottomY: currentBottomY,
                        unit: unit
                    )

                case .customImage:
                    if let customImg = store.customLogoUIImage {
                        let targetH = 26.0 * unit
                        let aspect = customImg.size.width / max(customImg.size.height, 1.0)
                        let targetW = min(targetH * aspect, canvasSize.width * 0.55)
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
            }
        }
    }

    /// Ghép biểu mẫu vào Ảnh gốc (`UIImage`)
    static func renderWatermarkedImage(baseImage: UIImage, store: WatermarkStore) -> UIImage {
        let normalized = baseImage.normalizedUpOrientation()
        let imgSize = normalized.size
        guard imgSize.width > 0 && imgSize.height > 0 else { return baseImage }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = normalized.scale
        format.opaque = true

        let stampOverlay = renderWatermarkStampImage(canvasSize: imgSize, store: store)

        let renderer = UIGraphicsImageRenderer(size: imgSize, format: format)
        return renderer.image { _ in
            normalized.draw(in: CGRect(origin: .zero, size: imgSize))
            stampOverlay.draw(in: CGRect(origin: .zero, size: imgSize))
        }
    }

    /// Ghép biểu mẫu thời gian vào Video vừa quay (`URL`) và xuất ra file `.mp4`
    static func exportWatermarkedVideo(sourceURL: URL, store: WatermarkStore, completion: @escaping (URL?, String?) -> Void) {
        let asset = AVURLAsset(url: sourceURL)
        let composition = AVMutableComposition()

        guard let videoTrack = asset.tracks(withMediaType: .video).first,
              let compVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            DispatchQueue.main.async {
                completion(nil, "Không đọc được luồng video.")
            }
            return
        }

        let timeRange = CMTimeRange(start: .zero, duration: asset.duration)
        do {
            try compVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
            if let audioTrack = asset.tracks(withMediaType: .audio).first,
               let compAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                try? compAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
            }
        } catch {
            DispatchQueue.main.async {
                completion(nil, "Lỗi ghép luồng video: \(error.localizedDescription)")
            }
            return
        }

        // Xác định kích thước hiển thị chuẩn của video sau khi áp dụng preferredTransform (dọc/ngang)
        let transform = videoTrack.preferredTransform
        let transformedSize = videoTrack.naturalSize.applying(transform)
        let renderSize = CGSize(width: abs(transformedSize.width), height: abs(transformedSize.height))

        let stampImage = renderWatermarkStampImage(canvasSize: renderSize, store: store)

        let parentLayer = CALayer()
        let videoLayer = CALayer()
        let overlayLayer = CALayer()

        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        videoLayer.frame = CGRect(origin: .zero, size: renderSize)
        overlayLayer.frame = CGRect(origin: .zero, size: renderSize)
        overlayLayer.contents = stampImage.cgImage
        overlayLayer.contentsGravity = .resizeAspectFill
        // Trong hệ tọa độ CoreAnimation cho AVVideoComposition, lật trục Y để ảnh không bị ngược
        overlayLayer.isGeometryFlipped = true

        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(overlayLayer)

        let videoComp = AVMutableVideoComposition()
        videoComp.renderSize = renderSize
        videoComp.frameDuration = CMTime(value: 1, timescale: 30)
        videoComp.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = timeRange
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compVideoTrack)
        layerInstruction.setTransform(Self.fixedTransform(for: videoTrack, renderSize: renderSize), at: .zero)
        instruction.layerInstructions = [layerInstruction]
        videoComp.instructions = [instruction]

        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("timemark_video_\(Int(Date().timeIntervalSince1970)).mp4")
        try? FileManager.default.removeItem(at: outURL)

        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            DispatchQueue.main.async {
                completion(nil, "Không khởi tạo được bộ xuất video.")
            }
            return
        }

        exporter.outputURL = outURL
        exporter.outputFileType = .mp4
        exporter.videoComposition = videoComp
        exporter.shouldOptimizeForNetworkUse = true

        exporter.exportAsynchronously {
            DispatchQueue.main.async {
                if exporter.status == .completed {
                    completion(outURL, nil)
                } else {
                    completion(sourceURL, exporter.error?.localizedDescription)
                }
            }
        }
    }

    private static func fixedTransform(for track: AVAssetTrack, renderSize: CGSize) -> CGAffineTransform {
        let t = track.preferredTransform
        let natural = track.naturalSize
        if t.a == 0 && t.b == 1.0 && t.c == -1.0 && t.d == 0 {
            return CGAffineTransform(translationX: natural.height, y: 0).rotated(by: .pi / 2)
        } else if t.a == 0 && t.b == -1.0 && t.c == 1.0 && t.d == 0 {
            return CGAffineTransform(translationX: 0, y: natural.width).rotated(by: -.pi / 2)
        } else if t.a == -1.0 && t.b == 0 && t.c == 0 && t.d == -1.0 {
            return CGAffineTransform(translationX: natural.width, y: natural.height).rotated(by: .pi)
        }
        return t
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
        title: String,
        subtitle: String,
        leftX: CGFloat,
        bottomY: CGFloat,
        unit: CGFloat
    ) {
        let titleFont = UIFont.systemFont(ofSize: 12.0 * unit, weight: .heavy)
        let subFont = UIFont.systemFont(ofSize: 7.0 * unit, weight: .bold)
        let hpBlue = UIColor(red: 0.0, green: 0.32, blue: 0.62, alpha: 1.0)

        let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: hpBlue]
        let subAttrs: [NSAttributedString.Key: Any] = [.font: subFont, .foregroundColor: hpBlue]

        let tSize = (title as NSString).size(withAttributes: titleAttrs)
        let sSize = (subtitle as NSString).size(withAttributes: subAttrs)
        let badgeH = 24.0 * unit
        let iconW = 24.0 * unit
        let badgeW = iconW + max(tSize.width, sSize.width) + 14.0 * unit
        let badgeRect = CGRect(x: leftX, y: bottomY - badgeH, width: badgeW, height: badgeH)

        let pill = UIBezierPath(roundedRect: badgeRect, cornerRadius: 6.0 * unit)
        UIColor.white.withAlphaComponent(0.95).setFill()
        pill.fill()

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

    /// Lưu Ảnh vào Thư viện Ảnh
    static func saveToPhotoLibrary(_ image: UIImage, completion: @escaping (Bool, String) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    completion(false, "Chưa cấp quyền lưu vào Thư viện Ảnh.")
                }
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        completion(true, "Đã lưu ảnh đóng dấu thời gian vào Thư viện!")
                    } else {
                        completion(false, error?.localizedDescription ?? "Không thể lưu ảnh.")
                    }
                }
            }
        }
    }

    /// Lưu Video vào Thư viện Ảnh
    static func saveVideoToPhotoLibrary(_ videoURL: URL, completion: @escaping (Bool, String) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    completion(false, "Chưa cấp quyền lưu video vào Thư viện Ảnh.")
                }
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        completion(true, "Đã lưu video đóng dấu thời gian vào Thư viện!")
                    } else {
                        completion(false, error?.localizedDescription ?? "Không thể lưu video.")
                    }
                }
            }
        }
    }
}
