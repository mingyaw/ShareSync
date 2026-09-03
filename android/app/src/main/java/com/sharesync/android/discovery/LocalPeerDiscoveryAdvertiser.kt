package com.sharesync.android.discovery

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.os.Build
import com.sharesync.android.security.DeviceIdentity

class LocalPeerDiscoveryAdvertiser(
    context: Context,
) {
    private val nsdManager = context.applicationContext.getSystemService(NsdManager::class.java)
    private var registrationListener: NsdManager.RegistrationListener? = null

    fun start(identity: DeviceIdentity, port: Int) {
        if (registrationListener != null) {
            return
        }

        val serviceInfo = NsdServiceInfo().apply {
            serviceName = "ShareSync ${identity.deviceName}".take(MAX_SERVICE_NAME_LENGTH)
            serviceType = SERVICE_TYPE
            setPort(port)
            setAttribute("deviceId", identity.deviceId)
            setAttribute("platform", "android")
            setAttribute("version", PROTOCOL_VERSION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                network = null
            }
        }
        val listener = object : NsdManager.RegistrationListener {
            override fun onServiceRegistered(serviceInfo: NsdServiceInfo) = Unit
            override fun onRegistrationFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
                registrationListener = null
            }
            override fun onServiceUnregistered(serviceInfo: NsdServiceInfo) = Unit
            override fun onUnregistrationFailed(serviceInfo: NsdServiceInfo, errorCode: Int) = Unit
        }
        registrationListener = listener
        nsdManager.registerService(serviceInfo, NsdManager.PROTOCOL_DNS_SD, listener)
    }

    fun stop() {
        val listener = registrationListener ?: return
        registrationListener = null
        runCatching { nsdManager.unregisterService(listener) }
    }

    companion object {
        const val SERVICE_TYPE = "_sharesync._tcp."
        const val PROTOCOL_VERSION = "1"
        private const val MAX_SERVICE_NAME_LENGTH = 60
    }
}
