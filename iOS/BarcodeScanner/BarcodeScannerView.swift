//
//  BarcodeScannerView.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//
//  Barcode-Scanner nur fuer iOS/iPadOS (AVFoundation)
//

#if os(iOS)
import SwiftUI
import AVFoundation

/// Barcode-Scanner View mit Kamera-Vorschau
struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onBarcodeScanned: (String) -> Void

    @State private var isAuthorized = false
    @State private var showPermissionDenied = false

    var body: some View {
        ZStack {
            if isAuthorized {
                CameraPreviewView(onBarcodeScanned: { barcode in
                    onBarcodeScanned(barcode)
                    dismiss()
                })
                .ignoresSafeArea()

                // Scan-Overlay
                scanOverlay
            } else if showPermissionDenied {
                permissionDeniedView
            } else {
                ProgressView()
            }
        }
        .navigationTitle("barcode_scanner_title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("cancel") { dismiss() }
            }
        }
        .task {
            await requestCameraAccess()
        }
    }

    private var scanOverlay: some View {
        VStack {
            Spacer()
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white, lineWidth: 2)
                .frame(width: 250, height: 150)
                .background(.clear)
            Spacer()
            Text("barcode_scan_hint")
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(.bottom, 40)
        }
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
}

// MARK: - Kamera-Vorschau mit Barcode-Erkennung

private struct CameraPreviewView: UIViewRepresentable {
    let onBarcodeScanned: (String) -> Void

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

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device)
        else { return view }

        let session = AVCaptureSession()
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        session.addOutput(output)
        output.setMetadataObjectsDelegate(coordinator, queue: .main)
        output.metadataObjectTypes = [.ean13, .ean8, .upce]

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        view.previewLayer = previewLayer

        coordinator.previewLayer = previewLayer
        coordinator.session = session

        Task.detached {
            session.startRunning()
        }

        return view
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {
        uiView.previewLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcodeScanned: onBarcodeScanned)
    }

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onBarcodeScanned: (String) -> Void
        var previewLayer: AVCaptureVideoPreviewLayer?
        var session: AVCaptureSession?
        private var hasScanned = false

        init(onBarcodeScanned: @escaping (String) -> Void) {
            self.onBarcodeScanned = onBarcodeScanned
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard !hasScanned,
                  let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let barcode = object.stringValue
            else { return }

            hasScanned = true
            session?.stopRunning()
            onBarcodeScanned(barcode)
        }
    }
}
#endif
