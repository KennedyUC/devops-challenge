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

.PHONY: install-ingress
install-ingress:
	if kubectl get deployment -n ingress-nginx ingress-nginx-controller &> /dev/null; then
    	echo "Ingress controller already exists, skipping installation."
	else
		echo 'Installing Nginx Ingress Controller'
		kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.5.1/deploy/static/provider/cloud/deploy.yaml

.PHONY: deploy-apps
deploy-apps:
	@echo 'Deploying the applications to k8s cluster ==============>'
	@kubectl apply -f kubernetes

.PHONY: run-app
run-app:
	@kubectl port-forward svc/api-service 5000 >/dev/null 2>&1 &
	@echo 'Open http://localhost:8081 on your browser to access the UI'
	@echo 'Terminate the session using CTRL + C'
	@kubectl port-forward svc/web-service 8080:80

.PHONY: cleanup
cleanup:
	@kubectl delete -f kubernetes