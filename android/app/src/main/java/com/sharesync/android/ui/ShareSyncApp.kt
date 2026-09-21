package com.sharesync.android.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.key
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.sharesync.android.R

data class HistoryUiItem(val date: String, val completed: Int, val failed: Int)

data class ActivityUiState(
    val latestResult: String = "",
    val history: List<HistoryUiItem> = emptyList(),
)

data class SettingsUiState(
    val networkReady: Boolean = false,
    val photoAccess: Boolean = false,
    val notificationAccess: Boolean = false,
    val sharing: Boolean = false,
    val endpoint: String = "",
    val requestActivity: String = "",
    val transportSecurity: String = "",
    val pairingAvailable: Boolean = false,
    val endpointAvailable: Boolean = false,
    val resultAvailable: Boolean = false,
    val advancedExpanded: Boolean = false,
)

@Composable
fun ShareSyncApp(
    destination: MainDestination,
    home: PhotoSyncHomeUiState,
    activity: ActivityUiState,
    settings: SettingsUiState,
    feedbackMessage: String?,
    onFeedbackShown: () -> Unit,
    onDestinationChange: (MainDestination) -> Unit,
    onContinue: () -> Unit,
    onGrant: () -> Unit,
    onGrantPhotos: () -> Unit,
    onGrantNotifications: () -> Unit,
    onStart: () -> Unit,
    onStop: () -> Unit,
    onCopyPairing: () -> Unit,
    onCopyEndpoint: () -> Unit,
    onCopyResult: () -> Unit,
    onCopyDiagnostics: () -> Unit,
    onClearHistory: () -> Unit,
    onToggleAdvanced: () -> Unit,
) {
    val snackbarHostState = remember { SnackbarHostState() }
    LaunchedEffect(feedbackMessage) {
        if (feedbackMessage != null) {
            snackbarHostState.showSnackbar(feedbackMessage)
            onFeedbackShown()
        }
    }
    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            Surface(color = MaterialTheme.colorScheme.background) {
                Column(modifier = Modifier.fillMaxWidth().statusBarsPadding().padding(start = 20.dp, end = 20.dp, top = 18.dp, bottom = 12.dp)) {
                    Text(
                        stringResource(R.string.app_name),
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary,
                    )
                    Text(
                        stringResource(destination.titleRes),
                        style = MaterialTheme.typography.headlineMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }
        },
        bottomBar = {
            if (!home.showOnboarding) {
                NavigationBar(containerColor = MaterialTheme.colorScheme.surface) {
                    MainDestination.entries.forEach { section ->
                        val attentionCount = activity.history.sumOf { it.failed }
                        NavigationBarItem(
                            selected = destination == section,
                            onClick = { onDestinationChange(section) },
                            icon = {
                                if (section == MainDestination.ACTIVITY && attentionCount > 0) {
                                    BadgedBox(
                                        badge = {
                                            Badge {
                                                Text(if (attentionCount > 99) "99+" else attentionCount.toString())
                                            }
                                        },
                                    ) {
                                        Icon(painterResource(section.iconRes), contentDescription = null)
                                    }
                                } else {
                                    Icon(painterResource(section.iconRes), contentDescription = null)
                                }
                            },
                            label = { Text(stringResource(section.navigationRes)) },
                        )
                    }
                }
            }
        },
    ) { insets ->
        key(destination) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(insets)
                    .verticalScroll(rememberScrollState())
                    .padding(start = 20.dp, end = 20.dp, top = 12.dp, bottom = 28.dp),
            ) {
                when (destination) {
                    MainDestination.SYNC -> PhotoSyncHome(home, onContinue, onGrant, onStart)
                    MainDestination.ACTIVITY -> ActivityPage(
                        state = activity,
                        onOpenSync = { onDestinationChange(MainDestination.SYNC) },
                    )
                    MainDestination.SETTINGS -> SettingsPage(
                        state = settings,
                        onStart = onStart,
                        onStop = onStop,
                        onGrantPhotos = onGrantPhotos,
                        onGrantNotifications = onGrantNotifications,
                        onCopyPairing = onCopyPairing,
                        onCopyEndpoint = onCopyEndpoint,
                        onCopyResult = onCopyResult,
                        onCopyDiagnostics = onCopyDiagnostics,
                        onClearHistory = onClearHistory,
                        onToggleAdvanced = onToggleAdvanced,
                    )
                }
            }
        }
    }
}

@Composable
private fun ActivityPage(state: ActivityUiState, onOpenSync: () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(20.dp)) {
        Text(stringResource(R.string.ui_activity_subtitle), color = MaterialTheme.colorScheme.onSurfaceVariant)
        if (state.history.isEmpty()) {
            HorizontalDivider()
            SectionHeading(stringResource(R.string.activity_empty_title))
            Text(stringResource(R.string.activity_empty_body), color = MaterialTheme.colorScheme.onSurfaceVariant)
            Button(onClick = onOpenSync, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(R.string.activity_open_sync))
            }
        } else {
            val completed = state.history.sumOf { it.completed }
            val failed = state.history.sumOf { it.failed }
            Surface(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(8.dp),
                color = MaterialTheme.colorScheme.secondaryContainer,
            ) {
                Row(modifier = Modifier.padding(20.dp), horizontalArrangement = Arrangement.spacedBy(24.dp)) {
                    HistoryMetric(
                        value = completed,
                        label = stringResource(R.string.activity_photos_completed),
                        modifier = Modifier.weight(1f),
                    )
                    HistoryMetric(
                        value = failed,
                        label = stringResource(R.string.activity_photos_attention),
                        modifier = Modifier.weight(1f),
                        attention = failed > 0,
                    )
                }
            }
            if (failed > 0) {
                Text(
                    stringResource(R.string.activity_attention_body, failed),
                    color = MaterialTheme.colorScheme.error,
                )
                OutlinedButton(onClick = onOpenSync, modifier = Modifier.fillMaxWidth()) {
                    Text(stringResource(R.string.activity_review_sync))
                }
            }
            SectionHeading(stringResource(R.string.ui_recent_activity))
            state.history.forEach { item ->
                HorizontalDivider()
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(item.date, fontWeight = FontWeight.SemiBold)
                    HistoryStatus(attention = item.failed > 0)
                }
                Text(
                    stringResource(R.string.history_item_summary, item.completed, item.failed),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            HorizontalDivider()
            Text(state.latestResult, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun SettingsPage(
    state: SettingsUiState,
    onStart: () -> Unit,
    onStop: () -> Unit,
    onGrantPhotos: () -> Unit,
    onGrantNotifications: () -> Unit,
    onCopyPairing: () -> Unit,
    onCopyEndpoint: () -> Unit,
    onCopyResult: () -> Unit,
    onCopyDiagnostics: () -> Unit,
    onClearHistory: () -> Unit,
    onToggleAdvanced: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(22.dp)) {
        SectionHeading(stringResource(R.string.settings_connection))
        SharingRow(state.sharing) { enabled -> if (enabled) onStart() else onStop() }
        SettingsRow(stringResource(R.string.settings_local_network), state.networkReady)
        if (!state.networkReady) {
            Text(stringResource(R.string.home_same_network), color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        SettingsRow(stringResource(R.string.settings_photo_access), state.photoAccess, onGrantPhotos)
        SettingsRow(stringResource(R.string.settings_notifications), state.notificationAccess, onGrantNotifications)
        HorizontalDivider()
        SectionHeading(stringResource(R.string.ui_connection_tools))
        Text(stringResource(R.string.settings_pairing_description), color = MaterialTheme.colorScheme.onSurfaceVariant)
        if (!state.pairingAvailable) {
            Text(stringResource(R.string.settings_pairing_unavailable), color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        TextButton(onClick = onCopyPairing, enabled = state.pairingAvailable) {
            Text(stringResource(R.string.sync_copy_pairing_payload))
        }
        HorizontalDivider()
        SectionHeading(stringResource(R.string.settings_privacy))
        Text(stringResource(R.string.privacy_summary), color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(stringResource(R.string.privacy_storage), color = MaterialTheme.colorScheme.onSurfaceVariant)
        HorizontalDivider()
        TextButton(onClick = onToggleAdvanced) {
            Text(stringResource(if (state.advancedExpanded) R.string.settings_hide_advanced_support else R.string.settings_show_advanced_support))
        }
        if (state.advancedExpanded) {
            SectionHeading(stringResource(R.string.sync_panel_diagnostics))
            Text(state.endpoint, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(state.requestActivity, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(state.transportSecurity, color = MaterialTheme.colorScheme.onSurfaceVariant)
            TextButton(onClick = onCopyEndpoint, enabled = state.endpointAvailable) {
                Text(stringResource(R.string.sync_copy_endpoint))
            }
            TextButton(onClick = onCopyResult, enabled = state.resultAvailable) {
                Text(stringResource(R.string.sync_copy_sync_result))
            }
            TextButton(onClick = onCopyDiagnostics) {
                Text(stringResource(R.string.diagnostics_copy_diagnostics))
            }
            TextButton(onClick = onClearHistory, enabled = state.resultAvailable) {
                Text(stringResource(R.string.sync_clear_sync_state), color = MaterialTheme.colorScheme.error)
            }
        }
        Spacer(modifier = Modifier.padding(4.dp))
    }
}

@Composable
private fun HistoryStatus(attention: Boolean) {
    Surface(
        shape = RoundedCornerShape(4.dp),
        color = if (attention) MaterialTheme.colorScheme.errorContainer else MaterialTheme.colorScheme.secondaryContainer,
    ) {
        Text(
            stringResource(if (attention) R.string.history_status_attention else R.string.history_status_complete),
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
            style = MaterialTheme.typography.labelSmall,
            color = if (attention) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary,
        )
    }
}

@Composable
private fun HistoryMetric(
    value: Int,
    label: String,
    modifier: Modifier = Modifier,
    attention: Boolean = false,
) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            value.toString(),
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            color = if (attention) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface,
        )
        Text(label, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun SharingRow(enabled: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().heightIn(min = 64.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(stringResource(R.string.settings_photo_sharing), fontWeight = FontWeight.SemiBold)
            Text(
                stringResource(if (enabled) R.string.settings_sharing_on else R.string.settings_sharing_off),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Switch(
            checked = enabled,
            onCheckedChange = onChange,
        )
    }
}

@Composable
private fun SettingsRow(label: String, ready: Boolean, onFix: (() -> Unit)? = null) {
    Row(
        modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(label)
            Text(
                stringResource(if (ready) R.string.settings_status_ready else R.string.settings_status_needed),
                style = MaterialTheme.typography.bodySmall,
                color = if (ready) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        if (!ready && onFix != null) {
            TextButton(onClick = onFix) { Text(stringResource(R.string.settings_allow)) }
        }
    }
}
