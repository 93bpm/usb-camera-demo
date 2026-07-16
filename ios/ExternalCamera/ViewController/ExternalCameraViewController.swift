//
//  ExternalCameraViewController.swift
//  ExternalCamera
//
//  Created by 93bpm on 1/30/26.
//

import UIKit
import AVFoundation

import SnapKit
import Then

protocol ExternalCameraViewControllerDelegate: AnyObject {
    
    func cameraViewControllerDidDisconnect(_ viewController: ExternalCameraViewController)
    
    func cameraViewController(
        _ viewController: ExternalCameraViewController,
        didFailWithError error: Error
    )
    
    func cameraViewController(
        _ viewController: ExternalCameraViewController,
        didFinishCapture result: Result<UIImage, Error>
    )
}


class ExternalCameraViewController: UIViewController {
    
    weak var delegate: ExternalCameraViewControllerDelegate?
    
    private let discoverySession: AVCaptureDevice.DiscoverySession
    private var deviceObservation: NSKeyValueObservation?
    private var formatObservation: NSKeyValueObservation?
    
    private(set) var camera: AVCaptureDevice?
    private var activeFormat: AVCaptureDevice.Format?
    
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    
    private var previewLayer: AVCaptureVideoPreviewLayer?

    // 연결 상태 안내 UI (미연결·중단·오류 시 표시)
    private let placeholderView = UIView()
    private let placeholderImageView = UIImageView()
    private let placeholderLabel = UILabel()
    
    var formats: [AVCaptureDevice.Format] { camera?.formats ?? [] }

    private(set) var previewRotationAngle: CGFloat = 0

    var supportedRotationAngles: [CGFloat] {
        guard let connection = previewLayer?.connection else { return [] }

        let angles: [CGFloat] = [0, 90, 180, 270]
        return angles.filter { connection.isVideoRotationAngleSupported($0) }
    }
    
    init() {
        
        discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external],
            mediaType: .video,
            position: .unspecified
        )
        
        super.init(nibName: nil, bundle: nil)
        
        camera = discoverySession.devices.first
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupPlaceholder()
        setupNotifications()
        setupObservations()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        DispatchQueue.global().async {
            self.captureSession?.stopRunning()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // 레이아웃이 바뀌면 프리뷰 프레임만 갱신 (세션 재구성은 setupExternalCamera 내부에서 1회만 수행)
        previewLayer?.frame = view.bounds
        
        setupExternalCamera()
    }
    
    @objc
    private func didBecomeActive(_ notification: Notification) {
        DispatchQueue.global().async {
            self.captureSession?.startRunning()
        }
    }
    
    @objc
    private func willResignActive(_ notification: Notification) {
        DispatchQueue.global().async {
            self.captureSession?.stopRunning()
        }
    }

    @objc
    private func sessionRuntimeError(_ notification: Notification) {
        let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError
        print("External Camera Runtime Error:", error?.localizedDescription ?? "unknown")

        DispatchQueue.main.async {
            self.showPlaceholder("카메라 오류가 발생했습니다\n재연결을 시도합니다…")
        }

        // 일시적 오류(미디어 서비스 리셋 등)는 세션 재시작으로 복구 시도
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self, let session = self.captureSession else { return }

            session.startRunning()

            DispatchQueue.main.async {
                if session.isRunning {
                    self.hidePlaceholder()
                } else {
                    self.showPlaceholder("카메라를 복구하지 못했습니다\n케이블을 뽑았다가 다시 연결해주세요")
                }
            }
        }
    }

    @objc
    private func sessionWasInterrupted(_ notification: Notification) {
        var message = "카메라가 일시 중지되었습니다"

        if let value = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int,
           let reason = AVCaptureSession.InterruptionReason(rawValue: value) {
            switch reason {
            case .videoDeviceNotAvailableInBackground:
                message = "백그라운드에서는 카메라를 사용할 수 없습니다"
            case .videoDeviceInUseByAnotherClient:
                message = "다른 앱이 카메라를 사용 중입니다"
            case .videoDeviceNotAvailableWithMultipleForegroundApps:
                message = "멀티태스킹 중에는 카메라를 사용할 수 없습니다"
            case .videoDeviceNotAvailableDueToSystemPressure:
                message = "시스템 부하로 카메라가 일시 중지되었습니다"
            default:
                break
            }
        }

        DispatchQueue.main.async {
            self.showPlaceholder(message)
        }
    }

    @objc
    private func sessionInterruptionEnded(_ notification: Notification) {
        // 중단이 끝나면 세션은 자동으로 재개됨 → 안내만 숨김
        DispatchQueue.main.async {
            self.hidePlaceholder()
        }
    }

    func didChangeFormat(_ format: AVCaptureDevice.Format) {
        guard let camera else { return }
        
        activeFormat = format
        
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            self.captureSession?.stopRunning()
            
            do {
                try camera.lockForConfiguration()
                camera.activeFormat = format
                camera.unlockForConfiguration()
            } catch {
                self.delegate?.cameraViewController(self, didFailWithError: error)
            }
            
            self.captureSession?.startRunning()
        }
    }
    
    func handleCapture() {
        photoOutput?.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    /// 프리뷰 회전 각도 변경 (프리뷰에만 적용되며 캡처 이미지에는 영향 없음)
    @discardableResult
    func didChangeRotation(_ angle: CGFloat) -> Bool {
        guard let connection = previewLayer?.connection,
              connection.isVideoRotationAngleSupported(angle) else {
            return false
        }

        connection.videoRotationAngle = angle
        previewRotationAngle = angle
        return true
    }
    
    deinit {
        deviceObservation?.invalidate()
        formatObservation?.invalidate()
    }
}

extension ExternalCameraViewController: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: (any Error)?
    ) {
        if let error {
            delegate?.cameraViewController(self, didFinishCapture: .failure(error))
        }
        
        if let data = photo.fileDataRepresentation(), let image = UIImage(data: data) {
            
            // 캡처된 이미지가 회전되어 있을 경우 이미지 회전 로직
            /*
            var rotatedImage = image
            
            UIGraphicsBeginImageContext(CGSize(width: image.size.height, height: image.size.width))
            if let context = UIGraphicsGetCurrentContext() {
                context.translateBy(x: image.size.height / 2, y: image.size.width / 2)
                context.rotate(by: .pi / 2)
                
                image.draw(in: CGRect(x: -image.size.width / 2, y: -image.size.height / 2, width: image.size.width, height: image.size.height))
                
                if let image = UIGraphicsGetImageFromCurrentImageContext() {
                    rotatedImage = image
                }
                
                UIGraphicsEndImageContext()
            }
            */
            
            delegate?.cameraViewController(self, didFinishCapture: .success(image))
        }
    }
}

private extension ExternalCameraViewController {

    static let waitingMessage = "외장 카메라를 연결해주세요\niPadOS 17 이상 · USB-C · UVC 카메라 지원"

    func setupPlaceholder() {

        view.backgroundColor = .black

        placeholderImageView.do {
            $0.image = UIImage(systemName: "video.slash")
            $0.tintColor = .darkGray
            $0.contentMode = .scaleAspectFit
        }

        placeholderLabel.do {
            $0.text = Self.waitingMessage
            $0.textColor = .lightGray
            $0.font = .systemFont(ofSize: 16, weight: .medium)
            $0.textAlignment = .center
            $0.numberOfLines = 0
        }

        view.addSubview(placeholderView)
        placeholderView.addSubview(placeholderImageView)
        placeholderView.addSubview(placeholderLabel)

        placeholderView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.width.lessThanOrEqualToSuperview().inset(24)
        }

        placeholderImageView.snp.makeConstraints {
            $0.top.centerX.equalToSuperview()
            $0.size.equalTo(48)
        }

        placeholderLabel.snp.makeConstraints {
            $0.top.equalTo(placeholderImageView.snp.bottom).offset(12)
            $0.left.right.bottom.equalToSuperview()
        }
    }

    func showPlaceholder(_ message: String) {
        // 같은 문구면 갱신하지 않음 (불필요한 레이아웃 반복 방지)
        if placeholderLabel.text != message {
            placeholderLabel.text = message
        }
        placeholderView.isHidden = false
    }

    func hidePlaceholder() {
        placeholderView.isHidden = true
    }

    /// 연결된 카메라 정보 출력 (인식 문제 트러블슈팅용)
    func logCameraInfo(_ camera: AVCaptureDevice) {
        print("=== External Camera Connected ===")
        print("이름:", camera.localizedName)
        print("모델 ID:", camera.modelID)
        print("고유 ID:", camera.uniqueID)
        print("지원 포맷: \(camera.formats.count)개")

        camera.formats.forEach { format in
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)

            let ranges = format.videoSupportedFrameRateRanges
            let minFrame = Int(ranges.map { $0.minFrameRate }.min() ?? 0)
            let maxFrame = Int(ranges.map { $0.maxFrameRate }.max() ?? 0)

            print("- \(dimensions.width)x\(dimensions.height) @ \(minFrame)-\(maxFrame)fps")
        }
        print("=================================")
    }
    
    func setupNotifications() {
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(willResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        // 세션 오류·중단 감지 (외장 카메라 인식 실패/중단 대응)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionRuntimeError),
            name: AVCaptureSession.runtimeErrorNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionWasInterrupted),
            name: AVCaptureSession.wasInterruptedNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionInterruptionEnded),
            name: AVCaptureSession.interruptionEndedNotification,
            object: nil
        )
    }
    
    func setupObservations() {
        
        setupDeviceObservation()
        setupFormatObservation()
    }
    
    private func setupDeviceObservation() {
        
        deviceObservation = discoverySession.observe(\.devices, options: [.new, .old]) { [weak self] _, change in
            guard let self else { return }
            DispatchQueue.main.async {
                
                defer { self.setupFormatObservation() }
                
                // 외부 카메라 디바이스만 확인
                let devices = (change.newValue ?? []).filter {
                    $0.deviceType == .external && $0.hasMediaType(.video)
                }
                
                // 기존 세션을 로컬로 옮기고 참조를 먼저 비움 (직후 setupExternalCamera가 만드는 새 세션을 지우지 않도록)
                let oldSession = self.captureSession
                self.captureSession = nil

                DispatchQueue.global().async {
                    oldSession?.stopRunning()
                    
                    oldSession?.inputs.forEach { oldSession?.removeInput($0) }
                    oldSession?.outputs.forEach { oldSession?.removeOutput($0) }
                    
                }
                
                self.camera = nil
                self.photoOutput = nil
                self.activeFormat = nil
                
                self.previewLayer?.contents = nil
                self.previewLayer?.removeFromSuperlayer()
                self.previewLayer = nil
                
                if devices.isEmpty {
                    self.showPlaceholder(Self.waitingMessage)
                    self.delegate?.cameraViewControllerDidDisconnect(self)
                } else {
                    let camera = devices.first
                    
                    self.activeFormat = camera?.activeFormat
                    self.camera = camera
                    self.setupExternalCamera()
                }
            }
        }
    }
    
    private func setupFormatObservation() {
        if let formatObservation {
            formatObservation.invalidate()
        }
        
        formatObservation = camera?.observe(\.activeFormat, options: [.new, .old]) { [weak self] device, change in
            
            guard let activeFormat = self?.activeFormat, activeFormat != change.newValue else {
                return
            }
            
            DispatchQueue.global().async {
                do {
                    try device.lockForConfiguration()
                    device.activeFormat = activeFormat
                    device.unlockForConfiguration()
                } catch {
                    guard let self else { return }
                    self.delegate?.cameraViewController(self, didFailWithError: error)
                }
            }
        }
    }
    
    func setupExternalCamera() {
        
        // 이미 구성된 세션이 있으면 재구성하지 않음 (레이아웃 변경 때마다 프리뷰가 재생성되는 것 방지)
        guard captureSession == nil else { return }

        // 카메라가 없으면 연결 안내만 표시
        guard camera != nil else {
            showPlaceholder(Self.waitingMessage)
            return
        }

        captureSession = AVCaptureSession()
        
        guard let camera, let captureSession else { return }

        logCameraInfo(camera)
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
        } catch {
            showPlaceholder("카메라 입력을 구성하지 못했습니다\n케이블과 전원(허브)을 확인해주세요")
            delegate?.cameraViewController(self, didFailWithError: error)
        }
        
        photoOutput = AVCapturePhotoOutput()
        if let photoOutput, captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspect
        previewLayer.zPosition = -1
        
        if let connection = previewLayer.connection {
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
            
            // 기본은 회전 없음(0). 회전 버튼으로 선택한 각도가 있으면 재연결 시에도 유지
            if connection.isVideoRotationAngleSupported(previewRotationAngle) {
                connection.videoRotationAngle = previewRotationAngle
            }
        }
        
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
        
        DispatchQueue.global().async { [weak self] in
            captureSession.startRunning()

            DispatchQueue.main.async {
                guard let self else { return }

                if captureSession.isRunning {
                    self.hidePlaceholder()
                } else {
                    // 세션 시작 실패 (전력 부족, USB 대역폭 초과 등)
                    self.showPlaceholder("카메라 영상을 시작하지 못했습니다\n케이블·전원을 확인하거나 낮은 해상도로 시도해보세요")
                }
            }
        }
    }
}
