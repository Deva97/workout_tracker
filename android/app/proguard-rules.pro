# ML Kit Text Recognition ProGuard/R8 Rules

# Suppress warnings for optional language packs not bundled with Latin recognizer
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Keep all ML Kit classes, interfaces, enums and internal components
# (Required for MlKitInitProvider dependency injection and service discovery)
-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }
-keep enum com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Keep ML Kit Flutter Plugin
-keep class com.google_mlkit_text_recognition.** { *; }
-keep interface com.google_mlkit_text_recognition.** { *; }

# Keep Firebase ComponentRegistrar used by ML Kit DI
-keep class * implements com.google.firebase.components.ComponentRegistrar { *; }
-keep class com.google.firebase.components.** { *; }
-keep interface com.google.firebase.components.** { *; }
-dontwarn com.google.firebase.components.**

# Keep Google Play Services Common
-keep class com.google.android.gms.common.** { *; }
-keep interface com.google.android.gms.common.** { *; }
-dontwarn com.google.android.gms.**
