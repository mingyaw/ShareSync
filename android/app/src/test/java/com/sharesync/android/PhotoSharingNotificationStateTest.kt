package com.sharesync.android

import org.junit.Assert.assertEquals
import org.junit.Test

class PhotoSharingNotificationStateTest {
    @Test
    fun waitingIsUsedBeforeIPhoneConnects() {
        assertEquals(
            NotificationState.WAITING,
            NotificationState.from(hasConnectedPeer = false, hasSyncResult = false, hasFailures = false),
        )
    }

    @Test
    fun connectionAndCompletionAdvanceNotificationState() {
        assertEquals(
            NotificationState.CONNECTED,
            NotificationState.from(hasConnectedPeer = true, hasSyncResult = false, hasFailures = false),
        )
        assertEquals(
            NotificationState.COMPLETE,
            NotificationState.from(hasConnectedPeer = true, hasSyncResult = true, hasFailures = false),
        )
    }

    @Test
    fun retryableFailureTakesPriority() {
        assertEquals(
            NotificationState.ATTENTION,
            NotificationState.from(hasConnectedPeer = true, hasSyncResult = true, hasFailures = true),
        )
    }
}
