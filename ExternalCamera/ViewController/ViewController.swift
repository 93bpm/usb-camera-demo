//
//  ViewController.swift
//  ExternalCamera
//
//  Created by 93bpm on 1/30/26.
//

import UIKit
import AVFoundation

import SnapKit
import Then

class ViewController: UIViewController {

    lazy var cameraController = ExternalCameraViewController().then {
        $0.delegate = self
    }
    
    private var resolutionPopup: ResolutionPopup?
    
    private var buttonView = UIView()
    
    // TODO: 캡처 목록 표시 기능 추가 필요
    private var albumButton = UIButton()
    
    private var captureButton = UIButton()
    private var resolutionButton = UIButton()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupControls()
        setupActions()
        setupLayout()
        
        FileManager.default.createDirectory()
    }

    @objc
    private func didTapButton(_ button: UIButton) {
        button.isEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            button.isEnabled = true
        }
        
        switch button {
        case captureButton   : handleCapture()
        case resolutionButton: handleResolution()
        default              : break
        }
    }
    
    private func handleCapture() {
        cameraController.handleCapture()
    }
    
    private func handleResolution() {
        guard !cameraController.formats.isEmpty else {
            print("연결된 카메라 또는 카메라가 지원하는 해상도가 존재하지 않습니다.")
            return
        }
        
        resolutionPopup = ResolutionPopup(formats: cameraController.formats).then {
            $0.delegate = self
        }
        
        if let popup = resolutionPopup {
            present(popup, animated: true)
        }
    }
}


// MARK: ExternalCameraViewControllerDelegate
extension ViewController: ExternalCameraViewControllerDelegate {
    
    func cameraViewControllerDidDisconnect(_ viewController: ExternalCameraViewController) {
        resolutionPopup?.dismiss(animated: true)
        resolutionPopup = nil
    }
    
    func cameraViewController(
        _ viewController: ExternalCameraViewController,
        didFailWithError error: any Error
    ) {
        print("External Camera Error:", error.localizedDescription)
    }
    
    func cameraViewController(
        _ viewController: ExternalCameraViewController,
        didFinishCapture result: Result<UIImage, any Error>
    ) {
        switch result {
        case .success(let image):
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            
            let fileName = dateFormatter.string(from: Date()) + ".jpg"
            FileManager.default.saveImage(image, name: fileName)
            
        case .failure(let error):
            print("External Camera Capture Error:", error.localizedDescription)
        }
    }
}


// MARK: ResolutionPopupDelegate
extension ViewController: ResolutionPopupDelegate {
    
    func didSelect(_ format: AVCaptureDevice.Format) {
        cameraController.didChangeFormat(format)
    }
}


private extension ViewController {
    
    func setupControls() {
        
        view.backgroundColor = .black
        
        captureButton.do {
            $0.backgroundColor = .clear
            $0.tintColor = .white
            $0.setImage(UIImage(systemName: "inset.filled.circle"), for: .normal)
            $0.imageView?.contentMode = .scaleToFill
            $0.imageView?.snp.makeConstraints {
                $0.center.size.equalToSuperview()
            }
        }
        
        resolutionButton.do {
            $0.backgroundColor = .clear
            $0.tintColor = .lightGray
            $0.setImage(UIImage(systemName: "camera.fill"), for: .normal)
            $0.imageView?.contentMode = .scaleToFill
            $0.imageView?.snp.makeConstraints {
                $0.center.size.equalToSuperview()
            }
        }
    }
    
    func setupActions() {
        
        captureButton.addTarget(
            self,
            action: #selector(didTapButton),
            for: .touchUpInside
        )
        
        // TODO: 해상도 변경을 자주할 경우 화면이 멈출 수 있음(문제 개선 필요)
        resolutionButton.addTarget(
            self,
            action: #selector(didTapButton),
            for: .touchUpInside
        )
    }
    
    func setupLayout() {
        
        addChild(cameraController)
        
        view.addSubview(cameraController.view)
        cameraController.view.snp.makeConstraints {
            $0.top.bottom.equalToSuperview()
            $0.left.equalTo(view.safeAreaLayoutGuide)
            $0.right.equalToSuperview().multipliedBy(0.83)
        }
        
        cameraController.didMove(toParent: self)
        
        
        view.addSubview(buttonView)
        
        setupButtonView()
        buttonView.snp.makeConstraints {
            $0.top.bottom.equalToSuperview()
            $0.left.equalTo(cameraController.view.snp.right)
            $0.right.equalTo(view.safeAreaLayoutGuide)
        }
    }
    
    private func setupButtonView() {
        
        buttonView.addSubview(resolutionButton)
        buttonView.addSubview(captureButton)
        
        resolutionButton.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalToSuperview().offset(40)
            $0.width.equalToSuperview().multipliedBy(0.45)
            $0.height.equalTo(resolutionButton.snp.width).multipliedBy(0.85)
        }
        
        captureButton.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.width.equalToSuperview().multipliedBy(0.9)
            $0.height.equalTo(captureButton.snp.width)
        }
    }
}
