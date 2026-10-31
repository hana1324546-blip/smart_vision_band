package com.smartvisionband.ai
import android.content.Context
import android.os.Build
import android.util.Log
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Color
import org.tensorflow.lite.Interpreter
import org.tensorflow.lite.DataType
import org.tensorflow.lite.gpu.GpuDelegate
import org.tensorflow.lite.nnapi.NnApiDelegate
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.io.IOException
import kotlin.math.*

class TfliteDetector(context:Context):AutoCloseable {
 private val labelsByLanguage=mapOf(
  "en" to loadLabels(context,"labels_en.txt"),
  "ar" to loadLabels(context,"labels_ar.txt"))
 @Volatile private var languageCode="en"
 private val interpreter:Interpreter
 private val delegate:AutoCloseable?
 private val input:ByteBuffer
 private val inputShape:IntArray
 private val inputType:DataType
 private val inputScale:Float
 private val inputZeroPoint:Int
 private val inputWidth:Int
 private val inputHeight:Int
 private val outputType:DataType
 private val outputScale:Float
 private val outputZeroPoint:Int
 private val shape:IntArray
 private val output:ByteBuffer
 init {
  val classCount=labelsByLanguage.getValue("en").size
  require(classCount>0&&labelsByLanguage.getValue("ar").size==classCount){"English and Arabic label lists must have the same nonzero class count"}
  val bytes=readModel(context)
  val model=ByteBuffer.allocateDirect(bytes.size).order(ByteOrder.nativeOrder()).apply{put(bytes);rewind()}
  val runtime=createInterpreter(model)
  interpreter=runtime.first
  delegate=runtime.second
  val inputTensor=interpreter.getInputTensor(0)
  inputShape=inputTensor.shape()
  inputType=inputTensor.dataType()
  require(inputShape.size==4&&inputShape[0]==1&&inputShape[3]==3&&inputShape[1]==inputShape[2]){"Expected square NHWC RGB input"}
  inputHeight=inputShape[1];inputWidth=inputShape[2]
  require(inputWidth==320||inputWidth==640){"Supported input sizes are 320 and 640"}
  require(inputType==DataType.FLOAT32||inputType==DataType.UINT8||inputType==DataType.INT8){"Unsupported model input type: $inputType"}
  val inputQuantization=inputTensor.quantizationParams()
  inputScale=inputQuantization.scale;inputZeroPoint=inputQuantization.zeroPoint
  if(inputType!=DataType.FLOAT32)require(inputScale>0f){"Quantized input tensor has no scale"}
  input=ByteBuffer.allocateDirect(inputTensor.numBytes()).order(ByteOrder.nativeOrder())
  val t=interpreter.getOutputTensor(0)
  shape=t.shape()
  outputType=t.dataType()
  require((outputType==DataType.FLOAT32||outputType==DataType.UINT8||outputType==DataType.INT8)&&shape.size==3&&shape[0]==1){"Expected a raw YOLO output tensor"}
  val outputQuantization=t.quantizationParams()
  outputScale=outputQuantization.scale;outputZeroPoint=outputQuantization.zeroPoint
  if(outputType!=DataType.FLOAT32)require(outputScale>0f){"Quantized output tensor has no scale"}
  require(shape[1]==classCount+4 || shape[2]==classCount+4){"Model class/output mismatch"}
  output=ByteBuffer.allocateDirect(t.numBytes()).order(ByteOrder.nativeOrder())
 }
 data class Box(val cls:Int,val confidence:Float,val x1:Float,val y1:Float,val x2:Float,val y2:Float)
 fun setLanguage(languageCode:String){
  require(labelsByLanguage.containsKey(languageCode)){"Unsupported detector language: $languageCode"}
  this.languageCode=languageCode
 }
 @Synchronized fun detect(frame:Bitmap,threshold:Float=.5f):Map<String,Any>{
  val activeLanguage=languageCode
  val labels=labelsByLanguage.getValue(activeLanguage)
  val started=android.os.SystemClock.elapsedRealtimeNanos()
  val scale=min(inputWidth.toFloat()/frame.width,inputHeight.toFloat()/frame.height)
  val w=(frame.width*scale).roundToInt();val h=(frame.height*scale).roundToInt()
  val dx=(inputWidth-w)/2;val dy=(inputHeight-h)/2
  val padded=Bitmap.createBitmap(inputWidth,inputHeight,Bitmap.Config.ARGB_8888)
  val resized=Bitmap.createScaledBitmap(frame,w,h,true)
  Canvas(padded).apply{drawColor(Color.rgb(114,114,114));drawBitmap(resized,dx.toFloat(),dy.toFloat(),Paint())}
  val pixels=IntArray(inputWidth*inputHeight);padded.getPixels(pixels,0,inputWidth,0,0,inputWidth,inputHeight)
  input.rewind()
  for(p in pixels){putChannel((p shr 16) and 255);putChannel((p shr 8) and 255);putChannel(p and 255)}
  input.rewind();output.rewind();interpreter.run(input,output)
  padded.recycle();if(resized!==frame)resized.recycle()
  val channelsFirst=shape[1]==labels.size+4
  val n=if(channelsFirst)shape[2] else shape[1]
  fun value(c:Int,i:Int):Float {
   val index=if(channelsFirst)c*n+i else i*(labels.size+4)+c
   return when(outputType){
    DataType.FLOAT32 -> output.getFloat(index*4)
    DataType.INT8 -> (output.get(index).toInt().toByte().toInt()-outputZeroPoint)*outputScale
    DataType.UINT8 -> ((output.get(index).toInt() and 255)-outputZeroPoint)*outputScale
    else -> error("Unsupported output type")
   }
  }
  val candidates=mutableListOf<Box>()
  for(i in 0 until n){
   var cls=0;var score=0f
   for(c in labels.indices){val s=value(c+4,i);if(s>score){score=s;cls=c}}
   if(!score.isFinite()||score<threshold)continue
   val cx=value(0,i);val cy=value(1,i);val bw=value(2,i);val bh=value(3,i)
   if(!cx.isFinite()||!cy.isFinite()||!bw.isFinite()||!bh.isFinite()||bw<=0||bh<=0)continue
  val x1=((cx-bw/2-dx)/scale/frame.width).coerceIn(0f,1f)
  val y1=((cy-bh/2-dy)/scale/frame.height).coerceIn(0f,1f)
  val x2=((cx+bw/2-dx)/scale/frame.width).coerceIn(0f,1f)
  val y2=((cy+bh/2-dy)/scale/frame.height).coerceIn(0f,1f)
   if(x2>x1&&y2>y1)candidates.add(Box(cls,score,x1,y1,x2,y2))
  }
  val kept=mutableListOf<Box>()
  for(b in candidates.sortedByDescending{it.confidence}.take(300)){
   if(kept.none{it.cls==b.cls&&iou(it,b)>.45f})kept.add(b)
  }
  val elapsed=(android.os.SystemClock.elapsedRealtimeNanos()-started)/1e6
  return mapOf("timestamp" to System.currentTimeMillis(),"latencyMs" to elapsed,"languageCode" to activeLanguage,
   "detections" to kept.map{mapOf("class" to labels[it.cls],"confidence" to it.confidence.toDouble(),"bbox" to listOf(it.x1.toDouble(),it.y1.toDouble(),it.x2.toDouble(),it.y2.toDouble()),"centerX" to ((it.x1+it.x2)/2).toDouble())})
 }
 private fun loadLabels(context:Context,asset:String)=context.assets.open(asset).bufferedReader().readLines().filter{it.isNotBlank()}
 private fun readModel(context:Context):ByteArray {
  try{return context.assets.open("yolov8n.tflite").use{it.readBytes()}}
  catch(error:IOException){
   Log.w(TAG,"yolov8n.tflite model missing",error)
   try{return context.assets.open("best_float32.tflite").use{it.readBytes()}}
   catch(fallbackError:IOException){throw IOException("yolov8n.tflite model missing; add a trained model to enable camera inference. Ultrasonic guidance remains available.",fallbackError)}
  }
 }
 private fun putChannel(channel:Int){
  val normalized=channel/255f
  when(inputType){
   DataType.FLOAT32 -> input.putFloat(normalized)
   DataType.INT8 -> input.put((normalized/inputScale+inputZeroPoint).roundToInt().coerceIn(-128,127).toByte())
   DataType.UINT8 -> input.put((normalized/inputScale+inputZeroPoint).roundToInt().coerceIn(0,255).toByte())
   else -> error("Unsupported input type")
  }
 }
 private fun iou(a:Box,b:Box):Float{
  val intersection=max(0f,min(a.x2,b.x2)-max(a.x1,b.x1))*max(0f,min(a.y2,b.y2)-max(a.y1,b.y1))
  val union=(a.x2-a.x1)*(a.y2-a.y1)+(b.x2-b.x1)*(b.y2-b.y1)-intersection
  return if(union>0)intersection/union else 0f
 }
 override fun close(){try{interpreter.close()}finally{delegate?.close()}}

 private fun createInterpreter(model:ByteBuffer):Pair<Interpreter,AutoCloseable?> {
  try{
   val gpu=GpuDelegate()
   try{
    val options=Interpreter.Options().addDelegate(gpu).setNumThreads(4)
    val runtime=Interpreter(model.asReadOnlyBuffer().order(ByteOrder.nativeOrder()).apply{rewind()},options)
    Log.i(TAG,"Using GPU delegate for TFLite inference")
    return runtime to gpu
   }catch(error:Exception){gpu.close();Log.w(TAG,"GPU delegate unavailable; trying NNAPI",error)}
  }catch(error:Exception){Log.w(TAG,"GPU delegate unavailable; trying NNAPI",error)}
   catch(error:LinkageError){Log.w(TAG,"GPU delegate native library unavailable; trying NNAPI",error)}
  if(Build.VERSION.SDK_INT>=27){
   try{
    val nnapi=NnApiDelegate()
    try{
     val options=Interpreter.Options().addDelegate(nnapi).setNumThreads(4)
     val runtime=Interpreter(model.asReadOnlyBuffer().order(ByteOrder.nativeOrder()).apply{rewind()},options)
     Log.i(TAG,"Using NNAPI delegate for TFLite inference")
     return runtime to nnapi
    }catch(error:Exception){nnapi.close();Log.w(TAG,"NNAPI delegate unavailable; using CPU",error)}
  }catch(error:Exception){Log.w(TAG,"NNAPI delegate unavailable; using CPU",error)}
   catch(error:LinkageError){Log.w(TAG,"NNAPI delegate unavailable; using CPU",error)}
  }
  return Interpreter(model.asReadOnlyBuffer().order(ByteOrder.nativeOrder()).apply{rewind()},Interpreter.Options().setNumThreads(4)) to null
 }

 companion object {
  const val TAG="TfliteDetector"

  fun checkModelAssets(context:Context):Boolean {
    return try{
     val assets=context.assets.list("")?.toSet().orEmpty()
     val primary=assets.contains("yolov8n.tflite")
     val fallback=assets.contains("best_float32.tflite")
     if(!primary)Log.w(TAG,if(fallback)"yolov8n.tflite model missing; legacy best_float32.tflite will be used" else "yolov8n.tflite model missing; ultrasonic-only mode remains available")
     primary||fallback
    }catch(error:Exception){
     Log.w(TAG,"Unable to inspect TFLite assets; ultrasonic-only mode remains available",error)
     false
    }
  }
 }
}
