package com.sharesync.android.security

import android.content.Context
import java.util.UUID

class SharedPreferencesPairingSecretStore(context: Context) {
    private val preferences = context.applicationContext.getSharedPreferences(
        PREFERENCES_NAME,
        Context.MODE_PRIVATE,
    )

    fun getOrCreate(): String {
        synchronized(preferences) {
            val existing = preferences.getString(KEY_PAIRING_SECRET, null)
            if (!existing.isNullOrBlank()) return existing

            val created = UUID.randomUUID().toString().replace("-", "")
            preferences.edit().putString(KEY_PAIRING_SECRET, created).apply()
            return created
        }
    }

    private companion object {
        const val PREFERENCES_NAME = "share_sync_pairing_secret"
        const val KEY_PAIRING_SECRET = "pairing_secret"
    }
}
