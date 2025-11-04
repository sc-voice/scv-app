.PHONY: test test-all test-core test-core-verbose build build-demo-ios clean mock-response-view scv-demo-ios version-major version-minor version-patch

test: test-all

test-all: clean build test-core

test-core:
	@cd scv-core && swift test --no-parallel 2>&1 | grep -v "started\."

test-core-verbose:
	@cd scv-core && swift test --no-parallel --verbose

build: build-demo-ios

build-demo-ios:
	@swift scripts/version.swift patch
	xcodebuild build -scheme scv-demo-ios -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15' -quiet 2>/dev/null || true

clean:
	@cd scv-core && swift package clean 2>/dev/null || true
	@cd scv-ui && swift package clean 2>/dev/null || true
	rm -rf scv-demo-iOS/build
	rm -rf scv-demo-iOS/.swiftpm
	xcodebuild clean -scheme scv-demo-ios -quiet 2>/dev/null || true

mock-response-view:
	@cd scv-ui && swift run mock-response-view

scv-demo-ios: clean build
	@open scv-demo-iOS/scv-demo-ios.xcodeproj

version-major:
	@swift scripts/version.swift major

version-minor:
	@swift scripts/version.swift minor

version-patch:
	@swift scripts/version.swift patch

.DEFAULT_GOAL := help

help:
	@echo "SC-Voice Build Targets"
	@echo ""
	@echo "  make test              Run all package tests (shortcut for test-all)"
	@echo "  make test-all          Run all package tests"
	@echo "  make test-core         Run scv-core tests serially"
	@echo "  make test-core-verbose Run scv-core tests serially with verbose output"
	@echo "  make build             Build iOS app (increments patch version)"
	@echo "  make build-demo-ios    Build iOS app (increments patch version)"
	@echo "  make clean             Clean build artifacts (increments major version)"
	@echo "  make mock-response-view Build and launch mock-response-view app"
	@echo "  make scv-demo-ios      Clean, build, and open scv-demo-iOS in Xcode"
	@echo "  make version-major     Increment major version (X.0.0)"
	@echo "  make version-minor     Increment minor version (X.Y.0)"
	@echo "  make version-patch     Increment patch version (X.Y.Z)"
