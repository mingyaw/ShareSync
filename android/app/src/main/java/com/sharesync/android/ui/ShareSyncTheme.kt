package com.sharesync.android.ui

import android.content.Context
import com.sharesync.android.R

data class ShareSyncTheme(
    val primary: Int,
    val onPrimary: Int,
    val success: Int,
    val warning: Int,
    val info: Int,
    val textPrimary: Int,
    val textSecondary: Int,
    val background: Int,
    val surface: Int,
    val surfaceAlt: Int,
    val divider: Int,
    val qrSurface: Int,
) {
    companion object {
        fun from(context: Context): ShareSyncTheme {
            return ShareSyncTheme(
                primary = context.getColor(R.color.sharesync_primary),
                onPrimary = context.getColor(R.color.sharesync_on_primary),
                success = context.getColor(R.color.sharesync_success),
                warning = context.getColor(R.color.sharesync_warning),
                info = context.getColor(R.color.sharesync_info),
                textPrimary = context.getColor(R.color.sharesync_text_primary),
                textSecondary = context.getColor(R.color.sharesync_text_secondary),
                background = context.getColor(R.color.sharesync_background),
                surface = context.getColor(R.color.sharesync_surface),
                surfaceAlt = context.getColor(R.color.sharesync_surface_alt),
                divider = context.getColor(R.color.sharesync_divider),
                qrSurface = context.getColor(R.color.sharesync_qr_surface),
            )
        }
    }
}
