# flutter_local_notifications stores scheduled notifications with Gson,
# which reads generic types through reflection. Without these rules R8 strips
# what Gson needs, and a release build fails to schedule from the second
# reminder on ("Missing type parameter").
# https://github.com/google/gson/blob/main/examples/android-proguard-example/proguard.cfg
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep class com.dexterous.** { *; }
