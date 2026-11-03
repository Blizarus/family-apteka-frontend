# Flutter Proguard / R8 Optimization Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# ML Kit and Mobile Scanner rules
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.libraries.barhopper.** { *; }
-keep class com.google.photos.** { *; }
-keep class dev.steenbakker.mobile_scanner.** { *; }
-keep class androidx.camera.** { *; }

-keepclassmembers class * extends java.lang.Enum {
    <fields>;
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Image Picker & Device Info
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class dev.fluttercommunity.plus.device_info.** { *; }

# Speech to Text
-keep class com.csdcorp.speech_to_text.** { *; }

# Play Core Deferred Components suppress
-dontwarn com.google.android.play.core.**
