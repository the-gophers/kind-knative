GOPATH  := $(shell go env GOPATH)
GOARCH  := $(shell go env GOARCH)
GOOS    := $(shell go env GOOS)
GOPROXY := $(shell go env GOPROXY)
ifeq ($(GOPROXY),)
GOPROXY := https://proxy.golang.org
endif
export GOPROXY

ROOT_DIR        :=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
APP             = go-action
PACKAGE  		= github.com/the-gophers/$(APP)
DATE    		?= $(shell date +%FT%T%z)
VERSION 		?= $(shell git rev-list -1 HEAD)
SHORT_VERSION 	?= $(shell git rev-parse --short HEAD)
GOBIN      		?= $(HOME)/go/bin
GOFMT   		= gofmt
GO      		= go
PKGS     		= $(or $(PKG),$(shell $(GO) list ./... | grep -vE "^$(PACKAGE)/templates/"))
TOOLSBIN		= $(ROOT_DIR)/tools/bin
GO_INSTALL		= $(ROOT_DIR)/scripts/go_install.sh
KNATIVE_VERSION := 0.18.2
KOURIER_VERSION := 0.18.1
IMAGE			:= dev.local/the-gophers/knative-go
TAG				:= dev

# Active module mode, as we use go modules to manage dependencies
export GO111MODULE=on

V = 0
Q = $(if $(filter 1,$V),,@)

.PHONY: all
all: fmt lint tidy build test

## --------------------------------------
## Tooling Binaries
## --------------------------------------

GOLINT_VER := v1.31.0
GOLINT_BIN := golangci-lint
GOLINT := $(TOOLSBIN)/$(GOLINT_BIN)-$(GOLINT_VER)

$(GOLINT): ; $(info $(M) buiding $(GOLINT))
	GOBIN=$(TOOLSBIN) $(GO_INSTALL) github.com/golangci/golangci-lint/cmd/golangci-lint $(GOLINT_BIN) $(GOLINT_VER)

GOVERALLS_VER := v0.0.7
GOVERALLS_BIN := goveralls
GOVERALLS := $(TOOLSBIN)/$(GOVERALLS_BIN)-$(GOVERALLS_VER)

$(GOVERALLS): ; $(info $(M) buiding $(GOVERALLS))
	GOBIN=$(TOOLSBIN) $(GO_INSTALL) github.com/mattn/goveralls $(GOVERALLS_BIN) $(GOVERALLS_VER)

KUBECTL_VER := v1.19.1
KUBECTL_BIN := kubectl
KUBECTL := $(TOOLSBIN)/$(KUBECTL_BIN)-$(KUBECTL_VER)

$(KUBECTL):
	mkdir -p $(TOOLSBIN)
	rm -f "$(KUBECTL)*"
	curl -fsL https://storage.googleapis.com/kubernetes-release/release/$(KUBECTL_VER)/bin/$(GOOS)/$(GOARCH)/kubectl -o $(KUBECTL)
	ln -sf "$(KUBECTL)" "$(TOOLSBIN)/$(KUBECTL_BIN)"
	chmod +x "$(TOOLSBIN)/$(KUBECTL_BIN)" "$(KUBECTL)"

KUSTOMIZE_VER := v3.5.4
KUSTOMIZE_BIN := kustomize
KUSTOMIZE := $(TOOLSBIN)/$(KUSTOMIZE_BIN)-$(KUSTOMIZE_VER)

$(KUSTOMIZE):
	GOBIN=$(TOOLSBIN) $(GO_INSTALL) sigs.k8s.io/kustomize/kustomize/v3 $(KUSTOMIZE_BIN) $(KUSTOMIZE_VER)

ENVSUBST_VER := master
ENVSUBST_BIN := envsubst
ENVSUBST := $(TOOLSBIN)/$(ENVSUBST_BIN)

$(ENVSUBST):
	GOBIN=$(TOOLSBIN) $(GO_INSTALL) github.com/drone/envsubst/cmd/envsubst $(ENVSUBST_BIN) $(ENVSUBST_VER)

## --------------------------------------
## Tilt / Kind
## --------------------------------------

build: lint tidy ; $(info $(M) buiding ./bin/$(APP))
	$Q $(GO)  build -ldflags "-X $(PACKAGE)/cmd.GitCommit=$(VERSION)" -o ./bin/$(APP)

.PHONY: lint
lint: $(GOLINT) ; $(info $(M) running golanci-lint…) @ ## Run golangci-lint
	$(Q) $(GOLINT) run ./...

.PHONY: fmt
fmt: ; $(info $(M) running gofmt…) @ ## Run gofmt on all source files
	@ret=0 && for d in $$($(GO) list -f '{{.Dir}}' ./...); do \
		$(GOFMT) -l -w $$d/*.go || ret=$$? ; \
	 done ; exit $$ret

.PHONY: vet
vet: ; $(info $(M) running vet…) @ ## Run vet
	$Q $(GO) vet ./...

.PHONY: tidy
tidy: ; $(info $(M) running tidy…) @ ## Run tidy
	$Q $(GO) mod tidy

.PHONY: build-debug
build-debug: ; $(info $(M) buiding debug...)
	$Q $(GO)  build -o ./bin/$(APP) -tags debug

.PHONY: test
test: ; $(info $(M) running go test…)
	$(Q) $(GO) test ./... -tags=noexit

.PHONY: test-cover
test-cover: $(GOVERALLS) ; $(info $(M) running go test…)
	$(Q) $(GO) test -tags=noexit -race -covermode atomic -coverprofile=profile.cov ./...
	$(Q) $(GOVERALLS) -coverprofile=profile.cov -service=github

.PHONY: ci
ci: fmt lint vet tidy test-cover

.PHONE: test-e2e
test-e2e: deploy-knative

## --------------------------------------
## Tilt / Kind
## --------------------------------------

.PHONY: kind-create
kind-create: ; $(info $(M) create knative kind cluster if needed…)
	./scripts/kind-without-local-registry.sh

.PHONY: tilt-up
tilt-up: $(KUSTOMIZE) kind-create deploy-knative ; $(info $(M) start tilt and build kind cluster if needed…)
	tilt up

.PHONY: kind-reset
kind-reset: ; $(info $(M) delete local kind cluster…)
	kind delete cluster --name=knative || true

.PHONY: kind-deploy-app
kind-deploy-app: $(KUSTOMIZE) $(KUBECTL) $(ENVSUBST) docker-build ; $(info $(M) deploying knative app…)
	kind load docker-image --name knative $(IMAGE):$(TAG)
	IMAGE=$(IMAGE) TAG=$(TAG) $(ENVSUBST) < ./config/image-patch-template.yml > ./test/config/image-patch.yml
	$(KUSTOMIZE) build ./test/config | $(KUBECTL) apply -f -
	$(KUBECTL) wait ksvc helloworld-go --all --timeout=-1s --for=condition=Ready

## --------------------------------------
## KNative
## --------------------------------------

.PHONY: deploy-knative
deploy-knative: deploy-knative-serving deploy-kourier ; $(info $(M) deploying knative…)

.PHONY: deploy-knative-serving
deploy-knative-serving: $(KUBECTL) ; $(info $(M) deploying knative serving CRDs and core components…)
	$(KUBECTL) apply -f https://github.com/knative/serving/releases/download/v$(KNATIVE_VERSION)/serving-crds.yaml
	$(KUBECTL) apply -f https://github.com/knative/serving/releases/download/v$(KNATIVE_VERSION)/serving-core.yaml
	$(KUBECTL) wait deployment --all --timeout=-1s --for=condition=Available -n knative-serving

.PHONY: deploy-kourier
deploy-kourier: $(KUBECTL) ; $(info $(M) deploying kourier components…)
	$(KUBECTL) apply -f https://github.com/knative/net-kourier/releases/download/v$(KOURIER_VERSION)/kourier.yaml
	$(KUBECTL) wait deployment --all --timeout=-1s --for=condition=Available -n kourier-system
	# deployment for net-kourier gets deployed to namespace knative-serving
	$(KUBECTL) wait deployment --all --timeout=-1s --for=condition=Available -n knative-serving
	$(KUBECTL) patch configmap -n knative-serving config-domain -p "{\"data\": {\"127.0.0.1.nip.io\": \"\"}}"
	$(KUBECTL) apply -f ./config/kourier-listen.yml
	$(KUBECTL) patch configmap/config-network -n knative-serving --type merge --patch '{"data":{"ingress.class":"kourier.ingress.networking.knative.dev"}}'

.PHONY: status-knative
status-knative: $(KUBECTL) ; $(info $(M) getting knative status…)
	$(KUBECTL) get pods -n knative-serving
	$(KUBECTL) get pods -n kourier-system
	$(KUBECTL) get svc kourier-ingress -n kourier-system

.PHONY: deploy-knative-helloworld
deploy-knative-helloworld: $(KUBECTL) ; $(info $(M) deploying helloworld…)
	$(KUBECTL) apply -f ./config/knative-helloworld.yml
	$(KUBECTL) wait ksvc hello --all --timeout=-1s --for=condition=Ready
	curl $$($(KUBECTL) get ksvc hello -o jsonpath='{.status.url}')

.PHONY: helloworld-url
helloworld-url: $(KUBECTL)
	$(Q) $(KUBECTL) get ksvc hello -o jsonpath='{.status.url}'

.PHONY: dev-url
dev-url: $(KUBECTL)
	$(Q) $(KUBECTL) get ksvc helloworld-go -o jsonpath='{.status.url}'

## --------------------------------------
## Docker
## --------------------------------------

.PHONY: docker-build
docker-build: ; $(info $(M) docker build…)
	docker build . -t $(IMAGE):$(TAG)

.PHONY: docker-push
docker-push: ; $(info $(M) docker push…)
	docker push $(IMAGE):$(TAG)

## --------------------------------------
## Test
## --------------------------------------

.PHONY: test-e2e
test-e2e: kind-deploy-app ; $(info $(M) deploying to kind and running tests…)
	curl $$($(KUBECTL) get ksvc helloworld-go -o jsonpath='{.status.url}')
