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
