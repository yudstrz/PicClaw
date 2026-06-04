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
subprojects {
    fun injectNamespace(proj: Project) {
        if (proj.hasProperty("android")) {
            val android = proj.extensions.findByName("android")
            if (android != null) {
                val namespaceMethod = android.javaClass.methods.firstOrNull { it.name == "setNamespace" }
                val getNamespaceMethod = android.javaClass.methods.firstOrNull { it.name == "getNamespace" }
                if (namespaceMethod != null && getNamespaceMethod != null) {
                    val currentNamespace = getNamespaceMethod.invoke(android)
                    if (currentNamespace == null) {
                        namespaceMethod.invoke(android, proj.group.toString())
                    }
                }
            }
        }
    }

    if (state.executed) {
        injectNamespace(this)
    } else {
        afterEvaluate {
            injectNamespace(this)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

