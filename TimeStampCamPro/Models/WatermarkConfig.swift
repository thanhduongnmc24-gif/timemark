import Foundation
import SwiftUI
import UIKit

enum LogoStyle: String, Codable, CaseIterable, Identifiable {
    case hoaPhat = "Hòa Phát Gang Thép"
    case customText = "Logo chữ tùy chỉnh"
    case customImage = "Ảnh logo từ máy"
    case hidden = "Ẩn logo"

    var id: String { rawValue }
}

enum AccentBarColorOption: String, Codable, CaseIterable, Identifiable {
    case orange = "Cam (Chuẩn Timemark)"
    case blue = "Xanh Hòa Phát"
    case yellow = "Vàng công trường"
    case green = "Xanh lá an toàn"
    case red = "Đỏ nổi bật"

    var id: String { rawValue }

    var swiftUIColor: Color {
        switch self {
        case .orange: return Color(red: 1.0, green: 0.48, blue: 0.0)
        case .blue: return Color(red: 0.0, green: 0.48, blue: 0.85)
        case .yellow: return Color(red: 1.0, green: 0.78, blue: 0.05)
        case .green: return Color(red: 0.15, green: 0.78, blue: 0.35)
        case .red: return Color(red: 0.95, green: 0.22, blue: 0.22)
        }
    }

    var uiColor: UIColor {
        switch self {
        case .orange: return UIColor(red: 1.0, green: 0.48, blue: 0.0, alpha: 1.0)
        case .blue: return UIColor(red: 0.0, green: 0.48, blue: 0.85, alpha: 1.0)
        case .yellow: return UIColor(red: 1.0, green: 0.78, blue: 0.05, alpha: 1.0)
        case .green: return UIColor(red: 0.15, green: 0.78, blue: 0.35, alpha: 1.0)
        case .red: return UIColor(red: 0.95, green: 0.22, blue: 0.22, alpha: 1.0)
        }
    }
}

struct WatermarkPreset: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var subtitle: String
    var logoStyle: LogoStyle
    var customLogoTitle: String
    var customLogoSubtitle: String
    var noteLine1: String
    var noteLine2: String
    var showLocationLine: Bool
    var showVerificationBadge: Bool
    var directionBannerCode: String
    var showDirectionBanner: Bool
    var barColor: AccentBarColorOption
}

class WatermarkStore: ObservableObject {
    // Chế độ thời gian: tự động theo đồng hồ thực hoặc tự điền bất kỳ
    @Published var useRealTime: Bool = false {
        didSet { saveSettings() }
    }
    @Published var selectedDate: Date = Date() {
        didSet {
            if useDatePickerSync {
                syncStringsFromDate(selectedDate)
            }
            saveSettings()
        }
    }
    @Published var useDatePickerSync: Bool = true

    // Chuỗi hiển thị trực tiếp (cho phép sửa bằng DatePicker hoặc gõ tay từng chữ)
    @Published var timeText: String = "21:55" {
        didSet { saveSettings() }
    }
    @Published var dateText: String = "26/10/2026" {
        didSet { saveSettings() }
    }
    @Published var weekdayText: String = "Thứ Hai" {
        didSet { saveSettings() }
    }

    // Dòng ghi chú ca/kíp trong khung mờ bên dưới giờ
    @Published var noteLine1: String = "Tổ Vận hành - Kíp A X.CT1" {
        didSet { saveSettings() }
    }
    @Published var noteLine2: String = "" {
        didSet { saveSettings() }
    }
    @Published var locationText: String = "" {
        didSet { saveSettings() }
    }
    @Published var showLocationLine: Bool = false {
        didSet { saveSettings() }
    }

    // Cấu hình Logo
    @Published var logoStyle: LogoStyle = .hoaPhat {
        didSet { saveSettings() }
    }
    @Published var customLogoTitle: String = "HOA PHAT" {
        didSet { saveSettings() }
    }
    @Published var customLogoSubtitle: String = "GANG THÉP" {
        didSet { saveSettings() }
    }
    @Published var customLogoImageData: Data? = nil {
        didSet { saveSettings() }
    }

    // Cấu hình giao diện & Thanh trạng thái
    @Published var barColor: AccentBarColorOption = .orange {
        didSet { saveSettings() }
    }
    @Published var showVerificationBadge: Bool = true {
        didSet { saveSettings() }
    }
    @Published var verificationBadgeText: String = "Xác minh Ảnh" {
        didSet { saveSettings() }
    }
    @Published var showDirectionBanner: Bool = true {
        didSet { saveSettings() }
    }
    @Published var directionBannerCode: String = "D" {
        didSet { saveSettings() }
    }
    @Published var watermarkScale: Double = 1.0 {
        didSet { saveSettings() }
    }
    @Published var includeBottomBannerInExport: Bool = false {
        didSet { saveSettings() }
    }

    // Danh sách ghi chú nhanh để đổi ca/kíp trong 1 chạm
    @Published var quickNotes: [String] = [
        "Tổ Vận hành - Kíp A X.CT1",
        "Tổ Vận hành - Kíp B X.CT1",
        "Tổ Vận hành - Kíp C X.CT1",
        "Tổ Vận hành - Kíp D X.CT1",
        "Tổ Cơ điện - Ca 1 Nhà máy Luyện gang",
        "Tổ An toàn & Môi trường - Kiểm tra định kỳ"
    ] {
        didSet { saveSettings() }
    }

    // Danh sách bản mẫu (Presets)
    @Published var presets: [WatermarkPreset] = [
        WatermarkPreset(
            name: "Mẫu Hòa Phát Gang Thép (Chuẩn)",
            subtitle: "Giống hệt ảnh mẫu: Logo Hòa Phát + Giờ lớn + Vạch cam + Khung mờ Kíp vận hành",
            logoStyle: .hoaPhat,
            customLogoTitle: "HOA PHAT",
            customLogoSubtitle: "GANG THÉP",
            noteLine1: "Tổ Vận hành - Kíp A X.CT1",
            noteLine2: "",
            showLocationLine: false,
            showVerificationBadge: true,
            directionBannerCode: "D",
            showDirectionBanner: true,
            barColor: .orange
        ),
        WatermarkPreset(
            name: "Mẫu Báo Cáo Kèm Vị Trí GPS",
            subtitle: "Hiển thị thêm dòng tọa độ/địa chỉ bên dưới tên Tổ vận hành",
            logoStyle: .hoaPhat,
            customLogoTitle: "HOA PHAT",
            customLogoSubtitle: "GANG THÉP",
            noteLine1: "Tổ Vận hành - Kíp A X.CT1",
            noteLine2: "Khu liên hợp Gang Thép Dung Quất",
            showLocationLine: true,
            showVerificationBadge: true,
            directionBannerCode: "B",
            showDirectionBanner: true,
            barColor: .orange
        ),
        WatermarkPreset(
            name: "Mẫu Chấm Công Công Trường Tối Giản",
            subtitle: "Không logo, chỉ hiện giờ, ngày tháng, thứ và ghi chú công việc",
            logoStyle: .hidden,
            customLogoTitle: "",
            customLogoSubtitle: "",
            noteLine1: "Kiểm tra bàn giao ca trực",
            noteLine2: "",
            showLocationLine: false,
            showVerificationBadge: true,
            directionBannerCode: "Đ",
            showDirectionBanner: true,
            barColor: .yellow
        )
    ] {
        didSet { saveSettings() }
    }

    private var timer: Timer?
    private let defaultsKey = "TimeStampCamPro_Settings_v1"

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

    func applyPreset(_ preset: WatermarkPreset) {
        self.logoStyle = preset.logoStyle
        if !preset.customLogoTitle.isEmpty {
            self.customLogoTitle = preset.customLogoTitle
        }
        if !preset.customLogoSubtitle.isEmpty {
            self.customLogoSubtitle = preset.customLogoSubtitle
        }
        self.noteLine1 = preset.noteLine1
        self.noteLine2 = preset.noteLine2
        self.showLocationLine = preset.showLocationLine
        self.showVerificationBadge = preset.showVerificationBadge
        self.directionBannerCode = preset.directionBannerCode
        self.showDirectionBanner = preset.showDirectionBanner
        self.barColor = preset.barColor
    }

    func saveCurrentAsPreset(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newPreset = WatermarkPreset(
            name: trimmed,
            subtitle: "Ghi chú: \(noteLine1)",
            logoStyle: logoStyle,
            customLogoTitle: customLogoTitle,
            customLogoSubtitle: customLogoSubtitle,
            noteLine1: noteLine1,
            noteLine2: noteLine2,
            showLocationLine: showLocationLine,
            showVerificationBadge: showVerificationBadge,
            directionBannerCode: directionBannerCode,
            showDirectionBanner: showDirectionBanner,
            barColor: barColor
        )
        presets.insert(newPreset, at: 0)
    }

    var customLogoUIImage: UIImage? {
        guard let data = customLogoImageData else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Persistence
    private struct PersistedData: Codable {
        var useRealTime: Bool
        var timeText: String
        var dateText: String
        var weekdayText: String
        var noteLine1: String
        var noteLine2: String
        var locationText: String
        var showLocationLine: Bool
        var logoStyle: LogoStyle
        var customLogoTitle: String
        var customLogoSubtitle: String
        var customLogoImageData: Data?
        var barColor: AccentBarColorOption
        var showVerificationBadge: Bool
        var directionBannerCode: String
        var showDirectionBanner: Bool
        var watermarkScale: Double
        var includeBottomBannerInExport: Bool
        var quickNotes: [String]
        var presets: [WatermarkPreset]
    }

    private func saveSettings() {
        let data = PersistedData(
            useRealTime: useRealTime,
            timeText: timeText,
            dateText: dateText,
            weekdayText: weekdayText,
            noteLine1: noteLine1,
            noteLine2: noteLine2,
            locationText: locationText,
            showLocationLine: showLocationLine,
            logoStyle: logoStyle,
            customLogoTitle: customLogoTitle,
            customLogoSubtitle: customLogoSubtitle,
            customLogoImageData: customLogoImageData,
            barColor: barColor,
            showVerificationBadge: showVerificationBadge,
            directionBannerCode: directionBannerCode,
            showDirectionBanner: showDirectionBanner,
            watermarkScale: watermarkScale,
            includeBottomBannerInExport: includeBottomBannerInExport,
            quickNotes: quickNotes,
            presets: presets
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
        self.timeText = decoded.timeText
        self.dateText = decoded.dateText
        self.weekdayText = decoded.weekdayText
        self.noteLine1 = decoded.noteLine1
        self.noteLine2 = decoded.noteLine2
        self.locationText = decoded.locationText
        self.showLocationLine = decoded.showLocationLine
        self.logoStyle = decoded.logoStyle
        self.customLogoTitle = decoded.customLogoTitle
        self.customLogoSubtitle = decoded.customLogoSubtitle
        self.customLogoImageData = decoded.customLogoImageData
        self.barColor = decoded.barColor
        self.showVerificationBadge = decoded.showVerificationBadge
        self.directionBannerCode = decoded.directionBannerCode
        self.showDirectionBanner = decoded.showDirectionBanner
        self.watermarkScale = decoded.watermarkScale
        self.includeBottomBannerInExport = decoded.includeBottomBannerInExport
        self.quickNotes = decoded.quickNotes
        self.presets = decoded.presets
    }
}
