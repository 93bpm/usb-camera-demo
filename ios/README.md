# iOS — usb-camera-demo

iOS용 USB/외장(UVC) 카메라 앱입니다. 외장 카메라 프리뷰 · 사진 캡처 · 로컬 저장 · 프리뷰 회전 데모(0/90/180/270°) · 연결 상태 안내 및 자동 복구를 지원합니다.

## 스택

- **언어/UI**: Swift 5, UIKit (코드 기반 UI — SnapKit + Then)
- **카메라**: AVFoundation — `AVCaptureDevice.DiscoverySession`의 `.external` 디바이스 타입
- **의존성 (SPM)**: SnapKit 5.7, Then 3.0 (Xcode가 자동으로 해석)
- **배포 타겟**: iOS 17.0+ / 가로(Landscape) 전용

## 실행 방법

1. `ExternalCamera.xcodeproj`를 Xcode로 엽니다
2. **실기기**(USB-C 지원 iPhone/iPad)를 선택해 빌드합니다
   - 시뮬레이터에서는 외장 카메라를 연결할 수 없습니다
3. USB-C로 UVC 카메라를 연결하면 자동으로 프리뷰가 시작됩니다

## 카메라 인식이 안 될 때

OS가 디바이스를 아예 잡지 못하는 경우(`discoverySession.devices`에 안 뜸)는 앱 밖 물리 계층 문제입니다:

1. **전원 공급(powered) USB-C 허브**를 거쳐 연결 — iPad 단독 공급 전력 부족이 가장 흔한 원인
2. **데이터 지원 케이블**인지 확인 — 충전 전용 케이블은 인식 불가
3. **UVC 표준 카메라**인지 확인 — 전용 드라이버가 필요한 카메라는 iPad에서 인식 불가
4. 연결 후 1~3초 대기 — 디바이스 열거(enumeration) 지연은 정상

앱은 연결 대기·중단 사유·오류를 프리뷰 영역에 표시하고, 일시적 세션 오류는 자동 재시작으로 복구를 시도합니다. 연결 시 카메라 정보(이름·모델·지원 포맷)를 콘솔에 출력하므로 트러블슈팅에 활용할 수 있습니다.

## 구조

```
ExternalCamera/
├─ AppDelegate.swift / SceneDelegate.swift   # 앱 진입점
├─ ViewController/
│  ├─ ViewController.swift                   # 메인 화면 (프리뷰 embed + 캡처/해상도 버튼)
│  ├─ ExternalCameraViewController.swift     # 카메라 코어 (탐색·세션·캡처, KVO 핫플러그 대응)
│  └─ ResolutionPopup.swift                  # 지원 해상도 선택 팝업
└─ Extensions/
   └─ FileManager.swift                      # Documents/ExternalCamera/ 에 이미지 저장·조회·삭제
```

## 알려진 이슈 / TODO

- [x] `NSCameraUsageDescription` 설정 완료
- [ ] 카메라 권한 요청 흐름(`AVCaptureDevice.requestAccess`) 없음
- [ ] 캡처 목록(앨범) 표시 기능 미구현
- [ ] 해상도를 자주 변경하면 프리뷰가 멈출 수 있음
- [ ] 캡처 이미지 회전 보정 로직 주석 처리 상태
