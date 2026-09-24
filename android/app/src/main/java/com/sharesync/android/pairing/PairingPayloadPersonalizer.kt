package com.sharesync.android.pairing

import org.json.JSONObject

class PairingPayloadPersonalizer {
    fun replacePairingToken(payloadJson: String, pairingToken: String): String {
        require(pairingToken.isNotBlank())
        val payload = JSONObject(payloadJson)
        require(payload.getString("type") == "sharesync_pairing")
        require(payload.getString("platform") == "android")
        return payload.put("pairingToken", pairingToken).toString()
    }
}
