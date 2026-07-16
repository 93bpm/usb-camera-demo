//
//  ExternalCameraViewController.swift
//  ExternalCamera
//
//  Created by 93bpm on 1/30/26.
//

import UIKit
import AVFoundation

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
    
    var formats: [AVCaptureDevice.Format] { camera?.formats ?? [] }
    
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
                
                DispatchQueue.global().async {
                    self.captureSession?.stopRunning()
                    
                    self.captureSession?.inputs.forEach { self.captureSession?.removeInput($0) }
                    self.captureSession?.outputs.forEach { self.captureSession?.removeOutput($0) }
                    
                    self.captureSession = nil
                }
                
                self.camera = nil
                self.photoOutput = nil
                self.activeFormat = nil
                
                self.previewLayer?.contents = nil
                self.previewLayer?.removeFromSuperlayer()
                self.previewLayer = nil
                
                if devices.isEmpty {
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
        
        captureSession = AVCaptureSession()
        
        guard let camera, let captureSession else { return }
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
        } catch {
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
            
            connection.videoRotationAngle = 0
        }
        
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
        
        DispatchQueue.global().async {
            captureSession.startRunning()
        }
    }
}
