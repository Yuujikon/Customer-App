plugins {
    id("com.google.gms.google-services") version "4.5.0" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Redirect build artifacts to the root build directory (Flutter standard)
val rootBuildDir = rootProject.layout.projectDirectory.dir("../build")
rootProject.layout.buildDirectory.value(rootBuildDir)

subprojects {
    val subBuildDir = rootBuildDir.dir(project.name)
    if (project.projectDir.absolutePath.startsWith(rootProject.projectDir.parent)) {
        project.layout.buildDirectory.value(subBuildDir)
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
