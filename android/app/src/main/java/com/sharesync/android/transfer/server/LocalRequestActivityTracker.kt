package com.sharesync.android.transfer.server

data class LocalRequestActivity(
    val endpoint: String,
    val statusCode: Int,
    val recordedAtEpochMillis: Long,
)

class LocalRequestActivityTracker(
    private val clock: () -> Long = { System.currentTimeMillis() },
) {
    @Volatile
    private var latestActivity: LocalRequestActivity? = null

    fun record(endpoint: String, statusCode: Int) {
        latestActivity = LocalRequestActivity(
            endpoint = endpoint,
            statusCode = statusCode,
            recordedAtEpochMillis = clock(),
        )
    }

    fun latest(): LocalRequestActivity? = latestActivity
}
