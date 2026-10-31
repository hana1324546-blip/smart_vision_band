import java.util.Properties
plugins { id("com.android.application"); id("org.jetbrains.kotlin.android"); id("dev.flutter.flutter-gradle-plugin") }
val signing = Properties().apply {
 val f = rootProject.file("key.properties")
 if(f.exists()) f.inputStream().use { load(it) }
}
android {
 namespace = "com.smartvisionband"
 compileSdk = 35
 defaultConfig {
  applicationId = "com.smartvisionband"
  minSdk = 26
  targetSdk = 34
  versionCode = 1
  versionName = "0.1.0"
  testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
 }
 compileOptions { sourceCompatibility=JavaVersion.VERSION_17; targetCompatibility=JavaVersion.VERSION_17 }
 kotlinOptions { jvmTarget="17" }
 androidResources { noCompress += "tflite" }
 signingConfigs {
  if(signing.isNotEmpty()) create("production") {
   storeFile=file(signing.getProperty("storeFile")); storePassword=signing.getProperty("storePassword")
   keyAlias=signing.getProperty("keyAlias"); keyPassword=signing.getProperty("keyPassword")
  }
 }
 buildTypes {
  getByName("release") {
   isMinifyEnabled=true
   isShrinkResources=true
   proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"),"proguard-rules.pro")
   if(signing.isNotEmpty()) signingConfig=signingConfigs.getByName("production")
  }
 }
}
flutter { source="../.." }
dependencies {
 implementation("org.tensorflow:tensorflow-lite:2.16.1")
 implementation("org.tensorflow:tensorflow-lite-gpu:2.16.1")
 testImplementation("junit:junit:4.13.2")
 androidTestImplementation("androidx.test.ext:junit:1.2.1")
 androidTestImplementation("androidx.test:runner:1.6.2")
 // The camera source is the ESP32-CAM HTTP MJPEG stream; no UVC dependency is used.
}
