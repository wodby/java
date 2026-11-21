# Base image inputs shared by local builds and CI. Updated by wodby/images.
# Each digest identifies the complete multi-platform image index.
BASE_IMAGE_REPOSITORY := eclipse-temurin
BASE_IMAGE_VERSION_SUFFIX := -jdk-alpine

# Temurin build number of each Java version.
TEMURIN_BUILD_25.0.5.1 := 2
TEMURIN_BUILD_21.0.13.1 := 2

BASE_IMAGE_DIGEST_21.0.13.1_2-jdk-alpine := sha256:c07bb82e004a166b5d3d63b84ad70e2e822f228505e2e0c0b8dfdc2890d22f13
BASE_IMAGE_DIGEST_25.0.5.1_2-jdk-alpine := sha256:22edbb1021420ae6e248519d1af07577742314d67d4c60fcbb2e285b7e47fa78

# Fail before building when a version or variant has no reviewed pin.
BASE_IMAGE = $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG)@$(or $(BASE_IMAGE_DIGEST_$(BASE_IMAGE_TAG)),$(error No base image digest for $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG); update base-images.mk))
