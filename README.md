# usb-camera-demo

USB/외장(UVC) 카메라를 프리뷰하고 사진을 캡처·저장하는 데모 앱입니다. iOS와 Android를 각각 **네이티브**로 구현합니다.

## 저장소 구조

```
.
├─ ios/        # iOS 앱 (Swift / UIKit / AVFoundation)
└─ android/    # Android 앱 (Kotlin / Compose / USB Host API)
```

## 플랫폼

### iOS (`ios/`)

- **스택**: Swift 5, UIKit, AVFoundation
- **외장 카메라**: `AVCaptureDevice`의 `.external` 디바이스 타입
- **의존성 (SPM)**: SnapKit, Then
- **배포 타겟**: iOS 17.0+
- **열기**: `ios/ExternalCamera.xcodeproj`
- **자세한 내용**: [`ios/README.md`](ios/README.md)

### Android (`android/`)

- **스택**: Kotlin + Jetpack Compose, Gradle(Kotlin DSL), 최소 SDK 26
- **외장 카메라**: UVCAndroid `CameraHelper` (감지·권한·프리뷰)
- **상태**: 감지·권한·프리뷰 연동 완료(온디바이스 검증 전) — 자세한 내용은 [`android/README.md`](android/README.md)

## 개발 방식

두 앱은 **독립 네이티브**로 개발합니다. USB 외장 카메라는 플랫폼별 저수준 API(iOS AVFoundation / Android USB Host)에 강하게 의존해 크로스플랫폼으로 공유할 수 있는 코드가 적기 때문입니다.
