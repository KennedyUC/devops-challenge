SHELL := /bin/bash
CWD:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

DOCKER_USERNAME ?= default
DOCKER_PASSWORD ?= default
TAG ?= v1.0.0
ENV ?= dev
APP_NAMESPACE := $(ENV)-platform

.PHONY: docker-login
docker-login:
	@echo 'Authenticating to Docker Registry ===============>'
	@echo $(DOCKER_PASSWORD) | docker login --username $(DOCKER_USERNAME) --password-stdin

.PHONY: docker-login-local
docker-login-local:
	@echo 'Authenticating to Docker Registry ===============>'
	@cat $(CWD)/.env/docker-login.txt | docker login --username $(DOCKER_USERNAME) --password-stdin

.PHONY: skaffold-build
skaffold-build:
	@echo 'Updating the nginx.conf file with the correct API url ==============>'
	@echo 'Building Project Container Images for the $(ENV) Environment with tag=$(TAG)'
	@skaffold build  --platform linux/amd64 --default-repo=$(DOCKER_USERNAME) --push --tag $(ENV)-$(TAG)

.PHONY: deploy-apps
deploy-apps:
	@kubectl create namespace $(APP_NAMESPACE) 2>/dev/null || echo "Namespace $(APP_NAMESPACE) already exists"
	@pushd "kubernetes/application/overlays/$(ENV)"; yq e -i '.spec.template.spec.containers[0].image = "$(DOCKER_USERNAME)/flask-api:$(ENV)-$(TAG)"' api_deployment_patch.yaml; popd
	@pushd "kubernetes/application/overlays/$(ENV)"; yq e -i '.spec.template.spec.containers[0].image = "$(DOCKER_USERNAME)/vue-web:$(ENV)-$(TAG)"' web_deployment_patch.yaml; popd
	@pushd "kubernetes/application/overlays/$(ENV)"; yq e -i '.data.PROXY_PASS = "http://api-service.$(APP_NAMESPACE).svc:5000"' web_config_patch.yaml; popd
	@echo 'Deploying the applications to k8s cluster in the $(APP_NAMESPACE) namespace ==============>'
	@pushd "kubernetes/application"; kustomize build overlays/$(ENV) | kubectl -n $(APP_NAMESPACE) apply -f -; popd

.PHONY: setup-monitoring
setup-monitoring:
	@echo 'Updating the API service monitor file with the correct Namespace ==============>'
	@pushd "kubernetes/monitoring/overlays"; yq e -i '.spec.namespaceSelector.matchNames[0] = "$(APP_NAMESPACE)"' api-service-monitor-patch.yaml; popd
	@echo 'Deploying the monitoring setup to k8s cluster ==============>'
	@kubectl create namespace monitoring 2>/dev/null || echo "Namespace monitoring already exists"
	@pushd "kubernetes"; while ! kustomize build monitoring | kubectl apply --server-side -f -; do echo "Retrying to apply resources"; sleep 10; done; popd

.PHONY: run-app
run-app:
	@kubectl -n $(APP_NAMESPACE) port-forward svc/api-service 5000 >/dev/null 2>&1 &
	@echo 'Open http://localhost:8080 on your browser to access the UI'
	@echo 'Terminate the session using CTRL + C'
	@kubectl -n $(APP_NAMESPACE) port-forward svc/web-service 8080:80

.PHONY: cleanup
cleanup:
	@pushd "kubernetes/application"; kustomize build base | kubectl -n $(APP_NAMESPACE) delete -f -; popd
	@pushd "kubernetes"; kustomize build monitoring | kubectl delete -f -; popd