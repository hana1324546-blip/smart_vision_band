pluginManagement {
 val flutterSdkPath = run {
  val properties = java.util.Properties()
    val localProperties=file("local.properties")
    if(localProperties.exists())localProperties.inputStream().use{properties.load(it)}
    properties.getProperty("flutter.sdk")?.takeIf{it.isNotBlank()}
     ?:System.getenv("FLUTTER_ROOT")?.takeIf{it.isNotBlank()}
     ?:error("Flutter SDK not configured. Set flutter.sdk in android/local.properties or export FLUTTER_ROOT.")
 }
 includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")
 repositories { google(); mavenCentral(); gradlePluginPortal() }
}
plugins {
 id("dev.flutter.flutter-plugin-loader") version "1.0.0"
 id("com.android.application") version "8.6.1" apply false
 id("org.jetbrains.kotlin.android") version "1.9.25" apply false
}
include(":app")
