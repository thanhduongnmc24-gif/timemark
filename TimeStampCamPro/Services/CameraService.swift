import Foundation
import AVFoundation
import UIKit
import SwiftUI

enum CaptureMode: String, CaseIterable {
    case photo = "ẢNH"
    case video = "VIDEO"
}

final class CameraService: NSObject, ObservableObject {
    @Published var isAuthorized: Bool = false
    @Published var isFlashOn: Bool = false
    @Published var currentZoomFactor: CGFloat = 1.0
    @Published var isUsingFrontCamera: Bool = false
    @Published var cameraErrorMessage: String? = nil

    // Trạng thái quay phim (Video)
    @Published var isRecordingVideo: Bool = false
    @Published var recordingSeconds: Int = 0

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.timestampcam.pro.camera.queue", qos: .userInitiated)
    private let photoProcessingQueue = DispatchQueue(label: "com.timestampcam.pro.photo.processing", qos: .userInitiated)
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var currentVideoInput: AVCaptureDeviceInput?
    private var currentAudioInput: AVCaptureDeviceInput?

    private var photoCaptureCompletion: ((UIImage?) -> Void)?
    private var videoRecordingCompletion: ((URL?) -> Void)?
    private var recordingTimer: Timer?

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
                self.cameraErrorMessage = "Chưa cấp quyền Camera. Bạn vẫn có thể chọn ảnh từ mục 'Có sẵn' bên dưới."
            }
        }
    }

    private func ensureAudioInputOnSessionQueue() {
        guard currentAudioInput == nil else { return }
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
            return
        }
        guard status == .authorized,
              let audioDevice = AVCaptureDevice.default(for: .audio),
              let audioInput = try? AVCaptureDeviceInput(device: audioDevice) else { return }
        session.beginConfiguration()
        if session.canAddInput(audioInput) {
            session.addInput(audioInput)
            currentAudioInput = audioInput
        }
        session.commitConfiguration()
    }

    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()
            if self.session.canSetSessionPreset(.photo) {
                self.session.sessionPreset = .photo
            } else if self.session.canSetSessionPreset(.high) {
                self.session.sessionPreset = .high
            }

            let position: AVCaptureDevice.Position = self.isUsingFrontCamera ? .front : .back
            guard let videoDevice = Self.bestCameraDevice(for: position) else {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    self.cameraErrorMessage = "Không tìm thấy thiết bị Camera."
                }
                return
            }

            do {
                let videoInput = try AVCaptureDeviceInput(device: videoDevice)
                if let currentInput = self.currentVideoInput {
                    self.session.removeInput(currentInput)
                }
                if self.session.canAddInput(videoInput) {
                    self.session.addInput(videoInput)
                    self.currentVideoInput = videoInput
                }

                if !self.session.outputs.contains(self.photoOutput) && self.session.canAddOutput(self.photoOutput) {
                    self.session.addOutput(self.photoOutput)
                    self.photoOutput.isHighResolutionCaptureEnabled = true
                    if #available(iOS 13.0, *) {
                        self.photoOutput.maxPhotoQualityPrioritization = .balanced
                    }
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
        guard !isRecordingVideo else { return }
        isUsingFrontCamera.toggle()
        currentZoomFactor = 1.0
        setupSession()
    }

    func toggleFlash() {
        isFlashOn.toggle()
        let flashTarget = isFlashOn
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let device = self.currentVideoInput?.device,
                  device.hasTorch else { return }
            do {
                try device.lockForConfiguration()
                if self.isRecordingVideo && flashTarget {
                    try device.setTorchModeOn(level: 1.0)
                } else {
                    device.torchMode = .off
                }
                device.unlockForConfiguration()
            } catch {}
        }
    }

    func setZoom(factor: CGFloat) {
        currentZoomFactor = factor
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let device = self.currentVideoInput?.device else { return }
            do {
                try device.lockForConfiguration()
                let minZoom = device.minAvailableVideoZoomFactor
                let maxZoom = min(device.maxAvailableVideoZoomFactor, 15.0)
                let targetZoom = max(minZoom, min(factor, maxZoom))
                device.videoZoomFactor = targetZoom
                device.unlockForConfiguration()
            } catch {}
        }
    }

    /// Chụp ảnh phản hồi tức thì (Zero Shutter Lag), gọi callback ở luồng xử lý nền
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        let wantFlash = isFlashOn
        sessionQueue.async { [weak self] in
            guard let self = self, self.session.isRunning else {
                completion(nil)
                return
            }
            self.photoCaptureCompletion = completion

            let settings = AVCapturePhotoSettings()
            if wantFlash,
               let device = self.currentVideoInput?.device,
               device.hasFlash,
               self.photoOutput.supportedFlashModes.contains(.on) {
                settings.flashMode = .on
            } else if self.photoOutput.supportedFlashModes.contains(.off) {
                settings.flashMode = .off
            }
            if #available(iOS 13.0, *) {
                settings.photoQualityPrioritization = .speed
            }

            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func startVideoRecording(completion: @escaping (URL?) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self, self.session.isRunning && !self.movieOutput.isRecording else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            self.videoRecordingCompletion = completion

            // Chỉ gắn MovieOutput & Audio khi thực sự bấm Quay Video để chế độ Chụp Ảnh luôn nhanh tuyệt đối
            self.ensureAudioInputOnSessionQueue()
            self.session.beginConfiguration()
            if self.session.canSetSessionPreset(.high) {
                self.session.sessionPreset = .high
            }
            if !self.session.outputs.contains(self.movieOutput) && self.session.canAddOutput(self.movieOutput) {
                self.session.addOutput(self.movieOutput)
            }
            self.session.commitConfiguration()

            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("raw_video_\(Int(Date().timeIntervalSince1970)).mov")
            try? FileManager.default.removeItem(at: fileURL)

            if let connection = self.movieOutput.connection(with: .video),
               connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if let device = self.currentVideoInput?.device, device.hasTorch {
                try? device.lockForConfiguration()
                device.torchMode = self.isFlashOn ? .on : .off
                device.unlockForConfiguration()
            }
            self.movieOutput.startRecording(to: fileURL, recordingDelegate: self)
            DispatchQueue.main.async {
                self.isRecordingVideo = true
                self.recordingSeconds = 0
                self.recordingTimer?.invalidate()
                self.recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                    self?.recordingSeconds += 1
                }
            }
        }
    }

    func stopVideoRecording() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.movieOutput.isRecording else { return }
            self.movieOutput.stopRecording()
            if let device = self.currentVideoInput?.device, device.hasTorch {
                try? device.lockForConfiguration()
                device.torchMode = .off
                device.unlockForConfiguration()
            }
        }
    }

    var formattedRecordingDuration: String {
        let mins = recordingSeconds / 60
        let secs = recordingSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let completion = self.photoCaptureCompletion
        self.photoCaptureCompletion = nil

        guard error == nil, let data = photo.fileDataRepresentation() else {
            completion?(nil)
            return
        }

        // Giải mã ảnh hoàn toàn trên luồng nền để không làm khựng giao diện chính dù chỉ 1ms
        photoProcessingQueue.async {
            let rawImage = UIImage(data: data)
            completion?(rawImage)
        }
    }
}

extension CameraService: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async {
            self.recordingTimer?.invalidate()
            self.recordingTimer = nil
            self.isRecordingVideo = false
            if error == nil {
                self.videoRecordingCompletion?(outputFileURL)
            } else {
                self.videoRecordingCompletion?(nil)
            }
            self.videoRecordingCompletion = nil
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
