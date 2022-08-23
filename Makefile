IMAGE_NAME := aaw-dev-docs:0.1.0

.DEFAULT_GOAL := create

create: build
	./create_diagrams.sh

build: Dockerfile
	docker build . -t $(IMAGE_NAME)