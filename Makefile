# Get a short hash of the git head for building images.
TAG = $$(git rev-parse --short HEAD)

# Name of actual binary to create
BINARY = simple-server

.PHONY: deps
deps:
	@echo "\n....Installing dependencies for $(BINARY)...."
	go mod download

.PHONY: bin
bin:
	@echo "\n....Building $(BINARY)...."
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o bin/$(BINARY) src/main.go

.PHONY: install
install:
	$(MAKE) deps
	$(MAKE) bin

.PHONY: docker
docker:
	docker build -t josh9398/$(BINARY):$(TAG) .

.PHONY: run
run:
	@echo "\n....Running $(BINARY)...."
	go run src/main.go