package com.externalcamera

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.ContextCompat
import com.externalcamera.ui.CameraScreen
import com.externalcamera.ui.CameraUiState
import com.externalcamera.ui.theme.ExternalCameraTheme

/**
 * 외장 카메라 데모의 메인 화면.
 *
 * [UvcCameraController]가 벤더링된 libuvccamera(UVCAndroid 포크)로 감지·권한·프리뷰를 관리하고,
 * 상태를 Compose state로 반영한다. Android 14+ 요구사항에 맞춰 앱 시작 시 CAMERA 권한을 먼저 받는다.
 */
class MainActivity : ComponentActivity(), UvcCameraController.Callback {

    private lateinit var controller: UvcCameraController
    private var uiState by mutableStateOf<CameraUiState>(CameraUiState.Waiting)
    private var hasCameraPermission = false

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        hasCameraPermission = granted
        if (granted) {
            controller.start()
        } else {
            uiState = CameraUiState.PermissionDenied
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        controller = UvcCameraController(this, this)

        hasCameraPermission = ContextCompat.checkSelfPermission(
            this, Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED

        setContent {
            ExternalCameraTheme {
                CameraScreen(
                    state = uiState,
                    onViewReady = { view -> controller.bindPreviewView(view) },
                    packetsOptions = controller.packetsOptions,
                    onApplyPackets = { controller.applyPacketsMax(it) },
                    querySupportedResolutions = { controller.supportedResolutionItems() },
                    onApplyResolution = { controller.applyResolution(it) },
                )
            }
        }

        // 스캔 화면 진입이 아니라 시작 시점에 미리 요청 (없으면 USB 권한이 자동 거부됨)
        if (!hasCameraPermission) {
            permissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    override fun onStart() {
        super.onStart()
        if (hasCameraPermission) controller.start()
    }

    override fun onStop() {
        super.onStop()
        controller.stop()
    }

    // 라이브러리 콜백이 다른 스레드로 올 수 있으므로 메인 스레드에서 상태 갱신
    override fun onStatus(status: CameraUiState) {
        runOnUiThread { uiState = status }
    }
}
