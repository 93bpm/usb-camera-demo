# Android — usb-camera-demo

Android용 USB/외장(UVC) 카메라 앱입니다.

## 스택

- **언어/UI**: Kotlin + Jetpack Compose (Material 3)
- **빌드**: Gradle (Kotlin DSL) + Version Catalog / **AGP 8.10.1**
- **SDK**: minSdk 26 / target·compile **36**
- **UVC 엔진**: 벤더링된 로컬 모듈 **`:libuvccamera`** — shiyinghan/**UVCAndroid 1.0.12 포크**(Apache 2.0) + 사내 **패킷 제어 패치**. prebuilt `.so` 포함(arm64-v8a·armeabi-v7a·x86·x86_64).

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
- 연결되면 우측 상단에 **해상도**·**패킷(P8/16/32/64)** 버튼이 표시됨. 두 다이얼로그 모두 현재 적용값을 회색 배경 + 라디오로 표시.

## 열기 / 빌드

1. **Android Studio에서 `android/` 폴더를 엽니다** — 최초 Gradle Sync 시 래퍼가 생성되고, `libuvccamera` 모듈의 **NDK `27.0.12077973`** 설치를 요구할 수 있습니다(프리뷰 없이 prebuilt `.so`만 패키징하지만 stripping에 NDK가 필요). Android Studio 안내대로 설치하면 됩니다.
2. **USB Host를 지원하는 실기기** 필요 (에뮬레이터는 USB 외장 카메라 연결 불가)
3. USB-C로 UVC 카메라를 연결 → CAMERA 권한 허용 → 프리뷰 시작

## 인식이 안 될 때

1. **전원 공급(powered) USB-C/OTG 허브** 사용 (기기 단독 전력 부족)
2. **데이터 지원 케이블/OTG 어댑터** 확인
3. **UVC 표준 카메라**인지 확인
4. MediaTek 기기에서 프리뷰가 깨지면 — 이미 `getRecommendedPlatformQuirks`(FIX_BANDWIDTH)가 적용됨. 그래도 불안정하면 **패킷 버튼으로 P8**(기본·최소)까지 낮춰볼 것.

### 검은 화면의 원인은 두 가지

`adb logcat -d libusb:E "*:S" | grep submiturb` 로 갈린다.

- **나옴** (`submiturb failed, errno=12` = ENOMEM) — 커널이 전송 버퍼를 못 내준 것. 패킷 값이 클수록 요구하는 연속 메모리가 커진다(URB 1개 = P × `dwMaxPayloadTransferSize`). **P를 낮추면 해결.**
- **안 나오는데 검음** — 전송은 정상인데 카메라가 영상을 안 실어보내는 경우(payload 없이 헤더만 도착). **P를 낮춰도 안 고쳐진다.** 해상도나 포맷(MJPEG↔YUV)을 바꿔야 함.

### fps가 협상값보다 낮을 때

자동 노출을 먼저 의심할 것. UVC는 어두우면 노출 시간을 늘리려고 카메라가 **스스로 프레임레이트를 떨어뜨리는 것을 허용**한다(`CT_AE_PRIORITY_CONTROL`). 해상도와 무관하게 일정한 값으로 낮다면 대부분 이 경우다.

- 확인: 밝은 곳을 비춰 fps가 오르는지 본다
- 고정: `cameraHelper.uvcControl.setAutoExposurePriority(0)` (프레임레이트 고정 강제, 대신 어두운 곳에서 화면이 어두워짐)

> 실측 (Galaxy A50s / Exynos 9610 / dwc3+xhci): 1920x1080 MJPEG에서 어두울 때 16.5fps → 조명 시 30fps. 패킷은 P8~P64 전 구간에서 fps·제출 실패 모두 차이 없었다. 이 기기에서 패킷 노브는 효과가 없고, 의미가 있는 건 MediaTek 계열이다.

## 참고

- 이 `libuvccamera`는 사내 `flutter-usb-camera-test`의 **prebuilt 사본**(C 소스 없음)입니다. 네이티브(libuvc C)를 추가로 수정해야 하면, C 소스를 포함한 `aos-usb-camera-test/libuvccamera`(소스 마스터)로 교체해야 합니다.
