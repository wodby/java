# Java Docker Container Images

[![Build Status](https://github.com/wodby/java/workflows/Build%20docker%20image/badge.svg)](https://github.com/wodby/java/actions)
[![Docker Pulls](https://img.shields.io/docker/pulls/wodby/java.svg)](https://hub.docker.com/r/wodby/java)
[![Docker Stars](https://img.shields.io/docker/stars/wodby/java.svg)](https://hub.docker.com/r/wodby/java)

## Table of Contents

- [Docker Images](#docker-images)
    - [`-dev`](#-dev)
    - [Supported architectures](#supported-architectures)
- [Environment Variables](#environment-variables)
- [Build arguments](#build-arguments)
- [Tools](#tools)
- [Building and running applications](#building-and-running-applications)
- [Development workspaces](#development-workspaces)
- [Changelog](#changelog)
- [Crond](#crond)
- [SSHD](#sshd)
- [Adding SSH key](#adding-ssh-key)
- [Orchestration Actions](#orchestration-actions)

## Docker Images

Use image revision tags such as `wodby/java:25-rN` to select a Wodby image revision.
Major tags use the repository release number, starting at `r0`. Full-version tags such as
`wodby/java:25.0.5-r0` start at `r0` for each exact upstream version.
Every published versioned revision tag has a matching annotated Git tag pointing to its release commit.
Existing tags remain available after support for their major version ends.
See [release tags](https://github.com/wodby/java/tags) for available revisions and the [image revision policy](https://github.com/wodby/images#image-revisions) for upgrade guidance.

About images:

- All images are based on Alpine Linux
- Base image: [Eclipse Temurin](https://github.com/adoptium/containers) JDK
- [GitHub actions builds](https://github.com/wodby/java/actions)
- [Docker Hub](https://hub.docker.com/r/wodby/java)

Supported tags and respective `Dockerfile` links:

- `25`, `latest` [_(Dockerfile)_]
- `21` [_(Dockerfile)_]
- `25-dev`, `dev` [_(Dockerfile)_]
- `21-dev` [_(Dockerfile)_]

[_(Dockerfile)_]: https://github.com/wodby/java/tree/master/Dockerfile

### `-dev`

Images with `-dev` tag have `sudo` allowed for all commands for the `wodby` user, include `ripgrep` and `jq`, and declare the Wodby development workspace contract.

### Supported architectures

All images are built for `linux/amd64` and `linux/arm64`.

## Environment Variables

| Variable                          | Default value                 |
|-----------------------------------|-------------------------------|
| `APP_ROOT`                        | `/usr/src/app`                |
| `FILES_DIR`                       | `/mnt/files`                  |
| `GIT_USER_EMAIL`                  | `wodby@example.com`           |
| `GIT_USER_NAME`                   | `wodby`                       |
| `JAVA_APP_JAR`                    | `/home/wodby/app.jar`         |
| `JAVA_BUILD_ARGS`                 |                               |
| `JAVA_BUILD_COMMAND`              |                               |
| `JAVA_BUILD_JAR`                  |                               |
| `JAVA_OPTS`                       | `-XX:MaxRAMPercentage=75.0`   |
| `JAVA_READY_PATH`                 |                               |
| `MAVEN_HOME`                      | `/opt/maven`                  |
| `SSH_DISABLE_STRICT_KEY_CHECKING` |                               |
| `SSH_PRIVATE_KEY`                 |                               |
| `SSHD_GATEWAY_PORTS`              | `no`                          |
| `SSHD_HOST_KEYS_DIR`              | `/etc/ssh`                    |
| `SSHD_LOG_LEVEL`                  | `INFO`                        |
| `SSHD_PASSWORD_AUTHENTICATION`    | `no`                          |
| `SSHD_PERMIT_USER_ENV`            | `no`                          |
| `SSHD_USE_DNS`                    | `yes`                         |

## Build arguments

| Argument         | Default value |
|------------------|---------------|
| `JAVA_DEV`       |               |
| `MAVEN_VER`      | `3.10.0`      |
| `WODBY_GROUP_ID` | `1000`        |
| `WODBY_USER_ID`  | `1000`        |

Change `WODBY_USER_ID` and `WODBY_GROUP_ID` to build an image whose `wodby` user matches the owner of mounted files. If either value matches an existing system user/group id, the existing user/group will be deleted before creating the `wodby` user.

## Tools

| Tool         | all versions |
|--------------|--------------|
| JDK          | Eclipse Temurin, from the upstream `eclipse-temurin` image |
| Maven        | `3.10.0`, verified against its published SHA-512 |
| make         | latest Alpine package |
| git          | latest Alpine package |

Gradle is not installed: Gradle projects build with their own wrapper (`gradlew`).

## Building and running applications

`java-build <jar>` builds the project in `APP_ROOT` and copies its runnable jar to `<jar>`:

- Maven projects (`pom.xml`) build with `mvnw` when present, or else with the image's Maven: `package` with `-Dmaven.test.skip=true`. The jar comes from `target/`.
- Gradle projects (`build.gradle` or `build.gradle.kts`) build with `gradlew assemble`. The jar comes from `build/libs/`.
- Jars ending in `-sources`, `-javadoc`, `-tests` or `-plain`, and Maven's `original-*.jar`, are not counted. When more than one jar remains, `JAVA_BUILD_JAR` names the one to copy, relative to `APP_ROOT`.
- `JAVA_BUILD_COMMAND` replaces the build command; `JAVA_BUILD_ARGS` adds arguments to Maven or Gradle.

`java-app` runs `java $JAVA_OPTS -jar $JAVA_APP_JAR` and is the default command. `java-ready` checks that the application answers HTTP on port 8080: any status below 500 at `/`, or 200 at `JAVA_READY_PATH` when it is set. `make check-ready` uses it.

## Development workspaces

`-dev` images implement the Wodby development workspace contract with `workspace-java`:

- `workspace-java prepare` downloads dependencies (`mvn dependency:go-offline` or `gradlew dependencies`); code that does not compile yet does not fail it.
- `workspace-java start` builds the checkout with `java-build`, runs the jar from `.wodby-workspace/app.jar`, and polls the checkout: when a file changes, it builds again and restarts the application in the same container. A failed build keeps the previous build running, and a failed first build waits for a change.
- Gradle rebuilds in the workspace are set up for speed: the Gradle daemon is kept, Kotlin compiles inside it instead of in a Kotlin daemon of its own, only the runnable jar is built (`bootJar` with Spring Boot, `shadowJar` with Shadow, `assemble` otherwise, and always `assemble` when `JAVA_BUILD_JAR` is set), and the jar is written without compression. Projects with large Kotlin sources may need more memory for the Gradle daemon (`org.gradle.jvmargs` in `gradle.properties`).
- Maven's repository, the Maven wrapper's downloads and Gradle's home are kept in `.wodby-workspace/`, so a container restart downloads nothing again. A `-Dmaven.repo.local` in `MAVEN_OPTS` or a `GRADLE_USER_HOME` that is already set is kept.
- `WORKSPACE_JAVA_WATCH=0` turns watching off, `WORKSPACE_JAVA_COMMAND` replaces the start command, and `WORKSPACE_POLL_INTERVAL` sets the polling interval in milliseconds (default `1000`).

## Changelog

For changes in each image revision, see the [release notes](https://github.com/wodby/java/releases).

## Crond

You can run Crond with this image by changing the command to `sudo -E crond -f -d 0` and mounting a crontab file to `./crontab:/etc/crontabs/wodby`. Example crontab file contents:

```
# min	hour	day	month	weekday	command
*/1	*	*	*	*	echo "test" > /mnt/files/cron
```

## SSHD

You can run SSHD with this image by changing the command to `sudo /usr/sbin/sshd -De` and mounting authorized public keys to `/home/wodby/.ssh/authorized_keys`.

## Adding SSH key

You can add a private SSH key to the container by mounting it to `/home/wodby/.ssh/id_rsa`.


## Complete Spring Boot stack

See https://github.com/wodby/stack-spring-boot

## Orchestration Actions

Usage:

```
make COMMAND [params ...]

commands:
    check-ready [host max_try wait_seconds delay_seconds]
    files-import source
    files-link public_dir
```

## Building with pinned base images

Build with the Makefile to use the base image digests in `base-images.mk`. Local
builds and CI resolve the same version and variant to the same multi-platform
image. A version without a pin fails before the build starts. Temurin image tags
carry a build number after the Java version (`25.0.5_8-jdk-alpine`), so
`base-images.mk` also records the build number of each version as `TEMURIN_BUILD_<version>`.

When adding a supported base version, add its build number and its image index
digest to `base-images.mk`. For a custom build, override `BASE_IMAGE` with a
complete `repository:tag@sha256:...` reference.

### Development workspace contract

Development variants declare `com.wodby.workspace.contract=1`. Configuration-only
startup (`/docker-entrypoint.sh --configure-runtime`) does not rewrite developer
SSH/Git settings, initialize shared storage, or run application hooks. Normal
startup retains its existing behavior. `WODBY_WORKSPACE=1` selects the workspace
startup command. Login-shell tools remain available when the developer home is mounted,
and Maven and Gradle in a login shell use the dependencies kept in `.wodby-workspace/`.

Files are polled because file events don't reach a shared volume. Git's own files,
`.wodby-workspace`, build output and build state (`target`, `build`, `.gradle`, `.kotlin`), `node_modules`, `.idea`
and `.vscode` are not watched. The directory `.wodby-workspace` is excluded through
`.git/info/exclude` without editing `.gitignore`; a tracked directory or symlink at
that reserved path is refused.

CI checks labels for all image variants and runs configuration, developer-state,
reserved-path, runtime, reload and Gradle workspace build tests for development variants.
