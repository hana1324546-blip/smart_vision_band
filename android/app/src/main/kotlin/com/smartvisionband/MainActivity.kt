package com.smartvisionband
import io.flutter.embedding.android.FlutterActivity
import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import com.smartvisionband.service.NavigationRuntime
class MainActivity: FlutterActivity() {
 override fun provideFlutterEngine(context:Context):FlutterEngine=NavigationRuntime.provideEngine(context)
 override fun shouldDestroyEngineWithHost():Boolean=false
 override fun configureFlutterEngine(engine: FlutterEngine) {
  super.configureFlutterEngine(engine)
    NavigationRuntime.configure(applicationContext,engine)
 }
}
