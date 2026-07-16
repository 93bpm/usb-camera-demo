# Android — usb-camera-demo

Android용 USB/외장(UVC) 카메라 앱입니다. 현재 **초기 스캐폴드 상태**이며, 실제 Android Studio 프로젝트는 아직 생성 전입니다.

## 계획

- **언어**: Kotlin
- **외장 USB 카메라**: Android USB Host API + UVC 라이브러리(예: `libuvc` / `UVCCamera`) 검토
  - CameraX/Camera2만으로는 임의의 USB(UVC) 외장 카메라 지원이 제한적이라 별도 라이브러리가 필요할 수 있습니다.
- **기능 스펙**: 외장 카메라 프리뷰 · 사진 캡처 · 로컬 저장 (iOS 앱과 동일 스펙 목표)

## 다음 단계

1. Android Studio에서 이 `android/` 폴더에 새 프로젝트 생성 (Kotlin, 최소 SDK 검토)
2. USB Host 권한 및 디바이스 연결/해제 처리
3. UVC 프리뷰 · 캡처 파이프라인 구현
