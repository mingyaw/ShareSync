package com.sharesync.android.ui

import com.sharesync.android.R

enum class MainDestination(
    val titleRes: Int,
    val subtitleRes: Int,
    val navigationRes: Int,
    val iconRes: Int,
) {
    SYNC(
        R.string.ui_sync_title,
        R.string.ui_sync_subtitle,
        R.string.ui_nav_sync,
        android.R.drawable.ic_menu_share,
    ),
    ACTIVITY(
        R.string.ui_activity_title,
        R.string.ui_activity_subtitle,
        R.string.ui_nav_activity,
        android.R.drawable.ic_menu_recent_history,
    ),
    SETTINGS(
        R.string.ui_settings_title,
        R.string.ui_settings_subtitle,
        R.string.ui_nav_settings,
        android.R.drawable.ic_menu_preferences,
    ),
}
