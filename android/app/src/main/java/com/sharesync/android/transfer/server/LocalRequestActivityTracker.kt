package com.sharesync.android.transfer.server

data class LocalRequestActivity(
    val endpoint: String,
    val statusCode: Int,
    val recordedAtEpochMillis: Long,
    val requestCount: Int,
    val endpointRequestCount: Int,
)

class LocalRequestActivityTracker(
    private val clock: () -> Long = { System.currentTimeMillis() },
) {
    private val lock = Any()

    @Volatile
    private var latestActivity: LocalRequestActivity? = null
    private var requestCount = 0
    private var hasConnectedPeer = false
    private val endpointRequestCounts = mutableMapOf<String, Int>()

    fun record(endpoint: String, statusCode: Int) {
        synchronized(lock) {
            requestCount += 1
            val endpointCount = (endpointRequestCounts[endpoint] ?: 0) + 1
            endpointRequestCounts[endpoint] = endpointCount
            hasConnectedPeer = hasConnectedPeer ||
                (statusCode in 200..299 && endpoint in PHOTO_ENDPOINTS)
            latestActivity = LocalRequestActivity(
                endpoint = endpoint,
                statusCode = statusCode,
                recordedAtEpochMillis = clock(),
                requestCount = requestCount,
                endpointRequestCount = endpointCount,
            )
        }
    }

    fun latest(): LocalRequestActivity? = latestActivity

    fun hasConnectedPeer(): Boolean = synchronized(lock) { hasConnectedPeer }

    private companion object {
        val PHOTO_ENDPOINTS = setOf("manifest", "media", "sync-result")
    }
}
