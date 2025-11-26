SHELL := /bin/bash

TAG_PREFIX ?= $(shell git describe --always --dirty --abbrev=12)

IMAGE_NAME ?= wk88/timezone-alias-utils
BASE_TAG := $(TAG_PREFIX)-base

define build_images
	$(1) --file base.Dockerfile \
	  --build-arg WITH_TEST_TZ=$(WITH_BASE_TEST_TZ) \
	  --tag $(IMAGE_NAME):$(BASE_TAG) . \
  && for dir in flavors/*; do \
		if [ -f $$dir/Dockerfile ]; then \
			name=$$(basename $$dir) \
			 && image="$(IMAGE_NAME):$(TAG_PREFIX)-$$name" \
			 && echo "~~~ Building flavor $$name to $$image ~~~" \
			 && $(1) \
				--file $$dir/Dockerfile \
				--build-arg BASE_NAME=$(IMAGE_NAME) \
				--build-arg BASE_TAG=$(BASE_TAG) \
				--tag $$image \
				$$dir \
			 && continue; \
			 echo "Failed to build flavor $$dir"; \
			 exit 1; \
		fi; \
	done
endef

# single-arch (local) build
.PHONY: build
build:
	$(call build_images,docker build)

# multi-arch build + push
.PHONY: push
push:
	$(call build_images,docker buildx build --platform linux/amd64,linux/arm64 --push)

activate: venv
	@ [ -f activate ] || (ln -s venv/bin/activate . && $(MAKE) requirements)

requirements: activate
	. activate && venv/bin/pip install -r requirements.dev

venv:
	@ [ -d venv ] || python3 -m venv venv

.PHONY: freeze
freeze: activate
	. activate && venv/bin/pip freeze > requirements.dev

.PHONY: test
test: activate
	. activate && pytest --capture=no

.PHONY: pep8
pep8: activate
	. activate && pycodestyle *.py --max-line-length=120
