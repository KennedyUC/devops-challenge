SHELL := /bin/bash
CWD:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

DOCKER_USERNAME ?= default
DOCKER_PASSWORD ?= default
TAG ?= latest
ENV ?= dev

.PHONY: docker-login
docker-login:
	@echo 'Authenticating to Docker Registry ===============>'
	@echo $(DOCKER_PASSWORD) | docker login --username $(DOCKER_USERNAME) --password-stdin

.PHONY: skaffold-build
skaffold-build:
	@echo 'Building Project Container Images for the $(ENV) Environment with tag=$(TAG)'
	@skaffold build  --platform linux/amd64 --default-repo=$(DOCKER_USERNAME) --push --tag $(ENV)-$(TAG)

.PHONY: deploy-apps
deploy-apps:
	@echo 'Deploying the applications to k8s cluster ==============>'
	@pushd "kubernetes"; kustomize build application | kubectl apply -f -; popd

.PHONY: setup-monitoring
setup-monitoring:
	@echo 'Deploying the monitoring setup to k8s cluster ==============>'
	@pushd "kubernetes"; kustomize build monitoring | kubectl apply -f -; popd

.PHONY: run-app
run-app:
	@kubectl port-forward svc/api-service 5000 >/dev/null 2>&1 &
	@echo 'Open http://localhost:8081 on your browser to access the UI'
	@echo 'Terminate the session using CTRL + C'
	@kubectl port-forward svc/web-service 8080:80

.PHONY: cleanup
cleanup:
	@kubectl delete -f kubernetes