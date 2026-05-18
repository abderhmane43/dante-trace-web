plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.dante_trace_mobile"
    
    // 🔥 تم الرفع إلى 36 لتلبية طلبات المكتبات الحديثة جداً
    compileSdk = 36 
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        // 🔥 تم التعديل لتجنب رسائل التحذير الخاصة بـ Kotlin
        jvmTarget = "17" 
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.dante_trace_mobile"
        
        // 🔥 تم تحديد الحد الأدنى بـ 21 لضمان عمل جميع الميزات المتقدمة
        minSdk = flutter.minSdkVersion 
        
        // 🔥 تم الرفع إلى 36 للتوافق التام
        targetSdk = 36 
        
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
