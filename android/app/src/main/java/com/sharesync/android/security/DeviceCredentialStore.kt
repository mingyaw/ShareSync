package com.sharesync.android.security

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.security.SecureRandom
import java.util.Base64

data class DeviceCredentialRotation(val deviceId: String, val secret: String)

interface DeviceCredentialStore {
    /** Null means this device has not migrated and may use the bootstrap secret. */
    fun authorizationSecrets(deviceId: String): List<String>?
    fun beginRotation(deviceId: String): DeviceCredentialRotation
    fun commit(rotation: DeviceCredentialRotation)
    fun cancel(rotation: DeviceCredentialRotation)
    fun revoke(deviceId: String)
}

class InMemoryDeviceCredentialStore(
    private val secretFactory: () -> String = ::newCredentialSecret,
) : DeviceCredentialStore {
    private val records = LinkedHashMap<String, DeviceCredentialRecord>()

    @Synchronized
    override fun authorizationSecrets(deviceId: String): List<String>? = records[deviceId]?.authorizationSecrets()

    @Synchronized
    override fun beginRotation(deviceId: String): DeviceCredentialRotation {
        require(deviceId.isNotBlank())
        val rotation = DeviceCredentialRotation(deviceId, secretFactory())
        val current = records[deviceId]
        records[deviceId] = DeviceCredentialRecord(current?.activeSecret, rotation.secret, revoked = false)
        return rotation
    }

    @Synchronized
    override fun commit(rotation: DeviceCredentialRotation) {
        val current = records[rotation.deviceId]
        require(current?.pendingSecret == rotation.secret)
        records[rotation.deviceId] = DeviceCredentialRecord(rotation.secret, null, revoked = false)
    }

    @Synchronized
    override fun cancel(rotation: DeviceCredentialRotation) {
        val current = records[rotation.deviceId] ?: return
        if (current.pendingSecret != rotation.secret) return
        if (current.activeSecret == null) records.remove(rotation.deviceId)
        else records[rotation.deviceId] = current.copy(pendingSecret = null)
    }

    @Synchronized
    override fun revoke(deviceId: String) {
        require(deviceId.isNotBlank())
        records[deviceId] = DeviceCredentialRecord(null, null, revoked = true)
    }
}

class SharedPreferencesDeviceCredentialStore(
    context: Context,
    private val secretFactory: () -> String = ::newCredentialSecret,
) : DeviceCredentialStore {
    private val preferences = context.applicationContext.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

    @Synchronized
    override fun authorizationSecrets(deviceId: String): List<String>? = readRecords()[deviceId]?.authorizationSecrets()

    @Synchronized
    override fun beginRotation(deviceId: String): DeviceCredentialRotation {
        require(deviceId.isNotBlank())
        val records = readRecords()
        val rotation = DeviceCredentialRotation(deviceId, secretFactory())
        val current = records[deviceId]
        records[deviceId] = DeviceCredentialRecord(current?.activeSecret, rotation.secret, revoked = false)
        writeRecords(records)
        return rotation
    }

    @Synchronized
    override fun commit(rotation: DeviceCredentialRotation) {
        val records = readRecords()
        val current = records[rotation.deviceId]
        require(current?.pendingSecret == rotation.secret)
        records[rotation.deviceId] = DeviceCredentialRecord(rotation.secret, null, revoked = false)
        writeRecords(records)
    }

    @Synchronized
    override fun cancel(rotation: DeviceCredentialRotation) {
        val records = readRecords()
        val current = records[rotation.deviceId] ?: return
        if (current.pendingSecret != rotation.secret) return
        if (current.activeSecret == null) records.remove(rotation.deviceId)
        else records[rotation.deviceId] = current.copy(pendingSecret = null)
        writeRecords(records)
    }

    @Synchronized
    override fun revoke(deviceId: String) {
        require(deviceId.isNotBlank())
        val records = readRecords()
        records[deviceId] = DeviceCredentialRecord(null, null, revoked = true)
        writeRecords(records)
    }

    private fun readRecords(): LinkedHashMap<String, DeviceCredentialRecord> {
        val encoded = preferences.getString(KEY_RECORDS, null) ?: return linkedMapOf()
        return runCatching {
            val array = JSONArray(encoded)
            LinkedHashMap<String, DeviceCredentialRecord>().apply {
                for (index in 0 until array.length()) {
                    val item = array.getJSONObject(index)
                    put(
                        item.getString("deviceId"),
                        DeviceCredentialRecord(
                            activeSecret = item.optString("activeSecret").takeIf(String::isNotBlank),
                            pendingSecret = item.optString("pendingSecret").takeIf(String::isNotBlank),
                            revoked = item.optBoolean("revoked"),
                        ),
                    )
                }
            }
        }.getOrDefault(linkedMapOf())
    }

    private fun writeRecords(records: Map<String, DeviceCredentialRecord>) {
        val array = JSONArray()
        records.forEach { (deviceId, record) ->
            array.put(
                JSONObject()
                    .put("deviceId", deviceId)
                    .put("activeSecret", record.activeSecret ?: "")
                    .put("pendingSecret", record.pendingSecret ?: "")
                    .put("revoked", record.revoked),
            )
        }
        preferences.edit().putString(KEY_RECORDS, array.toString()).apply()
    }

    private companion object {
        const val PREFERENCES_NAME = "share_sync_device_credentials"
        const val KEY_RECORDS = "records"
    }
}

private data class DeviceCredentialRecord(
    val activeSecret: String?,
    val pendingSecret: String?,
    val revoked: Boolean,
) {
    fun authorizationSecrets(): List<String> {
        if (revoked) return emptyList()
        return listOfNotNull(activeSecret, pendingSecret).distinct()
    }
}

private fun newCredentialSecret(): String {
    val bytes = ByteArray(32)
    SecureRandom().nextBytes(bytes)
    return Base64.getEncoder().withoutPadding().encodeToString(bytes)
}
