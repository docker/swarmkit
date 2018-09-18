.DEFAULT_GOAL = all
.PHONY: all
all: check binaries test integration-tests ## run check, build the binaries and run the tests

.PHONY: ci
ci: check binaries checkprotos coverage coverage-integration ## to be used by the CI

.PHONY: AUTHORS
AUTHORS: .mailmap .git/HEAD
	git log --format='%aN <%aE>' | sort -fu > $@

# This only needs to be generated by hand when cutting full releases.
version/version.go:
	./version/version.sh > $@

.PHONY: setup
setup: ## install dependencies
	@echo "🐳 $@"
	# TODO(stevvooe): Install these from the vendor directory
	@go get -u github.com/alecthomas/gometalinter
	@gometalinter --install
	@go get -u github.com/lk4d4/vndr
	@go get -u github.com/stevvooe/protobuild

.PHONY: generate
generate: protos
	@echo "🐳 $@"
	@PATH=${ROOTDIR}/bin:${PATH} go generate -x ${PACKAGES}

.PHONY: protos
protos: bin/protoc-gen-gogoswarm ## generate protobuf
	@echo "🐳 $@"
	@PATH=${ROOTDIR}/bin:${PATH} protobuild ${PACKAGES}

.PHONY: checkprotos
checkprotos: generate ## check if protobufs needs to be generated again
	@echo "🐳 $@"
	@test -z "$$(git status --short | grep ".pb.go" | tee /dev/stderr)" || \
		((git diff | cat) && \
		(echo "👹 please run 'make generate' when making changes to proto files" && false))

.PHONY: check
check: fmt-proto
check: ## Run various source code validation tools
	@echo "🐳 $@"
	@gometalinter ./...

.PHONY: fmt-proto
fmt-proto:
	@test -z "$$(find . -path ./vendor -prune -o ! -name timestamp.proto ! -name duration.proto -name '*.proto' -type f -exec grep -Hn -e "^ " {} \; | tee /dev/stderr)" || \
		(echo "👹 please indent proto files with tabs only" && false)
	@test -z "$$(find . -path ./vendor -prune -o -name '*.proto' -type f -exec grep -Hn "Meta meta = " {} \; | grep -v '(gogoproto.nullable) = false' | tee /dev/stderr)" || \
		(echo "👹 meta fields in proto files must have option (gogoproto.nullable) = false" && false)

.PHONY: build
build: ## build the go packages
	@echo "🐳 $@"
	@go build -i -tags "${DOCKER_BUILDTAGS}" -v ${GO_LDFLAGS} ${GO_GCFLAGS} ${PACKAGES}

.PHONY: test
test: ## run tests, except integration tests
	@echo "🐳 $@"
	@go test -parallel 8 ${RACE} -tags "${DOCKER_BUILDTAGS}" $(filter-out ${INTEGRATION_PACKAGE},${PACKAGES})

.PHONY: integration-tests
integration-tests: ## run integration tests
	@echo "🐳 $@"
	@go test -parallel 8 ${RACE} -tags "${DOCKER_BUILDTAGS}" ${INTEGRATION_PACKAGE}

# Build a binary from a cmd.
bin/%: cmd/% .FORCE
	@test $$(go list) = "${PROJECT_ROOT}" || \
		(echo "👹 Please correctly set up your Go build environment. This project must be located at <GOPATH>/src/${PROJECT_ROOT}" && false)
	@echo "🐳 $@"
	@go build -i -tags "${DOCKER_BUILDTAGS}" -o $@ ${GO_LDFLAGS}  ${GO_GCFLAGS} ./$<

.PHONY: .FORCE
.FORCE:

.PHONY: binaries
binaries: $(BINARIES) ## build binaries
	@echo "🐳 $@"

.PHONY: clean
clean: ## clean up binaries
	@echo "🐳 $@"
	@rm -f $(BINARIES)

.PHONY: install
install: $(BINARIES) ## install binaries
	@echo "🐳 $@"
	@mkdir -p $(DESTDIR)/bin
	@install $(BINARIES) $(DESTDIR)/bin

.PHONY: uninstall
uninstall:
	@echo "🐳 $@"
	@rm -f $(addprefix $(DESTDIR)/bin/,$(notdir $(BINARIES)))

.PHONY: coverage
coverage: ## generate coverprofiles from the unit tests
	@echo "🐳 $@"
	@( for pkg in $(filter-out ${INTEGRATION_PACKAGE},${PACKAGES}); do \
		go test -i ${RACE} -tags "${DOCKER_BUILDTAGS}" -test.short -coverprofile="../../../$$pkg/coverage.txt" -covermode=atomic $$pkg || exit; \
		go test ${RACE} -tags "${DOCKER_BUILDTAGS}" -test.short -coverprofile="../../../$$pkg/coverage.txt" -covermode=atomic $$pkg || exit; \
	done )

.PHONY: coverage-integration
coverage-integration: ## generate coverprofiles from the integration tests
	@echo "🐳 $@"
	go test ${RACE} -tags "${DOCKER_BUILDTAGS}" -test.short -coverprofile="../../../${INTEGRATION_PACKAGE}/coverage.txt" -covermode=atomic ${INTEGRATION_PACKAGE}

.PHONY: help
help: ## this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST) | sort

.PHONY: dep-validate
dep-validate:
	@echo "+ $@"
	$(if $(VNDR), , \
		$(error Please install vndr: go get github.com/lk4d4/vndr))
	@rm -Rf .vendor.bak
	@mv vendor .vendor.bak
	@$(VNDR)
	@test -z "$$(diff -r vendor .vendor.bak 2>&1 | tee /dev/stderr)" || \
		(echo >&2 "+ inconsistent dependencies! what you have in vendor.conf does not match with what you have in vendor" && false)
	@rm -Rf vendor
	@mv .vendor.bak vendor
