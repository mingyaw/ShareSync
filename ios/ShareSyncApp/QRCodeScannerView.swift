import AVFoundation
import SwiftUI

struct QRCodeScannerView: View {
    let onCodeScanned: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        NavigationStack {
            Group {
                switch cameraAuthorizationStatus {
                case .authorized:
                    ZStack {
                        QRCodeScannerRepresentable { code in
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            onCodeScanned(code)
                            dismiss()
                        }
                        .ignoresSafeArea()

                        VStack(spacing: 20) {
                            Spacer()
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(.white, lineWidth: 3)
                                .frame(width: 250, height: 250)
                                .shadow(color: .black.opacity(0.35), radius: 6)
                                .accessibilityHidden(true)
                            Text("ios.qr.align_code")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .background(.black.opacity(0.72))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .padding(.horizontal, 24)
                            Spacer()
                        }
                    }
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
                        Image(systemName: "camera.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("ios.qr.camera_required")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button("ios.qr.open_settings") {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                            openURL(url)
                        }
                        .buttonStyle(.borderedProminent)
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
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
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
