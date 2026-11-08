# R8 kuralları - Godot motoru JNI ve yansıma kullanır; motor sınıfları korunur.
-keep class org.godotengine.** { *; }
-keep class com.godot.game.** { *; }
-keepclasseswithmembernames,includedescriptorclasses class * { native <methods>; }
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod,SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
-dontwarn org.godotengine.**
-dontwarn javax.annotation.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn org.jetbrains.annotations.**
# AdMob eklentisi (kurallar .aar içinden de gelir; burada yalnızca zararsız uyarılar susturulur)
-keep class * extends org.godotengine.godot.plugin.GodotPlugin { *; }
-dontwarn kotlin.Metadata
-dontwarn com.android.billingclient.**
-dontwarn com.google.android.gms.**
