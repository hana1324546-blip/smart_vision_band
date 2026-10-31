package com.smartvisionband.service

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import com.smartvisionband.audio.AudioRoutePlugin
import com.smartvisionband.bluetooth.BluetoothSppPlugin
import com.smartvisionband.camera.UvcCameraPlugin
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

object NavigationRuntime {
    @Volatile private var engine: FlutterEngine? = null
    @Volatile private var serviceEngine: FlutterEngine? = null
    @Volatile private var configuredEngine: FlutterEngine? = null
    @Volatile private var bluetooth: BluetoothSppPlugin? = null
    @Volatile private var camera: UvcCameraPlugin? = null
    @Volatile private var serviceChannel: MethodChannel? = null

    @Synchronized
    fun provideEngine(context: Context): FlutterEngine {
        return engine ?: FlutterEngine(context.applicationContext).also { engine = it }
    }

    @Synchronized
    fun configure(context: Context, flutterEngine: FlutterEngine) {
        if (configuredEngine === flutterEngine) return
        val appContext = context.applicationContext
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        bluetooth = BluetoothSppPlugin(appContext, messenger)
        camera = UvcCameraPlugin(appContext, messenger)
        AudioRoutePlugin(appContext, messenger)
        val channel = MethodChannel(messenger, "com.smartvisionband/service")
        serviceChannel = channel
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "start" -> {
                        val intent = Intent(appContext, NavigationForegroundService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            appContext.startForegroundService(intent)
                        } else {
                            appContext.startService(intent)
                        }
                        result.success(null)
                    }
                    "stop" -> {
                        appContext.startService(Intent(appContext, NavigationForegroundService::class.java)
                            .setAction(NavigationForegroundService.ACTION_STOP))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("SERVICE", error.message, null)
            }
        }
        configuredEngine = flutterEngine
    }

    @Synchronized
    fun attachToService(context: Context): FlutterEngine {
        val retained = provideEngine(context)
        configure(context, retained)
        if (!retained.dartExecutor.isExecutingDart) {
            val bundlePath = FlutterInjector.instance().flutterLoader().findAppBundlePath()
            retained.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(bundlePath, "main"))
        }
        serviceEngine = retained
        return retained
    }

    fun stopCamera() {
        camera?.stop()
    }

    fun stopFromNotification() {
        stopCamera()
        Handler(Looper.getMainLooper()).post {
            serviceChannel?.invokeMethod("stoppedByNotification", null)
        }
    }

    fun detachService() {
        serviceEngine = null
    }
}