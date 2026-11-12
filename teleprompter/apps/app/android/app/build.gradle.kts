import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 应用包名集中在此处：修改 android/gradle.properties 的 appApplicationId 即可。
// 注意：Kotlin 源码包路径（com/dawan/teleprompter）与 MethodChannel 名称不随此值自动变化。
val appId = providers.gradleProperty("appApplicationId").getOrElse("com.dawan.teleprompter")

// 正式签名配置存放在仓库之外，避免密钥与密码进入 Git。
// 可用环境变量 DAWAN_KEYSTORE_PROPERTIES 指向其他位置的 key.properties。
val keystorePropertiesFile = file(
    System.getenv("DAWAN_KEYSTORE_PROPERTIES")
        ?: "${System.getProperty("user.home")}/.dawan-teleprompter-secrets/keystore.properties",
)
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}

android {
    namespace = appId
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // 应用 ID 与 namespace 共用 appApplicationId，避免两处不一致。
        applicationId = appId
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // 有仓库外 key.properties 时使用正式签名；缺失时退回 debug，
            // 仅用于本地 `flutter run --release`，不可作为发布包。
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "未找到 ${keystorePropertiesFile.absolutePath}，release 构建将使用 debug 签名。",
                )
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
