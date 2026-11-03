# check=skip=InvalidDefaultArgInFrom

# The Makefile supplies the required digest-pinned BASE_IMAGE argument.
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

ARG JAVA_DEV
LABEL com.wodby.workspace.contract="${JAVA_DEV:+1}"

ARG WODBY_USER_ID=1000
ARG WODBY_GROUP_ID=1000

# Maven is installed from Maven Central and checked against its published SHA-512.
ARG MAVEN_VER=3.10.0
ARG MAVEN_SHA512=908b1501bfb420bf7c8affb855534a9c407fd6099367bfb9f2f2dcb8e9799102bffb84518cde74c679bd76870247c6528683abdd620581bffa90f95d92d175aa

ENV JAVA_DEV="${JAVA_DEV}" \
    SSHD_PERMIT_USER_ENV="yes"

ENV APP_ROOT="/usr/src/app" \
    CONF_DIR="/usr/src/conf" \
    FILES_DIR="/mnt/files" \
    SSHD_HOST_KEYS_DIR="/etc/ssh" \
    ENV="/home/wodby/.shrc" \
    MAVEN_HOME="/opt/maven" \
    JAVA_APP_JAR="/home/wodby/app.jar" \
    JAVA_OPTS="-XX:MaxRAMPercentage=75.0" \
    \
    GIT_USER_EMAIL="wodby@example.com" \
    GIT_USER_NAME="wodby"

ENV PATH="${MAVEN_HOME}/bin:${PATH}"

ARG TARGETPLATFORM

# Upgrade inherited packages even when their existing versions satisfy dependencies.
RUN set -xe; \
    apk upgrade --no-cache; \
    \
    # Delete existing user/group if uid/gid occupied. \
    existing_group=$(getent group "${WODBY_GROUP_ID}" | cut -d: -f1); \
    if [ -n "${existing_group}" ]; then delgroup "${existing_group}"; fi; \
    existing_user=$(getent passwd "${WODBY_USER_ID}" | cut -d: -f1); \
    if [ -n "${existing_user}" ]; then deluser "${existing_user}"; fi; \
    \
    addgroup -g "${WODBY_GROUP_ID}" -S wodby; \
    adduser -u "${WODBY_USER_ID}" -D -S -s /bin/bash -G wodby wodby; \
    sed -i '/^wodby/s/!/*/' /etc/shadow; \
    \
    apk add --update --no-cache -t .wodby-java-run-deps \
        bash \
        ca-certificates \
        curl \
        git \
        gzip \
        less \
        make \
        mariadb-client \
        nano \
        openssh \
        openssh-client \
        patch \
        postgresql-client \
        rsync \
        su-exec \
        sudo \
        tar \
        tig \
        tmux \
        tzdata \
        unzip \
        wget \
        yaml; \
    \
    if [ -n "${JAVA_DEV}" ]; then \
        apk add --no-cache ripgrep jq; \
    fi; \
    \
    # Install Maven. \
    wget -qO /tmp/maven.tar.gz "https://repo1.maven.org/maven2/org/apache/maven/apache-maven/${MAVEN_VER}/apache-maven-${MAVEN_VER}-bin.tar.gz"; \
    echo "${MAVEN_SHA512}  /tmp/maven.tar.gz" | sha512sum -c -; \
    mkdir -p "${MAVEN_HOME}"; \
    tar xzf /tmp/maven.tar.gz --strip-components=1 --no-same-owner -C "${MAVEN_HOME}"; \
    mvn --version; \
    \
    # Download helper scripts. \
    dockerplatform=${TARGETPLATFORM:-linux/amd64}; \
    gotpl_url="https://github.com/wodby/gotpl/releases/latest/download/gotpl-${dockerplatform/\//-}.tar.gz"; \
    wget -qO- "${gotpl_url}" | tar xz --no-same-owner -C /usr/local/bin; \
    git clone https://github.com/wodby/alpine /tmp/alpine; \
    cd /tmp/alpine; \
    latest=$(git describe --abbrev=0 --tags); \
    git checkout "${latest}"; \
    mv /tmp/alpine/bin/* /usr/local/bin; \
    \
    # Install redis-cli. \
    apk add --update --no-cache redis; \
    mv /usr/bin/redis-cli /tmp/; \
    apk del --purge redis; \
    deluser redis; \
    mv /tmp/redis-cli /usr/bin; \
    \
    install -o wodby -g wodby -d \
        "${APP_ROOT}" \
        "${CONF_DIR}" \
        "${FILES_DIR}/public" \
        "${FILES_DIR}/private" \
        /home/wodby/.m2 \
        /home/wodby/.gradle \
        /home/wodby/.ssh; \
    \
    { \
        echo 'export PS1="\u@$(hostname):\w $ "'; \
        echo "export PATH=${PATH}"; \
    } | tee /home/wodby/.shrc; \
    \
    cp /home/wodby/.shrc /home/wodby/.bashrc; \
    cp /home/wodby/.shrc /home/wodby/.bash_profile; \
    \
    # Configure sudoers. \
    { \
        echo "Defaults secure_path=\"$PATH\""; \
        echo 'Defaults env_keep += "APP_ROOT FILES_DIR JAVA_HOME MAVEN_HOME"'; \
        \
        if [ -n "${JAVA_DEV}" ]; then \
            echo 'wodby ALL=(root) NOPASSWD:SETENV:ALL'; \
        else \
            echo -n 'wodby ALL=(root) NOPASSWD:SETENV: '; \
            echo -n '/usr/local/bin/gen_ssh_keys, '; \
            echo -n '/usr/local/bin/init_container, '; \
            echo -n '/usr/sbin/sshd, '; \
            echo '/usr/sbin/crond'; \
        fi; \
    } | tee /etc/sudoers.d/wodby; \
    \
    touch /etc/ssh/sshd_config; \
    chown wodby:wodby /etc/ssh/sshd_config /home/wodby/.*; \
    \
    rm -rf \
        /etc/crontabs/root \
        /tmp/* \
        /var/cache/apk/*

USER wodby

WORKDIR ${APP_ROOT}
EXPOSE 8080

COPY templates /etc/gotpl/
COPY docker-entrypoint.sh /
COPY bin /usr/local/bin/
COPY share /usr/local/share/wodby/

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["java-app"]

COPY workspace-profile.sh /etc/profile.d/workspace.sh
