INTEGRATION  := $(shell basename $(shell pwd))
BINARY_NAME   = $(INTEGRATION)
GO_PKGS      := $(shell go list ./... | grep -v "/vendor/")
GO_FILES     := $(shell find src -type f -name "*.go")
VALIDATE_DEPS = golang.org/x/lint/golint
DEPS          = github.com/kardianos/govendor
TEST_DEPS     = github.com/axw/gocov/gocov github.com/AlekSi/gocov-xml

all: build

build: clean validate compile test

build-linux: clean validate compile-linux test

clean:
	@echo "=== $(INTEGRATION) === [ clean ]: removing binaries and coverage file..."
	@rm -rfv bin coverage.xml

validate-deps:
	@echo "=== $(INTEGRATION) === [ validate-deps ]: installing validation dependencies..."
	@go get -v $(VALIDATE_DEPS)

validate-only:
	@printf "=== $(INTEGRATION) === [ validate ]: running gofmt... "
# `gofmt` expects files instead of packages. `go fmt` works with
# packages, but forces -l -w flags.
	@OUTPUT="$(shell gofmt -l $(GO_FILES))" ;\
	if [ -z "$$OUTPUT" ]; then \
		echo "passed." ;\
	else \
		echo "failed. Incorrect syntax in the following files:" ;\
		echo "$$OUTPUT" ;\
		exit 1 ;\
	fi
	@printf "=== $(INTEGRATION) === [ validate ]: running golint... "
	@OUTPUT="$(shell golint $(GO_PKGS))" ;\
	if [ -z "$$OUTPUT" ]; then \
		echo "passed." ;\
	else \
		echo "failed. Issues found:" ;\
		echo "$$OUTPUT" ;\
		exit 1 ;\
	fi
	@printf "=== $(INTEGRATION) === [ validate ]: running go vet... "
	@OUTPUT="$(shell go vet $(GO_PKGS))" ;\
	if [ -z "$$OUTPUT" ]; then \
		echo "passed." ;\
	else \
		echo "failed. Issues found:" ;\
		echo "$$OUTPUT" ;\
		exit 1;\
	fi

validate: validate-deps validate-only

compile-deps:
	@echo "=== $(INTEGRATION) === [ compile-deps ]: installing build dependencies..."
	@go get $(DEPS)
	@govendor sync

compile-only:
	@echo "=== $(INTEGRATION) === [ compile ]: building $(BINARY_NAME)..."
	@go build -o bin/$(BINARY_NAME) $(GO_FILES)

compile-only-linux:
	@echo "=== $(INTEGRATION) === [ compile ]: building $(BINARY_NAME)..."
	@env GOOS=linux GOARCH=amd64 go build -o bin/$(BINARY_NAME) $(GO_FILES)

compile: compile-deps compile-only

compile-linux: compile-deps compile-only-linux

package:
	@echo "=== $(INTEGRATION) === [ package ]: packaging release for $(BINARY_NAME)..."
	@cp collectd-plugin* bin/
	@cp README.md bin/
	@tar czf nri-collectd-linux-amd64.tar.gz bin/*

test-deps: compile-deps
	@echo "=== $(INTEGRATION) === [ test-deps ]: installing testing dependencies..."
	@go get -v $(TEST_DEPS)

test-only:
	@echo "=== $(INTEGRATION) === [ test ]: running unit tests..."
	@gocov test $(GO_PKGS) | gocov-xml > coverage.xml

test: test-deps test-only

.PHONY: all build clean validate-deps validate-only validate compile-deps compile-only compile test-deps test-only test
