NS ?= juspaydotin
VERSION ?= v1.0.4
IMAGE_NAME ?= hyperswitch-web
BRANCH_NAME ?= $(shell git rev-parse --abbrev-ref HEAD)
CONTAINER_NAME ?= hyperswitch-web
CONTAINER_INSTANCE ?= default
SOURCE_COMMIT := $(shell git rev-parse HEAD)
RUN_TEST ?= false
.PHONY: build push shell run start stop rm release
build: Dockerfile
	$(info Building $(NS)/$(IMAGE_NAME):$(VERSION) / git-head: $(SOURCE_COMMIT))
	$(info git branch is $(BRANCH_NAME))
	# cp -R ~/.ssh .
	docker build --platform=linux/amd64 -t $(IMAGE_NAME):$(VERSION) -f Dockerfile .
# aws-auth:
# 	aws ecr get-login-password --region $(REGION) | docker login --username AWS --password-stdin $(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com
push:
	docker tag $(IMAGE_NAME):$(VERSION) $(NS)/$(IMAGE_NAME):$(VERSION)
	docker push $(NS)/$(IMAGE_NAME):$(VERSION)