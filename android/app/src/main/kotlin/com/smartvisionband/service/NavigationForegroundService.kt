package com.smartvisionband.service
import android.app.*
import android.content.Intent
import android.os.IBinder
import android.os.PowerManager
import com.smartvisionband.MainActivity
class NavigationForegroundService:Service(){
 private var lock:PowerManager.WakeLock?=null
 private var runtimeEngine:io.flutter.embedding.engine.FlutterEngine?=null
 override fun onCreate(){
  super.onCreate()
  val nm=getSystemService(NOTIFICATION_SERVICE) as NotificationManager
  nm.createNotificationChannel(NotificationChannel("navigation","Navigation",NotificationManager.IMPORTANCE_LOW))
  val open=PendingIntent.getActivity(this,0,Intent(this,MainActivity::class.java),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
  val stop=PendingIntent.getService(this,1,Intent(this,NavigationForegroundService::class.java).setAction(ACTION_STOP_NOTIFICATION),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
  val notification=Notification.Builder(this,"navigation").setContentTitle("Insight Wear is active")
   .setContentText("Tap Stop to end navigation").setSmallIcon(android.R.drawable.ic_dialog_info).setContentIntent(open).setOngoing(true)
   .addAction(android.R.drawable.ic_media_pause,"Stop",stop).build()
  startForeground(1,notification)
  lock=(getSystemService(POWER_SERVICE) as PowerManager).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK,"SmartVision:Navigation").apply{acquire()}
 }
 override fun onStartCommand(intent:Intent?,flags:Int,startId:Int):Int {
   if(intent?.action==ACTION_STOP_NOTIFICATION){NavigationRuntime.stopFromNotification();stopSelf(startId);return START_NOT_STICKY}
   if(intent?.action==ACTION_STOP){NavigationRuntime.stopCamera();stopSelf(startId);return START_NOT_STICKY}
    runtimeEngine=NavigationRuntime.attachToService(this)
    return START_STICKY
 }
 override fun onBind(intent:Intent?):IBinder?=null
 override fun onDestroy(){NavigationRuntime.stopCamera();NavigationRuntime.detachService();runtimeEngine=null;if(lock?.isHeld==true)lock?.release();super.onDestroy()}

 companion object {
  const val ACTION_STOP="com.smartvisionband.action.STOP_NAVIGATION"
  const val ACTION_STOP_NOTIFICATION="com.smartvisionband.action.STOP_NAVIGATION_NOTIFICATION"
 }
}
