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
    func didSelect(_ format: AVCaptureDevice.Format, fps: Double)
}

class ResolutionPopup: UIViewController {

    weak var delegate: ResolutionPopupDelegate?

    // 픽셀 포맷별 세그먼트 + (해상도, fps) 셀
    private struct Cell {
        let format: AVCaptureDevice.Format
        let width: Int
        let height: Int
        let fps: Double
        var label: String { "\(width) x \(height) (\(Int(fps))FPS)" }
    }
    private struct Segment {
        let name: String
        let cells: [Cell]
    }

    private let segments: [Segment]
    private var selectedSegment = 0

    private let container = UIView()
    private let segmentedControl = UISegmentedControl()
    private let tableView = UITableView()

    init(formats: [AVCaptureDevice.Format]) {
        self.segments = ResolutionPopup.buildSegments(from: formats)

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

    private var currentCells: [Cell] {
        guard !segments.isEmpty, selectedSegment < segments.count else { return [] }
        return segments[selectedSegment].cells
    }

    @objc
    private func didChangeSegment(_ sender: UISegmentedControl) {
        selectedSegment = sender.selectedSegmentIndex
        tableView.reloadData()
    }

    @objc
    private func didTapDismiss(_ gesture: UITapGestureRecognizer) {
        // 컨테이너(세그먼트/목록) 바깥을 탭하면 닫기
        let location = gesture.location(in: view)
        if !container.frame.contains(location) {
            dismiss(animated: true)
        }
    }
}

// MARK: - 세그먼트/셀 구성 (포맷별 그룹핑 + 모든 fps 펼침)
private extension ResolutionPopup {

    static func buildSegments(from formats: [AVCaptureDevice.Format]) -> [Segment] {
        var order: [String] = []
        var groups: [String: [Cell]] = [:]

        for format in formats {
            let desc = format.formatDescription
            let subType = CMFormatDescriptionGetMediaSubType(desc)
            let name = formatName(subType)
            let dims = CMVideoFormatDescriptionGetDimensions(desc)

            // B안: 지원 프레임레이트 범위를 모두 셀로 펼침
            for range in format.videoSupportedFrameRateRanges {
                let cell = Cell(
                    format: format,
                    width: Int(dims.width),
                    height: Int(dims.height),
                    fps: range.maxFrameRate
                )
                if groups[name] == nil {
                    groups[name] = []
                    order.append(name)
                }
                groups[name]?.append(cell)
            }
        }

        return order.map { name in
            let cells = (groups[name] ?? []).sorted {
                let a = $0.width * $0.height
                let b = $1.width * $1.height
                if a != b { return a > b }
                return $0.fps > $1.fps
            }
            return Segment(name: name, cells: cells)
        }
    }

    static func formatName(_ subType: FourCharCode) -> String {
        switch fourCCString(subType) {
        case "dmb1":          return "MJPEG"
        case "2vuy", "yuvs":  return "YUV 4:2:2"
        case "420v", "420f":  return "YUV 4:2:0"
        case let other:       return other
        }
    }

    static func fourCCString(_ code: FourCharCode) -> String {
        let bytes = [
            UInt8((code >> 24) & 0xFF),
            UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF),
            UInt8(code & 0xFF),
        ]
        return String(bytes: bytes, encoding: .ascii) ?? "\(code)"
    }
}

// MARK: - TableView
extension ResolutionPopup: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentCells.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

        var content = cell.defaultContentConfiguration()
        content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
        content.text = currentCells[indexPath.row].label

        cell.contentConfiguration = content
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = currentCells[indexPath.row]
        delegate?.didSelect(cell.format, fps: cell.fps)
        dismiss(animated: true)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 56
    }
}

// MARK: - Setup
private extension ResolutionPopup {

    func setupControls() {
        container.do {
            $0.backgroundColor = .white
            $0.layer.cornerRadius = 12
            $0.clipsToBounds = true
        }

        segments.enumerated().forEach { index, segment in
            segmentedControl.insertSegment(withTitle: segment.name, at: index, animated: false)
        }
        segmentedControl.selectedSegmentIndex = segments.isEmpty ? UISegmentedControl.noSegment : 0

        tableView.do {
            $0.dataSource = self
            $0.delegate = self
            $0.backgroundColor = .white
            $0.sectionHeaderTopPadding = 0
            $0.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        }
    }

    func setupActions() {
        segmentedControl.addTarget(self, action: #selector(didChangeSegment), for: .valueChanged)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapDismiss)).then {
            $0.cancelsTouchesInView = false
        }
        view.addGestureRecognizer(tapGesture)
    }

    func setupLayout() {
        view.addSubview(container)
        container.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.width.equalToSuperview().multipliedBy(0.7)
            $0.height.equalToSuperview().multipliedBy(0.7)
        }

        container.addSubview(segmentedControl)
        container.addSubview(tableView)

        segmentedControl.snp.makeConstraints {
            $0.top.equalToSuperview().offset(12)
            $0.left.right.equalToSuperview().inset(12)
        }

        tableView.snp.makeConstraints {
            $0.top.equalTo(segmentedControl.snp.bottom).offset(8)
            $0.left.right.bottom.equalToSuperview()
        }
    }
}
