package com.sharesync.android.pairing

import org.json.JSONObject

class PairingPayloadPersonalizer {
    fun replacePairingToken(payloadJson: String, pairingToken: String): String {
        require(pairingToken.isNotBlank())
        val payload = JSONObject(payloadJson)
        require(payload.getString("type") == "sharesync_pairing")
        require(payload.getString("platform") == "android")
        payload.put("pairingToken", pairingToken)
        payload.remove("registrationToken")
        return payload.toString()
    }
}
