import AVFoundation
import SwiftUI
import UIKit

/// Thin AVCaptureSession wrapper for the BeReal-style back-then-front capture.
/// All session work happens on a private serial queue.
/// `@unchecked Sendable`: all mutable state is only touched on `queue`.
final class CameraService: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "app.buckit.camera")
    private var input: AVCaptureDeviceInput?
    private var continuation: CheckedContinuation<UIImage?, Never>?

    /// The Simulator has no camera, so the capture screen falls back to demo/library photos.
    static var isCameraAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
        #endif
    }

    var hasFrontCamera: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
    }

    /// Requests permission and starts the back camera. Returns false if no camera can be used.
    func start() async -> Bool {
        guard Self.isCameraAvailable else { return false }
        var granted = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            granted = await AVCaptureDevice.requestAccess(for: .video)
        }
        guard granted else { return false }

        return await withCheckedContinuation { cont in
            queue.async {
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo
                let ok = self.attachInput(position: .back)
                if ok, !self.session.outputs.contains(self.output), self.session.canAddOutput(self.output) {
                    self.session.addOutput(self.output)
                }
                self.session.commitConfiguration()
                if ok { self.session.startRunning() }
                cont.resume(returning: ok)
            }
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func switchCamera(to position: AVCaptureDevice.Position) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            queue.async {
                self.session.beginConfiguration()
                _ = self.attachInput(position: position)
                self.session.commitConfiguration()
                cont.resume()
            }
        }
    }

    func capture() async -> UIImage? {
        await withCheckedContinuation { cont in
            queue.async {
                guard self.session.isRunning, self.continuation == nil else {
                    cont.resume(returning: nil)
                    return
                }
                self.continuation = cont
                if let connection = self.output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90 // portrait
                }
                self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            }
        }
    }

    /// Must be called on `queue`.
    private func attachInput(position: AVCaptureDevice.Position) -> Bool {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let newInput = try? AVCaptureDeviceInput(device: device) else { return false }
        if let input { session.removeInput(input) }
        guard session.canAddInput(newInput) else {
            if let input { session.addInput(input) }
            return false
        }
        session.addInput(newInput)
        input = newInput
        return true
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = photo.fileDataRepresentation().flatMap { UIImage(data: $0) }
        queue.async {
            self.continuation?.resume(returning: image)
            self.continuation = nil
        }
    }
}

/// Live camera preview layer.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}
