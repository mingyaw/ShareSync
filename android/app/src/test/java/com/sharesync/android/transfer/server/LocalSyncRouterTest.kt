package com.sharesync.android.transfer.server

import com.sharesync.android.SuspendBridge
import com.sharesync.android.notes.InMemoryNoteStore
import com.sharesync.android.notes.NoteRepository
import com.sharesync.android.notes.NoteRevision
import com.sharesync.android.notes.NoteSyncBatch
import com.sharesync.android.notes.NoteSyncBatchCodec
import com.sharesync.android.notes.VersionedNote
import com.sharesync.android.pairing.PairingRegistrationWindow
import com.sharesync.android.security.DeviceCredentialStore
import com.sharesync.android.security.InMemoryDeviceCredentialStore
import com.sharesync.android.sync.InMemorySyncEventStore
import com.sharesync.android.sync.InMemoryGatewayOwnershipStore
import com.sharesync.android.sync.InMemorySyncResultStore
import com.sharesync.android.sync.MediaAsset
import com.sharesync.android.sync.MediaType
import com.sharesync.android.sync.SyncManifest
import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.Instant

class LocalSyncRouterTest {
    @Test
    fun notesSnapshotRejectsMissingAuthorization() {
        val response = SuspendBridge.runBlocking {
            router(noteRepository = noteRepository()).noteSnapshot()
        }

        assertEquals(401, response.statusCode)
        assertEquals("""{"errorCode":"SS-AUTH-001"}""", response.body)
    }

    @Test
    fun notesSnapshotReturnsDeterministicRepositoryBatch() {
        val store = InMemoryNoteStore(listOf(note()))
        val response = SuspendBridge.runBlocking {
            router(
                noteRepository = noteRepository(store),
                noteBatchIdProvider = { "notes-batch-001" },
                clock = { 2_000L },
                authorizationPolicy = AuthorizationPolicy.SignedRequestsWithPairingTokenFallback,
            ).noteSnapshot(headers = pairingHeaders())
        }
        val batch = NoteSyncBatchCodec().decode(response.body)

        assertEquals(200, response.statusCode)
        assertEquals("notes-batch-001", batch.batchId)
        assertEquals("android-device-001", batch.sourceDeviceId)
        assertEquals(2_000L, batch.generatedAtEpochMillis)
        assertEquals(listOf("note-001"), batch.notes.map(VersionedNote::id))
    }

    @Test
    fun notesPostMergesRemoteBatchAndReportsAggregateResult() {
        val store = InMemoryNoteStore()
        val batch = NoteSyncBatch(
            batchId = "mac-notes-001",
            sourceDeviceId = "mac-device-001",
            generatedAtEpochMillis = 2_000L,
            notes = listOf(note(deviceId = "mac-device-001")),
        )
        val body = NoteSyncBatchCodec().encode(batch)
        val response = SuspendBridge.runBlocking {
            router(
                noteRepository = noteRepository(store),
                authorizationPolicy = AuthorizationPolicy.SignedRequestsWithPairingTokenFallback,
            ).mergeNotes(body = body, headers = pairingHeaders())
        }

        assertEquals(202, response.statusCode)
        assertEquals("accepted", org.json.JSONObject(response.body).getString("status"))
        assertEquals(1, org.json.JSONObject(response.body).getInt("acceptedRemoteCount"))
        assertEquals(note(deviceId = "mac-device-001"), SuspendBridge.runBlocking { store.get("note-001") })
    }

    @Test
    fun notesPostRejectsBatchFromDifferentSignedDevice() {
        val batch = NoteSyncBatch(
            batchId = "mac-notes-001",
            sourceDeviceId = "different-device",
            generatedAtEpochMillis = 2_000L,
            notes = listOf(note(deviceId = "different-device")),
        )
        val body = NoteSyncBatchCodec().encode(batch)
        val timestamp = "1800000000000"
        val nonce = "notes-source-mismatch"
        val response = SuspendBridge.runBlocking {
            router(
                noteRepository = noteRepository(),
                signatureValidator = RequestSignatureValidator(
                    secretProvider = { PAIRING_TOKEN },
                    clock = { 1_800_000_000_000L },
                ),
            ).mergeNotes(
                body = body,
                headers = signedHeaders(
                    deviceId = "mac-device-001",
                    nonce = nonce,
                    timestamp = timestamp,
                    signature = RequestSignatureValidator.sign(
                        secret = PAIRING_TOKEN,
                        version = "2",
                        deviceId = "mac-device-001",
                        sessionId = "ios-photo-mvp",
                        method = "POST",
                        path = "/v1/notes",
                        timestamp = timestamp,
                        nonce = nonce,
                        body = body,
                    ),
                ),
            )
        }

        assertEquals(400, response.statusCode)
        assertEquals("""{"errorCode":"SS-REQ-001"}""", response.body)
    }

    @Test
    fun pairedDeviceCanRevokeItsCredentialAndGatewayRegistration() {
        val credentialStore = InMemoryDeviceCredentialStore { "ios-device-secret" }
        credentialStore.commit(credentialStore.beginRotation("ios-device-001"))
        val gatewayStore = InMemoryGatewayOwnershipStore().apply {
            observe("ios-device-001", "Mingyao iPhone")
        }
        val timestamp = "1800000000000"
        val nonce = "remove-device-nonce"
        val headers = signedHeaders(
            deviceId = "ios-device-001",
            nonce = nonce,
            signature = RequestSignatureValidator.sign(
                secret = "ios-device-secret",
                version = "2",
                deviceId = "ios-device-001",
                sessionId = "ios-photo-mvp",
                method = "DELETE",
                path = "/v1/pairing/device",
                timestamp = timestamp,
                nonce = nonce,
                body = "",
            ),
        )

        val response = SuspendBridge.runBlocking {
            router(
                gatewayOwnershipStore = gatewayStore,
                deviceCredentialStore = credentialStore,
                signatureValidator = RequestSignatureValidator(
                    secretProvider = { PAIRING_TOKEN },
                    deviceSecretsProvider = credentialStore::authorizationSecrets,
                    clock = { 1_800_000_000_000L },
                ),
            ).unregisterDevice(headers = headers)
        }

        assertEquals(202, response.statusCode)
        assertEquals(emptyList<String>(), credentialStore.authorizationSecrets("ios-device-001"))
        assertEquals(emptyList<String>(), gatewayStore.devices().map { it.deviceId })
    }

    @Test
    fun pairingRegistrationIssuesDeviceScopedSecretAndObservesGateway() {
        val credentialStore = InMemoryDeviceCredentialStore { "ios-device-secret" }
        val gatewayStore = InMemoryGatewayOwnershipStore()
        val window = PairingRegistrationWindow(
            token = "registration-token",
            expiresAt = Instant.parse("2100-01-01T00:10:00Z"),
            clock = { Instant.parse("2100-01-01T00:00:00Z") },
        )
        val body = """{"deviceId":"ios-device-001","deviceName":"Mingyao iPhone","platform":"ios"}"""
        val timestamp = System.currentTimeMillis().toString()
        val nonce = "registration-nonce"
        val headers = signedHeaders(
            deviceId = "ios-device-001",
            nonce = nonce,
            signature = RequestSignatureValidator.sign(
                secret = window.token,
                version = "2",
                deviceId = "ios-device-001",
                sessionId = "ios-pairing-registration",
                method = "POST",
                path = "/v1/pairing/register",
                timestamp = timestamp,
                nonce = nonce,
                body = body,
            ),
            timestamp = timestamp,
            sessionId = "ios-pairing-registration",
        )

        val response = SuspendBridge.runBlocking {
            router(
                gatewayOwnershipStore = gatewayStore,
                deviceCredentialStore = credentialStore,
                pairingRegistrationWindow = window,
            ).registerDevice(body = body, headers = headers)
        }

        assertEquals(201, response.statusCode)
        assertEquals("ios-device-secret", org.json.JSONObject(response.body).getString("pairingToken"))
        assertEquals(listOf("ios-device-secret"), credentialStore.authorizationSecrets("ios-device-001"))
        assertEquals("Mingyao iPhone", gatewayStore.devices().single().displayName)
    }

    @Test
    fun manifestRejectsMissingPairingToken() {
        val response = SuspendBridge.runBlocking {
            router().manifest()
        }

        assertEquals(401, response.statusCode)
        assertEquals("""{"errorCode":"SS-AUTH-001"}""", response.body)
    }

    @Test
    fun manifestAcceptsExpectedPairingToken() {
        val activityTracker = LocalRequestActivityTracker(clock = { 1234L })
        val response = SuspendBridge.runBlocking {
            router(
                requestActivityTracker = activityTracker,
                authorizationPolicy = AuthorizationPolicy.SignedRequestsWithPairingTokenFallback,
            )
                .manifest(mapOf(LocalSyncRouter.PAIRING_TOKEN_HEADER to PAIRING_TOKEN))
        }

        assertEquals(200, response.statusCode)
        assertEquals(LocalRequestActivity("manifest", 200, 1234L, 1, 1), activityTracker.latest())
    }

    @Test
    fun manifestRejectsTokenOnlyWhenSignedRequestsAreRequired() {
        val response = SuspendBridge.runBlocking {
            router()
                .manifest(mapOf(LocalSyncRouter.PAIRING_TOKEN_HEADER to PAIRING_TOKEN))
        }

        assertEquals(401, response.statusCode)
    }

    @Test
    fun manifestAcceptsSignedRequestWithoutPairingTokenHeader() {
        val response = SuspendBridge.runBlocking {
            router(
                signatureValidator = RequestSignatureValidator(
                    secretProvider = { "pairing-token-001" },
                    clock = { 1_800_000_000_000L },
                )
            ).manifest(
                headers = signedHeaders(
                    signature = "wJ/9g1hjKiodbIT7xAKm5apkW0NJWqeTc1BdocF+ywQ=",
                )
            )
        }

        assertEquals(200, response.statusCode)
    }

    @Test
    fun manifestForwardsRequestingDeviceIdToProvider() {
        var requestedTargetDeviceId: String? = null
        val response = SuspendBridge.runBlocking {
            router(
                manifestProvider = object : ManifestProvider {
                    override suspend fun currentManifest(
                        sinceCursor: String?,
                        pageCursor: String?,
                        targetDeviceId: String?,
                    ): SyncManifest {
                        requestedTargetDeviceId = targetDeviceId
                        return emptyManifest()
                    }
                },
                signatureValidator = RequestSignatureValidator(
                    secretProvider = { PAIRING_TOKEN },
                    clock = { 1_800_000_000_000L },
                ),
            ).manifest(
                headers = signedHeaders(
                    deviceId = "mac-device-001",
                    signature = RequestSignatureValidator.sign(
                        secret = PAIRING_TOKEN,
                        version = "2",
                        deviceId = "mac-device-001",
                        sessionId = "ios-photo-mvp",
                        method = "GET",
                        path = "/v1/manifest",
                        timestamp = "1800000000000",
                        nonce = "nonce-001",
                        body = "",
                    ),
                )
            )
        }

        assertEquals(200, response.statusCode)
        assertEquals("mac-device-001", requestedTargetDeviceId)
    }

    @Test
    fun manifestRejectsNonActiveGateway() {
        val gatewayStore = InMemoryGatewayOwnershipStore()
        gatewayStore.observe("ios-device-001")
        gatewayStore.observe("mac-device-001")
        val response = SuspendBridge.runBlocking {
            router(
                gatewayOwnershipStore = gatewayStore,
                signatureValidator = RequestSignatureValidator(
                    secretProvider = { PAIRING_TOKEN },
                    clock = { 1_800_000_000_000L },
                ),
            ).manifest(
                headers = signedHeaders(
                    deviceId = "mac-device-001",
                    nonce = "inactive-gateway",
                    signature = RequestSignatureValidator.sign(
                        secret = PAIRING_TOKEN,
                        version = "2",
                        deviceId = "mac-device-001",
                        sessionId = "ios-photo-mvp",
                        method = "GET",
                        path = "/v1/manifest",
                        timestamp = "1800000000000",
                        nonce = "inactive-gateway",
                        body = "",
                    ),
                )
            )
        }

        assertEquals(409, response.statusCode)
        assertEquals("""{"errorCode":"SS-GATEWAY-409"}""", response.body)
    }

    @Test
    fun manifestRejectsReplayedSignedRequest() {
        val signatureValidator = RequestSignatureValidator(
            secretProvider = { "pairing-token-001" },
            clock = { 1_800_000_000_000L },
        )
        val router = router(signatureValidator = signatureValidator)
        val headers = signedHeaders(signature = "wJ/9g1hjKiodbIT7xAKm5apkW0NJWqeTc1BdocF+ywQ=")

        SuspendBridge.runBlocking {
            assertEquals(200, router.manifest(headers = headers).statusCode)
            assertEquals(401, router.manifest(headers = headers).statusCode)
        }
    }

    @Test
    fun manifestRejectsStaleSignedRequest() {
        val response = SuspendBridge.runBlocking {
            router(
                signatureValidator = RequestSignatureValidator(
                    secretProvider = { PAIRING_TOKEN },
                    clock = { 1_800_000_600_001L },
                )
            ).manifest(
                headers = signedHeaders(
                    signature = RequestSignatureValidator.sign(
                        secret = PAIRING_TOKEN,
                        version = "2",
                        deviceId = "ios-device-001",
                        sessionId = "ios-photo-mvp",
                        method = "GET",
                        path = "/v1/manifest",
                        timestamp = "1800000000000",
                        nonce = "stale-manifest-nonce",
                        body = "",
                    ),
                    nonce = "stale-manifest-nonce",
                )
            )
        }

        assertEquals(401, response.statusCode)
        assertEquals("""{"errorCode":"SS-AUTH-001"}""", response.body)
    }

    @Test
    fun manifestRejectsInvalidSignature() {
        val response = SuspendBridge.runBlocking {
            router(
                signatureValidator = RequestSignatureValidator(
                    secretProvider = { PAIRING_TOKEN },
                    clock = { 1_800_000_000_000L },
                )
            ).manifest(
                headers = signedHeaders(
                    signature = "not-a-valid-signature",
                    nonce = "invalid-manifest-signature",
                )
            )
        }

        assertEquals(401, response.statusCode)
        assertEquals("""{"errorCode":"SS-AUTH-001"}""", response.body)
    }

    @Test
    fun mediaAcceptsSignedRequestWithoutPairingTokenHeader() {
        val response = SuspendBridge.runBlocking {
            router(
                signatureValidator = RequestSignatureValidator(
                    secretProvider = { PAIRING_TOKEN },
                    clock = { 1_800_000_000_000L },
                )
            ).media(
                assetId = "media-001",
                headers = signedHeaders(
                    nonce = "media-nonce-001",
                    signature = RequestSignatureValidator.sign(
                        secret = PAIRING_TOKEN,
                        version = "2",
                        deviceId = "ios-device-001",
                        sessionId = "ios-photo-mvp",
                        method = "GET",
                        path = "/v1/media/media-001",
                        timestamp = "1800000000000",
                        nonce = "media-nonce-001",
                        body = "",
                    )
                )
            )
        }

        assertEquals(200, (response as LocalMediaResponse.Found).statusCode)
    }

    @Test
    fun mediaRejectsInvalidSignature() {
        val response = SuspendBridge.runBlocking {
            router(
                signatureValidator = RequestSignatureValidator(
                    secretProvider = { PAIRING_TOKEN },
                    clock = { 1_800_000_000_000L },
                )
            ).media(
                assetId = "media-001",
                headers = signedHeaders(
                    nonce = "invalid-media-signature",
                    signature = "not-a-valid-signature",
                ),
                path = "/v1/media/media-001",
            )
        }

        assertEquals(LocalMediaResponse.Unauthorized(401, "SS-AUTH-001"), response)
    }

    @Test
    fun mediaRejectsWrongPairingToken() {
        val activityTracker = LocalRequestActivityTracker(clock = { 5678L })
        val response = SuspendBridge.runBlocking {
            router(requestActivityTracker = activityTracker).media(
                assetId = "media-001",
                headers = pairingHeaders("wrong-token"),
            )
        }

        assertEquals(LocalMediaResponse.Unauthorized(401, "SS-AUTH-001"), response)
        assertEquals(LocalRequestActivity("media", 401, 5678L, 1, 1), activityTracker.latest())
    }

    @Test
    fun syncResultRecordsBadRequestActivity() {
        val activityTracker = LocalRequestActivityTracker(clock = { 9012L })
        val response = SuspendBridge.runBlocking {
            router(
                requestActivityTracker = activityTracker,
                authorizationPolicy = AuthorizationPolicy.SignedRequestsWithPairingTokenFallback,
            ).syncResult(
                body = """{"bad": true}""",
                headers = pairingHeaders(),
            )
        }

        assertEquals(400, response.statusCode)
        assertEquals(LocalRequestActivity("sync-result", 400, 9012L, 1, 1), activityTracker.latest())
    }

    @Test
    fun syncResultRejectsBlankRequiredFieldsWithoutPersisting() {
        val store = InMemorySyncResultStore()
        val response = SuspendBridge.runBlocking {
            router(
                syncResultStore = store,
                authorizationPolicy = AuthorizationPolicy.SignedRequestsWithPairingTokenFallback,
            ).syncResult(
                body = """
                    {
                      "syncBatchId": " ",
                      "targetDeviceId": "ios-device-001",
                      "results": [
                        {
                          "itemType": "media",
                          "sourceItemId": "media-001",
                          "targetItemId": "photo-local-001",
                          "status": "synced",
                          "errorCode": null
                        }
                      ]
                    }
                """.trimIndent(),
                headers = pairingHeaders(),
            )
        }

        assertEquals(400, response.statusCode)
        assertEquals(null, SuspendBridge.runBlocking { store.latest() })
    }

    @Test
    fun syncResultRejectsBlankSourceItemIdsWithoutPersisting() {
        val store = InMemorySyncResultStore()
        val response = SuspendBridge.runBlocking {
            router(
                syncResultStore = store,
                authorizationPolicy = AuthorizationPolicy.SignedRequestsWithPairingTokenFallback,
            ).syncResult(
                body = """
                    {
                      "syncBatchId": "batch-001",
                      "targetDeviceId": "ios-device-001",
                      "results": [
                        {
                          "itemType": "media",
                          "sourceItemId": " ",
                          "targetItemId": "photo-local-001",
                          "status": "synced",
                          "errorCode": null
                        }
                      ]
                    }
                """.trimIndent(),
                headers = pairingHeaders(),
            )
        }

        assertEquals(400, response.statusCode)
        assertEquals(null, SuspendBridge.runBlocking { store.latest() })
    }

    @Test
    fun syncResultRejectsNonMediaItemsWithoutPersisting() {
        val store = InMemorySyncResultStore()
        val response = SuspendBridge.runBlocking {
            router(
                syncResultStore = store,
                authorizationPolicy = AuthorizationPolicy.SignedRequestsWithPairingTokenFallback,
            ).syncResult(
                body = syncResultBody(itemType = "contact", status = "synced", errorCode = "null"),
                headers = pairingHeaders(),
            )
        }

        assertEquals(400, response.statusCode)
        assertEquals(null, SuspendBridge.runBlocking { store.latest() })
    }

    @Test
    fun syncResultRejectsSuccessfulItemWithErrorCodeWithoutPersisting() {
        val store = InMemorySyncResultStore()
        val response = SuspendBridge.runBlocking {
            router(
                syncResultStore = store,
                authorizationPolicy = AuthorizationPolicy.SignedRequestsWithPairingTokenFallback,
            ).syncResult(
                body = syncResultBody(status = "synced", errorCode = """"SS-MEDIA-999""""),
                headers = pairingHeaders(),
            )
        }

        assertEquals(400, response.statusCode)
        assertEquals(null, SuspendBridge.runBlocking { store.latest() })
    }

    @Test
    fun syncResultRejectsFailedItemWithoutErrorCodeWithoutPersisting() {
        val store = InMemorySyncResultStore()
        val response = SuspendBridge.runBlocking {
            router(
                syncResultStore = store,
                authorizationPolicy = AuthorizationPolicy.SignedRequestsWithPairingTokenFallback,
            ).syncResult(
                body = syncResultBody(status = "failed", errorCode = "null"),
                headers = pairingHeaders(),
            )
        }

        assertEquals(400, response.statusCode)
        assertEquals(null, SuspendBridge.runBlocking { store.latest() })
    }

    @Test
    fun syncResultAcceptsFailedItemWithErrorCode() {
        val store = InMemorySyncResultStore()
        val response = SuspendBridge.runBlocking {
            router(
                syncResultStore = store,
                authorizationPolicy = AuthorizationPolicy.SignedRequestsWithPairingTokenFallback,
            ).syncResult(
                body = syncResultBody(status = "failed", errorCode = """"SS-MEDIA-999""""),
                headers = pairingHeaders(),
            )
        }

        val stored = SuspendBridge.runBlocking { store.latest() }
        assertEquals(202, response.statusCode)
        assertEquals("batch-001", stored?.syncBatchId)
        assertEquals("failed", stored?.results?.first()?.status?.name)
        assertEquals("SS-MEDIA-999", stored?.results?.first()?.errorCode)
    }

    @Test
    fun syncResultAcceptsSignedRequestWithoutPairingTokenHeader() {
        val store = InMemorySyncResultStore()
        val eventStore = InMemorySyncEventStore()
        val body = syncResultBody(status = "synced", errorCode = "null")
        val response = SuspendBridge.runBlocking {
            router(
                syncResultStore = store,
                syncEventStore = eventStore,
                signatureValidator = RequestSignatureValidator(
                    secretProvider = { PAIRING_TOKEN },
                    clock = { 1_800_000_000_000L },
                )
            ).syncResult(
                body = body,
                headers = signedHeaders(
                    nonce = "result-nonce-001",
                    signature = RequestSignatureValidator.sign(
                        secret = PAIRING_TOKEN,
                        version = "2",
                        deviceId = "ios-device-001",
                        sessionId = "ios-photo-mvp",
                        method = "POST",
                        path = "/v1/sync/result",
                        timestamp = "1800000000000",
                        nonce = "result-nonce-001",
                        body = body,
                    )
                )
            )
        }

        assertEquals(202, response.statusCode)
        assertEquals("batch-001", SuspendBridge.runBlocking { store.latest() }?.syncBatchId)
        val event = SuspendBridge.runBlocking { eventStore.latest() }
        assertEquals("batch-001", event?.syncBatchId)
        assertEquals(1, event?.syncedCount)
        assertEquals(0, event?.failedCount)
    }

    @Test
    fun syncResultRejectsTargetDeviceThatDoesNotMatchSignedRequester() {
        val store = InMemorySyncResultStore()
        val body = syncResultBody(status = "synced", errorCode = "null")
        val response = SuspendBridge.runBlocking {
            router(
                syncResultStore = store,
                signatureValidator = RequestSignatureValidator(
                    secretProvider = { PAIRING_TOKEN },
                    clock = { 1_800_000_000_000L },
                ),
            ).syncResult(
                body = body,
                headers = signedHeaders(
                    deviceId = "mac-device-001",
                    nonce = "wrong-target-device",
                    signature = RequestSignatureValidator.sign(
                        secret = PAIRING_TOKEN,
                        version = "2",
                        deviceId = "mac-device-001",
                        sessionId = "ios-photo-mvp",
                        method = "POST",
                        path = "/v1/sync/result",
                        timestamp = "1800000000000",
                        nonce = "wrong-target-device",
                        body = body,
                    ),
                ),
            )
        }

        assertEquals(400, response.statusCode)
        assertEquals(null, SuspendBridge.runBlocking { store.latest() })
    }

    @Test
    fun syncResultRejectsInvalidSignatureWithoutPersisting() {
        val store = InMemorySyncResultStore()
        val response = SuspendBridge.runBlocking {
            router(
                syncResultStore = store,
                signatureValidator = RequestSignatureValidator(
                    secretProvider = { PAIRING_TOKEN },
                    clock = { 1_800_000_000_000L },
                )
            ).syncResult(
                body = syncResultBody(status = "synced", errorCode = "null"),
                headers = signedHeaders(
                    nonce = "invalid-result-signature",
                    signature = "not-a-valid-signature",
                )
            )
        }

        assertEquals(401, response.statusCode)
        assertEquals("""{"errorCode":"SS-AUTH-001"}""", response.body)
        assertEquals(null, SuspendBridge.runBlocking { store.latest() })
    }

    @Test
    fun syncResultMergesMultipleAcceptedBatchesAndRecordsEachEvent() {
        val store = InMemorySyncResultStore()
        val eventStore = InMemorySyncEventStore()
        val router = router(
            syncResultStore = store,
            syncEventStore = eventStore,
            authorizationPolicy = AuthorizationPolicy.SignedRequestsWithPairingTokenFallback,
        )

        SuspendBridge.runBlocking {
            assertEquals(
                202,
                router.syncResult(
                    body = syncResultBody(
                        batchId = "batch-001",
                        sourceItemId = "media-001",
                        status = "synced",
                        errorCode = "null",
                    ),
                    headers = pairingHeaders(),
                ).statusCode,
            )
            assertEquals(
                202,
                router.syncResult(
                    body = syncResultBody(
                        batchId = "batch-002",
                        sourceItemId = "media-002",
                        status = "failed",
                        errorCode = """"SS-NET-002"""",
                    ),
                    headers = pairingHeaders(),
                ).statusCode,
            )
            assertEquals(
                202,
                router.syncResult(
                    body = syncResultBody(
                        batchId = "batch-003",
                        sourceItemId = "media-002",
                        targetItemId = "photo-local-002",
                        status = "synced",
                        errorCode = "null",
                    ),
                    headers = pairingHeaders(),
                ).statusCode,
            )
        }

        val latest = SuspendBridge.runBlocking { store.latest() }
        val events = SuspendBridge.runBlocking { eventStore.all() }
        assertEquals("batch-003", latest?.syncBatchId)
        assertEquals(listOf("media-001", "media-002"), latest?.results?.map { it.sourceItemId })
        assertEquals(listOf("synced", "synced"), latest?.results?.map { it.status.name })
        assertEquals(listOf("batch-001", "batch-002", "batch-003"), events.map { it.syncBatchId })
        assertEquals(listOf(1, 0, 1), events.map { it.syncedCount })
        assertEquals(listOf(0, 1, 0), events.map { it.failedCount })
    }

    @Test
    fun requestActivityCountsLocalRequestsAcrossEndpoints() {
        var now = 10_000L
        val activityTracker = LocalRequestActivityTracker(clock = { now })
        val router = router(
            requestActivityTracker = activityTracker,
            authorizationPolicy = AuthorizationPolicy.SignedRequestsWithPairingTokenFallback,
        )

        SuspendBridge.runBlocking {
            router.health()
            now = 11_000L
            router.manifest(pairingHeaders())
            now = 12_000L
            router.media(assetId = "media-001", headers = pairingHeaders())
            now = 13_000L
            router.media(assetId = "media-001", headers = pairingHeaders())
        }

        assertEquals(LocalRequestActivity("media", 200, 13_000L, 4, 2), activityTracker.latest())
    }

    @Test
    fun mediaReturnsPartialRangeMetadata() {
        val response = SuspendBridge.runBlocking {
            legacyRouter().media(
                assetId = "media-001",
                rangeHeader = "bytes=100-199",
                headers = pairingHeaders(),
                path = "/v1/media/media-001",
            )
        } as LocalMediaResponse.Found

        assertEquals(206, response.statusCode)
        assertEquals(ByteRange(start = 100, endInclusive = 199, totalSize = 1024, isPartial = true), response.range)
        assertEquals("100", response.headers["Content-Length"])
        assertEquals("bytes 100-199/1024", response.headers["Content-Range"])
    }

    @Test
    fun mediaSupportsSuffixRangeMetadata() {
        val response = SuspendBridge.runBlocking {
            legacyRouter().media(
                assetId = "media-001",
                rangeHeader = "bytes=-24",
                headers = pairingHeaders(),
                path = "/v1/media/media-001",
            )
        } as LocalMediaResponse.Found

        assertEquals(206, response.statusCode)
        assertEquals(ByteRange(start = 1000, endInclusive = 1023, totalSize = 1024, isPartial = true), response.range)
        assertEquals("24", response.headers["Content-Length"])
        assertEquals("bytes 1000-1023/1024", response.headers["Content-Range"])
    }

    @Test
    fun mediaRejectsUnsatisfiableRange() {
        val response = SuspendBridge.runBlocking {
            legacyRouter().media(
                assetId = "media-001",
                rangeHeader = "bytes=2048-4096",
                headers = pairingHeaders(),
                path = "/v1/media/media-001",
            )
        }

        assertEquals(
            LocalMediaResponse.RangeNotSatisfiable(
                statusCode = 416,
                errorCode = "SS-REQ-416",
                headers = mapOf("Content-Range" to "bytes */1024"),
            ),
            response,
        )
    }

    private fun router(
        requestActivityTracker: LocalRequestActivityTracker? = null,
        syncResultStore: InMemorySyncResultStore = InMemorySyncResultStore(),
        syncEventStore: InMemorySyncEventStore? = null,
        gatewayOwnershipStore: InMemoryGatewayOwnershipStore? = null,
        deviceCredentialStore: DeviceCredentialStore? = null,
        pairingRegistrationWindow: PairingRegistrationWindow? = null,
        manifestProvider: ManifestProvider = object : ManifestProvider {
            override suspend fun currentManifest(
                sinceCursor: String?,
                pageCursor: String?,
                targetDeviceId: String?,
            ): SyncManifest = emptyManifest()
        },
        signatureValidator: RequestSignatureValidator = RequestSignatureValidator(secretProvider = { PAIRING_TOKEN }),
        authorizationPolicy: AuthorizationPolicy = AuthorizationPolicy.SignedRequestsOnly,
        noteRepository: NoteRepository? = null,
        noteBatchIdProvider: () -> String = { "notes-batch-test" },
        clock: () -> Long = { 1_000L },
    ): LocalSyncRouter {
        return LocalSyncRouter(
            deviceId = "android-device-001",
            appVersion = "0.1.0",
            pairingToken = PAIRING_TOKEN,
            manifestProvider = manifestProvider,
            mediaProvider = object : MediaProvider {
                override suspend fun findMedia(assetId: String): MediaAsset? {
                    return mediaAsset(assetId)
                }
            },
            syncResultStore = syncResultStore,
            syncEventStore = syncEventStore,
            gatewayOwnershipStore = gatewayOwnershipStore,
            deviceCredentialStore = deviceCredentialStore,
            pairingRegistrationWindow = pairingRegistrationWindow,
            requestActivityTracker = requestActivityTracker,
            noteRepository = noteRepository,
            noteBatchIdProvider = noteBatchIdProvider,
            clock = clock,
            signatureValidator = signatureValidator,
            authorizationPolicy = authorizationPolicy,
        )
    }

    private fun legacyRouter(): LocalSyncRouter {
        return router(authorizationPolicy = AuthorizationPolicy.SignedRequestsWithPairingTokenFallback)
    }

    private fun pairingHeaders(token: String = PAIRING_TOKEN): Map<String, String> {
        return mapOf(LocalSyncRouter.PAIRING_TOKEN_HEADER.lowercase() to token)
    }

    private fun signedHeaders(
        nonce: String = "nonce-001",
        deviceId: String = "ios-device-001",
        signature: String,
        timestamp: String = "1800000000000",
        sessionId: String = "ios-photo-mvp",
    ): Map<String, String> {
        return mapOf(
            RequestSignatureValidator.VERSION_HEADER to "2",
            RequestSignatureValidator.DEVICE_ID_HEADER to deviceId,
            RequestSignatureValidator.SESSION_ID_HEADER to sessionId,
            RequestSignatureValidator.TIMESTAMP_HEADER to timestamp,
            RequestSignatureValidator.NONCE_HEADER to nonce,
            RequestSignatureValidator.SIGNATURE_HEADER to signature,
        )
    }


    private fun emptyManifest(): SyncManifest {
        return SyncManifest(
            version = 1,
            sourceDeviceId = "android-device-001",
            generatedAt = "2026-08-25T00:00:00Z",
            cursor = "cursor-001",
            media = listOf(mediaAsset("media-001")),
            contacts = emptyList(),
            files = emptyList(),
        )
    }

    private fun mediaAsset(assetId: String): MediaAsset {
        return MediaAsset(
            assetId = assetId,
            sourceDeviceId = "android-device-001",
            mediaType = MediaType.photo,
            fileName = "$assetId.jpg",
            mimeType = "image/jpeg",
            size = 1024,
        )
    }

    private fun noteRepository(store: InMemoryNoteStore = InMemoryNoteStore()): NoteRepository {
        return NoteRepository(store = store, deviceId = "android-device-001", now = { 1_000L })
    }

    private fun note(deviceId: String = "android-device-001"): VersionedNote {
        return VersionedNote(
            id = "note-001",
            title = "Shared note",
            markdownBody = "A note synchronized over the local network.",
            createdAtEpochMillis = 1_000L,
            updatedAtEpochMillis = 1_000L,
            tags = listOf("shared"),
            revision = NoteRevision(sequence = 1, deviceId = deviceId),
            parentRevision = null,
            deletedAtEpochMillis = null,
        )
    }

    private fun syncResultBody(
        batchId: String = "batch-001",
        sourceItemId: String = "media-001",
        targetItemId: String = "photo-local-001",
        itemType: String = "media",
        status: String,
        errorCode: String,
    ): String {
        return """
            {
              "syncBatchId": "$batchId",
              "targetDeviceId": "ios-device-001",
              "results": [
                {
                  "itemType": "$itemType",
                  "sourceItemId": "$sourceItemId",
                  "targetItemId": "$targetItemId",
                  "status": "$status",
                  "errorCode": $errorCode
                }
              ]
            }
        """.trimIndent()
    }

    private companion object {
        const val PAIRING_TOKEN = "expected-token"
    }
}
