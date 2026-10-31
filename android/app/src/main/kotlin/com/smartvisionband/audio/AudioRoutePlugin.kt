package com.smartvisionband.audio
import android.content.Context
import android.media.AudioManager
import android.media.AudioDeviceInfo
import android.os.Vibrator
import android.os.VibrationEffect
import io.flutter.plugin.common.*
class AudioRoutePlugin(context:Context,messenger:BinaryMessenger){
 init{
  val audio=context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
  MethodChannel(messenger,"com.smartvisionband/audio").setMethodCallHandler{call,result->
   try{when(call.method){
    "isBluetoothOutput" -> result.success(audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS).any{it.type==AudioDeviceInfo.TYPE_BLUETOOTH_A2DP||it.type==AudioDeviceInfo.TYPE_BLE_HEADSET})
    "vibrate" -> {(context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator).vibrate(VibrationEffect.createOneShot(500,VibrationEffect.DEFAULT_AMPLITUDE));result.success(null)}
    else -> result.notImplemented()
   }}catch(e:Exception){result.error("AUDIO",e.message,null)}
  }
 }
}
