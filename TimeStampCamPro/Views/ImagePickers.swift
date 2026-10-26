import SwiftUI
import PhotosUI
import UIKit

/// Bộ chọn ảnh từ Thư viện Ảnh (nút "Có sẵn")
struct PhotoLibraryPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) private var presentationMode

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoLibraryPicker

        init(_ parent: PhotoLibraryPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }

            provider.loadObject(ofClass: UIImage.self) { object, _ in
                if let image = object as? UIImage {
                    let normalized = image.normalizedUpOrientation()
                    DispatchQueue.main.async {
                        self.parent.selectedImage = normalized
                    }
                }
            }
        }
    }
}

/// Bảng chia sẻ ảnh iOS (UIActivityViewController) dùng cho SwiftUI sheet
struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Trình hỗ trợ mở bảng Chia sẻ hệ thống iOS (Zalo, Facebook, Messenger, AirDrop...) trực tiếp trên ViewController trên cùng
enum ShareHelper {
    static func presentShareSheet(items: [Any]) {
        guard !items.isEmpty else { return }
        DispatchQueue.main.async {
            let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
            guard let topVC = topViewController() else { return }
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = topVC.view
                popover.sourceRect = CGRect(
                    x: topVC.view.bounds.midX,
                    y: topVC.view.bounds.maxY - 60,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = []
            }
            topVC.present(activityVC, animated: true)
        }
    }

    private static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let root: UIViewController? = base ?? {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let keyWindow = scenes
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? scenes.first?.windows.first
            return keyWindow?.rootViewController
        }()
        if let nav = root as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        if let presented = root?.presentedViewController {
            return topViewController(base: presented)
        }
        return root
    }
}
