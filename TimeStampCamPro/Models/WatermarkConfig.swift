import Foundation
import SwiftUI
import UIKit

enum LogoStyle: String, Codable, CaseIterable, Identifiable {
    case hoaPhat = "Logo Hòa Phát Gang Thép"
    case customText = "Logo chữ tùy chỉnh"
    case customImage = "Ảnh logo từ máy (tự xóa nền trắng)"
    case hidden = "Ẩn logo"

    var id: String { rawValue }
}

enum AccentBarColorOption: String, Codable, CaseIterable, Identifiable {
    case orange = "Cam (Chuẩn Timemark)"
    case blue = "Xanh Hòa Phát"
    case yellow = "Vàng công trường"
    case green = "Xanh lá an toàn"
    case red = "Đỏ nổi bật"
    case white = "Trắng tinh"

    var id: String { rawValue }

    var swiftUIColor: Color {
        switch self {
        case .orange: return Color(red: 1.0, green: 0.48, blue: 0.0)
        case .blue: return Color(red: 0.0, green: 0.48, blue: 0.85)
        case .yellow: return Color(red: 1.0, green: 0.78, blue: 0.05)
        case .green: return Color(red: 0.15, green: 0.78, blue: 0.35)
        case .red: return Color(red: 0.95, green: 0.22, blue: 0.22)
        case .white: return Color.white
        }
    }

    var uiColor: UIColor {
        switch self {
        case .orange: return UIColor(red: 1.0, green: 0.48, blue: 0.0, alpha: 1.0)
        case .blue: return UIColor(red: 0.0, green: 0.48, blue: 0.85, alpha: 1.0)
        case .yellow: return UIColor(red: 1.0, green: 0.78, blue: 0.05, alpha: 1.0)
        case .green: return UIColor(red: 0.15, green: 0.78, blue: 0.35, alpha: 1.0)
        case .red: return UIColor(red: 0.95, green: 0.22, blue: 0.22, alpha: 1.0)
        case .white: return UIColor.white
        }
    }
}

struct CustomTextItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var isEnabled: Bool
}

class WatermarkStore: ObservableObject {
    // 1. Chế độ thời gian
    @Published var useRealTime: Bool = false { didSet { saveSettings() } }
    @Published var selectedDate: Date = Date() {
        didSet {
            if useDatePickerSync { syncStringsFromDate(selectedDate) }
            saveSettings()
        }
    }
    @Published var useDatePickerSync: Bool = true

    @Published var showTimeBlock: Bool = true { didSet { saveSettings() } }
    @Published var timeText: String = "22:26" { didSet { saveSettings() } }
    @Published var dateText: String = "26/10/2026" { didSet { saveSettings() } }
    @Published var weekdayText: String = "Thứ Hai" { didSet { saveSettings() } }

    // 2. Các công tắc bật/tắt trong bảng "Chỉnh sửa mẫu" (giống hệt ảnh mẫu image_79402a.png)
    @Published var showLogo: Bool = true { didSet { saveSettings() } }
    @Published var logoStyle: LogoStyle = .hoaPhat { didSet { saveSettings() } }
    @Published var customLogoTitle: String = "HOA PHAT" { didSet { saveSettings() } }
    @Published var customLogoSubtitle: String = "GANG THÉP" { didSet { saveSettings() } }
    @Published var customLogoImageData: Data? = nil { didSet { saveSettings() } }
    @Published var removeWhiteBgForCustomLogo: Bool = true { didSet { saveSettings() } }

    // Dòng chính: Tổ Vận hành - Kíp A X.CT1
    @Published var showMainNote: Bool = true { didSet { saveSettings() } }
    @Published var noteLine1: String = "Tổ Vận hành - Kíp A X.CT1" { didSet { saveSettings() } }

    // Các dòng Text tùy chỉnh người dùng tự thêm trong mục "Bản mẫu"
    @Published var customTextItems: [CustomTextItem] = [
        CustomTextItem(title: "Nhà máy Luyện gang - Khu liên hợp Dung Quất", isEnabled: false)
    ] { didSet { saveSettings() } }

    // Các mục bật/tắt chuẩn Timemark trong ảnh "Chỉnh sửa mẫu"
    @Published var showAvatarBadge: Bool = false { didSet { saveSettings() } }
    @Published var avatarBadgeTitle: String = "NV: Nguyễn Văn A - MSNV: HP1024" { didSet { saveSettings() } }

    @Published var showPhotoVerifyCode: Bool = false { didSet { saveSettings() } }
    @Published var photoVerifyCodeText: String = "Mã ảnh: Xác minh tính xác thực #HP2610" { didSet { saveSettings() } }

    @Published var showMiniMap: Bool = false { didSet { saveSettings() } }
    @Published var miniMapLocationText: String = "Bình Đông, Bình Sơn, Quảng Ngãi" { didSet { saveSettings() } }

    @Published var showCoordinates: Bool = false { didSet { saveSettings() } }
    @Published var coordinatesText: String = "15.38521°N, 108.76142°E" { didSet { saveSettings() } }

    @Published var showAltitude: Bool = false { didSet { saveSettings() } }
    @Published var altitudeText: String = "Độ cao: 18.5 m" { didSet { saveSettings() } }

    @Published var showCompassDirection: Bool = false { didSet { saveSettings() } }
    @Published var compassDirectionText: String = "Phương hướng: Đông Bắc (42°)" { didSet { saveSettings() } }

    @Published var showTagRow: Bool = false { didSet { saveSettings() } }
    @Published var tagRowText: String = "#KiểmTraCa #AnToànThiếtBị" { didSet { saveSettings() } }

    // 3. Màu sắc & Tỉ lệ phóng to thu nhỏ + Vị trí kéo thả biểu mẫu trên màn hình
    @Published var barColor: AccentBarColorOption = .orange { didSet { saveSettings() } }
    @Published var watermarkScale: Double = 1.0 { didSet { saveSettings() } }

    // Tọa độ dịch chuyển chuẩn hóa theo tỷ lệ khung ảnh (-0.45 ... +0.45) để khi xuất ảnh/video giữ nguyên vị trí
    @Published var normalizedOffsetX: Double = 0.0 { didSet { saveSettings() } }
    @Published var normalizedOffsetY: Double = 0.0 { didSet { saveSettings() } }

    // Danh sách ghi chú nhanh để đổi Kíp
    @Published var quickNotes: [String] = [
        "Tổ Vận hành - Kíp A X.CT1",
        "Tổ Vận hành - Kíp B X.CT1",
        "Tổ Vận hành - Kíp C X.CT1",
        "Tổ Vận hành - Kíp D X.CT1",
        "Tổ Cơ điện - Ca 1 X.CT1",
        "Tổ Kiểm tra An toàn - Khu liên hợp"
    ] { didSet { saveSettings() } }

    private var timer: Timer?
    private let defaultsKey = "TimeStampCamPro_Settings_v2"

    init() {
        loadSettings()
        startClockTimer()
    }

    deinit {
        timer?.invalidate()
    }

    func startClockTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.useRealTime {
                let now = Date()
                self.useDatePickerSync = false
                self.selectedDate = now
                self.syncStringsFromDate(now)
                self.useDatePickerSync = true
            }
        }
    }

    func setNow() {
        let now = Date()
        useDatePickerSync = false
        selectedDate = now
        syncStringsFromDate(now)
        useDatePickerSync = true
    }

    func resetPositionAndScale() {
        watermarkScale = 1.0
        normalizedOffsetX = 0.0
        normalizedOffsetY = 0.0
    }

    func syncStringsFromDate(_ date: Date) {
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "vi_VN")
        timeFormatter.dateFormat = "HH:mm"
        self.timeText = timeFormatter.string(from: date)

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "vi_VN")
        dateFormatter.dateFormat = "dd/MM/yyyy"
        self.dateText = dateFormatter.string(from: date)

        self.weekdayText = Self.vietnameseWeekday(from: date)
    }

    static func vietnameseWeekday(from date: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let weekday = calendar.component(.weekday, from: date)
        switch weekday {
        case 1: return "Chủ Nhật"
        case 2: return "Thứ Hai"
        case 3: return "Thứ Ba"
        case 4: return "Thứ Tư"
        case 5: return "Thứ Năm"
        case 6: return "Thứ Sáu"
        case 7: return "Thứ Bảy"
        default: return "Thứ Hai"
        }
    }

    /// Tất cả các dòng văn bản đang được bật để vẽ vào khung mờ bên dưới giờ
    var activeNoteLines: [String] {
        var lines: [String] = []
        if showMainNote && !noteLine1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append(noteLine1)
        }
        for item in customTextItems where item.isEnabled {
            let trimmed = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { lines.append(trimmed) }
        }
        if showAvatarBadge && !avatarBadgeTitle.isEmpty {
            lines.append("👤 \(avatarBadgeTitle)")
        }
        if showMiniMap && !miniMapLocationText.isEmpty {
            lines.append("📍 \(miniMapLocationText)")
        }
        if showCoordinates && !coordinatesText.isEmpty {
            lines.append("🌐 \(coordinatesText)")
        }
        if showAltitude && !altitudeText.isEmpty {
            lines.append("⛰️ \(altitudeText)")
        }
        if showCompassDirection && !compassDirectionText.isEmpty {
            lines.append("🧭 \(compassDirectionText)")
        }
        if showTagRow && !tagRowText.isEmpty {
            lines.append("🏷️ \(tagRowText)")
        }
        if showPhotoVerifyCode && !photoVerifyCodeText.isEmpty {
            lines.append("🛡️ \(photoVerifyCodeText)")
        }
        return lines
    }

    var customLogoUIImage: UIImage? {
        guard let data = customLogoImageData, let raw = UIImage(data: data) else { return nil }
        if removeWhiteBgForCustomLogo {
            return raw.removingWhiteBackground() ?? raw
        }
        return raw
    }

    // MARK: - Persistence
    private struct PersistedData: Codable {
        var useRealTime: Bool
        var showTimeBlock: Bool
        var timeText: String
        var dateText: String
        var weekdayText: String
        var showLogo: Bool
        var logoStyle: LogoStyle
        var customLogoTitle: String
        var customLogoSubtitle: String
        var customLogoImageData: Data?
        var removeWhiteBgForCustomLogo: Bool
        var showMainNote: Bool
        var noteLine1: String
        var customTextItems: [CustomTextItem]
        var showAvatarBadge: Bool
        var avatarBadgeTitle: String
        var showPhotoVerifyCode: Bool
        var photoVerifyCodeText: String
        var showMiniMap: Bool
        var miniMapLocationText: String
        var showCoordinates: Bool
        var coordinatesText: String
        var showAltitude: Bool
        var altitudeText: String
        var showCompassDirection: Bool
        var compassDirectionText: String
        var showTagRow: Bool
        var tagRowText: String
        var barColor: AccentBarColorOption
        var watermarkScale: Double
        var normalizedOffsetX: Double
        var normalizedOffsetY: Double
        var quickNotes: [String]
    }

    private func saveSettings() {
        let data = PersistedData(
            useRealTime: useRealTime,
            showTimeBlock: showTimeBlock,
            timeText: timeText,
            dateText: dateText,
            weekdayText: weekdayText,
            showLogo: showLogo,
            logoStyle: logoStyle,
            customLogoTitle: customLogoTitle,
            customLogoSubtitle: customLogoSubtitle,
            customLogoImageData: customLogoImageData,
            removeWhiteBgForCustomLogo: removeWhiteBgForCustomLogo,
            showMainNote: showMainNote,
            noteLine1: noteLine1,
            customTextItems: customTextItems,
            showAvatarBadge: showAvatarBadge,
            avatarBadgeTitle: avatarBadgeTitle,
            showPhotoVerifyCode: showPhotoVerifyCode,
            photoVerifyCodeText: photoVerifyCodeText,
            showMiniMap: showMiniMap,
            miniMapLocationText: miniMapLocationText,
            showCoordinates: showCoordinates,
            coordinatesText: coordinatesText,
            showAltitude: showAltitude,
            altitudeText: altitudeText,
            showCompassDirection: showCompassDirection,
            compassDirectionText: compassDirectionText,
            showTagRow: showTagRow,
            tagRowText: tagRowText,
            barColor: barColor,
            watermarkScale: watermarkScale,
            normalizedOffsetX: normalizedOffsetX,
            normalizedOffsetY: normalizedOffsetY,
            quickNotes: quickNotes
        )
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: defaultsKey)
        }
    }

    private func loadSettings() {
        guard let raw = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(PersistedData.self, from: raw) else {
            return
        }
        self.useRealTime = decoded.useRealTime
        self.showTimeBlock = decoded.showTimeBlock
        self.timeText = decoded.timeText
        self.dateText = decoded.dateText
        self.weekdayText = decoded.weekdayText
        self.showLogo = decoded.showLogo
        self.logoStyle = decoded.logoStyle
        self.customLogoTitle = decoded.customLogoTitle
        self.customLogoSubtitle = decoded.customLogoSubtitle
        self.customLogoImageData = decoded.customLogoImageData
        self.removeWhiteBgForCustomLogo = decoded.removeWhiteBgForCustomLogo
        self.showMainNote = decoded.showMainNote
        self.noteLine1 = decoded.noteLine1
        self.customTextItems = decoded.customTextItems
        self.showAvatarBadge = decoded.showAvatarBadge
        self.avatarBadgeTitle = decoded.avatarBadgeTitle
        self.showPhotoVerifyCode = decoded.showPhotoVerifyCode
        self.photoVerifyCodeText = decoded.photoVerifyCodeText
        self.showMiniMap = decoded.showMiniMap
        self.miniMapLocationText = decoded.miniMapLocationText
        self.showCoordinates = decoded.showCoordinates
        self.coordinatesText = decoded.coordinatesText
        self.showAltitude = decoded.showAltitude
        self.altitudeText = decoded.altitudeText
        self.showCompassDirection = decoded.showCompassDirection
        self.compassDirectionText = decoded.compassDirectionText
        self.showTagRow = decoded.showTagRow
        self.tagRowText = decoded.tagRowText
        self.barColor = decoded.barColor
        self.watermarkScale = decoded.watermarkScale
        self.normalizedOffsetX = decoded.normalizedOffsetX
        self.normalizedOffsetY = decoded.normalizedOffsetY
        self.quickNotes = decoded.quickNotes
    }
}

extension UIImage {
    /// Tự động xóa nền trắng cho ảnh Logo người dùng tải lên từ máy
    func removingWhiteBackground() -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rawData = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        for i in stride(from: 0, to: rawData.count, by: 4) {
            let r = rawData[i]
            let g = rawData[i + 1]
            let b = rawData[i + 2]
            if r > 235 && g > 235 && b > 235 {
                rawData[i] = 0
                rawData[i + 1] = 0
                rawData[i + 2] = 0
                rawData[i + 3] = 0
            }
        }

        guard let outCG = context.makeImage() else { return nil }
        return UIImage(cgImage: outCG, scale: self.scale, orientation: self.imageOrientation)
    }
}
