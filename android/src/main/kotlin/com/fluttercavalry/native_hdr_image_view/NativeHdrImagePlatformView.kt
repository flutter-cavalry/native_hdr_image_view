package com.fluttercavalry.native_hdr_image_view

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.pm.ActivityInfo
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.graphics.Matrix
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.nio.ByteBuffer
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.WeakHashMap

internal class NativeHdrImagePlatformView(
    context: Context,
    viewId: Int,
    messenger: BinaryMessenger,
) : PlatformView, MethodChannel.MethodCallHandler {
    private sealed class Source {
        data class FilePath(val path: String) : Source()
        data class NetworkUrl(val url: String) : Source()
        class EncodedBytes(val bytes: ByteArray) : Source() {
            override fun equals(other: Any?): Boolean =
                other is EncodedBytes && bytes.contentEquals(other.bytes)

            override fun hashCode(): Int = bytes.contentHashCode()
        }
    }

    private class NetworkException(message: String, val details: String) : IOException(message)

    private val container = FrameLayout(context)
    private val imageView = ImageView(context)
    private val channel = MethodChannel(messenger, "native_hdr_image_view/$viewId")
    private val mainHandler = Handler(Looper.getMainLooper())
    private var source: Source? = null
    private var fit = "contain"
    private var generation = 0
    private var load: Future<*>? = null
    private var pendingResult: MethodChannel.Result? = null
    @Volatile
    private var activeConnection: HttpURLConnection? = null
    private var disposed = false
    private var hdrActivity: Activity? = null

    init {
        container.clipChildren = true
        container.clipToPadding = true
        imageView.scaleType = ImageView.ScaleType.MATRIX
        container.addView(
            imageView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )
        imageView.addOnLayoutChangeListener { _, _, _, _, _, _, _, _, _ ->
            updateImageMatrix()
        }
        channel.setMethodCallHandler(this)
    }

    override fun getView(): View = container

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "update") {
            result.notImplemented()
            return
        }
        val parameters = call.arguments as? Map<*, *>
        if (parameters == null) {
            result.error("invalid_arguments", "Expected image parameters.", null)
            return
        }

        val nextSource = try {
            parseSource(parameters)
        } catch (error: IllegalArgumentException) {
            result.error("invalid_url", error.message, parameters["imageUrl"])
            return
        }
        fit = parameters["fit"] as? String ?: "contain"
        updateImageMatrix()
        if (nextSource == source) {
            result.success(null)
            return
        }

        finishPendingRequest()
        source = nextSource
        generation++
        load?.cancel(true)
        activeConnection?.disconnect()
        activeConnection = null
        load = null
        imageView.setImageDrawable(null)
        restoreWindowColorMode()
        updateImageMatrix()

        if (nextSource == null) {
            result.success(null)
            return
        }

        pendingResult = result
        val currentGeneration = generation
        load = loader.submit {
            try {
                val drawable = decode(nextSource)
                mainHandler.post {
                    if (currentGeneration == generation && !disposed) {
                        load = null
                        updateWindowColorMode(drawable)
                        imageView.setImageDrawable(drawable)
                        updateImageMatrix()
                        finishPendingRequest()
                    }
                }
            } catch (error: NetworkException) {
                mainHandler.post {
                    if (currentGeneration == generation && !disposed) {
                        load = null
                        source = null
                        finishPendingRequest("network_error", error.message, error.details)
                    }
                }
            } catch (error: Exception) {
                mainHandler.post {
                    if (currentGeneration == generation && !disposed) {
                        load = null
                        source = null
                        val (message, details) = when (nextSource) {
                            is Source.FilePath -> "Cannot load image file." to nextSource.path
                            is Source.NetworkUrl -> "Cannot decode downloaded image." to nextSource.url
                            is Source.EncodedBytes -> "Cannot decode image bytes." to null
                        }
                        finishPendingRequest("invalid_image", message, details)
                    }
                }
            }
        }
    }

    override fun dispose() {
        disposed = true
        generation++
        load?.cancel(true)
        activeConnection?.disconnect()
        activeConnection = null
        finishPendingRequest()
        channel.setMethodCallHandler(null)
        restoreWindowColorMode()
        imageView.setImageDrawable(null)
    }

    private fun parseSource(parameters: Map<*, *>): Source? {
        val urlString = parameters["imageUrl"] as? String
        if (urlString != null) {
            val url = try {
                URL(urlString)
            } catch (error: Exception) {
                throw IllegalArgumentException("Expected an HTTP or HTTPS image URL.", error)
            }
            if (url.protocol !in setOf("http", "https") || url.host.isBlank()) {
                throw IllegalArgumentException("Expected an HTTP or HTTPS image URL.")
            }
            return Source.NetworkUrl(urlString)
        }
        (parameters["imageBytes"] as? ByteArray)?.let {
            return Source.EncodedBytes(it.clone())
        }
        (parameters["imagePath"] as? String)?.let { return Source.FilePath(it) }
        return null
    }

    private fun decode(source: Source): Drawable {
        val bytes = when (source) {
            is Source.FilePath -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    // ImageDecoder can retain HDR gain maps; BitmapFactory is the
                    // compatibility path for Android versions before API 28.
                    return ImageDecoder.decodeDrawable(
                        ImageDecoder.createSource(File(source.path)),
                    )
                }
                val bitmap = BitmapFactory.decodeFile(source.path)
                    ?: throw IOException("Cannot decode image file.")
                return BitmapDrawable(container.resources, bitmap)
            }
            is Source.EncodedBytes -> source.bytes
            is Source.NetworkUrl -> download(source.url)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            // Decode the original encoded bytes so Android can keep HDR metadata.
            return ImageDecoder.decodeDrawable(
                ImageDecoder.createSource(ByteBuffer.wrap(bytes)),
            )
        }
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            ?: throw IOException("Cannot decode image bytes.")
        return BitmapDrawable(container.resources, bitmap)
    }

    private fun download(urlString: String): ByteArray {
        val connection = (URL(urlString).openConnection() as HttpURLConnection).apply {
            connectTimeout = 15_000
            readTimeout = 15_000
            instanceFollowRedirects = true
        }
        activeConnection = connection
        try {
            val status = connection.responseCode
            if (status !in 200..299) {
                throw NetworkException("HTTP $status", urlString)
            }
            return connection.inputStream.use { input ->
                ByteArrayOutputStream().use { output ->
                    input.copyTo(output)
                    output.toByteArray()
                }
            }
        } catch (error: NetworkException) {
            throw error
        } catch (error: Exception) {
            throw NetworkException(error.message ?: "Network request failed.", urlString)
        } finally {
            if (activeConnection === connection) activeConnection = null
            connection.disconnect()
        }
    }

    private fun updateWindowColorMode(drawable: Drawable) {
        // Ultra HDR gain-map rendering and HDR window color mode require Android 14+.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return
        val bitmap = (drawable as? BitmapDrawable)?.bitmap ?: return
        // Only request HDR output for images that actually contain a gain map.
        if (!bitmap.hasGainmap()) return

        val activity = findActivity(container.context) ?: return
        if (hdrActivity !== activity) {
            restoreWindowColorMode()
            hdrActivity = activity
            val state = hdrWindows[activity]
            if (state == null) {
                // Track the prior mode and shared views so removal restores the
                // window only after its last gain-map image is gone.
                hdrWindows[activity] = HdrWindowState(activity.window.colorMode, 1)
                activity.window.colorMode = ActivityInfo.COLOR_MODE_HDR
            } else {
                state.viewCount++
            }
        }
    }

    private fun restoreWindowColorMode() {
        val activity = hdrActivity
        if (activity != null) {
            val state = hdrWindows[activity]
            if (state != null && --state.viewCount == 0) {
                if (activity.window.colorMode == ActivityInfo.COLOR_MODE_HDR) {
                    activity.window.colorMode = state.previousColorMode
                }
                hdrWindows.remove(activity)
            }
        }
        hdrActivity = null
    }

    private fun findActivity(context: Context): Activity? {
        var current = context
        while (current is ContextWrapper) {
            if (current is Activity) return current
            current = current.baseContext
        }
        return current as? Activity
    }

    private fun updateImageMatrix() {
        val drawable = imageView.drawable
        val imageWidth = drawable?.intrinsicWidth?.toFloat() ?: 0f
        val imageHeight = drawable?.intrinsicHeight?.toFloat() ?: 0f
        val viewWidth = imageView.width.toFloat()
        val viewHeight = imageView.height.toFloat()
        if (imageWidth <= 0f || imageHeight <= 0f || viewWidth <= 0f || viewHeight <= 0f) {
            imageView.imageMatrix = Matrix()
            return
        }

        val widthScale = viewWidth / imageWidth
        val heightScale = viewHeight / imageHeight
        val scaleX: Float
        val scaleY: Float
        when (fit) {
            "fill" -> {
                scaleX = widthScale
                scaleY = heightScale
            }
            else -> {
                val scale = when (fit) {
                    "cover" -> maxOf(widthScale, heightScale)
                    "fitWidth" -> widthScale
                    "fitHeight" -> heightScale
                    "none" -> 1f
                    "scaleDown" -> minOf(1f, minOf(widthScale, heightScale))
                    else -> minOf(widthScale, heightScale)
                }
                scaleX = scale
                scaleY = scale
            }
        }
        val matrix = Matrix().apply {
            setScale(scaleX, scaleY)
            postTranslate(
                (viewWidth - imageWidth * scaleX) / 2f,
                (viewHeight - imageHeight * scaleY) / 2f,
            )
        }
        imageView.imageMatrix = matrix
    }

    private fun finishPendingRequest(
        errorCode: String? = null,
        message: String? = null,
        details: Any? = null,
    ) {
        val result = pendingResult ?: return
        pendingResult = null
        if (errorCode == null) {
            result.success(null)
        } else {
            result.error(errorCode, message, details)
        }
    }

    companion object {
        private val loader: ExecutorService = Executors.newFixedThreadPool(4)
        private val hdrWindows = WeakHashMap<Activity, HdrWindowState>()
    }

    private data class HdrWindowState(val previousColorMode: Int, var viewCount: Int)
}
