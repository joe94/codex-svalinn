DEFAULT: build

GO           ?= go
GOFMT        ?= $(GO)fmt
FIRST_GOPATH := $(firstword $(subst :, ,$(shell $(GO) env GOPATH)))
SVALINN    := $(FIRST_GOPATH)/bin/svalinn

PROGVER = $(shell grep 'applicationVersion.*= ' main.go | awk '{print $$3}' | sed -e 's/\"//g')

.PHONY: go-mod-vendor
go-mod-vendor:
	GO111MODULE=on $(GO) mod vendor

.PHONY: build
build: go-mod-vendor
	$(GO) build -o svalinn

rpm:
	mkdir -p ./OPATH/SOURCES
	tar -czvf ./OPATH/SOURCES/svalinn-$(PROGVER).tar.gz . --exclude ./.git --exclude ./OPATH --exclude ./conf --exclude ./deploy --exclude ./vendor
	cp conf/svalinn.service ./OPATH/SOURCES/
	cp conf/svalinn.yaml  ./OPATH/SOURCES/
	rpmbuild --define "_topdir $(CURDIR)/OPATH" \
    		--define "_version $(PROGVER)" \
    		--define "_release 1" \
    		-ba deploy/packaging/svalinn.spec

.PHONY: version
version:
	@echo $(PROGVER)


# If the first argument is "update-version"...
ifeq (update-version,$(firstword $(MAKECMDGOALS)))
  # use the rest as arguments for "update-version"
  RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  # ...and turn them into do-nothing targets
  $(eval $(RUN_ARGS):;@:)
endif

.PHONY: update-version
update-version:
	@echo "Update Version $(PROGVER) to $(RUN_ARGS)"
	sed -i "s/$(PROGVER)/$(RUN_ARGS)/g" main.go


.PHONY: install
install: go-mod-vendor
	echo go build -o $(SVALINN) $(PROGVER)

.PHONY: release-artifacts
release-artifacts: go-mod-vendor
	GOOS=darwin GOARCH=amd64 go build -o ./OPATH/svalinn-$(PROGVER).darwin-amd64
	GOOS=linux  GOARCH=amd64 go build -o ./OPATH/svalinn-$(PROGVER).linux-amd64

.PHONY: docker
docker:
	docker build -f ./deploy/Dockerfile -t svalinn:$(PROGVER) .

# build docker without running modules
.PHONY: local-docker
local-docker:
	GOOS=linux  GOARCH=amd64 go build -o svalinn_linux_amd64
	docker build -f ./deploy/Dockerfile.local -t svalinn:local .

.PHONY: style
style:
	! gofmt -d $$(find . -path ./vendor -prune -o -name '*.go' -print) | grep '^'

.PHONY: test
test: go-mod-vendor
	go test -o $(SVALINN) -v -race  -coverprofile=cover.out $(go list ./... | grep -v "/vendor/")

.PHONY: test-cover
test-cover: test
	go tool cover -html=cover.out

.PHONY: codecov
codecov: test
	curl -s https://codecov.io/bash | bash

.PHONEY: it
it:
	./it.sh

.PHONY: clean
clean:
	rm -rf ./codex-svalinn ./OPATH ./coverage.txt ./vendor
