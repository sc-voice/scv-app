.PHONY: test test-all test-core test-core-verbose build clean mock-response-view

test: test-all

test-all: test-core

test-core:
	@cd scv-core && swift test --no-parallel

test-core-verbose:
	@cd scv-core && swift test --no-parallel --verbose

build:
	swift build

clean:
	swift package clean

mock-response-view:
	@cd scv-ui && swift run mock-response-view

.DEFAULT_GOAL := help

help:
	@echo "SC-Voice Build Targets"
	@echo ""
	@echo "  make test              Run all package tests (shortcut for test-all)"
	@echo "  make test-all          Run all package tests"
	@echo "  make test-core         Run scv-core tests serially"
	@echo "  make test-core-verbose Run scv-core tests serially with verbose output"
	@echo "  make build             Build all packages"
	@echo "  make clean               Clean build artifacts"
	@echo "  make mock-response-view  Build and launch mock-response-view app"
