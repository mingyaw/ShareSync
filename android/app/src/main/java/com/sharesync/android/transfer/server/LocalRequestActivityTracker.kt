package com.sharesync.android.transfer.server

data class LocalRequestActivity(
    val endpoint: String,
    val statusCode: Int,
    val recordedAtEpochMillis: Long,
    val requestCount: Int,
)

class LocalRequestActivityTracker(
    private val clock: () -> Long = { System.currentTimeMillis() },
) {
    private val lock = Any()

    @Volatile
    private var latestActivity: LocalRequestActivity? = null
    private var requestCount = 0

    fun record(endpoint: String, statusCode: Int) {
        synchronized(lock) {
            requestCount += 1
            latestActivity = LocalRequestActivity(
                endpoint = endpoint,
                statusCode = statusCode,
                recordedAtEpochMillis = clock(),
                requestCount = requestCount,
            )
        }
    }

    fun latest(): LocalRequestActivity? = latestActivity
}
