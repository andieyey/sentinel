allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

fun Project.inferAndroidNamespace(): String {
    val manifestFile = file("src/main/AndroidManifest.xml")
    if (manifestFile.exists()) {
        val manifestContent = manifestFile.readText()
        val packageMatch = Regex("""package\s*=\s*\"([^\"]+)\"""").find(manifestContent)
        val packageName = packageMatch?.groupValues?.getOrNull(1)
        if (!packageName.isNullOrBlank()) {
            return packageName
        }
    }

    val sanitizedName = name.replace('-', '_')
    val groupValue = group.toString()
    return if (groupValue.isNotBlank() && groupValue != "unspecified") {
        "$groupValue.$sanitizedName"
    } else {
        "dev.sentinel.$sanitizedName"
    }
}

fun Project.applyAndroidNamespaceFallback() {
    val androidExtension = extensions.findByName("android") ?: return

    val getNamespaceMethod = androidExtension.javaClass.methods.firstOrNull {
        it.name == "getNamespace" && it.parameterCount == 0
    } ?: return

    val currentNamespace = runCatching {
        getNamespaceMethod.invoke(androidExtension) as? String
    }.getOrNull()

    if (!currentNamespace.isNullOrBlank()) {
        return
    }

    val setNamespaceMethod = androidExtension.javaClass.methods.firstOrNull {
        it.name == "setNamespace" &&
            it.parameterCount == 1 &&
            it.parameterTypes[0] == String::class.java
    } ?: return

    runCatching {
        setNamespaceMethod.invoke(androidExtension, inferAndroidNamespace())
    }
}

subprojects {
    if (state.executed) {
        applyAndroidNamespaceFallback()
    } else {
        afterEvaluate {
            applyAndroidNamespaceFallback()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
