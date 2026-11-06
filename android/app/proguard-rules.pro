# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.maestro.** { *; }
-dontwarn io.flutter.embedding.**

# ML Kit / scanner
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }

# Reflection / serialização
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
