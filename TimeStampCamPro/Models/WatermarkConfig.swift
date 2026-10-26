import Foundation
import SwiftUI
import UIKit

enum CameraAspectRatio: String, Codable, CaseIterable, Identifiable {
    case ratio3x4 = "3:4"
    case ratio9x16 = "9:16"
    case full = "Full"
    case ratio1x1 = "1:1"

    var id: String { rawValue }

    /// Tính kích thước khung hiển thị thực tế vừa khít bên trong vùng chứa `containerSize`
    func targetSize(fitting containerSize: CGSize) -> CGSize {
        guard containerSize.width > 0 && containerSize.height > 0 else { return containerSize }
        let targetAspect: CGFloat
        switch self {
        case .ratio3x4:
            targetAspect = 3.0 / 4.0
        case .ratio9x16:
            targetAspect = 9.0 / 16.0
        case .ratio1x1:
            targetAspect = 1.0
        case .full:
            return containerSize
        }

        let containerAspect = containerSize.width / containerSize.height
        if containerAspect > targetAspect {
            let h = containerSize.height
            let w = round(h * targetAspect)
            return CGSize(width: w, height: h)
        } else {
            let w = containerSize.width
            let h = round(w / targetAspect)
            return CGSize(width: w, height: h)
        }
    }

    /// Tỉ lệ Rộng / Cao (width / height) để cắt ảnh đầu ra đúng kích thước khung hình đã chọn
    func numericAspect(fallbackContainerSize: CGSize) -> CGFloat {
        switch self {
        case .ratio3x4:
            return 3.0 / 4.0
        case .ratio9x16:
            return 9.0 / 16.0
        case .ratio1x1:
            return 1.0
        case .full:
            guard fallbackContainerSize.width > 0 && fallbackContainerSize.height > 0 else {
                return 3.0 / 4.0
            }
            return fallbackContainerSize.width / fallbackContainerSize.height
        }
    }
}

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

/// Bản chụp cấu hình nhẹ (Value Type) phục vụ vẽ ảnh/video ở luồng nền (Background Thread) mà không gây đơ giao diện chính
struct WatermarkRenderSnapshot {
    let showTimeBlock: Bool
    let timeText: String
    let dateText: String
    let weekdayText: String
    let showLogo: Bool
    let logoStyle: LogoStyle
    let customLogoTitle: String
    let customLogoSubtitle: String
    let customLogoUIImage: UIImage?
    let activeNoteLines: [String]
    let barColor: AccentBarColorOption
    let watermarkScale: Double
    let normalizedOffsetX: Double
    let normalizedOffsetY: Double
    let aspectRatio: CameraAspectRatio

    init(from store: WatermarkStore) {
        self.showTimeBlock = store.showTimeBlock
        self.timeText = store.timeText
        self.dateText = store.dateText
        self.weekdayText = store.weekdayText
        self.showLogo = store.showLogo
        self.logoStyle = store.logoStyle
        self.customLogoTitle = store.customLogoTitle
        self.customLogoSubtitle = store.customLogoSubtitle
        self.customLogoUIImage = store.customLogoUIImage
        self.activeNoteLines = store.activeNoteLines
        self.barColor = store.barColor
        self.watermarkScale = store.watermarkScale
        self.normalizedOffsetX = store.normalizedOffsetX
        self.normalizedOffsetY = store.normalizedOffsetY
        self.aspectRatio = store.aspectRatio
    }
}

class WatermarkStore: ObservableObject {
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "dd/MM/yyyy"
        return f
    }()

    static let hoaPhatAssetLogo: UIImage? = UIImage(named: "HoaPhatLogo")

    private var isLoadingSettings: Bool = false
    private var saveWorkItem: DispatchWorkItem?
    private let saveQueue = DispatchQueue(label: "com.timestampcam.pro.settings.save", qos: .utility)

    // Tỉ lệ khung hình Camera (3:4, 9:16, Full, 1:1)
    @Published var aspectRatio: CameraAspectRatio = .ratio3x4 { didSet { scheduleSaveSettings() } }

    // 1. Chế độ thời gian
    @Published var useRealTime: Bool = false { didSet { scheduleSaveSettings() } }
    @Published var selectedDate: Date = Date() {
        didSet {
            if useDatePickerSync { syncStringsFromDate(selectedDate) }
            scheduleSaveSettings()
        }
    }
    @Published var useDatePickerSync: Bool = true

    @Published var showTimeBlock: Bool = true { didSet { scheduleSaveSettings() } }
    @Published var timeText: String = "22:26" { didSet { scheduleSaveSettings() } }
    @Published var dateText: String = "26/10/2026" { didSet { scheduleSaveSettings() } }
    @Published var weekdayText: String = "Thứ Hai" { didSet { scheduleSaveSettings() } }

    // 2. Các công tắc bật/tắt trong bảng "Chỉnh sửa mẫu"
    @Published var showLogo: Bool = true { didSet { scheduleSaveSettings() } }
    @Published var logoStyle: LogoStyle = .hoaPhat { didSet { scheduleSaveSettings() } }
    @Published var customLogoTitle: String = "HOA PHAT" { didSet { scheduleSaveSettings() } }
    @Published var customLogoSubtitle: String = "GANG THÉP" { didSet { scheduleSaveSettings() } }
    @Published var customLogoImageData: Data? = nil {
        didSet {
            rebuildCachedCustomLogo()
            saveCustomLogoDataAsync()
        }
    }
    @Published var removeWhiteBgForCustomLogo: Bool = true {
        didSet {
            rebuildCachedCustomLogo()
            scheduleSaveSettings()
        }
    }

    @Published private(set) var customLogoUIImage: UIImage? = nil

    // Dòng chính: Tổ Vận hành - Kíp A X.CT1
    @Published var showMainNote: Bool = true { didSet { scheduleSaveSettings() } }
    @Published var noteLine1: String = "Tổ Vận hành - Kíp A X.CT1" { didSet { scheduleSaveSettings() } }

    // Các dòng Text tùy chỉnh người dùng tự thêm trong mục "Bản mẫu"
    @Published var customTextItems: [CustomTextItem] = [
        CustomTextItem(title: "Nhà máy Luyện gang - Khu liên hợp Dung Quất", isEnabled: false)
    ] { didSet { scheduleSaveSettings() } }

    // Các mục bật/tắt chuẩn Timemark
    @Published var showAvatarBadge: Bool = false { didSet { scheduleSaveSettings() } }
    @Published var avatarBadgeTitle: String = "NV: Nguyễn Văn A - MSNV: HP1024" { didSet { scheduleSaveSettings() } }

    @Published var showPhotoVerifyCode: Bool = false { didSet { scheduleSaveSettings() } }
    @Published var photoVerifyCodeText: String = "Mã ảnh: Xác minh tính xác thực #HP2610" { didSet { scheduleSaveSettings() } }

    @Published var showMiniMap: Bool = false { didSet { scheduleSaveSettings() } }
    @Published var miniMapLocationText: String = "Bình Đông, Bình Sơn, Quảng Ngãi" { didSet { scheduleSaveSettings() } }

    @Published var showCoordinates: Bool = false { didSet { scheduleSaveSettings() } }
    @Published var coordinatesText: String = "15.38521°N, 108.76142°E" { didSet { scheduleSaveSettings() } }

    @Published var showAltitude: Bool = false { didSet { scheduleSaveSettings() } }
    @Published var altitudeText: String = "Độ cao: 18.5 m" { didSet { scheduleSaveSettings() } }

    @Published var showCompassDirection: Bool = false { didSet { scheduleSaveSettings() } }
    @Published var compassDirectionText: String = "Phương hướng: Đông Bắc (42°)" { didSet { scheduleSaveSettings() } }

    @Published var showTagRow: Bool = false { didSet { scheduleSaveSettings() } }
    @Published var tagRowText: String = "#KiểmTraCa #AnToànThiếtBị" { didSet { scheduleSaveSettings() } }

    // 3. Màu sắc & Tỉ lệ phóng to thu nhỏ + Vị trí kéo thả biểu mẫu trên màn hình
    @Published var barColor: AccentBarColorOption = .orange { didSet { scheduleSaveSettings() } }
    @Published var watermarkScale: Double = 1.0 { didSet { scheduleSaveSettings() } }

    // Tọa độ dịch chuyển chuẩn hóa theo tỷ lệ khung ảnh (-0.45 ... +0.45)
    @Published var normalizedOffsetX: Double = 0.0 { didSet { scheduleSaveSettings() } }
    @Published var normalizedOffsetY: Double = 0.0 { didSet { scheduleSaveSettings() } }

    // Danh sách ghi chú nhanh để đổi Kíp
    @Published var quickNotes: [String] = [
        "Tổ Vận hành - Kíp A X.CT1",
        "Tổ Vận hành - Kíp B X.CT1",
        "Tổ Vận hành - Kíp C X.CT1",
        "Tổ Vận hành - Kíp D X.CT1",
        "Tổ Cơ điện - Ca 1 X.CT1",
        "Tổ Kiểm tra An toàn - Khu liên hợp"
    ] { didSet { scheduleSaveSettings() } }

    private var timer: Timer?
    private let defaultsKey = "TimeStampCamPro_Settings_v3"
    private let customLogoDefaultsKey = "TimeStampCamPro_CustomLogoData_v3"

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
            guard let self = self, self.useRealTime else { return }
            self.syncStringsFromDateIfNeeded(Date())
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

    private func syncStringsFromDateIfNeeded(_ date: Date) {
        let newTime = Self.timeFormatter.string(from: date)
        let newDate = Self.dateFormatter.string(from: date)
        let newWeekday = Self.vietnameseWeekday(from: date)

        if self.timeText != newTime {
            self.timeText = newTime
        }
        if self.dateText != newDate {
            self.dateText = newDate
        }
        if self.weekdayText != newWeekday {
            self.weekdayText = newWeekday
        }
    }

    func syncStringsFromDate(_ date: Date) {
        self.timeText = Self.timeFormatter.string(from: date)
        self.dateText = Self.dateFormatter.string(from: date)
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

    private func rebuildCachedCustomLogo() {
        guard let data = customLogoImageData else {
            customLogoUIImage = nil
            return
        }
        let shouldStripWhite = removeWhiteBgForCustomLogo
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let raw = UIImage(data: data) else { return }
            let processed = shouldStripWhite ? (raw.removingWhiteBackground() ?? raw) : raw
            DispatchQueue.main.async {
                self?.customLogoUIImage = processed
            }
        }
    }

    // MARK: - Persistence (Chạy bất đồng bộ ở luồng nền, tuyệt đối không làm khựng giao diện)
    private struct PersistedData: Codable {
        var aspectRatio: CameraAspectRatio?
        var useRealTime: Bool
        var showTimeBlock: Bool
        var timeText: String
        var dateText: String
        var weekdayText: String
        var showLogo: Bool
        var logoStyle: LogoStyle
        var customLogoTitle: String
        var customLogoSubtitle: String
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

    private func saveCustomLogoDataAsync() {
        guard !isLoadingSettings else { return }
        let dataToSave = customLogoImageData
        let key = customLogoDefaultsKey
        saveQueue.async {
            UserDefaults.standard.set(dataToSave, forKey: key)
        }
    }

    private func scheduleSaveSettings() {
        guard !isLoadingSettings else { return }
        saveWorkItem?.cancel()

        let snapshot = PersistedData(
            aspectRatio: aspectRatio,
            useRealTime: useRealTime,
            showTimeBlock: showTimeBlock,
            timeText: timeText,
            dateText: dateText,
            weekdayText: weekdayText,
            showLogo: showLogo,
            logoStyle: logoStyle,
            customLogoTitle: customLogoTitle,
            customLogoSubtitle: customLogoSubtitle,
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

        let key = defaultsKey
        let work = DispatchWorkItem {
            if let encoded = try? JSONEncoder().encode(snapshot) {
                UserDefaults.standard.set(encoded, forKey: key)
            }
        }
        saveWorkItem = work
        saveQueue.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private func loadSettings() {
        isLoadingSettings = true
        defer { isLoadingSettings = false }

        if let logoData = UserDefaults.standard.data(forKey: customLogoDefaultsKey) {
            self.customLogoImageData = logoData
        }

        let raw = UserDefaults.standard.data(forKey: defaultsKey)
            ?? UserDefaults.standard.data(forKey: "TimeStampCamPro_Settings_v2")
        guard let data = raw,
              let decoded = try? JSONDecoder().decode(PersistedData.self, from: data) else {
            return
        }

        self.aspectRatio = decoded.aspectRatio ?? .ratio3x4
        self.useRealTime = decoded.useRealTime
        self.showTimeBlock = decoded.showTimeBlock
        self.timeText = decoded.timeText
        self.dateText = decoded.dateText
        self.weekdayText = decoded.weekdayText
        self.showLogo = decoded.showLogo
        self.logoStyle = decoded.logoStyle
        self.customLogoTitle = decoded.customLogoTitle
        self.customLogoSubtitle = decoded.customLogoSubtitle
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
        rebuildCachedCustomLogo()
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
