package com.sharesync.android.sync

import org.json.JSONArray
import org.json.JSONObject

class SyncResultJsonCodec {
    fun decode(json: String): SyncResult {
        val root = JSONObject(json)
        return SyncResult(
            syncBatchId = root.getString("syncBatchId"),
            targetDeviceId = root.getString("targetDeviceId"),
            results = root.getJSONArray("results").toSyncItemResults(),
        )
    }

    fun encode(result: SyncResult): String {
        return JSONObject()
            .put("syncBatchId", result.syncBatchId)
            .put("targetDeviceId", result.targetDeviceId)
            .put(
                "results",
                JSONArray().also { array ->
                    result.results.forEach { item ->
                        array.put(
                            JSONObject()
                                .put("itemType", item.itemType.name)
                                .put("sourceItemId", item.sourceItemId)
                                .put("targetItemId", item.targetItemId)
                                .put("status", item.status.name)
                                .put("errorCode", item.errorCode)
                        )
                    }
                },
            )
            .toString(2)
    }

    private fun JSONArray.toSyncItemResults(): List<SyncItemResult> {
        return buildList {
            for (index in 0 until length()) {
                val item = getJSONObject(index)
                add(
                    SyncItemResult(
                        itemType = SyncItemType.valueOf(item.getString("itemType")),
                        sourceItemId = item.getString("sourceItemId"),
                        targetItemId = item.optNullableString("targetItemId"),
                        status = SyncItemStatus.valueOf(item.getString("status")),
                        errorCode = item.optNullableString("errorCode"),
                    )
                )
            }
        }
    }

    private fun JSONObject.optNullableString(name: String): String? {
        if (!has(name) || isNull(name)) {
            return null
        }
        return getString(name)
    }
}
