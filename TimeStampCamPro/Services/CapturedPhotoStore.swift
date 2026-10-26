import Foundation
import UIKit
import SwiftUI

struct CapturedPhotoItem: Identifiable, Codable, Hashable {
    private static let fullTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "HH:mm - dd/MM/yyyy"
        return f
    }()

    private static let badgeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "HH:mm dd/MM"
        return f
    }()

    let id: UUID
    let fileName: String
    let thumbFileName: String?
    let createdAt: Date
    let captionText: String
    let formattedTime: String
    let shortTimeBadge: String

    enum CodingKeys: String, CodingKey {
        case id, fileName, thumbFileName, createdAt, captionText
    }

    init(id: UUID, fileName: String, thumbFileName: String?, createdAt: Date, captionText: String) {
        self.id = id
        self.fileName = fileName
        self.thumbFileName = thumbFileName
        self.createdAt = createdAt
        self.captionText = captionText
        self.formattedTime = Self.fullTimeFormatter.string(from: createdAt)
        self.shortTimeBadge = Self.badgeFormatter.string(from: createdAt)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let fileName = try container.decode(String.self, forKey: .fileName)
        let thumbFileName = try container.decodeIfPresent(String.self, forKey: .thumbFileName)
        let createdAt = try container.decode(Date.self, forKey: .createdAt)
        let captionText = (try? container.decode(String.self, forKey: .captionText)) ?? ""
        self.init(id: id, fileName: fileName, thumbFileName: thumbFileName, createdAt: createdAt, captionText: captionText)
    }
}

/// Quản lý bộ sưu tập các ảnh đã chụp bằng ứng dụng với cơ chế đọc/ghi và tạo ảnh thu nhỏ 100% ở luồng nền (Background Queue)
/// Tuyệt đối không đọc đĩa hay giải mã ảnh trên Main Thread để giao diện luôn mượt 60/120fps
final class CapturedPhotoStore: ObservableObject {
    @Published private(set) var items: [CapturedPhotoItem] = []
    @Published private(set) var thumbnails: [UUID: UIImage] = [:]
    @Published private(set) var latestThumbnail: UIImage? = nil

    private let folderName = "TimeMarkCapturedPhotos"
    private let manifestFileName = "manifest_v2.json"
    private let ioQueue = DispatchQueue(label: "com.timestampcam.pro.captured.io", qos: .userInitiated)

    init() {
        loadManifestAsync()
    }

    private var folderURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(folderName, isDirectory: true)
    }

    private var manifestURL: URL {
        folderURL.appendingPathComponent(manifestFileName)
    }

    private func createFolderIfNeeded() {
        let url = folderURL
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    func fileURL(for item: CapturedPhotoItem) -> URL {
        folderURL.appendingPathComponent(item.fileName)
    }

    private func thumbURL(for item: CapturedPhotoItem) -> URL {
        let name = item.thumbFileName ?? "thumb_\(item.fileName)"
        return folderURL.appendingPathComponent(name)
    }

    private func loadManifestAsync() {
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            self.createFolderIfNeeded()
            let legacyURL = self.folderURL.appendingPathComponent("manifest.json")
            let data = (try? Data(contentsOf: self.manifestURL)) ?? (try? Data(contentsOf: legacyURL))
            guard let rawData = data,
                  let decoded = try? JSONDecoder().decode([CapturedPhotoItem].self, from: rawData) else {
                return
            }

            let validItems = decoded
                .filter { FileManager.default.fileExists(atPath: self.fileURL(for: $0).path) }
                .sorted(by: { $0.createdAt > $1.createdAt })

            var loadedThumbs: [UUID: UIImage] = [:]
            for item in validItems {
                let tURL = self.thumbURL(for: item)
                if let tData = try? Data(contentsOf: tURL), let tImg = UIImage(data: tData) {
                    loadedThumbs[item.id] = tImg
                } else if let fullData = try? Data(contentsOf: self.fileURL(for: item)),
                          let fullImg = UIImage(data: fullData),
                          let generatedThumb = Self.makeThumbnail(from: fullImg, maxDimension: 260) {
                    loadedThumbs[item.id] = generatedThumb
                    if let jData = generatedThumb.jpegData(compressionQuality: 0.78) {
                        try? jData.write(to: tURL, options: .atomic)
                    }
                }
            }

            let firstThumb = validItems.first.flatMap { loadedThumbs[$0.id] }
            DispatchQueue.main.async {
                self.thumbnails = loadedThumbs
                self.latestThumbnail = firstThumb
                self.items = validItems
            }
        }
    }

    private func saveManifestOnIOQueue(_ currentItems: [CapturedPhotoItem]) {
        createFolderIfNeeded()
        if let data = try? JSONEncoder().encode(currentItems) {
            try? data.write(to: manifestURL, options: .atomic)
        }
    }

    /// Lưu ảnh mới chụp hoàn toàn ở luồng nền, không làm khựng giao diện
    func addCapturedPhotoAsync(_ image: UIImage, caption: String = "") {
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            self.createFolderIfNeeded()
            let id = UUID()
            let timestamp = Int(Date().timeIntervalSince1970)
            let fileName = "timemark_\(timestamp)_\(id.uuidString.prefix(8)).jpg"
            let thumbName = "thumb_\(fileName)"

            let targetURL = self.folderURL.appendingPathComponent(fileName)
            let targetThumbURL = self.folderURL.appendingPathComponent(thumbName)

            guard let jpegData = image.jpegData(compressionQuality: 0.88) else { return }
            try? jpegData.write(to: targetURL, options: .atomic)

            let thumbImage = Self.makeThumbnail(from: image, maxDimension: 260) ?? image
            if let thumbData = thumbImage.jpegData(compressionQuality: 0.78) {
                try? thumbData.write(to: targetThumbURL, options: .atomic)
            }

            let newItem = CapturedPhotoItem(
                id: id,
                fileName: fileName,
                thumbFileName: thumbName,
                createdAt: Date(),
                captionText: caption
            )

            DispatchQueue.main.async {
                self.thumbnails[id] = thumbImage
                self.latestThumbnail = thumbImage
                self.items.insert(newItem, at: 0)
                let snapshotItems = self.items
                self.ioQueue.async {
                    self.saveManifestOnIOQueue(snapshotItems)
                }
            }
        }
    }

    /// Trả về ảnh thu nhỏ đã nạp sẵn trong RAM (O(1), 0ms, không bao giờ đọc đĩa trên Main Thread)
    func thumbnailImage(for item: CapturedPhotoItem) -> UIImage? {
        return thumbnails[item.id]
    }

    /// Đọc ảnh gốc độ phân giải đầy đủ khi người dùng bấm xem chi tiết hoặc chia sẻ
    func loadFullImageAsync(for item: CapturedPhotoItem, completion: @escaping (UIImage?) -> Void) {
        let url = fileURL(for: item)
        ioQueue.async {
            let img = (try? Data(contentsOf: url)).flatMap { UIImage(data: $0) }
            DispatchQueue.main.async {
                completion(img)
            }
        }
    }

    /// Chuẩn bị danh sách ảnh để chia sẻ qua Zalo / Facebook trên luồng nền
    func prepareImagesForSharing(ids: Set<UUID>, completion: @escaping ([UIImage]) -> Void) {
        let selectedItems = items.filter { ids.contains($0.id) }
        ioQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            let imgs: [UIImage] = selectedItems.compactMap { item in
                let url = self.fileURL(for: item)
                guard let data = try? Data(contentsOf: url) else { return nil }
                return UIImage(data: data)
            }
            DispatchQueue.main.async {
                completion(imgs)
            }
        }
    }

    func deleteItems(withIDs ids: Set<UUID>) {
        let itemsToDelete = items.filter { ids.contains($0.id) }
        for id in ids {
            thumbnails.removeValue(forKey: id)
        }
        items.removeAll { ids.contains($0.id) }
        latestThumbnail = items.first.flatMap { thumbnails[$0.id] }

        let remainingItems = items
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            for item in itemsToDelete {
                try? FileManager.default.removeItem(at: self.fileURL(for: item))
                try? FileManager.default.removeItem(at: self.thumbURL(for: item))
            }
            self.saveManifestOnIOQueue(remainingItems)
        }
    }

    private static func makeThumbnail(from image: UIImage, maxDimension: CGFloat) -> UIImage? {
        let size = image.size
        guard size.width > 0 && size.height > 0 else { return nil }
        let scale = min(maxDimension / max(size.width, size.height), 1.0)
        let targetSize = CGSize(width: max(1, round(size.width * scale)), height: max(1, round(size.height * scale)))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
