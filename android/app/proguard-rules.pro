# Flutter wrapper
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# mobile_scanner / MLKit barcode scanning
-keep class dev.steenbakker.mobile_scanner.** { *; }
-keep class com.google.mlkit.** { *; }
-keepclassmembers class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-keepclassmembers class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }

# CameraX
-keep class androidx.camera.** { *; }
-keepclassmembers class androidx.camera.** { *; }

# Prevent stripping classes accessed via reflection
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
