# Flutter için genel ProGuard kuralları

# Flutter wrapper'a ilişkin kurallar
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.plugin.editing.** { *; }

# In-App Purchase için gerekli kurallar
-keep class com.android.billingclient.** { *; }
-keep class com.android.vending.billing.** { *; }

# Firebase için gerekli kurallar
-keep class com.google.firebase.** { *; }

# Kotlin için gerekli kurallar
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**

# MultiDex için gerekli kurallar
-keep class androidx.multidex.** { *; }

# ============= YENİ EKLENEN GOOGLE PLAY CORE KURALLARI =============

# Google Play Core - Flutter deferred components için KRİTİK KURALLAR
-dontwarn com.google.android.play.core.tasks.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**

# Flutter deferred components - missing class'ları ignore et
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.PlayStoreDeferredComponentManager

# Google Play Core tasks - missing class sorununu çöz
-keep class com.google.android.play.core.tasks.** { *; }
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# Google Play Services tasks ile uyumluluk
-keep class com.google.android.gms.tasks.** { *; }

# ============= ESKI KURALLAR DEVAM EDİYOR =============

# Serializable sınıfları koruma
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Enum sınıflarını koruma
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Eğer bazı model sınıflarınız varsa ve bunları korumak istiyorsanız
# -keep class com.mkagca.yksgunluk.models.** { *; }

# Log mesajlarını kaldırma (isteğe bağlı)
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}