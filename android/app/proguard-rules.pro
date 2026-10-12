# Release derlemesinde R8 kodu küçültür ve adları karıştırır. Flutter Gradle
# eklentisi bu dosyayı varsa release kurallarına kendisi ekler.

## flutter_local_notifications + Gson
# Eklenti zamanlanmış bildirimleri Gson ile saklar; kullandığı Gson 2.8.9 kendi
# R8 kurallarını taşımaz. Bu kurallar olmadan TypeToken'ın generic bilgisi
# silinir ve her zamanlamada "Missing type parameter." hatası alınır.
# Kaynak: eklentinin örnek uygulamasındaki proguard-rules.pro (Gson kuralları).
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# Bildirim modelleri JSON olarak SharedPreferences'a ve alarm intent'lerine
# yazılır; alan ve enum adları karışırsa uygulama güncellemesinden önce
# kaydedilenler yeni sürümde okunamaz.
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
