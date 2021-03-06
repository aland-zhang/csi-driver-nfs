# Copyright 2017 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
CMDS=nfsplugin
DEPLOY_FOLDER = ./deploy/kubernetes
CMDS=nfsplugin
PKG = github.com/kubernetes-csi/csi-driver-nfs
IMAGE_VERSION ?= v0.5.0
LDFLAGS ?= "-X ${PKG}/pkg/nfs.driverVersion=${IMAGE_VERSION} -X -s -w -extldflags '-static'"
IMAGE_NAME ?= nfsplugin
REGISTRY ?= andyzhangx
IMAGE_TAG = $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_VERSION)
GINKGO_FLAGS = -ginkgo.v
all: build

include release-tools/build.make

.PHONY: sanity-test
sanity-test: build
	./test/sanity/run-test.sh

.PHONY: local-build-push
local-build-push: build
	docker build -t $(LOCAL_USER)/nfsplugin:latest .
	docker push $(LOCAL_USER)/nfsplugin

.PHONY: local-k8s-install
local-k8s-install:
	echo "Instlling locally"
	kubectl apply -f $(DEPLOY_FOLDER)/rbac-csi-nfs-controller.yaml
	kubectl apply -f $(DEPLOY_FOLDER)/csi-nfs-driverinfo.yaml
	kubectl apply -f $(DEPLOY_FOLDER)/csi-nfs-controller.yaml
	kubectl apply -f $(DEPLOY_FOLDER)/csi-nfs-node.yaml
	echo "Successfully installed"

.PHONY: local-k8s-uninstall
local-k8s-uninstall:
	echo "Uninstalling driver"
	kubectl delete -f $(DEPLOY_FOLDER)/csi-nfs-controller.yaml --ignore-not-found
	kubectl delete -f $(DEPLOY_FOLDER)/csi-nfs-node.yaml --ignore-not-found
	kubectl delete -f $(DEPLOY_FOLDER)/csi-nfs-driverinfo.yaml --ignore-not-found
	kubectl delete -f $(DEPLOY_FOLDER)/rbac-csi-nfs-controller.yaml --ignore-not-found
	echo "Uninstalled NFS driver"

.PHONY: nfs
nfs:
	CGO_ENABLED=0 GOOS=linux go build -a -ldflags ${LDFLAGS} -o _output/nfsplugin ./cmd/nfsplugin

.PHONY: install-nfs-server
install-nfs-server:
	kubectl apply -f ./examples/kubernetes/nfs-server/nfs-server.yaml

.PHONY: install-helm
install-helm:
	curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

.PHONY: e2e-bootstrap
e2e-bootstrap: install-helm
	helm install -n csi-driver-nfs ./charts/csi-driver-nfs --namespace kube-system --wait --timeout=15m -v=5 --debug \
	--set image.nfs.repository=$(REGISTRY)/$(IMAGE_NAME) \
	--set image.nfs.tag=$(IMAGE_VERSION)

.PHONY: e2e-teardown
e2e-teardown:
	helm delete csi-driver-nfs --namespace kube-system

.PHONY: e2e-test
e2e-test:
	go test -v -timeout=0 ./test/e2e ${GINKGO_FLAGS}