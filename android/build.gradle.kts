allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    afterEvaluate {
        (extensions.findByName("android") as? com.android.build.gradle.BaseExtension)?.apply {
            // Android 15+ can use 16 KB memory pages, and Play rejects bundles
            // whose native libraries are linked for 4 KB ("Your app does not
            // support 16 KB memory page sizes"). Under NDK r27 that alignment
            // is opt-in per module, and plugin modules do not inherit the app
            // module's settings -- every plugin here compiles against NDK 27
            // even though app/build.gradle.kts pins 28.1.
            //
            // flutter_zxing opts in for itself and comes out correct; webcrypto
            // does not, and was the single misaligned library in the v1.0.0-test
            // bundle. Setting it for every subproject fixes webcrypto and stops
            // the next source-built plugin from reintroducing this.
            defaultConfig {
                externalNativeBuild {
                    cmake {
                        arguments += "-DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON"
                    }
                }
            }

            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            kotlinOptions {
                jvmTarget = JavaVersion.VERSION_17.toString()
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
