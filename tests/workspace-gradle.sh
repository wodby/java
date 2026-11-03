#!/usr/bin/env bash
# Workspace builds of a Gradle project build only the runnable jar, uncompressed, and compile
# Kotlin inside the Gradle daemon; one-off builds still build everything assemble builds.
# Gradle and the Kotlin and Shadow plugins are downloaded, so this needs a network.
# GRADLE_USER_HOME_SEED may name the Gradle home of an earlier build: its wrapper
# distributions and downloaded modules are copied first, so nothing is downloaded again.
set -euo pipefail
image="${IMAGE:?Set IMAGE to the candidate Java development image}"
here=$(cd "$(dirname "$0")" && pwd)
seed=()
if [ -n "${GRADLE_USER_HOME_SEED:-}" ]; then seed=(-v "$GRADLE_USER_HOME_SEED:/seed:ro"); fi
docker run --rm --entrypoint /bin/bash -v "$here/gradle-app:/gradle-app:ro" ${seed[@]+"${seed[@]}"} "$image" -ec '
fixture=$(mktemp -d)
export APP_ROOT="$fixture/repo" GRADLE_USER_HOME="$fixture/repo/.wodby-workspace/gradle"
cp -R /gradle-app "$APP_ROOT"
cd "$APP_ROOT"
git init -q
git add -A
if [ -d /seed ]; then
 mkdir -p "$GRADLE_USER_HOME/caches"
 cp -R /seed/wrapper "$GRADLE_USER_HOME/wrapper"
 cp -R /seed/caches/modules-2 "$GRADLE_USER_HOME/caches/modules-2"
fi
# Outside a workspace, java-build runs assemble and the jar is compressed.
java-build "$fixture/one-off.jar"
test -d build/distributions
unzip -v "$fixture/one-off.jar" | grep -q " Defl:"
test "$(JAVA_APP_JAR="$fixture/one-off.jar" java-app)" = before
echo "gradle: a one-off build ran assemble"
rm -rf build

# In a workspace, only the Shadow jar is built, it is stored without compression, and
# no Kotlin daemon runs next to the Gradle daemon.
test "$(WORKSPACE_JAVA_WATCH=0 workspace-java start)" = before
test -f build/libs/workspace.jar
test ! -e build/libs/workspace-plain.jar
test ! -e build/distributions
test ! -e build/scripts
unzip -v .wodby-workspace/app.jar | grep -q " Stored "
if unzip -v .wodby-workspace/app.jar | grep -q " Defl:"; then echo "the workspace jar is compressed" >&2; exit 1; fi
# ps cuts long command lines, so the main classes are read from /proc.
running() { cat /proc/[0-9]*/cmdline 2>/dev/null | tr "\0" "\n" | grep -qx "$1"; }
running org.gradle.launcher.daemon.bootstrap.GradleDaemon
if running org.jetbrains.kotlin.daemon.KotlinCompileDaemon; then echo "a Kotlin daemon runs next to Gradle" >&2; exit 1; fi
echo "gradle: a workspace build made only the runnable jar, uncompressed, without a Kotlin daemon"

# A jar named by JAVA_BUILD_JAR may come from any task, so the workspace builds assemble.
rm -rf build
JAVA_GRADLE_WORKSPACE=1 JAVA_BUILD_JAR=build/libs/workspace.jar java-build "$fixture/named.jar"
test -d build/distributions
test "$(JAVA_APP_JAR="$fixture/named.jar" java-app)" = before
echo "gradle: a workspace build with JAVA_BUILD_JAR ran assemble"
'
