# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.embedding.android.** { *; }
-keep class io.flutter.embedding.engine.** { *; }

# sqflite
-keep class com.tekartik.sqflite.** { *; }

# share_plus
-keep class com.braintreepayments.api.** { *; }

# Don't warn for unused JNI calls
-dontwarn javax.annotation.**
-dontwarn kotlin.Unit