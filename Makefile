
# Image URL to use all building/pushing image targets
IMG ?= nikengp/podpreset-controller:v0.2

all: test manager

# Run tests
test: generate fmt vet manifests
	go test ./pkg/... ./cmd/... -coverprofile cover.out

# Build manager binary
manager: generate fmt vet
	go build -o bin/manager github.com/arturozv/podpreset-crd/cmd/manager

# Run against the configured Kubernetes cluster in ~/.kube/config
run: generate fmt vet
	go run ./cmd/manager/main.go

# Install CRDs into a cluster
install: manifests
	kubectl apply -f config/crds

# Deploy controller in the configured Kubernetes cluster in ~/.kube/config
deploy: manifests
	kubectl apply -f config/crds
	kustomize build config/default | kubectl apply -f -

undeploy:
	kustomize build config/default | kubectl delete -f -
	kubectl delete -f config/crds

# Generate manifests e.g. CRD, RBAC etc.
manifests:
	go run vendor/sigs.k8s.io/controller-tools/cmd/controller-gen/main.go all

# Run go fmt against code
fmt:
	go fmt ./pkg/... ./cmd/...

# Run go vet against code
vet:
	go vet ./pkg/... ./cmd/...

# Generate code
generate:
	go generate ./pkg/... ./cmd/...

# Build the docker image
docker-build: generate fmt vet manifests
	docker build . -t ${IMG}
	@echo "updating kustomize image patch file for manager resource"
	sed -i '' -e 's@image: .*@image: '"${IMG}"'@' ./config/default/manager_image_patch.yaml

# Push the docker image
docker-push:
	docker push ${IMG}

#
# Mutating webhook targets from here below
#
deploy-webhook: docker-build-webhook
	kubectl apply -f webhook/rbac/
	kustomize build webhook | kubectl apply -f -

undeploy-webhook:
	kustomize build webhook | kubectl delete -f -
	kubectl delete -f webhook/rbac/
docker-build-webhook:
	CGO_ENABLED=0 GOOS=linux go build -o ./webhook/webhook ./webhook/
	docker build --no-cache -t nikengp/admission-webhook:v0.4 ./webhook/
	rm -rf ./webhook/webhook
	docker push nikengp/admission-webhook:v0.4
