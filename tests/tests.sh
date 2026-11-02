#!/usr/bin/env bash

set -e

if [[ -n "${DEBUG}" ]]; then
    set -x
fi

source /home/wodby/.shrc
expected_prompt='\u@'"$(hostname)"':\w $ '
if [[ "${PS1}" != "${expected_prompt}" ]]; then
    echo "Unexpected shell prompt: ${PS1}"
    exit 1
fi

# The base image names the JDK as jdk-<version>+<build>.
java_version="${JAVA_VERSION#jdk-}"
java -version 2>&1 | grep -q "version \"${java_version%%+*}\""
mvn --version | grep -q "Apache Maven"

ssh sshd cat /home/wodby/.ssh/authorized_keys | grep -q admin@example.com

curl -s nginx | grep -q "Java test app"
curl -s localhost:8080 | grep -q "Java test app"
