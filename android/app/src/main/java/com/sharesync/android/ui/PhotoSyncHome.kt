package com.sharesync.android.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.res.colorResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.sharesync.android.R
import com.sharesync.android.pairing.QrCodeBitmapFactory

data class PhotoSyncHomeUiState(
    val phase: String = "",
    val status: String = "",
    val photoCount: Int? = null,
    val photoStatus: String = "",
    val guidance: String = "",
    val pairingPayload: String? = null,
    val showPairing: Boolean = false,
    val showOnboarding: Boolean = false,
    val showGrant: Boolean = false,
    val showStart: Boolean = false,
    val startEnabled: Boolean = false,
    val isRunning: Boolean = false,
    val needsAttention: Boolean = false,
)

@Composable
fun ShareSyncComposeTheme(content: @Composable () -> Unit) {
    val dark = androidx.compose.foundation.isSystemInDarkTheme()
    val scheme = if (dark) darkColorScheme() else lightColorScheme()
    MaterialTheme(
        colorScheme = scheme.copy(
            primary = colorResource(R.color.sharesync_primary),
            onPrimary = colorResource(R.color.sharesync_on_primary),
            secondary = colorResource(R.color.sharesync_info),
            onSecondary = colorResource(R.color.sharesync_on_primary),
            tertiary = colorResource(R.color.sharesync_warning),
            onTertiary = colorResource(R.color.sharesync_on_primary),
            background = colorResource(R.color.sharesync_background),
            onBackground = colorResource(R.color.sharesync_text_primary),
            surface = colorResource(R.color.sharesync_surface),
            onSurface = colorResource(R.color.sharesync_text_primary),
            onSurfaceVariant = colorResource(R.color.sharesync_text_secondary),
            outline = colorResource(R.color.sharesync_divider),
            outlineVariant = colorResource(R.color.sharesync_divider),
            secondaryContainer = colorResource(R.color.sharesync_surface_alt),
            onSecondaryContainer = colorResource(R.color.sharesync_text_primary),
            surfaceVariant = colorResource(R.color.sharesync_surface_alt),
            surfaceContainerLowest = colorResource(R.color.sharesync_surface),
            surfaceContainerLow = colorResource(R.color.sharesync_background),
            surfaceContainer = colorResource(R.color.sharesync_surface),
            surfaceContainerHigh = colorResource(R.color.sharesync_surface_alt),
            surfaceContainerHighest = colorResource(R.color.sharesync_divider),
            error = colorResource(R.color.sharesync_error),
            onError = colorResource(R.color.sharesync_on_primary),
            errorContainer = colorResource(R.color.sharesync_error_container),
            onErrorContainer = colorResource(R.color.sharesync_text_primary),
            inversePrimary = colorResource(R.color.sharesync_primary),
            surfaceTint = colorResource(R.color.sharesync_primary),
        ),
        content = content,
    )
}

@Composable
fun PhotoSyncHome(
    state: PhotoSyncHomeUiState,
    onContinue: () -> Unit,
    onGrant: () -> Unit,
    onStart: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(24.dp)) {
        if (state.showOnboarding) {
            Column(verticalArrangement = Arrangement.spacedBy(20.dp)) {
                SectionHeading(stringResource(R.string.onboarding_title))
                OnboardingStep("01", stringResource(R.string.onboarding_step_photos))
                OnboardingStep("02", stringResource(R.string.onboarding_step_network))
                OnboardingStep("03", stringResource(R.string.onboarding_step_pair))
                HorizontalDivider()
                Text(stringResource(R.string.onboarding_privacy), color = MaterialTheme.colorScheme.onSurfaceVariant)
                Button(onClick = onContinue, modifier = Modifier.fillMaxWidth()) {
                    Text(stringResource(R.string.onboarding_continue))
                }
            }
            return@Column
        }

        Surface(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(8.dp),
            color = MaterialTheme.colorScheme.secondaryContainer,
        ) {
            Column(modifier = Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(9.dp)) {
                    Surface(
                        modifier = Modifier.size(9.dp),
                        shape = RoundedCornerShape(9.dp),
                        color = when {
                            state.needsAttention -> colorResource(R.color.sharesync_warning)
                            state.isRunning -> colorResource(R.color.sharesync_success)
                            else -> MaterialTheme.colorScheme.onSurfaceVariant
                        },
                    ) {}
                    Text(
                        text = stringResource(R.string.home_this_phone),
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Text(state.phase, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.SemiBold)
                Text(state.status, color = MaterialTheme.colorScheme.onSurfaceVariant)
                if (state.photoCount != null) {
                    HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.55f))
                    Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text(state.photoCount.toString(), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
                        Text(
                            stringResource(R.string.home_photos_available),
                            modifier = Modifier.padding(bottom = 5.dp),
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    Text(state.photoStatus, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary)
                }
            }
        }

        if (state.showPairing && state.pairingPayload != null) {
            HorizontalDivider()
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                SectionHeading(stringResource(R.string.sync_panel_pairing))
                Text(stringResource(R.string.home_scan_from_iphone), color = MaterialTheme.colorScheme.onSurfaceVariant)
                val qr = remember(state.pairingPayload) {
                    QrCodeBitmapFactory().create(state.pairingPayload, 720).asImageBitmap()
                }
                BoxWithConstraints(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    val qrSize = minOf(maxWidth, 280.dp)
                    Box(
                        modifier = Modifier
                            .size(qrSize)
                            .background(colorResource(R.color.sharesync_qr_surface), RoundedCornerShape(8.dp))
                            .padding(12.dp),
                    ) {
                        Image(
                            bitmap = qr,
                            contentDescription = stringResource(R.string.pairing_qr_accessibility),
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }
                Text(stringResource(R.string.home_same_network), color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                SectionHeading(stringResource(R.string.home_next_step))
                Text(state.guidance, style = MaterialTheme.typography.bodyLarge)
                if (state.showGrant) {
                    Button(onClick = onGrant, modifier = Modifier.fillMaxWidth()) {
                        Text(stringResource(R.string.sync_grant_permissions))
                    }
                }
                if (state.showStart) {
                    Button(onClick = onStart, enabled = state.startEnabled, modifier = Modifier.fillMaxWidth()) {
                        Text(stringResource(R.string.sync_start_server))
                    }
                }
            }
        }
        Spacer(modifier = Modifier.size(4.dp))
    }
}

@Composable
private fun OnboardingStep(number: String, description: String) {
    Row(horizontalArrangement = Arrangement.spacedBy(16.dp), verticalAlignment = Alignment.Top) {
        Text(number, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
        Text(description, style = MaterialTheme.typography.bodyLarge)
    }
}

@Composable
internal fun SectionHeading(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.titleMedium,
        fontWeight = FontWeight.SemiBold,
        modifier = Modifier.semantics { heading() },
    )
}
