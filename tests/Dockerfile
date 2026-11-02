ARG JAVA_IMAGE=wodby/java:25-dev

FROM $JAVA_IMAGE

COPY --chown=wodby:wodby app .

RUN java-build "${JAVA_APP_JAR}"
