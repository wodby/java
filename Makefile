-include env_make

JAVA_VER ?= 25.0.5
JAVA_VER_MAJOR := $(shell v='$(JAVA_VER)'; echo "$${v%%.*}")

REPO = wodby/java
NAME = java-$(JAVA_VER_MAJOR)

PLATFORM ?= linux/arm64

ifeq ($(WODBY_USER_ID),)
    WODBY_USER_ID := 1000
endif

ifeq ($(WODBY_GROUP_ID),)
    WODBY_GROUP_ID := 1000
endif

ifeq ($(TAG),)
	ifneq ($(JAVA_DEV),)
		ifeq ($(WODBY_USER_ID),501)
			TAG := $(JAVA_VER_MAJOR)-dev-macos
			NAME := $(NAME)-dev-macos
		else
			TAG := $(JAVA_VER_MAJOR)-dev
			NAME := $(NAME)-dev
		endif
	else
		TAG := $(JAVA_VER_MAJOR)
	endif
endif

IMAGETOOLS_TAG ?= $(TAG)

ifneq ($(ARCH),)
	override TAG := $(TAG)-$(ARCH)
endif

.PHONY: build buildx-build buildx-push test push shell run start stop logs clean release buildx-imagetools-create

# Resolve the same pinned base image for every local and CI build target.
include base-images.mk
# Temurin tags carry the build number after the Java version.
BASE_IMAGE_TAG = $(JAVA_VER)_$(TEMURIN_BUILD_$(JAVA_VER))-jdk-alpine

default: build

build:
	docker build --build-arg BASE_IMAGE="$(BASE_IMAGE)" -t $(REPO):$(TAG) \
		--build-arg JAVA_DEV=$(JAVA_DEV) \
		--build-arg WODBY_GROUP_ID=$(WODBY_GROUP_ID) \
		--build-arg WODBY_USER_ID=$(WODBY_USER_ID) \
		./

buildx-build:
	docker buildx build --build-arg BASE_IMAGE="$(BASE_IMAGE)" --platform $(PLATFORM) -t $(REPO):$(TAG) \
		--build-arg JAVA_DEV=$(JAVA_DEV) \
		--build-arg WODBY_GROUP_ID=$(WODBY_GROUP_ID) \
		--build-arg WODBY_USER_ID=$(WODBY_USER_ID) \
		--load \
		./

buildx-push:
	docker buildx build --build-arg BASE_IMAGE="$(BASE_IMAGE)" --platform $(PLATFORM) --push -t $(REPO):$(TAG) \
		--build-arg JAVA_DEV=$(JAVA_DEV) \
		--build-arg WODBY_GROUP_ID=$(WODBY_GROUP_ID) \
		--build-arg WODBY_USER_ID=$(WODBY_USER_ID) \
		./

buildx-imagetools-create:
	docker buildx imagetools create -t $(REPO):$(IMAGETOOLS_TAG) \
				  $(REPO):$(TAG)-amd64 \
				  $(REPO):$(TAG)-arm64

test:
	cd ./tests && IMAGE=$(REPO):$(TAG) bash ./workspace-contract.sh
ifneq ($(JAVA_DEV),)
	cd ./tests && JAVA_IMAGE=$(REPO):$(TAG) ./run.sh
	cd ./tests && IMAGE=$(REPO):$(TAG) bash ./workspace-reload.sh
	cd ./tests && IMAGE=$(REPO):$(TAG) bash ./workspace-gradle.sh
else
	@echo "We run tests only for DEV images."
endif

push:
	docker push $(REPO):$(TAG)

shell:
	docker run --rm --name $(NAME) -i -t $(PORTS) $(VOLUMES) $(ENV) $(REPO):$(TAG) /bin/bash

run:
	docker run --rm --name $(NAME) $(PORTS) $(VOLUMES) $(ENV) $(REPO):$(TAG) $(CMD)

start:
	docker run -d --name $(NAME) $(PORTS) $(VOLUMES) $(ENV) $(REPO):$(TAG)

stop:
	docker stop $(NAME)

logs:
	docker logs $(NAME)

clean:
ifneq ($(JAVA_DEV),)
	cd ./tests && JAVA_IMAGE=$(REPO):$(TAG) docker compose down -v
endif
	-docker rm -f $(NAME)

release: build push

# Keep CI scans aligned with the version, variant and architecture built by make.
.PHONY: image-ref
image-ref:
	@printf '%s\n' '$(REPO):$(TAG)'
