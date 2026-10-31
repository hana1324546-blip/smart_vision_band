package com.smartvisionband.bluetooth
import android.annotation.SuppressLint
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.*
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.math.min

@SuppressLint("MissingPermission")
class BluetoothSppPlugin(context:Context,messenger:BinaryMessenger):EventChannel.StreamHandler {
 private val adapter=(context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).adapter
 private val main=Handler(Looper.getMainLooper())
 private val workers=Executors.newCachedThreadPool()
 private val scheduler=Executors.newSingleThreadScheduledExecutor()
 private var sink:EventChannel.EventSink?=null
 @Volatile private var socket:BluetoothSocket?=null
 @Volatile private var wanted=false
 @Volatile private var closed=false
 @Volatile private var connecting=false
 @Volatile private var lastPong=0L
 private var address=""
 private var backoff=1L
 private val writeLock=Any()
 init {
  EventChannel(messenger,"com.smartvisionband/bluetooth/events").setStreamHandler(this)
  MethodChannel(messenger,"com.smartvisionband/bluetooth").setMethodCallHandler { call,result ->
   try {when(call.method){
    "bonded" -> result.success(adapter?.bondedDevices?.map{mapOf("name" to (it.name?:"Unknown"),"address" to it.address)}?:emptyList<Any>())
    "connect" -> {address=call.argument<String>("address")?:error("Missing address");wanted=true;backoff=1;emit(mapOf("type" to "state","connected" to false,"reconnecting" to false));connect();result.success(null)}
    "send" -> {val line=call.argument<String>("line")?:"";require(Protocol.outgoing.matches(line));workers.execute{try{write(line);main.post{result.success(null)}}catch(e:Exception){main.post{result.error("TX",e.message,null)};lost()}}}
    "alert" -> sendHaptic("W",result)
    "haptic" -> {val command=call.argument<String>("command")?:error("Missing haptic command");Protocol.hapticByte(command);sendHaptic(command,result)}
    "disconnect" -> {wanted=false;socket?.close();socket=null;emit(mapOf("type" to "state","connected" to false,"reconnecting" to false));result.success(null)}
    else -> result.notImplemented()
   }}catch(e:Exception){result.error("BLUETOOTH",e.message,null)}
  }
  scheduler.scheduleAtFixedRate({
   if(socket!=null)try{
    if(android.os.SystemClock.elapsedRealtime()-lastPong>=15000)lost() else write("PING")
   }catch(_:Exception){lost()}
  },5,5,TimeUnit.SECONDS)
 }
 private fun emit(e:Map<String,Any>){main.post{sink?.success(e)}}
 private fun write(line:String){synchronized(writeLock){val s=socket?:error("Disconnected");s.outputStream.write((line+"\n").toByteArray(Charsets.US_ASCII));s.outputStream.flush();emit(mapOf("type" to "tx","line" to line))}}
 private fun sendHaptic(command:String,result:MethodChannel.Result){workers.execute{try{writeRaw(command,Protocol.hapticByte(command));main.post{result.success(null)}}catch(e:Exception){main.post{result.error("TX",e.message,null)};lost()}}}
 private fun writeRaw(command:String,bytes:ByteArray){synchronized(writeLock){val s=socket?:error("Disconnected");s.outputStream.write(bytes);s.outputStream.flush();emit(mapOf("type" to "tx","line" to command))}}
 @Synchronized private fun connect(){
  if(closed||!wanted||connecting||socket!=null)return
  connecting=true
  workers.execute{
   var pending:BluetoothSocket?=null
   try{
    val a=adapter?:error("Bluetooth unavailable")
    val active=a.getRemoteDevice(address).createRfcommSocketToServiceRecord(UUID.fromString("00001101-0000-1000-8000-00805F9B34FB"))
    pending=active
    val timeout=scheduler.schedule({try{pending?.close()}catch(_:Exception){}},12,TimeUnit.SECONDS)
    try{active.connect()}finally{timeout.cancel(false)}
    if(!wanted||closed){active.close();return@execute}
    socket=active;backoff=1;lastPong=android.os.SystemClock.elapsedRealtime()
    emit(mapOf("type" to "state","connected" to true,"reconnecting" to false));connecting=false
    val buffer=ByteArray(256);val line=StringBuilder()
    while(wanted&&!closed){
     val n=active.inputStream.read(buffer);if(n<0)break
     for(i in 0 until n){val c=(buffer[i].toInt() and 255).toChar()
      if(c=='\n'){val text=line.toString().trimEnd('\r');line.setLength(0)
       if(text=="PONG")lastPong=android.os.SystemClock.elapsedRealtime()
       emit(mapOf("type" to "rx","line" to text))
      }else if(c!='\r'){line.append(c);if(line.length>128)throw IllegalStateException("RX line too long")}
     }
    }
   }catch(e:Exception){emit(mapOf("type" to "error","message" to (e.message?:"Connection failed")))}
   finally{try{pending?.close()}catch(_:Exception){};connecting=false;lost()}
  }
 }
 @Synchronized private fun lost(){
  try{socket?.close()}catch(_:Exception){};socket=null
    emit(mapOf("type" to "state","connected" to false,"reconnecting" to (wanted&&!closed)))
  if(wanted&&!closed){val delay=backoff;backoff=min(backoff*2,30);scheduler.schedule({connect()},delay,TimeUnit.SECONDS)}
 }
 override fun onListen(arguments:Any?,events:EventChannel.EventSink){sink=events;emit(mapOf("type" to "state","connected" to (socket!=null),"reconnecting" to (wanted&&socket==null)))}
 override fun onCancel(arguments:Any?){sink=null}
 fun close(){closed=true;wanted=false;try{socket?.close()}catch(_:Exception){};workers.shutdownNow();scheduler.shutdownNow()}
}
