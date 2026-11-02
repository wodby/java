# Base image inputs shared by local builds and CI. Updated by wodby/images.
# Each digest identifies the complete multi-platform image index.
BASE_IMAGE_REPOSITORY := eclipse-temurin
BASE_IMAGE_VERSION_SUFFIX := -jdk-alpine

# Temurin build number of each Java version.
TEMURIN_BUILD_25.0.5 := 8
TEMURIN_BUILD_21.0.13 := 9

BASE_IMAGE_DIGEST_21.0.13_9-jdk-alpine := sha256:b78a1d385da875588e21207f07dddf9a1418849971ae857fb24c8f3a7d441a72
BASE_IMAGE_DIGEST_25.0.5_8-jdk-alpine := sha256:425f0b733cb23843bd78dbe5552513976d0cf12b9722752c48a5161cf5cd2f32

# Fail before building when a version or variant has no reviewed pin.
BASE_IMAGE = $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG)@$(or $(BASE_IMAGE_DIGEST_$(BASE_IMAGE_TAG)),$(error No base image digest for $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG); update base-images.mk))
