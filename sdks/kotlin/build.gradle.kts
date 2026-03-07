plugins {
    kotlin("jvm") version "1.9.24"
    id("maven-publish")
    id("signing")
}

group = "com.jobcelis"
version = "1.0.0"

repositories {
    mavenCentral()
}

dependencies {
    implementation("com.google.code.gson:gson:2.11.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.8.1")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
}

java {
    sourceCompatibility = JavaVersion.VERSION_11
    targetCompatibility = JavaVersion.VERSION_11
    withSourcesJar()
    withJavadocJar()
}

kotlin {
    jvmToolchain(11)
}

publishing {
    publications {
        create<MavenPublication>("maven") {
            from(components["java"])
            pom {
                name.set("Jobcelis Kotlin SDK")
                description.set("Official Kotlin SDK for the Jobcelis Event Infrastructure Platform")
                url.set("https://github.com/vladimirCeli/jobcelis-kotlin")
                licenses {
                    license {
                        name.set("MIT License")
                        url.set("https://opensource.org/licenses/MIT")
                    }
                }
                developers {
                    developer {
                        id.set("vladimirCeli")
                        name.set("Vladimir Celi")
                    }
                }
                scm {
                    connection.set("scm:git:git://github.com/vladimirCeli/jobcelis-kotlin.git")
                    developerConnection.set("scm:git:ssh://github.com/vladimirCeli/jobcelis-kotlin.git")
                    url.set("https://github.com/vladimirCeli/jobcelis-kotlin")
                }
            }
        }
    }
}
