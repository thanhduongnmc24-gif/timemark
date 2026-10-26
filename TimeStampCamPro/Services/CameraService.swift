import Foundation
import AVFoundation
import UIKit
import SwiftUI

final class CameraService: NSObject, ObservableObject {
    @Published var isAuthorized: Bool = false
    @Published var isFlashOn: Bool = false
    @Published var currentZoomFactor: CGFloat = 1.0
    @Published var isUsingFrontCamera: Bool = false
    @Published var capturedImage: UIImage? = nil
    @Published var cameraErrorMessage: String? = nil

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.timestampcam.pro.camera.queue")
    private let photoOutput = AVCapturePhotoOutput()
    private var currentVideoInput: AVCaptureDeviceInput?
    private var photoCaptureCompletion: ((UIImage?) -> Void)?

    override init() {
        super.init()
        checkPermissionsAndSetup()
    }

    func checkPermissionsAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async {
                self.isAuthorized = true
            }
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.isAuthorized = granted
                }
                if granted {
                    self.setupSession()
                }
            }
        default:
            DispatchQueue.main.async {
                self.isAuthorized = false
                self.cameraErrorMessage = "Chưa cấp quyền Camera. Bạn vẫn có thể chọn ảnh từ mục 'Có sẵn' hoặc 'Tệp' bên dưới."
            }
        }
    }

    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            let position: AVCaptureDevice.Position = self.isUsingFrontCamera ? .front : .back
            guard let device = Self.bestCameraDevice(for: position) else {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    self.cameraErrorMessage = "Không tìm thấy thiết bị Camera."
                }
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)
                if let currentInput = self.currentVideoInput {
                    self.session.removeInput(currentInput)
                }
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.currentVideoInput = input
                }

                if self.session.outputs.isEmpty && self.session.canAddOutput(self.photoOutput) {
                    self.session.addOutput(self.photoOutput)
                    self.photoOutput.isHighResolutionCaptureEnabled = true
                }

                self.session.commitConfiguration()
                if !self.session.isRunning {
                    self.session.startRunning()
                }
            } catch {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    self.cameraErrorMessage = "Lỗi khởi tạo Camera: \(error.localizedDescription)"
                }
            }
        }
    }

    private static func bestCameraDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if position == .back {
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [
                    .builtInTripleCamera,
                    .builtInDualWideCamera,
                    .builtInDualCamera,
                    .builtInWideAngleCamera
                ],
                mediaType: .video,
                position: .back
            )
            return discovery.devices.first
        } else {
            return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        }
    }

    func switchCamera() {
        isUsingFrontCamera.toggle()
        currentZoomFactor = 1.0
        setupSession()
    }

    func toggleFlash() {
        isFlashOn.toggle()
    }

    func setZoom(factor: CGFloat) {
        DispatchQueue.main.async {
            self.currentZoomFactor = factor
        }
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let device = self.currentVideoInput?.device else { return }
            do {
                try device.lockForConfiguration()
                let minZoom = device.minAvailableVideoZoomFactor
                let maxZoom = min(device.maxAvailableVideoZoomFactor, 15.0)
                // Map UI zoom (0.5x, 1x, 2x, 10x) safely within hardware zoom range
                let targetZoom = max(minZoom, min(factor, maxZoom))
                device.videoZoomFactor = targetZoom
                device.unlockForConfiguration()
            } catch {
                // Ignore zoom configuration error on unsupported lens
            }
        }
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        guard session.isRunning else {
            completion(nil)
            return
        }
        self.photoCaptureCompletion = completion

        let settings = AVCapturePhotoSettings()
        if let device = currentVideoInput?.device, device.hasFlash {
            settings.flashMode = isFlashOn ? .on : .off
        }
        settings.isHighResolutionPhotoEnabled = true

        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let rawImage = UIImage(data: data) else {
            DispatchQueue.main.async {
                self.photoCaptureCompletion?(nil)
                self.photoCaptureCompletion = nil
            }
            return
        }

        let normalized = rawImage.normalizedUpOrientation()
        DispatchQueue.main.async {
            self.capturedImage = normalized
            self.photoCaptureCompletion?(normalized)
            self.photoCaptureCompletion = nil
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    final class VideoPreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }

    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        if let connection = view.videoPreviewLayer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        return view
    }

    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        if uiView.videoPreviewLayer.session != session {
            uiView.videoPreviewLayer.session = session
        }
    }
}

extension UIImage {
    func normalizedUpOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized ?? self
    }
}
