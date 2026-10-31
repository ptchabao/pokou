import java.util.Properties

// Signature de release. Les secrets vivent dans android/key.properties
// (ignoré par git) et le keystore HORS du dépôt : un fichier ignoré est
// effacé par `git clean -xfd`, et perdre cette clé interdit toute mise à
// jour de l'application déjà publiée sous cette signature.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase Cloud Messaging — reads google-services.json in this directory.
    id("com.google.gms.google-services")
}

android {
    namespace = "com.pokou.pokou"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications (Java 8+ API desugaring).
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.pokou.pokou"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
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
            // Repli sur les clés de DEBUG quand key.properties est absent :
            // un développeur sans le keystore doit pouvoir lancer
            // `flutter run --release`. Le repli est BRUYANT, parce que c'est
            // exactement ainsi qu'un binaire signé en debug se retrouve
            // distribué sans que personne ne s'en aperçoive — et qu'un tel
            // binaire est refusé par le Play Store et casse la vérification
            // des App Links.
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "\n⚠️  Pokou: android/key.properties absent — build release signé avec les " +
                        "clés de DEBUG. NE PAS DISTRIBUER ce binaire.\n"
                )
                signingConfig = signingConfigs.getByName("debug")
            }
            // Minification laissée DÉSACTIVÉE (défaut Flutter) : R8 casse
            // volontiers les greffons qui passent par la réflexion (LiveKit,
            // Firebase, notifications locales), et le gain de taille ne vaut
            // pas ce risque sur une première publication. À activer plus
            // tard, avec des règles ProGuard et un test sur appareil réel.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // ── Couche d'appel native (voir docs/native-call-layer.md) ──────────
    //
    // Ces bibliothèques arrivent déjà de façon transitive par les greffons
    // Flutter, mais en `implementation` : elles ne sont donc PAS sur le
    // chemin de compilation de ce module, et le code Kotlin qui les utilise
    // directement ne compile pas. On les déclare ici explicitement.
    //
    // La BoM fixe les versions entre elles : mélanger un firebase-messaging
    // et un firebase-common de générations différentes donne des erreurs de
    // liaison à l'exécution, pas à la compilation — donc tard et sur
    // l'appareil de quelqu'un d'autre.
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-messaging")

    // NotificationCompat.CallStyle, RemoteInput, Person. `core-ktx` porte
    // les extensions Kotlin ; `core` seul suffirait, mais les deux sont déjà
    // tirées par Flutter et les séparer n'apporterait rien.
    implementation("androidx.core:core-ktx:1.13.1")
}
