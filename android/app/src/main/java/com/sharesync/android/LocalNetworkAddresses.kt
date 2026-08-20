package com.sharesync.android

import java.net.Inet4Address
import java.net.NetworkInterface

object LocalNetworkAddresses {
    fun firstIpv4Address(): String? {
        val interfaces = NetworkInterface.getNetworkInterfaces()?.toList().orEmpty()
        return interfaces
            .asSequence()
            .filter { networkInterface ->
                networkInterface.isUp && !networkInterface.isLoopback
            }
            .flatMap { networkInterface ->
                networkInterface.inetAddresses.toList().asSequence()
            }
            .filterIsInstance<Inet4Address>()
            .firstOrNull { address ->
                !address.isLoopbackAddress && !address.isLinkLocalAddress
            }
            ?.hostAddress
    }
}

