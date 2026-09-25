//
//  AIFoodCameraView.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 05.02.26.
//
//  Vollbild-Kamera fuer KI-basierte Mahlzeiten-Erkennung (nur iOS)
//

#if os(iOS)
import SwiftUI
import AVFoundation
import PhotosUI

/// Preference Key fuer die Position des Auswahlrahmens
private struct FrameRectKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

/// Vollbild-Kamera zum Fotografieren von Mahlzeiten fuer die KI-Erkennung
struct AIFoodCameraView: View {
    @Environment(\.dismiss) private var dismiss
    let onImageCaptured: (UIImage) -> Void

    @State private var isAuthorized = false
    @State private var showPermissionDenied = false
    @State private var flashMode: AVCaptureDevice.FlashMode = .off
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var cropFrameRect: CGRect = .zero

    private let frameSize: CGFloat = 280

    var body: some View {
        ZStack {
            if isAuthorized {
                FoodCameraPreview(onPhotoCaptured: handlePhoto, flashMode: flashMode)
                    .ignoresSafeArea()
                cameraOverlay
            } else if showPermissionDenied {
                permissionDeniedView
            } else {
                ProgressView()
            }
        }
        .navigationTitle("ai_camera_title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("cancel") { dismiss() }
            }
        }
        .onPreferenceChange(FrameRectKey.self) { cropFrameRect = $0 }
        .task {
            await requestCameraAccess()
        }
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    // Galerie-Fotos nicht beschneiden
                    handlePhoto(image)
                }
            }
        }
    }

    // MARK: - Kamera-Overlay

    private var cameraOverlay: some View {
        VStack {
            Spacer()

            // Scan-Rahmen — Foto wird auf diesen Bereich zugeschnitten
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.6), lineWidth: 2)
                .frame(width: frameSize, height: frameSize)
                .overlay(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: FrameRectKey.self,
                            value: geo.frame(in: .global)
                        )
                    }
                )

            Spacer()

            // Hinweistext
            Text("ai_camera_hint")
                .font(.subheadline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 16)

            // Buttons: Fotos | Aufnahme | Blitz
            HStack(spacing: 40) {
                // Galerie-Button
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    VStack(spacing: 4) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title2)
                        Text("ai_photos_button")
                            .font(.caption2)
                    }
                    .foregroundStyle(.white)
                }

                // Aufnahme-Button
                Button {
                    NotificationCenter.default.post(
                        name: .capturePhoto,
                        object: nil,
                        userInfo: ["cropRect": NSValue(cgRect: cropFrameRect)]
                    )
                } label: {
                    Circle()
                        .fill(.white)
                        .frame(width: 72, height: 72)
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: 4)
                                .frame(width: 80, height: 80)
                        )
                }

                // Blitz-Button
                Button {
                    toggleFlash()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: flashIcon)
                            .font(.title2)
                        Text("ai_flash_button")
                            .font(.caption2)
                    }
                    .foregroundStyle(.white)
                }
            }
            .padding(.bottom, 40)
        }
    }

    private var flashIcon: String {
        switch flashMode {
        case .on: "bolt.fill"
        case .off: "bolt.slash.fill"
        default: "bolt.fill"
        }
    }

    private func toggleFlash() {
        flashMode = flashMode == .off ? .on : .off
    }

    private var permissionDeniedView: some View {
        ContentUnavailableView {
            Label("camera_permission_title", systemImage: "camera.fill")
        } description: {
            Text("camera_permission_description")
        } actions: {
            Button("open_settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private func requestCameraAccess() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
            if !isAuthorized { showPermissionDenied = true }
        default:
            showPermissionDenied = true
        }
    }

    private func handlePhoto(_ image: UIImage) {
        onImageCaptured(image)
    }
}

// MARK: - Notification fuer Foto-Aufnahme

extension Notification.Name {
    static let capturePhoto = Notification.Name("capturePhoto")
}

// MARK: - Kamera-Vorschau mit Foto-Aufnahme

private struct FoodCameraPreview: UIViewRepresentable {
    let onPhotoCaptured: (UIImage) -> Void
    let flashMode: AVCaptureDevice.FlashMode

    /// Custom UIView das die Preview-Layer bei Layout-Aenderungen aktualisiert
    class PreviewContainerView: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer?

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
    }

    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        let coordinator = context.coordinator

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device)
        else { return view }

        let session = AVCaptureSession()
        session.sessionPreset = .photo
        session.addInput(input)

        let photoOutput = AVCapturePhotoOutput()
        session.addOutput(photoOutput)

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        view.previewLayer = previewLayer

        coordinator.previewLayer = previewLayer
        coordinator.session = session
        coordinator.photoOutput = photoOutput

        Task.detached {
            session.startRunning()
        }

        // Notification beobachten fuer Foto-Aufnahme
        coordinator.observer = NotificationCenter.default.addObserver(
            forName: .capturePhoto,
            object: nil,
            queue: .main
        ) { notification in
            if let value = notification.userInfo?["cropRect"] as? NSValue {
                coordinator.cropFrameRect = value.cgRectValue
            }
            coordinator.capturePhoto(flashMode: coordinator.currentFlashMode)
        }

        return view
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {
        uiView.previewLayer?.frame = uiView.bounds
        context.coordinator.currentFlashMode = flashMode
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPhotoCaptured: onPhotoCaptured)
    }

    class Coordinator: NSObject, AVCapturePhotoCaptureDelegate {
        let onPhotoCaptured: (UIImage) -> Void
        var previewLayer: AVCaptureVideoPreviewLayer?
        var session: AVCaptureSession?
        var photoOutput: AVCapturePhotoOutput?
        var observer: NSObjectProtocol?
        var currentFlashMode: AVCaptureDevice.FlashMode = .off
        var cropFrameRect: CGRect = .zero
        private var hasCapture = false

        init(onPhotoCaptured: @escaping (UIImage) -> Void) {
            self.onPhotoCaptured = onPhotoCaptured
        }

        deinit {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
            session?.stopRunning()
        }

        func capturePhoto(flashMode: AVCaptureDevice.FlashMode) {
            guard !hasCapture, let photoOutput else { return }

            let settings = AVCapturePhotoSettings()
            if photoOutput.supportedFlashModes.contains(flashMode) {
                settings.flashMode = flashMode
            }

            photoOutput.capturePhoto(with: settings, delegate: self)
        }

        func photoOutput(
            _ output: AVCapturePhotoOutput,
            didFinishProcessingPhoto photo: AVCapturePhoto,
            error: Error?
        ) {
            guard !hasCapture,
                  error == nil,
                  let data = photo.fileDataRepresentation(),
                  let image = UIImage(data: data)
            else { return }

            hasCapture = true
            session?.stopRunning()
            let cropped = cropToFrame(image)
            onPhotoCaptured(cropped)
        }

        /// Beschneidet das Foto auf den sichtbaren Auswahlrahmen
        private func cropToFrame(_ image: UIImage) -> UIImage {
            guard !cropFrameRect.isEmpty,
                  let previewLayer
            else { return image }

            let viewSize = previewLayer.frame.size
            guard viewSize.width > 0, viewSize.height > 0 else { return image }

            // Orientierung korrigieren (CGImage-Daten sind oft rotiert)
            let renderer = UIGraphicsImageRenderer(size: image.size)
            let fixedImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: image.size))
            }
            guard let cgImage = fixedImage.cgImage else { return image }

            let imageW = CGFloat(cgImage.width)
            let imageH = CGFloat(cgImage.height)

            // Aspect-Fill-Mapping: wie die Kamera-Vorschau das Bild skaliert
            let viewAR = viewSize.width / viewSize.height
            let imageAR = imageW / imageH

            let scale: CGFloat
            let offsetX: CGFloat
            let offsetY: CGFloat

            if imageAR > viewAR {
                // Bild breiter als Vorschau — links/rechts abgeschnitten
                scale = imageH / viewSize.height
                offsetX = (imageW - viewSize.width * scale) / 2
                offsetY = 0
            } else {
                // Bild hoeher als Vorschau — oben/unten abgeschnitten
                scale = imageW / viewSize.width
                offsetX = 0
                offsetY = (imageH - viewSize.height * scale) / 2
            }

            // Rahmen-Koordinaten in Pixel-Koordinaten umrechnen
            let pixelX = offsetX + cropFrameRect.origin.x * scale
            let pixelY = offsetY + cropFrameRect.origin.y * scale
            let pixelW = cropFrameRect.width * scale
            let pixelH = cropFrameRect.height * scale

            var pixelRect = CGRect(x: pixelX, y: pixelY, width: pixelW, height: pixelH)
            pixelRect = pixelRect.intersection(
                CGRect(x: 0, y: 0, width: imageW, height: imageH)
            )

            guard !pixelRect.isEmpty,
                  let cropped = cgImage.cropping(to: pixelRect)
            else { return image }

            return UIImage(cgImage: cropped)
        }
    }
}
#endif
