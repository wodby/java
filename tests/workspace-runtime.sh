#!/usr/bin/env bash
# Run inside the image with the normal entrypoint bypassed. Maven needs network access.
set -euo pipefail
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/repo" "$fixture/home/.ssh"
export APP_ROOT="$fixture/repo" HOME="$fixture/home"
printf 'Host saved\n' > "$HOME/.ssh/config"
printf '[user]\n  name = Developer\n' > "$HOME/.gitconfig"
cp "$HOME/.ssh/config" "$fixture/ssh.expected"
cp "$HOME/.gitconfig" "$fixture/git.expected"
# Configuration succeeds repeatedly without running storage/init or identity setup.
/docker-entrypoint.sh --configure-runtime
/docker-entrypoint.sh --configure-runtime
cmp "$HOME/.ssh/config" "$fixture/ssh.expected"
cmp "$HOME/.gitconfig" "$fixture/git.expected"
bash -lc 'command -v java && command -v mvn' >/dev/null
cd "$APP_ROOT"
git init -q
printf 'tracked\n' > source.txt
git add source.txt
workspace-path > "$fixture/path"
test "$(cat "$fixture/path")" = "$APP_ROOT/.wodby-workspace"
test -z "$(git ls-files --others --exclude-standard)"
# A tracked collision is refused, even when local exclude rules hide new files.
printf collision > .wodby-workspace/collision
git add -f .wodby-workspace/collision
if workspace-path; then echo 'accepted tracked runtime storage' >&2; exit 1; fi
git rm -q --cached .wodby-workspace/collision
rm .wodby-workspace/collision
# A checkout without a build file is refused.
if workspace-java prepare; then echo 'prepared a checkout without a build file' >&2; exit 1; fi
# A real build proves the build file is unchanged and startup rebuilds.
mkdir -p src/main/java/test
cat > pom.xml <<'POM'
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>test</groupId>
  <artifactId>workspace</artifactId>
  <version>1.0</version>
  <properties>
    <maven.compiler.release>21</maven.compiler.release>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
  </properties>
  <build>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-jar-plugin</artifactId>
        <version>3.5.1</version>
        <configuration>
          <archive><manifest><mainClass>test.Main</mainClass></manifest></archive>
        </configuration>
      </plugin>
    </plugins>
  </build>
</project>
POM
printf 'package test;\npublic class Main { public static void main(String[] a) { System.out.print("before"); } }\n' > src/main/java/test/Main.java
cp pom.xml "$fixture/pom.expected"
# Code that does not compile does not fail preparation.
printf 'package test;\nclass Broken {\n' > src/main/java/test/Broken.java
workspace-java prepare
rm src/main/java/test/Broken.java
test "$(WORKSPACE_JAVA_WATCH=0 workspace-java start)" = before
# Dependencies and the build are kept with the checkout, not in the container's
# home, which a restart discards; a custom start command gets the same locations.
state="$APP_ROOT/.wodby-workspace"
test -n "$(ls -A "$state/m2/repository")"
test -f "$state/app.jar"
test ! -e "$HOME/.m2/repository"
test "$(WORKSPACE_JAVA_COMMAND='printf "%s\n" "$MAVEN_OPTS" "$GRADLE_USER_HOME"' workspace-java start)" = "-Dmaven.repo.local=$state/m2/repository
$state/gradle"
test -z "$(git ls-files --others --exclude-standard -- .wodby-workspace)"
# Locations set to anything else stay as set.
test "$(MAVEN_OPTS="-Dmaven.repo.local=$fixture/m2" GRADLE_USER_HOME="$fixture/gradle" WORKSPACE_JAVA_COMMAND='printf "%s\n" "$MAVEN_OPTS" "$GRADLE_USER_HOME"' workspace-java start)" = "-Dmaven.repo.local=$fixture/m2
$fixture/gradle"
sed -i 's/before/after/' src/main/java/test/Main.java
test "$(WODBY_WORKSPACE=1 WORKSPACE_JAVA_WATCH=0 /docker-entrypoint.sh ignored)" = after
cmp pom.xml "$fixture/pom.expected"
# A build with several runnable jars needs JAVA_BUILD_JAR.
cp target/workspace-1.0.jar target/extra.jar
if java-build "$fixture/out.jar"; then echo 'picked one of several jars' >&2; exit 1; fi
JAVA_BUILD_JAR=target/workspace-1.0.jar java-build "$fixture/out.jar"
test "$(JAVA_APP_JAR="$fixture/out.jar" java-app)" = after
cmp "$HOME/.ssh/config" "$fixture/ssh.expected"
cmp "$HOME/.gitconfig" "$fixture/git.expected"
echo 'Workspace runtime checks passed'
