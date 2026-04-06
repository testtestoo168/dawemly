## Permission Handler
-keep class com.baseflow.permissionhandler.** { *; }

## Google ML Kit
-keep class com.google.mlkit.** { *; }
-keep class com.google_mlkit_face_detection.** { *; }

## Flutter
-keep class io.flutter.** { *; }

## Google Play Core (referenced by Flutter deferred components)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
