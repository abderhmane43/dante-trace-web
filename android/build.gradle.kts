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

// 🛡️ 1. وضع الدرع السحري أولاً (قبل عملية التقييم)
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            try {
                val namespace = androidExt.javaClass.getMethod("getNamespace").invoke(androidExt)
                if (namespace == null || namespace.toString().isEmpty()) {
                    var groupName = project.group.toString()
                    if (groupName.isEmpty()) {
                        groupName = "com.plugin.${project.name.replace("-", "_")}"
                    }
                    androidExt.javaClass.getMethod("setNamespace", String::class.java).invoke(androidExt, groupName)
                }
            } catch (e: Exception) {
                // تجاهل
            }
        }
    }
}

// 🚀 2. أمر التقييم الأساسي للتطبيق (نضعه في النهاية)
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}