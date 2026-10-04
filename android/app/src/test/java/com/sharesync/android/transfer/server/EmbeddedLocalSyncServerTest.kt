package com.sharesync.android.transfer.server

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test
import java.io.ByteArrayInputStream
import java.nio.charset.StandardCharsets

class EmbeddedLocalSyncServerTest {
    @Test
    fun requestParserUsesByteLengthForUtf8NoteBodies() {
        val body = """{"title":"工作記事","body":"記得同步到 Mac"}"""
        val bodyBytes = body.toByteArray(StandardCharsets.UTF_8)
        val requestBytes = buildRequest(bodyBytes)

        val request = EmbeddedLocalSyncServer.HttpRequest.parse(ByteArrayInputStream(requestBytes))

        assertEquals("POST", request?.method)
        assertEquals("/v1/notes", request?.path)
        assertEquals(body, request?.body)
    }

    @Test
    fun requestParserRejectsTruncatedUtf8Body() {
        val bodyBytes = "記事".toByteArray(StandardCharsets.UTF_8)
        val requestBytes = buildRequest(bodyBytes, declaredLength = bodyBytes.size + 1)

        val request = EmbeddedLocalSyncServer.HttpRequest.parse(ByteArrayInputStream(requestBytes))

        assertNull(request)
    }

    @Test
    fun requestParserReportsPayloadLargerThanNoteLimit() {
        val requestBytes = buildRequest(ByteArray(0), declaredLength = 8 * 1024 * 1024 + 1)

        assertThrows(EmbeddedLocalSyncServer.PayloadTooLargeException::class.java) {
            EmbeddedLocalSyncServer.HttpRequest.parse(ByteArrayInputStream(requestBytes))
        }
    }

    private fun buildRequest(body: ByteArray, declaredLength: Int = body.size): ByteArray {
        val headers = (
            "POST /v1/notes HTTP/1.1\r\n" +
                "Host: 192.168.1.10\r\n" +
                "Content-Type: application/json; charset=utf-8\r\n" +
                "Content-Length: $declaredLength\r\n" +
                "\r\n"
            ).toByteArray(StandardCharsets.ISO_8859_1)
        return headers + body
    }
}
