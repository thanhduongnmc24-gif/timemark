import UIKit
import AVFoundation
import Photos

enum WatermarkRenderer {
    /// Vẽ trực tiếp khối biểu mẫu (Logo + Giờ/Ngày/Thứ + Khung mờ ghi chú) lên `CGContext` hiện tại (Single-Pass, không cấp phát thêm ảnh trung gian)
    static func drawWatermarkDirect(in cgContext: CGContext, canvasSize: CGSize, snapshot: WatermarkRenderSnapshot) {
        guard canvasSize.width > 0 && canvasSize.height > 0 else { return }

        let colorSpace = CGColorSpaceCreateDeviceRGB()

        // Hệ số phóng to/thu nhỏ do người dùng chụm 2 ngón tay (0.5x ... 2.2x)
        let userScale = CGFloat(max(0.5, min(snapshot.watermarkScale, 2.2)))
        let unit = (canvasSize.width / 375.0) * userScale

        // Tính vị trí gốc trái-dưới cộng thêm độ lệch kéo thả (normalizedOffsetX, normalizedOffsetY)
        let baseLeftX = 16.0 * (canvasSize.width / 375.0)
        let baseBottomY = canvasSize.height - (16.0 * (canvasSize.width / 375.0))

        let deltaX = CGFloat(snapshot.normalizedOffsetX) * canvasSize.width
        let deltaY = CGFloat(snapshot.normalizedOffsetY) * canvasSize.height

        let leftMargin = max(8.0, min(canvasSize.width * 0.82, baseLeftX + deltaX))
        var currentBottomY = max(canvasSize.height * 0.12, min(canvasSize.height - 8.0, baseBottomY + deltaY))

        // 1. Vẽ khung mờ chứa các dòng ghi chú đang bật (Tổ vận hành - Kíp A X.CT1, Tọa độ, Độ cao...)
        let noteLines = snapshot.activeNoteLines
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
        if snapshot.showTimeBlock {
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
            let timeString = snapshot.timeText as NSString
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
            snapshot.barColor.uiColor.setFill()
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

            let dateStr = snapshot.dateText as NSString
            let weekdayStr = snapshot.weekdayText as NSString
            let weekdaySize = weekdayStr.size(withAttributes: weekdayAttributes)

            let topDateY = dividerY - (1.0 * unit)
            let bottomWeekdayY = dividerY + dividerHeight - weekdaySize.height + (1.0 * unit)

            dateStr.draw(at: CGPoint(x: dateX, y: topDateY), withAttributes: dateAttributes)
            weekdayStr.draw(at: CGPoint(x: dateX, y: bottomWeekdayY), withAttributes: weekdayAttributes)

            currentBottomY = rowTopY - (6.0 * unit)
        }

        // 3. Vẽ Logo phía trên số giờ
        if snapshot.showLogo {
            switch snapshot.logoStyle {
            case .hoaPhat:
                if let hpImage = WatermarkStore.hoaPhatAssetLogo ?? UIImage(named: "HoaPhatLogo") {
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
                    title: snapshot.customLogoTitle,
                    subtitle: snapshot.customLogoSubtitle,
                    leftX: leftMargin,
                    bottomY: currentBottomY,
                    unit: unit
                )

            case .customImage:
                if let customImg = snapshot.customLogoUIImage {
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

    /// Tạo ảnh trong suốt chỉ chứa riêng khối biểu mẫu (dùng cho ghép lớp phủ Video)
    static func renderWatermarkStampImage(canvasSize: CGSize, snapshot: WatermarkRenderSnapshot) -> UIImage {
        guard canvasSize.width > 0 && canvasSize.height > 0 else { return UIImage() }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { ctx in
            drawWatermarkDirect(in: ctx.cgContext, canvasSize: canvasSize, snapshot: snapshot)
        }
    }

    /// Cắt ảnh theo đúng tỉ lệ khung hình đã chọn (`3:4`, `9:16`, `Full`, `1:1`) và đóng dấu biểu mẫu trong 1 lượt vẽ duy nhất (Single-Pass, siêu nhanh)
    static func renderWatermarkedImage(
        baseImage: UIImage,
        snapshot: WatermarkRenderSnapshot,
        viewportSize: CGSize = .zero
    ) -> UIImage {
        let srcSize = baseImage.size
        guard srcSize.width > 0 && srcSize.height > 0 else { return baseImage }

        // Tính tỉ lệ khung hình đích (width / height)
        let targetAspect = max(0.2, min(snapshot.aspectRatio.numericAspect(fallbackContainerSize: viewportSize), 5.0))
        let srcAspect = srcSize.width / srcSize.height

        // Xác định vùng crop trung tâm trên ảnh gốc
        let cropWidth: CGFloat
        let cropHeight: CGFloat
        if srcAspect > targetAspect {
            cropHeight = srcSize.height
            cropWidth = srcSize.height * targetAspect
        } else {
            cropWidth = srcSize.width
            cropHeight = srcSize.width / targetAspect
        }

        // Giới hạn cạnh dài tối đa ở mức 1920px (Full HD+ sắc nét, tốc độ xử lý <30ms, không gây đơ máy)
        let maxDimension: CGFloat = 1920.0
        let scaleDown = min(1.0, maxDimension / max(cropWidth, cropHeight))
        let outWidth = max(2.0, round(cropWidth * scaleDown))
        let outHeight = max(2.0, round(cropHeight * scaleDown))
        let outSize = CGSize(width: outWidth, height: outHeight)

        // Tính tọa độ vẽ ảnh gốc sao cho phần trung tâm khớp hoàn toàn với khung outSize
        let drawScale = max(outWidth / srcSize.width, outHeight / srcSize.height)
        let drawWidth = srcSize.width * drawScale
        let drawHeight = srcSize.height * drawScale
        let drawX = (outWidth - drawWidth) * 0.5
        let drawY = (outHeight - drawHeight) * 0.5

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: outSize, format: format)
        return renderer.image { ctx in
            // 1. Vẽ ảnh gốc (tự động chuẩn hóa hướng ảnh và cắt theo tỉ lệ trong 1 bước)
            baseImage.draw(in: CGRect(x: drawX, y: drawY, width: drawWidth, height: drawHeight))
            // 2. Vẽ trực tiếp biểu mẫu lên cùng Context
            drawWatermarkDirect(in: ctx.cgContext, canvasSize: outSize, snapshot: snapshot)
        }
    }

    /// Ghép biểu mẫu thời gian vào Video vừa quay (`URL`) và xuất ra file `.mp4`
    static func exportWatermarkedVideo(sourceURL: URL, snapshot: WatermarkRenderSnapshot, completion: @escaping (URL?, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
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

            let transform = videoTrack.preferredTransform
            let transformedSize = videoTrack.naturalSize.applying(transform)
            let renderSize = CGSize(width: abs(transformedSize.width), height: abs(transformedSize.height))

            let stampImage = renderWatermarkStampImage(canvasSize: renderSize, snapshot: snapshot)

            let parentLayer = CALayer()
            let videoLayer = CALayer()
            let overlayLayer = CALayer()

            parentLayer.frame = CGRect(origin: .zero, size: renderSize)
            videoLayer.frame = CGRect(origin: .zero, size: renderSize)
            overlayLayer.frame = CGRect(origin: .zero, size: renderSize)
            overlayLayer.contents = stampImage.cgImage
            overlayLayer.contentsGravity = .resizeAspectFill
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

    /// Lưu Ảnh vào Thư viện Ảnh (chạy ngầm hoàn toàn)
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
                        completion(true, "Đã lưu ảnh vào Thư viện!")
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
                        completion(true, "Đã lưu video vào Thư viện!")
                    } else {
                        completion(false, error?.localizedDescription ?? "Không thể lưu video.")
                    }
                }
            }
        }
    }
}
