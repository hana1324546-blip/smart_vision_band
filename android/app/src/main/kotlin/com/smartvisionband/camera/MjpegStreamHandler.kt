package com.smartvisionband.camera

import android.content.Context
import android.graphics.BitmapFactory
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.SystemClock
import android.util.Log
import com.smartvisionband.ai.TfliteDetector
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.min

class MjpegStreamHandler(context: Context) : CameraAdapter, AutoCloseable {
    private val appContext = context.applicationContext
    private val connectivity = appContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val worker = Executors.newSingleThreadExecutor()
    private val generation = AtomicLong()
    @Volatile private var connection: HttpURLConnection? = null
    @Volatile private var detector: TfliteDetector? = null
    @Volatile private var processingThread: Thread? = null
    @Volatile private var confidenceThreshold = 0.5f
    @Volatile private var languageCode = "en"
    @Volatile private var snapshotRequestId: Long? = null

    init {
        TfliteDetector.checkModelAssets(appContext)
    }

    override fun start(onEvent: (Map<String, Any>) -> Unit) {
        stop()
        val runId = generation.incrementAndGet()
        worker.execute { process(runId, onEvent) }
    }

    override fun configure(confidence: Float) {
        require(confidence in 0.1f..0.95f)
        confidenceThreshold = confidence
    }

    override fun setLanguage(languageCode: String) {
        require(languageCode == "ar" || languageCode == "en")
        this.languageCode = languageCode
        detector?.setLanguage(languageCode)
    }

    override fun requestSnapshot(requestId: Long) {
        require(requestId > 0)
        snapshotRequestId = requestId
    }

    override fun stop() {
        generation.incrementAndGet()
        snapshotRequestId = null
        connection?.disconnect()
        connection = null
        processingThread?.interrupt()
    }

    private fun process(runId: Long, onEvent: (Map<String, Any>) -> Unit) {
        if (generation.get() != runId) return
        processingThread = Thread.currentThread()
        onEvent(mapOf("type" to "state", "ready" to false))
        val inference = try {
            detector ?: synchronized(this) {
                detector ?: TfliteDetector(appContext).also {
                    it.setLanguage(languageCode)
                    detector = it
                }
            }
        } catch (error: Exception) {
            if (generation.get() != runId) return
            Log.w(TAG, "yolov8n.tflite model missing or incompatible; camera inference disabled", error)
            onEvent(mapOf("type" to "state", "ready" to false))
            onEvent(mapOf("type" to "error", "code" to "MODEL_UNAVAILABLE", "message" to (error.message ?: "Model initialization failed")))
            return
        }

        var reconnectDelay = 1L
        while (generation.get() == runId) {
            var activeConnection: HttpURLConnection? = null
            try {
                activeConnection = openStreamConnection()
                connection = activeConnection
                activeConnection.connectTimeout = 5000
                activeConnection.readTimeout = 15000
                activeConnection.setRequestProperty("Accept", "multipart/x-mixed-replace")
                activeConnection.connect()
                if (activeConnection.responseCode !in 200..299) {
                    throw IOException("MJPEG server returned HTTP ${activeConnection.responseCode}")
                }
                reconnectDelay = 1L
                onEvent(mapOf("type" to "state", "ready" to true))

                var lastInferenceNs = 0L
                var fpsWindowStartNs = SystemClock.elapsedRealtimeNanos()
                var framesInWindow = 0
                var measuredFps = 0.0
                val extractor = MjpegJpegFrameExtractor(MAX_FRAME_BYTES)
                val buffer = ByteArray(READ_BUFFER_BYTES)
                activeConnection.inputStream.use { input ->
                    while (generation.get() == runId) {
                        val count = input.read(buffer)
                        if (count < 0) throw IOException("MJPEG stream ended")
                        extractor.feed(buffer, count) { jpeg ->
                            if (generation.get() != runId) return@feed
                            val nowNs = SystemClock.elapsedRealtimeNanos()
                            val forcedSnapshotId = snapshotRequestId
                            val forceInference = forcedSnapshotId != null
                            if (forceInference || nowNs - lastInferenceNs >= MIN_INFERENCE_INTERVAL_NS) {
                                if (forceInference) snapshotRequestId = null
                                lastInferenceNs = nowNs
                                val bitmap = BitmapFactory.decodeByteArray(jpeg, 0, jpeg.size) ?: return@feed
                                try {
                                    val result = inference.detect(bitmap, confidenceThreshold).toMutableMap()
                                    framesInWindow++
                                    val windowNs = nowNs - fpsWindowStartNs
                                    if (windowNs >= FPS_WINDOW_NS) {
                                        measuredFps = framesInWindow * 1_000_000_000.0 / windowNs
                                        framesInWindow = 0
                                        fpsWindowStartNs = nowNs
                                    }
                                    result["fps"] = measuredFps
                                    if (forcedSnapshotId != null) result["snapshotId"] = forcedSnapshotId
                                    if (generation.get() == runId && result["languageCode"] == languageCode) onEvent(result)
                                } finally {
                                    bitmap.recycle()
                                }
                            }
                        }
                    }
                }
            } catch (error: Exception) {
                if (generation.get() == runId) {
                    onEvent(mapOf("type" to "state", "ready" to false))
                    onEvent(mapOf("type" to "error", "message" to (error.message ?: "MJPEG connection failed")))
                    try {
                        Thread.sleep(reconnectDelay * 1000)
                    } catch (_: InterruptedException) {
                        Thread.currentThread().interrupt()
                        return
                    }
                    reconnectDelay = min(reconnectDelay * 2, MAX_RECONNECT_DELAY_SECONDS)
                }
            } finally {
                activeConnection?.disconnect()
                if (connection === activeConnection) connection = null
            }
        }
    }

    private fun openStreamConnection(): HttpURLConnection {
        val wifi = connectivity.allNetworks.firstOrNull { network ->
            connectivity.getNetworkCapabilities(network)?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
        } ?: throw IOException("Connect the phone to the ESP32-CAM Wi-Fi network")
        return wifi.openConnection(URL(STREAM_URL)) as HttpURLConnection
    }

    override fun close() {
        stop()
        worker.shutdownNow()
        synchronized(this) {
            detector?.close()
            detector = null
        }
    }

    private companion object {
        const val TAG = "MjpegStreamHandler"
        const val STREAM_URL = "http://192.168.4.1:81/stream"
        const val READ_BUFFER_BYTES = 8192
        const val MAX_FRAME_BYTES = 4 * 1024 * 1024
        const val MIN_INFERENCE_INTERVAL_NS = 55_000_000L
        const val FPS_WINDOW_NS = 1_000_000_000L
        const val MAX_RECONNECT_DELAY_SECONDS = 30L
    }
}

internal class MjpegJpegFrameExtractor(private val maxFrameBytes: Int) {
    private var previousByte = -1
    private var frame: ByteArrayOutputStream? = null

    init {
        require(maxFrameBytes > 0)
    }

    fun feed(bytes: ByteArray, count: Int, onFrame: (ByteArray) -> Unit) {
        require(count in 0..bytes.size)
        for (index in 0 until count) {
            val current = bytes[index].toInt() and 0xff
            val activeFrame = frame
            if (activeFrame == null) {
                if (previousByte == 0xff && current == 0xd8) {
                    frame = ByteArrayOutputStream(INITIAL_FRAME_CAPACITY).apply {
                        write(0xff)
                        write(0xd8)
                    }
                }
            } else {
                activeFrame.write(current)
                if (activeFrame.size() > maxFrameBytes) {
                    frame = null
                } else if (previousByte == 0xff && current == 0xd9) {
                    frame = null
                    onFrame(activeFrame.toByteArray())
                }
            }
            previousByte = current
        }
    }

    private companion object {
        const val INITIAL_FRAME_CAPACITY = 65536
    }
}