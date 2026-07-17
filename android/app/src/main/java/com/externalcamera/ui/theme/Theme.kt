package com.externalcamera.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable

// 카메라 프리뷰 앱이라 항상 다크(검은 배경) 테마를 사용한다.
private val DarkColors = darkColorScheme()

@Composable
fun ExternalCameraTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = DarkColors,
        content = content
    )
}
