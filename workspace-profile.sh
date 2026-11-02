# Preserve image tool paths when the developer home is mounted.
export PATH="/opt/java/openjdk/bin:/opt/maven/bin:/usr/local/bin:$PATH"
# Maven and Gradle in a workspace shell use the dependencies workspace-java keeps with the checkout.
if [ -d "${APP_ROOT:-/usr/src/app}/.wodby-workspace" ]; then
    case " ${MAVEN_OPTS:-} " in
        *-Dmaven.repo.local=*) ;;
        *) export MAVEN_OPTS="${MAVEN_OPTS:+$MAVEN_OPTS }-Dmaven.repo.local=${APP_ROOT:-/usr/src/app}/.wodby-workspace/m2/repository" ;;
    esac
    export MAVEN_USER_HOME="${MAVEN_USER_HOME:-${APP_ROOT:-/usr/src/app}/.wodby-workspace/m2}"
    export GRADLE_USER_HOME="${GRADLE_USER_HOME:-${APP_ROOT:-/usr/src/app}/.wodby-workspace/gradle}"
fi
