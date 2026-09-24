package com.sharesync.android.sync

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class GatewayDevice(
    val deviceId: String,
    val displayName: String,
    val lastSeenEpochMillis: Long,
)

interface GatewayOwnershipStore {
    fun observe(deviceId: String, displayName: String? = null): GatewayDevice
    fun devices(): List<GatewayDevice>
    fun revokedDevices(): List<GatewayDevice>
    fun activeDeviceId(): String?
    fun select(deviceId: String)
    fun remove(deviceId: String)

    fun canSync(deviceId: String): Boolean {
        return activeDeviceId()?.let { it == deviceId } ?: true
    }
}

class InMemoryGatewayOwnershipStore(
    private val clock: () -> Long = System::currentTimeMillis,
) : GatewayOwnershipStore {
    private val devicesById = LinkedHashMap<String, GatewayDevice>()
    private val revokedById = LinkedHashMap<String, GatewayDevice>()
    private var activeId: String? = null

    @Synchronized
    override fun observe(deviceId: String, displayName: String?): GatewayDevice {
        require(deviceId.isNotBlank())
        val existing = devicesById[deviceId]
        val device = GatewayDevice(
            deviceId = deviceId,
            displayName = displayName?.takeIf { it.isNotBlank() }
                ?: existing?.displayName
                ?: defaultGatewayName(deviceId),
            lastSeenEpochMillis = clock(),
        )
        revokedById.remove(deviceId)
        devicesById[deviceId] = device
        if (activeId == null) activeId = deviceId
        return device
    }

    @Synchronized
    override fun devices(): List<GatewayDevice> = devicesById.values.sortedByDescending { it.lastSeenEpochMillis }

    @Synchronized
    override fun revokedDevices(): List<GatewayDevice> = revokedById.values.sortedByDescending { it.lastSeenEpochMillis }

    @Synchronized
    override fun activeDeviceId(): String? = activeId

    @Synchronized
    override fun select(deviceId: String) {
        require(devicesById.containsKey(deviceId))
        activeId = deviceId
    }

    @Synchronized
    override fun remove(deviceId: String) {
        val removed = devicesById.remove(deviceId) ?: return
        revokedById[deviceId] = removed
        if (activeId == deviceId) {
            activeId = devicesById.values.maxByOrNull(GatewayDevice::lastSeenEpochMillis)?.deviceId
        }
    }
}

class SharedPreferencesGatewayOwnershipStore(
    context: Context,
    private val clock: () -> Long = System::currentTimeMillis,
) : GatewayOwnershipStore {
    private val preferences = context.applicationContext.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

    @Synchronized
    override fun observe(deviceId: String, displayName: String?): GatewayDevice {
        require(deviceId.isNotBlank())
        val devices = readDevices().associateByTo(LinkedHashMap(), GatewayDevice::deviceId)
        val existing = devices[deviceId]
        val device = GatewayDevice(
            deviceId = deviceId,
            displayName = displayName?.takeIf { it.isNotBlank() }
                ?: existing?.displayName
                ?: defaultGatewayName(deviceId),
            lastSeenEpochMillis = clock(),
        )
        devices[deviceId] = device
        val revoked = readRevokedDevices().filterNot { it.deviceId == deviceId }
        val editor = preferences.edit()
            .putString(KEY_DEVICES, encode(devices.values))
            .putString(KEY_REVOKED_DEVICES, encode(revoked))
        if (activeDeviceId().isNullOrBlank()) editor.putString(KEY_ACTIVE_DEVICE_ID, deviceId)
        editor.apply()
        return device
    }

    @Synchronized
    override fun devices(): List<GatewayDevice> = readDevices().sortedByDescending { it.lastSeenEpochMillis }

    @Synchronized
    override fun revokedDevices(): List<GatewayDevice> =
        readRevokedDevices().sortedByDescending { it.lastSeenEpochMillis }

    override fun activeDeviceId(): String? {
        return preferences.getString(KEY_ACTIVE_DEVICE_ID, null)?.takeIf { it.isNotBlank() }
    }

    @Synchronized
    override fun select(deviceId: String) {
        require(readDevices().any { it.deviceId == deviceId })
        preferences.edit().putString(KEY_ACTIVE_DEVICE_ID, deviceId).apply()
    }

    @Synchronized
    override fun remove(deviceId: String) {
        val devices = readDevices()
        val removed = devices.firstOrNull { it.deviceId == deviceId } ?: return
        val remaining = devices.filterNot { it.deviceId == deviceId }
        val revoked = readRevokedDevices()
            .filterNot { it.deviceId == deviceId }
            .plus(removed)
        val editor = preferences.edit()
            .putString(KEY_DEVICES, encode(remaining))
            .putString(KEY_REVOKED_DEVICES, encode(revoked))
        if (activeDeviceId() == deviceId) {
            val replacement = remaining.maxByOrNull(GatewayDevice::lastSeenEpochMillis)?.deviceId
            if (replacement == null) editor.remove(KEY_ACTIVE_DEVICE_ID)
            else editor.putString(KEY_ACTIVE_DEVICE_ID, replacement)
        }
        editor.apply()
    }

    private fun readDevices(): List<GatewayDevice> {
        return readDevices(KEY_DEVICES)
    }

    private fun readRevokedDevices(): List<GatewayDevice> {
        return readDevices(KEY_REVOKED_DEVICES)
    }

    private fun readDevices(key: String): List<GatewayDevice> {
        val value = preferences.getString(key, null) ?: return emptyList()
        return runCatching {
            val array = JSONArray(value)
            buildList {
                for (index in 0 until array.length()) {
                    val item = array.getJSONObject(index)
                    add(
                        GatewayDevice(
                            deviceId = item.getString("deviceId"),
                            displayName = item.getString("displayName"),
                            lastSeenEpochMillis = item.getLong("lastSeenEpochMillis"),
                        )
                    )
                }
            }
        }.getOrDefault(emptyList())
    }

    private fun encode(devices: Collection<GatewayDevice>): String {
        val array = JSONArray()
        devices.forEach { device ->
            array.put(
                JSONObject()
                    .put("deviceId", device.deviceId)
                    .put("displayName", device.displayName)
                    .put("lastSeenEpochMillis", device.lastSeenEpochMillis)
            )
        }
        return array.toString()
    }

    private companion object {
        const val PREFERENCES_NAME = "share_sync_gateway_ownership"
        const val KEY_DEVICES = "devices"
        const val KEY_REVOKED_DEVICES = "revoked_devices"
        const val KEY_ACTIVE_DEVICE_ID = "active_device_id"
    }
}

private fun defaultGatewayName(deviceId: String): String {
    return when {
        deviceId.startsWith("mac", ignoreCase = true) -> "Mac"
        deviceId.startsWith("ios", ignoreCase = true) -> "iPhone / iPad"
        else -> deviceId
    }
}
