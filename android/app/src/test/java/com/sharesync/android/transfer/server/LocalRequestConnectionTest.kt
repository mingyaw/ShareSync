package com.sharesync.android.transfer.server

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LocalRequestConnectionTest {
    @Test
    fun successfulPhotoRequestsConfirmConnection() {
        listOf("manifest", "media", "sync-result").forEach { endpoint ->
            val tracker = LocalRequestActivityTracker()
            tracker.record(endpoint, 200)
            assertTrue(tracker.hasConnectedPeer())
        }
        val tracker = LocalRequestActivityTracker()
        tracker.record("sync-result", 202)
        assertTrue(tracker.hasConnectedPeer())
    }

    @Test
    fun healthAndFailedRequestsDoNotConfirmConnection() {
        val tracker = LocalRequestActivityTracker()
        tracker.record("health", 200)
        tracker.record("manifest", 401)
        assertFalse(tracker.hasConnectedPeer())
    }

    @Test
    fun connectionRemainsConfirmedAfterHealthCheck() {
        val tracker = LocalRequestActivityTracker()
        tracker.record("manifest", 200)
        tracker.record("health", 200)

        assertTrue(tracker.hasConnectedPeer())
    }
}
