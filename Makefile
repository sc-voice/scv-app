.PHONY: test test-all test-core test-core-verbose test-ui test-build test-zstd-integration test-nlp\
				build build-core build-ui build-build build-nlp build-ios build-ios-app\
        clean clean-core clean-build clean-ui clean-ios\
				format mock-response-view rebuild rebuild-raw \
        version-major version-minor version-patch \
				commit build-zst content

SWIFT_BUILD_FILTER = '(✘ Test|Suite.*after|error:|warning:|Build complete)'
XCODE_BUILD_FILTER = '(error:|warning:|BUILD SUCCEEDED|BUILD FAILED|Test Suite)'
TEST_ALL_FILTER = '(✘|Suite.*after|error:|warning:|Build complete|BUILD SUCCEEDED|BUILD FAILED|✔ Test run|failed|✓|NOTE:|Found unhandled)'

# Build test database if it doesn't exist
scv-core/Sources/Resources/ebt-en-soma.db.zst:
	@echo "Building test database..."
	@scripts/build-ebt-data en:soma

test: test-all

test-all: scv-core/Sources/Resources/ebt-en-soma.db.zst test-core test-ui 
	@mkdir -p local

test-core: build-core
	@echo "=======> test-core..."
	@cd scv-core && swift test --no-parallel --skip ZstdIntegrationTests 2>&1 \
	| tee ../local/test-core.log \
	| grep -E $(TEST_ALL_FILTER) || true

test-core-verbose: build-core
	@cd scv-core && swift test --no-parallel --verbose

test-build: build-build
	@echo "=======> test-build..."
	@cd scv-build && swift test --no-parallel 2>&1 | grep -v "started\."

test-ui: build-ui
	@echo "=======> test-ui..."
	@cd scv-ui && swift test --no-parallel 2>&1 | grep -E $(TEST_ALL_FILTER) || true

test-zstd-integration:
	@cd scv-core && swift test --no-parallel --filter ZstdIntegrationTests 2>&1 | grep -v "started\."

test-nlp: build-nlp
	@echo "=======> test-nlp..."
	@cd scv-nlp && swift test --no-parallel 2>&1 \
	| tee ../local/test-nlp.log \
	| grep -E $(TEST_ALL_FILTER) || true

# build-macros:
# 	@cd scv-macros && swift build 2>&1 | grep -E $(SWIFT_BUILD_FILTER) || true
# Note: scv-macros is a compiler plugin that rarely changes.
# Uncomment above to rebuild when macro code changes.
# Macro plugin is not currently used due to SPM cross-package limitations (see scv-macros/Sources/scvMacros/CCOK1.swift)

# Rebuild all .zst files from latest ebt-data content and regenerate manifest
build-zst: build-build
	@echo "Pulling latest ebt-data..."
	@(cd local/ebt-data && git pull)
	@echo "Rebuilding all databases from latest content..."
	@scripts/build-ebt-data --rebuild-from-manifest
	@echo "Regenerating db-manifest.json with schema versions..."
	@scripts/build-ebt-data --build-manifest
	@echo "✓ All .zst files rebuilt and manifest regenerated"

content: build-zst

build-build:
	@echo "=====> build-build..."
	@cd scv-build && swift build 2>&1 | grep -E $(SWIFT_BUILD_FILTER) || true

build-core:
	@echo "=====> build-core..."
	@cd scv-core && swift build 2>&1 | grep -E $(SWIFT_BUILD_FILTER) || true

build-ui: build-core
	@echo "=====> build-ui..."
	@cd scv-build && swift build 2>&1 | grep -E $(SWIFT_BUILD_FILTER) || true

build-nlp:
	@echo "=====> build-nlp..."
	@cd scv-nlp && swift build 2>&1 | grep -E $(SWIFT_BUILD_FILTER) || true

build-ios: build-core build-ui build-ios-app

build: build-ios-app

rebuild-untimed: scv-core/Sources/Resources/ebt-en-soma.db.zst
	@echo "rebuild start... $$(date)" > local/rebuild.log
	@scripts/version patch
	@mkdir -p local
	@echo "Rebuilding..."
	@$(MAKE) clean build 2>&1 | tee -a local/rebuild.log
	@echo "Test run started at $$(date '+%Y-%m-%d %H:%M:%S')" | tee -a local/rebuild.log
	@$(MAKE) test-core test-ui 2>&1 | tee -a local/test-all.log 
	@echo "=========TEST SUMMARY======="
	@echo "EXPECTED: 1 unhandled resource warning" 
	cat local/test-all.log | grep -v "macro 'Z" | grep -E $(TEST_ALL_FILTER) || true >> local/rebuild.log
	@echo "✓ rebuild end $$(date)" >> local/rebuild.log

rebuild:
	time make rebuild-untimed

build-ios-app:
	@echo "=====> build-ios-app..."
	@cd scv-ios && \
	  xcodebuild build \
	    -scheme scv-ios \
	    -configuration Debug \
	    -destination 'generic/platform=iOS Simulator' \
	    2>&1 | \
			tee ../local/build-ios.log | grep -E $(XCODE_BUILD_FILTER) || true

clean: clean-core clean-build clean-ui clean-ios format

format:
	@swiftformat . --exclude Pods

# clean-macros:
# 	@cd scv-macros && swift package clean 2>/dev/null || true

clean-core:
	@echo "=====> clean-core..."
	@cd scv-core && swift package clean 2>/dev/null || true

clean-build:
	@echo "=====> clean-build..."
	@cd scv-build && swift package clean 2>/dev/null || true
	@rm -f ~/Library/Caches/ebt-*.db 2>/dev/null || true

clean-ui:
	@echo "=====> clean-ui..."
	@cd scv-ui && swift package clean 2>/dev/null || true

clean-ios:
	@echo "=====> clean-ios..."
	rm -rf scv-ios/build
	rm -rf scv-ios/.swiftpm
	cd scv-ios && \
	  xcodebuild clean -scheme scv-ios 2>/dev/null || true

mock-response-view:
	@cd scv-ui && swift run mock-response-view

version-major:
	@scripts/version major

version-minor:
	@scripts/version minor

version-patch:
	@scripts/version patch

commit:
	@if [ ! -f .commit-msg ]; then \
		echo "Error: .commit-msg file not found"; \
		exit 1; \
	fi
	@echo ""
	@echo "Commit message:"
	@echo "==============="
	@cat .commit-msg
	@echo "==============="
	@echo ""
	@read -p "Approve commit? (y/n) " -n 1 -r; \
	echo ""; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		git add -A && git commit -F .commit-msg && rm .commit-msg; \
	else \
		echo "Commit cancelled"; \
		exit 1; \
	fi

.DEFAULT_GOAL := help

help:
	@echo "SC-Voice Build Targets"
	@echo ""
	@echo "  make rebuild           Update version, clean, build and test and all packages"
	@echo "  make test              Run all package tests (shortcut for test-all)"
	@echo "  make test-all          Run all package tests and build validation"
	@echo "  make test-core         Run scv-core tests serially (excludes integration tests)"
	@echo "  make test-core-verbose Run scv-core tests serially with verbose output"
	@echo "  make test-build        Run scv-build tests serially"
	@echo "  make test-ui           Run scv-ui tests serially"
	@echo "  make test-zstd-integration Run zstd integration tests (database decompression)"
	@echo "  make build             Build all (core and iOS) with new version"
	@echo "  make build-core        Build scv-core package"
	@echo "  make build-ui	        Build scv-ui package"
	@echo "  make build-build       Build scv-build package (build tools)"
	@echo "  make build-ios         Build scv-ios app with new version"
	@echo "  make build-ios-part    Build scv-ios app"
	@echo "  make content						Pull latest ebt-data and rebuild all databases from manifest"
	@echo "  make clean             Clean all build artifacts and apply SwiftFormat"
	@echo "  make clean-core        Clean scv-core package"
	@echo "  make clean-build       Clean scv-build package"
	@echo "  make clean-ui          Clean scv-ui package"
	@echo "  make clean-ios         Clean scv-ios app build artifacts"
	@echo "  make format            Apply SwiftFormat to project"
	@echo "  make mock-response-view Build and launch mock-response-view app"
	@echo "  make version-major     Increment major version (X.0.0)"
	@echo "  make version-minor     Increment minor version (X.Y.0)"
	@echo "  make version-patch     Increment patch version (X.Y.Z)"
	@echo "  make commit            Review and approve commit from .commit-msg file"
