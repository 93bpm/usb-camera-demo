package com.externalcamera

import android.content.Context
import android.hardware.usb.UsbDevice
import android.view.SurfaceHolder
import com.externalcamera.ui.CameraUiState
import com.externalcamera.ui.ResolutionItem
import com.herohan.uvcapp.CameraHelper
import com.herohan.uvcapp.ICameraHelper
import com.serenegiant.usb.Size
import com.serenegiant.usb.UVCCamera
import com.serenegiant.usb.UVCParam
import com.serenegiant.widget.AspectRatioSurfaceView

/**
 * 벤더링된 libuvccamera(UVCAndroid 1.0.12 포크)의 CameraHelper를 감싸
 * 감지 → 권한 → 열기 → 프리뷰까지 관리한다.
 *
 * 로직은 사내 참조 aos-usb-camera-test의 CameraActivity를 이식했다:
 * 합류 게이트(camera+surface), openCamera(UVCParam+quirks), AspectRatioSurfaceView,
 * 패킷 제어(P8/16/32), 해상도 목록/변경.
 */
class UvcCameraController(
    context: Context,
    private val callback: Callback,
) {
    interface Callback {
        fun onStatus(status: CameraUiState)
    }

    private val appContext = context.applicationContext
    private var cameraHelper: ICameraHelper? = null
    private var cameraView: AspectRatioSurfaceView? = null

    @Volatile private var cameraOpened = false
    @Volatile private var surfaceReady = false
    @Volatile private var previewing = false

    fun start() {
        if (cameraHelper == null) {
            cameraHelper = CameraHelper().apply { setStateCallback(stateCallback) }
        }
        callback.onStatus(CameraUiState.Waiting)
    }

    fun stop() {
        cameraHelper?.let { helper ->
            try {
                if (previewing) helper.stopPreview()
                cameraView?.holder?.surface?.let { helper.removeSurface(it) }
                helper.closeCamera()
            } catch (e: Exception) {
                // teardown 중 예외는 무시
            }
            helper.release()
        }
        cameraHelper = null
        cameraOpened = false
        previewing = false
    }

    /** Compose에서 만든 프리뷰 뷰 연결 (surface 준비 콜백 등록) */
    fun bindPreviewView(view: AspectRatioSurfaceView) {
        cameraView = view
        view.holder.addCallback(surfaceCallback)
    }

    // ── 패킷/해상도 제어 (포크 전용) ─────────────────────────

    val packetsOptions = listOf(8, 16, 32, 64)

    /** USB 등시성 전송 패킷 수 변경 (P8/16/32). 프리뷰 중이면 재시작해 적용. */
    fun applyPacketsMax(value: Int) {
        UVCCamera.setPacketsPerTransferMax(value)
        val helper = cameraHelper
        if (helper != null && helper.isCameraOpened && previewing) {
            try {
                helper.stopPreview()
                helper.startPreview()
            } catch (e: Exception) {
                // 무시
            }
        }
    }

    /**
     * 지원 해상도를 (포맷 × 해상도 × fps) 조합으로 모두 펼쳐 반환 (카메라 열려있을 때만).
     * 데모: fpsList의 모든 fps를 개별 셀로 전부 노출.
     */
    fun supportedResolutionItems(): List<ResolutionItem> {
        val helper = cameraHelper ?: return emptyList()
        if (!helper.isCameraOpened) return emptyList()
        val sizes = helper.supportedSizeList ?: return emptyList()

        val items = mutableListOf<ResolutionItem>()
        for (size in sizes) {
            val name = formatName(size.type)
            val fpsValues = size.fpsList?.takeIf { it.isNotEmpty() } ?: listOf(size.fps)
            for (fps in fpsValues) {
                // 특정 fps를 담은 Size로 적용 (fpsList 보존)
                val applySize = Size(size.type, size.width, size.height, fps, size.fpsList ?: listOf(fps))
                items.add(ResolutionItem(name, size.width, size.height, fps, applySize))
            }
        }
        return items.sortedWith(
            compareByDescending<ResolutionItem> { it.width.toLong() * it.height }
                .thenByDescending { it.fps }
        )
    }

    private fun formatName(type: Int): String = when (type) {
        7 -> "MJPEG"          // UVC_VS_FRAME_MJPEG
        5 -> "YUV"            // UVC_VS_FRAME_UNCOMPRESSED
        else -> "type:$type"
    }

    /** 현재 적용된 해상도 (다이얼로그에서 선택 표시용) */
    fun currentResolution(): Size? {
        val helper = cameraHelper ?: return null
        if (!helper.isCameraOpened) return null
        return helper.previewSize
    }

    /** 해상도 변경: 프리뷰 정지 → 설정 → 재시작 → 종횡비 갱신 */
    fun applyResolution(size: Size) {
        val helper = cameraHelper ?: return
        if (!helper.isCameraOpened) return
        try {
            helper.stopPreview()
            helper.setPreviewSize(size)
            helper.startPreview()
            cameraView?.setAspectRatio(size.width, size.height)
        } catch (e: Exception) {
            // 무시
        }
    }

    // ─────────────────────────────────────────────────────

    private val surfaceCallback = object : SurfaceHolder.Callback {
        override fun surfaceCreated(holder: SurfaceHolder) {
            surfaceReady = true
            tryStartPreview()
        }

        override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) = Unit

        override fun surfaceDestroyed(holder: SurfaceHolder) {
            surfaceReady = false
            cameraHelper?.let { helper ->
                if (previewing) {
                    try {
                        helper.stopPreview()
                        helper.removeSurface(holder.surface)
                    } catch (e: Exception) {
                        // 무시
                    }
                }
            }
            previewing = false
        }
    }

    // 합류 게이트: camera 열림 + surface 준비 둘 다여야 프리뷰 시작
    @Synchronized
    private fun tryStartPreview() {
        val helper = cameraHelper ?: return
        val view = cameraView ?: return
        if (!cameraOpened || !surfaceReady || !helper.isCameraOpened || previewing) return
        try {
            helper.previewSize?.let { view.setAspectRatio(it.width, it.height) }
            helper.addSurface(view.holder.surface, false)
            helper.startPreview()
            previewing = true
        } catch (e: Exception) {
            // 무시
        }
    }

    private val stateCallback = object : ICameraHelper.StateCallback {
        override fun onAttach(device: UsbDevice) {
            cameraHelper?.selectDevice(device)
        }

        override fun onDeviceOpen(device: UsbDevice, isFirstOpen: Boolean) {
            // 기기별 대역폭 보정(quirk) 적용 후 카메라 열기 (MediaTek 등)
            val param = UVCParam()
            param.setQuirks(UVCCamera.getRecommendedPlatformQuirks())
            cameraHelper?.openCamera(param)
        }

        override fun onCameraOpen(device: UsbDevice) {
            cameraOpened = true
            tryStartPreview()
            val name = device.productName ?: appContext.getString(R.string.camera_unknown)
            callback.onStatus(CameraUiState.Connected(name))
        }

        override fun onCameraClose(device: UsbDevice) {
            cameraOpened = false
            previewing = false
        }

        override fun onDeviceClose(device: UsbDevice) = Unit

        override fun onDetach(device: UsbDevice) {
            callback.onStatus(CameraUiState.Waiting)
        }

        override fun onCancel(device: UsbDevice) {
            // USB 접근 권한 거부/취소
            callback.onStatus(CameraUiState.PermissionDenied)
        }
    }
}
