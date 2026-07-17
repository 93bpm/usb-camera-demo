# Android — usb-camera-demo

Android용 USB/외장(UVC) 카메라 앱입니다.

## 스택

- **언어/UI**: Kotlin + Jetpack Compose (Material 3)
- **빌드**: Gradle (Kotlin DSL) + Version Catalog / **AGP 8.10.1**
- **SDK**: minSdk 26 / target·compile **36**
- **UVC 엔진**: 벤더링된 로컬 모듈 **`:libuvccamera`** — shiyinghan/**UVCAndroid 1.0.12 포크**(Apache 2.0) + 사내 **패킷 제어(P8/16/32) 패치**. prebuilt `.so` 포함(arm64-v8a·armeabi-v7a·x86·x86_64).

> 순정 maven(`com.herohan:UVCAndroid`)이 아니라 **포크 소스 모듈**을 쓰는 이유: 순정에는 없는 **패킷 제어**가 MediaTek(Galaxy Tab A9 등) 기기 대역폭 대응에 필요하기 때문. (자세한 배경은 저장소 상위 메모리/조사 참고)

## 구조

```
android/
├─ app/                         # Compose 앱
│  └─ src/main/java/com/externalcamera/
│     ├─ MainActivity.kt        # 권한 요청 + 컨트롤러 생명주기 + Compose state
│     ├─ UvcCameraController.kt # CameraHelper 래퍼 (합류 게이트·quirks·프리뷰)
│     └─ ui/{CameraScreen, theme/Theme}.kt
└─ libuvccamera/                # 벤더링된 UVCAndroid 포크 (로컬 라이브러리 모듈)
```

## 동작 흐름

```
카메라 연결 → onAttach → selectDevice → (USB 권한) → onDeviceOpen
   → openCamera(UVCParam + 플랫폼 quirks) → onCameraOpen
   → [합류 게이트] camera 열림 && surface 준비 → setAspectRatio + addSurface + startPreview → 영상 출력
```

- **CAMERA 런타임 권한을 앱 시작 시 요청** — 없으면 Android 14+에서 USB 권한이 자동 거부됨.
- 프리뷰 뷰는 `com.serenegiant.widget.AspectRatioSurfaceView`를 Compose `AndroidView`로 임베드.

## 열기 / 빌드

1. **Android Studio에서 `android/` 폴더를 엽니다** — 최초 Gradle Sync 시 래퍼가 생성되고, `libuvccamera` 모듈의 **NDK `27.0.12077973`** 설치를 요구할 수 있습니다(프리뷰 없이 prebuilt `.so`만 패키징하지만 stripping에 NDK가 필요). Android Studio 안내대로 설치하면 됩니다.
2. **USB Host를 지원하는 실기기** 필요 (에뮬레이터는 USB 외장 카메라 연결 불가)
3. USB-C로 UVC 카메라를 연결 → CAMERA 권한 허용 → 프리뷰 시작

## 인식이 안 될 때

1. **전원 공급(powered) USB-C/OTG 허브** 사용 (기기 단독 전력 부족)
2. **데이터 지원 케이블/OTG 어댑터** 확인
3. **UVC 표준 카메라**인지 확인
4. MediaTek 기기에서 프리뷰가 깨지면 — 이미 `getRecommendedPlatformQuirks`(FIX_BANDWIDTH)가 적용됨. 그래도 불안정하면 패킷 값을 낮추는 UI(P8) 추가를 검토 (모듈에 `UVCCamera.setPacketsPerTransferMax` 존재).

## 참고

- 이 `libuvccamera`는 사내 `flutter-usb-camera-test`의 **prebuilt 사본**(C 소스 없음)입니다. 네이티브(libuvc C)를 추가로 수정해야 하면, C 소스를 포함한 `aos-usb-camera-test/libuvccamera`(소스 마스터)로 교체해야 합니다.
