package com.sharesync.android

import java.util.concurrent.CountDownLatch
import kotlin.coroutines.Continuation
import kotlin.coroutines.EmptyCoroutineContext
import kotlin.coroutines.startCoroutine

object SuspendBridge {
    fun <T> runBlocking(block: suspend () -> T): T {
        val latch = CountDownLatch(1)
        var result: Result<T>? = null

        block.startCoroutine(
            Continuation(EmptyCoroutineContext) { completed ->
                result = completed
                latch.countDown()
            }
        )

        latch.await()
        return result!!.getOrThrow()
    }
}

