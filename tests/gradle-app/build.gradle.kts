// A Kotlin application packaged as one Shadow jar, like the Wodby Kotlin boilerplate.
plugins {
    kotlin("jvm") version "2.4.21"
    id("com.gradleup.shadow") version "9.6.1"
    application
}

repositories {
    mavenCentral()
}

application {
    mainClass = "MainKt"
}

tasks.shadowJar {
    archiveClassifier = ""
}

tasks.jar {
    archiveClassifier = "plain"
}
