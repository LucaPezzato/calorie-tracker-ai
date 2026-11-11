# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }
-keep interface io.flutter.plugin.common.PluginRegistry** { *; }
-keep interface io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding** { *; }

# Mobile Scanner
-keep class dev.steenbakker.mobile_scanner.** { *; }
-dontwarn dev.steenbakker.mobile_scanner.**

# CameraX & ML Kit
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Image picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# Google Sign-in, Play Services & Play Core
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-dontwarn com.google.android.play.core.**

# Preserve annotations and signatures
-keepattributes *Annotation*,InnerClasses,EnclosingMethod,Signature
