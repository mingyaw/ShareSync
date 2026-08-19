package com.sharesync.android.security

data class DeviceIdentity(
    val deviceId: String,
    val deviceName: String,
    val publicKey: String,
)

interface DeviceIdentityStore {
    suspend fun getOrCreate(): DeviceIdentity
}

