package com.smartvisionband.camera
import android.content.Context
import io.flutter.plugin.common.*

interface CameraAdapter {
 fun start(onEvent:(Map<String,Any>)->Unit)
 fun configure(confidence:Float)
 fun setLanguage(languageCode:String)
 fun requestSnapshot(requestId:Long)
 fun stop()
}
class UvcCameraPlugin(context:Context,messenger:BinaryMessenger):EventChannel.StreamHandler {
 private var sink:EventChannel.EventSink?=null
 private var adapter:CameraAdapter?=MjpegStreamHandler(context.applicationContext)
 private val main=android.os.Handler(android.os.Looper.getMainLooper())
 init {
  EventChannel(messenger,"com.smartvisionband/camera/events").setStreamHandler(this)
  MethodChannel(messenger,"com.smartvisionband/camera").setMethodCallHandler { call,result ->
   try{when(call.method){
    "start" -> {
     val driver=adapter
    if(driver==null)result.error("CAMERA_ADAPTER_REQUIRED","Install a camera adapter and compatible model; see docs/CAMERA.md",null)
    else{driver.start{e->android.os.Handler(android.os.Looper.getMainLooper()).post{sink?.success(e)}};result.success(null)}
    }
    "stop" -> {stop();result.success(null)}
    "configure" -> {val confidence=call.argument<Number>("confidence")?.toFloat()?:error("Missing confidence");require(confidence in 0.1f..0.95f);adapter?.configure(confidence);result.success(null)}
    "setLanguage" -> {val language=call.argument<String>("languageCode")?:error("Missing languageCode");require(language=="ar"||language=="en");adapter?.setLanguage(language);result.success(null)}
    "snapshot" -> {val requestId=call.argument<Number>("requestId")?.toLong()?:error("Missing snapshot requestId");require(requestId>0);adapter?.requestSnapshot(requestId)?:error("Camera adapter unavailable");result.success(null)}
    else -> result.notImplemented()
   }}catch(e:Exception){result.error("CAMERA",e.message,null)}
  }
 }
 fun installAdapter(value:CameraAdapter){adapter=value}
 override fun onListen(arguments:Any?,events:EventChannel.EventSink){sink=events;events.success(mapOf("type" to "state","ready" to false))}
 override fun onCancel(arguments:Any?){sink=null}
 fun stop(){adapter?.stop();main.post{sink?.success(mapOf("type" to "state","ready" to false))}}
 fun close(){(adapter as? AutoCloseable)?.close()?:stop()}
}
