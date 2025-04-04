# Flutter相关规则
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.plugin.editing.** { *; }

# 保留注解
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions

# 第三方库规则
-keep class com.example.strava_pro.** { *; }
-dontwarn com.example.strava_pro.**

# Strava API 相关
-keep class com.sweetzpot.stravazpot.** { *; }
-dontwarn com.sweetzpot.stravazpot.**

# Geolocator
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# SQLite
-keep class org.sqlite.** { *; }
-dontwarn org.sqlite.** 