package com.sharesync.android.security

import android.content.Context
import android.os.Build
import java.util.UUID

data class DeviceIdentity(
    val deviceId: String,
    val deviceName: String,
    val publicKey: String,
)

interface DeviceIdentityStore {
    suspend fun getOrCreate(): DeviceIdentity
}

class SharedPreferencesDeviceIdentityStore(context: Context) : DeviceIdentityStore {
    private val preferences = context.applicationContext.getSharedPreferences(
        PREFERENCES_NAME,
        Context.MODE_PRIVATE,
    )

    override suspend fun getOrCreate(): DeviceIdentity {
        synchronized(preferences) {
            val existingDeviceId = preferences.getString(KEY_DEVICE_ID, null)
            val existingDeviceName = preferences.getString(KEY_DEVICE_NAME, null)
            val existingPublicKey = preferences.getString(KEY_PUBLIC_KEY, null)

            if (!existingDeviceId.isNullOrBlank() &&
                !existingDeviceName.isNullOrBlank() &&
                !existingPublicKey.isNullOrBlank()
            ) {
                return DeviceIdentity(
                    deviceId = existingDeviceId,
                    deviceName = existingDeviceName,
                    publicKey = existingPublicKey,
                )
            }

            val identity = DeviceIdentity(
                deviceId = "android-${UUID.randomUUID().toString().replace("-", "")}",
                deviceName = Build.MODEL.ifBlank { "Android" },
                publicKey = "m0-key-${UUID.randomUUID().toString().replace("-", "")}",
            )

            preferences.edit()
                .putString(KEY_DEVICE_ID, identity.deviceId)
                .putString(KEY_DEVICE_NAME, identity.deviceName)
                .putString(KEY_PUBLIC_KEY, identity.publicKey)
                .apply()

            return identity
        }
    }

    private companion object {
        const val PREFERENCES_NAME = "share_sync_device_identity"
        const val KEY_DEVICE_ID = "device_id"
        const val KEY_DEVICE_NAME = "device_name"
        const val KEY_PUBLIC_KEY = "public_key"
    }
}
