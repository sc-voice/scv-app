.PHONY: test test-verbose build clean

test:
	@cd scv-core && swift test --no-parallel

test-verbose:
	@cd scv-core && swift test --no-parallel --verbose

build:
	swift build

clean:
	swift package clean

.DEFAULT_GOAL := help

help:
	@echo "SC-Voice Build Targets"
	@echo ""
	@echo "  make test          Run scv-core tests serially"
	@echo "  make test-verbose  Run scv-core tests serially with verbose output"
	@echo "  make build         Build all packages"
	@echo "  make clean         Clean build artifacts"
