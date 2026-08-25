package com.sharesync.android.transfer.server

import com.sharesync.android.scanner.media.MediaStreamProvider
import java.io.BufferedReader
import java.io.InputStream
import java.io.InputStreamReader
import java.io.OutputStream
import java.net.ServerSocket
import java.net.Socket
import java.net.URLDecoder
import java.nio.charset.StandardCharsets
import java.util.Locale
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.coroutines.Continuation
import kotlin.coroutines.EmptyCoroutineContext
import kotlin.coroutines.startCoroutine

class EmbeddedLocalSyncServer(
    requestedPort: Int,
    private val router: LocalSyncRouter,
    private val mediaStreamProvider: MediaStreamProvider,
) : LocalSyncServer {
    override var port: Int = requestedPort
        private set

    @Volatile
    private var running = false

    private var serverSocket: ServerSocket? = null
    private val connectionExecutor = Executors.newCachedThreadPool()

    override suspend fun start() {
        if (running) return

        val socket = ServerSocket(port)
        port = socket.localPort
        serverSocket = socket
        running = true

        connectionExecutor.execute {
            while (running) {
                try {
                    val client = socket.accept()
                    connectionExecutor.execute {
                        client.use(::handleClient)
                    }
                } catch (_: Exception) {
                    if (running) {
                        // M0 server intentionally keeps failures local; diagnostics will be added later.
                    }
                }
            }
        }
    }

    override suspend fun stop() {
        running = false
        serverSocket?.close()
        serverSocket = null
        connectionExecutor.shutdown()
        connectionExecutor.awaitTermination(1, TimeUnit.SECONDS)
    }

    private fun handleClient(socket: Socket) {
        val reader = BufferedReader(InputStreamReader(socket.getInputStream(), StandardCharsets.UTF_8))
        val requestLine = reader.readLine() ?: return writeNotFound(socket.getOutputStream())
        val request = HttpRequest.parse(requestLine, reader) ?: return writeNotFound(socket.getOutputStream())

        when {
            request.method == "GET" && request.path == "/v1/health" -> {
                writeApiResponse(socket.getOutputStream(), runBlocking { router.health() })
            }
            request.method == "GET" && request.path == "/v1/manifest" -> {
                writeApiResponse(socket.getOutputStream(), runBlocking { router.manifest(request.headers) })
            }
            request.method == "GET" && request.path.startsWith("/v1/media/") -> {
                writeMediaResponse(socket.getOutputStream(), request)
            }
            request.method == "POST" && request.path == "/v1/sync/result" -> {
                writeApiResponse(
                    socket.getOutputStream(),
                    runBlocking { router.syncResult(request.body, request.headers) },
                )
            }
            request.method != "GET" && request.method != "POST" -> writeJsonError(socket.getOutputStream(), 405, "SS-NET-405")
            else -> writeNotFound(socket.getOutputStream())
        }
    }

    private fun writeMediaResponse(output: OutputStream, request: HttpRequest) {
        val assetId = request.path.removePrefix("/v1/media/").urlDecode()
        val response = runBlocking {
            router.media(
                assetId = assetId,
                rangeHeader = request.headers["range"],
                headers = request.headers,
            )
        }

        when (response) {
            is LocalMediaResponse.Found -> {
                val contentUri = response.asset.contentUri
                if (contentUri == null) {
                    writeJsonError(output, 404, "SS-MEDIA-URI")
                    return
                }

                val stream = mediaStreamProvider.open(contentUri)
                if (stream == null) {
                    writeJsonError(output, 404, "SS-MEDIA-STREAM")
                    return
                }

                val headers = response.headers.withSha256Header(
                    contentUri = contentUri,
                    range = response.range,
                )

                stream.use {
                    writeHeaders(output, response.statusCode, headers)
                    copyRange(it, output, response.range)
                }
            }
            is LocalMediaResponse.NotFound -> {
                writeJsonError(output, response.statusCode, response.errorCode)
            }
            is LocalMediaResponse.Unauthorized -> {
                writeJsonError(output, response.statusCode, response.errorCode)
            }
        }
    }

    private fun writeApiResponse(output: OutputStream, response: LocalApiResponse) {
        val body = response.body.toByteArray(StandardCharsets.UTF_8)
        writeHeaders(
            output = output,
            statusCode = response.statusCode,
            headers = response.headers + ("Content-Length" to body.size.toString()),
        )
        output.write(body)
    }

    private fun writeNotFound(output: OutputStream) {
        writeJsonError(output, 404, "SS-NET-404")
    }

    private fun writeJsonError(output: OutputStream, statusCode: Int, errorCode: String) {
        val body = """{"errorCode":"$errorCode"}""".toByteArray(StandardCharsets.UTF_8)
        writeHeaders(
            output = output,
            statusCode = statusCode,
            headers = mapOf(
                "Content-Type" to "application/json; charset=utf-8",
                "Content-Length" to body.size.toString(),
            ),
        )
        output.write(body)
    }

    private fun writeHeaders(output: OutputStream, statusCode: Int, headers: Map<String, String>) {
        output.write("HTTP/1.1 $statusCode ${statusText(statusCode)}\r\n".toByteArray(StandardCharsets.UTF_8))
        output.write("Connection: close\r\n".toByteArray(StandardCharsets.UTF_8))
        headers.forEach { (name, value) ->
            output.write("$name: $value\r\n".toByteArray(StandardCharsets.UTF_8))
        }
        output.write("\r\n".toByteArray(StandardCharsets.UTF_8))
    }

    private fun Map<String, String>.withSha256Header(
        contentUri: String,
        range: ByteRange,
    ): Map<String, String> {
        if (containsKey("X-ShareSync-SHA256") || range.isPartial) {
            return this
        }

        val sha256 = mediaStreamProvider.sha256(contentUri) ?: return this
        return this + ("X-ShareSync-SHA256" to sha256)
    }

    private fun copyRange(input: InputStream, output: OutputStream, range: ByteRange) {
        skipFully(input, range.start)
        var remaining = range.endInclusive - range.start + 1
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)

        while (remaining > 0) {
            val readSize = minOf(buffer.size.toLong(), remaining).toInt()
            val read = input.read(buffer, 0, readSize)
            if (read < 0) break
            output.write(buffer, 0, read)
            remaining -= read
        }
    }

    private fun skipFully(input: InputStream, bytes: Long) {
        var remaining = bytes
        while (remaining > 0) {
            val skipped = input.skip(remaining)
            if (skipped <= 0) {
                if (input.read() < 0) return
                remaining -= 1
            } else {
                remaining -= skipped
            }
        }
    }

    private fun statusText(statusCode: Int): String {
        return when (statusCode) {
            200 -> "OK"
            202 -> "Accepted"
            400 -> "Bad Request"
            401 -> "Unauthorized"
            206 -> "Partial Content"
            404 -> "Not Found"
            405 -> "Method Not Allowed"
            else -> "Error"
        }
    }

    private data class HttpRequest(
        val method: String,
        val path: String,
        val headers: Map<String, String>,
        val body: String,
    ) {
        companion object {
            fun parse(requestLine: String, reader: BufferedReader): HttpRequest? {
                val parts = requestLine.split(" ")
                if (parts.size < 2) return null

                val headers = mutableMapOf<String, String>()
                while (true) {
                    val line = reader.readLine() ?: break
                    if (line.isEmpty()) break
                    val name = line.substringBefore(":", missingDelimiterValue = "").trim()
                    val value = line.substringAfter(":", missingDelimiterValue = "").trim()
                    if (name.isNotEmpty()) {
                        headers[name.lowercase(Locale.US)] = value
                    }
                }

                val rawPath = parts[1].substringBefore("?")
                val contentLength = headers["content-length"]?.toIntOrNull()?.coerceAtLeast(0) ?: 0
                val body = if (contentLength > 0) {
                    val chars = CharArray(contentLength)
                    var offset = 0
                    while (offset < contentLength) {
                        val read = reader.read(chars, offset, contentLength - offset)
                        if (read < 0) break
                        offset += read
                    }
                    String(chars, 0, offset)
                } else {
                    ""
                }

                return HttpRequest(
                    method = parts[0].uppercase(Locale.US),
                    path = rawPath,
                    headers = headers,
                    body = body,
                )
            }
        }
    }

    private fun String.urlDecode(): String {
        return URLDecoder.decode(this, StandardCharsets.UTF_8.name())
    }

    private fun <T> runBlocking(block: suspend () -> T): T {
        val latch = CountDownLatch(1)
        var result: kotlin.Result<T>? = null

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
