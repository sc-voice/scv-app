.PHONY: test test-all test-core test-core-verbose build clean mock-response-view scv-demo-ios increment-build-number

test: test-all

test-all: clean build test-core

test-core:
	@cd scv-core && swift test --no-parallel 2>&1 | grep -v "started\."

test-core-verbose:
	@cd scv-core && swift test --no-parallel --verbose

build:
	@cd scv-ui && swift build 2>/dev/null || true
	xcodebuild build -scheme scv-demo-ios -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15' -quiet 2>/dev/null || true

clean: increment-build-number
	@cd scv-core && swift package clean 2>/dev/null || true
	@cd scv-ui && swift package clean 2>/dev/null || true
	rm -rf scv-demo-iOS/build
	rm -rf scv-demo-iOS/.swiftpm
	xcodebuild clean -scheme scv-demo-ios -quiet 2>/dev/null || true

mock-response-view:
	@cd scv-ui && swift run mock-response-view

scv-demo-ios: clean build
	@open scv-demo-iOS/scv-demo-ios.xcodeproj

increment-build-number:
	@echo "Incrementing scv-demo-iOS build number..."
	@swift scripts/increment_build_number.swift

.DEFAULT_GOAL := help

help:
	@echo "SC-Voice Build Targets"
	@echo ""
	@echo "  make test              Run all package tests (shortcut for test-all)"
	@echo "  make test-all          Run all package tests"
	@echo "  make test-core         Run scv-core tests serially"
	@echo "  make test-core-verbose Run scv-core tests serially with verbose output"
	@echo "  make build             Build all packages"
	@echo "  make clean             Clean build artifacts"
	@echo "  make mock-response-view Build and launch mock-response-view app"
	@echo "  make scv-demo-ios      Increment build number and open scv-demo-iOS in Xcode"
	@echo "  make increment-build-number Increment scv-demo-iOS build number only"
