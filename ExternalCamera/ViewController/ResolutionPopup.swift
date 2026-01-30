//
//  ResolutionPopup.swift
//  ExternalCamera
//
//  Created by 93bpm on 1/30/26.
//

import UIKit
import AVFoundation

import SnapKit
import Then

protocol ResolutionPopupDelegate: AnyObject {
    func didSelect(_ format: AVCaptureDevice.Format)
}

class ResolutionPopup: UIViewController {
    
    weak var delegate: ResolutionPopupDelegate?
    
    private let formats: [AVCaptureDevice.Format]
    
    private var tableView = UITableView()
    
    init(formats: [AVCaptureDevice.Format]) {
        self.formats = formats
        
        super.init(nibName: nil, bundle: nil)
        
        modalTransitionStyle = .crossDissolve
        modalPresentationStyle = .overFullScreen
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupControls()
        setupActions()
        
        setupLayout()
    }
    
    @objc
    private func didTapDismiss(_ gesture: UITapGestureRecognizer) {
        dismiss(animated: true)
    }
}

extension ResolutionPopup: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        return formats.count
    }
    
    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        var content = cell.defaultContentConfiguration()
        content.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 0,
            leading: 8,
            bottom: 0,
            trailing: 8
        )
        
        let description = formats[indexPath.row].formatDescription
        let dimensions = CMVideoFormatDescriptionGetDimensions(description)
        
        content.text = "\(dimensions.width) x \(dimensions.height)"
        
        cell.contentConfiguration = content
        return cell
    }
    
    func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        delegate?.didSelect(formats[indexPath.row])
        dismiss(animated: true)
    }
    
    func tableView(
        _ tableView: UITableView,
        heightForRowAt indexPath: IndexPath
    ) -> CGFloat {
        return tableView.frame.height * 0.18
    }
}

private extension ResolutionPopup {
    
    func setupControls() {
        
        tableView.do {
            $0.dataSource = self
            $0.delegate = self
            
            $0.backgroundColor = .white
            $0.sectionHeaderTopPadding = 0
            
            $0.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        }
    }
    
    func setupActions() {
        
        let tapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(didTapDismiss)
        ).then {
            $0.cancelsTouchesInView = false
        }
        
        view.addGestureRecognizer(tapGesture)
    }
    
    func setupLayout() {
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.width.equalToSuperview().multipliedBy(0.65)
            $0.height.equalToSuperview().multipliedBy(0.7)
        }
    }
}
