pluginManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        // 2단계(UVC 프리뷰)에서 사용할 라이브러리(JitPack 배포) 대비
        maven(url = "https://jitpack.io")
    }
}

rootProject.name = "ExternalCamera"
include(":app")
include(":libuvccamera")
