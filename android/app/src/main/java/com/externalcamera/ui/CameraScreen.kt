package com.externalcamera.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.externalcamera.R
import com.serenegiant.usb.Size
import com.serenegiant.widget.AspectRatioSurfaceView

/** 화면에 표시할 카메라 연결 상태 */
sealed interface CameraUiState {
    data object Waiting : CameraUiState
    data class Connected(val name: String) : CameraUiState
    data object PermissionDenied : CameraUiState
}

/** 해상도 다이얼로그 셀 하나 = (포맷, 해상도, fps) 조합. applySize는 그 조합을 적용할 Size. */
data class ResolutionItem(
    val formatName: String,
    val width: Int,
    val height: Int,
    val fps: Int,
    val applySize: Size,
) {
    /** Size는 equals가 없어 필드로 비교한다. */
    fun isCurrent(size: Size?): Boolean =
        size != null &&
            applySize.type == size.type &&
            width == size.width &&
            height == size.height &&
            fps == size.fps
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CameraScreen(
    state: CameraUiState,
    onViewReady: (AspectRatioSurfaceView) -> Unit,
    packetsOptions: List<Int>,
    onApplyPackets: (Int) -> Unit,
    querySupportedResolutions: () -> List<ResolutionItem>,
    queryCurrentResolution: () -> Size?,
    onApplyResolution: (Size) -> Unit,
) {
    var packets by remember { mutableStateOf(8) }
    var showPackets by remember { mutableStateOf(false) }
    var showResolution by remember { mutableStateOf(false) }
    var resolutions by remember { mutableStateOf<List<ResolutionItem>>(emptyList()) }
    var selectedFormat by remember { mutableStateOf("") }
    var currentSize by remember { mutableStateOf<Size?>(null) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black),
        contentAlignment = Alignment.Center,
    ) {
        AndroidView(
            modifier = Modifier.fillMaxSize(),
            factory = { ctx -> AspectRatioSurfaceView(ctx).also { onViewReady(it) } },
        )

        // 연결 전(대기/권한 거부): 안내 문구
        if (state !is CameraUiState.Connected) {
            val message = when (state) {
                is CameraUiState.Waiting -> stringResource(R.string.status_waiting)
                is CameraUiState.PermissionDenied -> stringResource(R.string.status_permission_denied)
                is CameraUiState.Connected -> ""
            }
            Text(
                text = message,
                color = Color.LightGray,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(24.dp),
            )
        }

        // 연결 시: 제어 버튼 (해상도 / 패킷)
        if (state is CameraUiState.Connected) {
            Column(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(16.dp),
                horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Button(onClick = {
                    resolutions = querySupportedResolutions()
                    currentSize = queryCurrentResolution()
                    // 현재 적용된 해상도가 속한 포맷을 먼저 보여준다
                    selectedFormat = resolutions.firstOrNull { it.isCurrent(currentSize) }?.formatName
                        ?: resolutions.firstOrNull()?.formatName
                        ?: ""
                    showResolution = true
                }) { Text(stringResource(R.string.btn_resolution)) }

                Button(onClick = { showPackets = true }) { Text("P$packets") }
            }
        }
    }

    // 패킷 선택 다이얼로그
    if (showPackets) {
        AlertDialog(
            onDismissRequest = { showPackets = false },
            title = { Text(stringResource(R.string.dialog_packets_title)) },
            text = {
                Column {
                    packetsOptions.forEach { opt ->
                        SelectableRow(
                            selected = opt == packets,
                            onClick = {
                                packets = opt
                                onApplyPackets(opt)
                                showPackets = false
                            },
                        ) {
                            val label = if (opt == 8) {
                                "P$opt (${stringResource(R.string.packets_default)})"
                            } else {
                                "P$opt"
                            }
                            Text(text = label, modifier = Modifier.weight(1f))
                        }
                    }
                }
            },
            confirmButton = {},
            dismissButton = {
                TextButton(onClick = { showPackets = false }) {
                    Text(stringResource(R.string.btn_cancel))
                }
            },
        )
    }

    // 해상도 선택 다이얼로그 (상단 포맷 세그먼트 + 해상도(FPS) 셀)
    if (showResolution) {
        val formats = remember(resolutions) { resolutions.map { it.formatName }.distinct() }
        AlertDialog(
            onDismissRequest = { showResolution = false },
            title = { Text(stringResource(R.string.btn_resolution)) },
            text = {
                if (resolutions.isEmpty()) {
                    Text(stringResource(R.string.no_resolutions))
                } else {
                    Column {
                        // 포맷 세그먼트 (FilterChip)
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            formats.forEach { fmt ->
                                FilterChip(
                                    selected = fmt == selectedFormat,
                                    onClick = { selectedFormat = fmt },
                                    label = { Text(fmt) },
                                )
                            }
                        }
                        Spacer(Modifier.height(8.dp))
                        // 해상도(FPS) 목록 — 선택된 포맷만. 현재 적용된 항목은 회색 배경 + 라디오 체크
                        Column(modifier = Modifier.verticalScroll(rememberScrollState())) {
                            resolutions
                                .filter { it.formatName == selectedFormat }
                                .forEach { item ->
                                    SelectableRow(
                                        selected = item.isCurrent(currentSize),
                                        onClick = {
                                            currentSize = item.applySize
                                            onApplyResolution(item.applySize)
                                            showResolution = false
                                        },
                                    ) {
                                        Text(
                                            text = "${item.width} x ${item.height} (${item.fps}FPS)",
                                            modifier = Modifier.weight(1f),
                                        )
                                    }
                                }
                        }
                    }
                }
            },
            confirmButton = {},
            dismissButton = {
                TextButton(onClick = { showResolution = false }) {
                    Text(stringResource(R.string.btn_cancel))
                }
            },
        )
    }
}

/**
 * 선택 가능한 목록 행 — 선택되면 회색 배경 + 우측 라디오 체크.
 * 행 전체가 클릭을 받으므로 라디오는 표시 전용(onClick = null)이다.
 * 패킷/해상도 다이얼로그가 같은 모양을 유지하도록 공유한다.
 */
@Composable
private fun SelectableRow(
    selected: Boolean,
    onClick: () -> Unit,
    content: @Composable RowScope.() -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(
                if (selected) MaterialTheme.colorScheme.surfaceVariant else Color.Transparent
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        content()
        RadioButton(selected = selected, onClick = null)
    }
}
