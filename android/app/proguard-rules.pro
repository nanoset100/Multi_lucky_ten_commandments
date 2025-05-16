# Flutter 웹 플러그인용 규칙
-keep class androidx.webkit.** { *; }

# Flutter용 일반 규칙
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Supabase 관련 규칙
-keep class io.github.jan.supabase.** { *; }
-keep class com.google.gson.** { *; }

# 다트 코드 보존
-keep class **.generated.** { *; }
-keep class **.g.dart { *; }

# SharedPreferences 보존
-keep class android.app.SharedPreferences { *; }

# WorkManager 보존 (백그라운드 작업을 위해)
-keep class androidx.work.** { *; }

# 애플리케이션 클래스 보존
-keep class com.nanoset.luckyten.** { *; }

# 경고 제거
-dontwarn io.flutter.embedding.**
-dontwarn android.graphics.Canvas 