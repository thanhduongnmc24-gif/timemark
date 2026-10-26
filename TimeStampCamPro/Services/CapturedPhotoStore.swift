import Foundation
import UIKit
import SwiftUI

struct CapturedPhotoItem: Identifiable, Codable, Hashable {
    let id: UUID
    let fileName: String
    let createdAt: Date
    let captionText: String

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "HH:mm - dd/MM/yyyy"
        return formatter.string(from: createdAt)
    }

    var shortTimeBadge: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "HH:mm dd/MM"
        return formatter.string(from: createdAt)
    }
}

final class CapturedPhotoStore: ObservableObject {
    @Published private(set) var items: [CapturedPhotoItem] = []

    private let folderName = "TimeMarkCapturedPhotos"
    private let manifestFileName = "manifest.json"
    private var thumbnailCache: [UUID: UIImage] = [:]

    init() {
        createFolderIfNeeded()
        loadManifest()
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

    private func loadManifest() {
        createFolderIfNeeded()
        guard let data = try? Data(contentsOf: manifestURL),
              let decoded = try? JSONDecoder().decode([CapturedPhotoItem].self, from: data) else {
            items = []
            return
        }
        // Chỉ giữ lại các ảnh còn tồn tại file thực tế trên bộ nhớ ứng dụng
        let validItems = decoded.filter { item in
            FileManager.default.fileExists(atPath: fileURL(for: item).path)
        }
        items = validItems.sorted(by: { $0.createdAt > $1.createdAt })
    }

    private func saveManifest() {
        createFolderIfNeeded()
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: manifestURL, options: .atomic)
        }
    }

    @discardableResult
    func addCapturedPhoto(_ image: UIImage, caption: String = "") -> CapturedPhotoItem? {
        createFolderIfNeeded()
        let id = UUID()
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "timemark_\(timestamp)_\(id.uuidString.prefix(8)).jpg"
        let targetURL = folderURL.appendingPathComponent(fileName)

        guard let jpegData = image.jpegData(compressionQuality: 0.94) else {
            return nil
        }

        do {
            try jpegData.write(to: targetURL, options: .atomic)
            let newItem = CapturedPhotoItem(
                id: id,
                fileName: fileName,
                createdAt: Date(),
                captionText: caption
            )
            if let thumb = Self.makeThumbnail(from: image, maxDimension: 360) {
                thumbnailCache[id] = thumb
            }
            DispatchQueue.main.async {
                self.items.insert(newItem, at: 0)
                self.saveManifest()
            }
            return newItem
        } catch {
            return nil
        }
    }

    func thumbnailImage(for item: CapturedPhotoItem) -> UIImage? {
        if let cached = thumbnailCache[item.id] {
            return cached
        }
        guard let full = fullImage(for: item) else { return nil }
        let thumb = Self.makeThumbnail(from: full, maxDimension: 360) ?? full
        thumbnailCache[item.id] = thumb
        return thumb
    }

    func fullImage(for item: CapturedPhotoItem) -> UIImage? {
        let url = fileURL(for: item)
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }

    func fullImages(for ids: Set<UUID>) -> [UIImage] {
        // Giữ thứ tự từ mới đến cũ theo danh sách items
        return items
            .filter { ids.contains($0.id) }
            .compactMap { fullImage(for: $0) }
    }

    func deleteItems(withIDs ids: Set<UUID>) {
        for item in items where ids.contains(item.id) {
            let url = fileURL(for: item)
            try? FileManager.default.removeItem(at: url)
            thumbnailCache.removeValue(forKey: item.id)
        }
        items.removeAll { ids.contains($0.id) }
        saveManifest()
    }

    private static func makeThumbnail(from image: UIImage, maxDimension: CGFloat) -> UIImage? {
        let size = image.size
        guard size.width > 0 && size.height > 0 else { return nil }
        let scale = min(maxDimension / max(size.width, size.height), 1.0)
        let targetSize = CGSize(width: round(size.width * scale), height: round(size.height * scale))
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
