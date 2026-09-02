import AVFoundation
import SwiftUI

struct QRCodeScannerView: View {
    let onCodeScanned: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        NavigationStack {
            Group {
                switch cameraAuthorizationStatus {
                case .authorized:
                    QRCodeScannerRepresentable { code in
                        onCodeScanned(code)
                        dismiss()
                    }
                    .ignoresSafeArea()
                case .notDetermined:
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("ios.qr.preparing_camera")
                            .foregroundStyle(.secondary)
                    }
                    .task {
                        let granted = await AVCaptureDevice.requestAccess(for: .video)
                        cameraAuthorizationStatus = granted ? .authorized : .denied
                    }
                default:
                    VStack(alignment: .center, spacing: 16) {
                        Text("ios.qr.camera_required")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("ios.qr.scan_pairing_qr")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("ios.qr.close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct QRCodeScannerRepresentable: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> QRCodeScannerViewController {
        let viewController = QRCodeScannerViewController()
        viewController.onCodeScanned = onCodeScanned
        return viewController
    }

    func updateUIViewController(_ uiViewController: QRCodeScannerViewController, context: Context) {
    }
}

private final class QRCodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeScanned: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScannedCode = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [session] in
                session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            session.stopRunning()
        }
    }

    private func configureSession() {
        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            return
        }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            return
        }

        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasScannedCode,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let value = object.stringValue else {
            return
        }

        hasScannedCode = true
        onCodeScanned?(value)
    }
}
