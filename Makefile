.PHONY: test test-all test-core test-core-verbose build build-core build-demo-ios \
        clean clean-core clean-ui clean-demo-ios mock-response-view scv-demo-ios \
        version-major version-minor version-patch commit build-ebt-data-db

SWIFT_BUILD_FILTER = '(error:|warning:|Build complete)'
XCODE_BUILD_FILTER = '(error:|warning:|BUILD SUCCEEDED|BUILD FAILED|Test Suite)'
TEST_ALL_FILTER = '(error:|warning:|Build complete|BUILD SUCCEEDED|BUILD FAILED|✔ Test run|✓)'

# Build ebt-data.db if it doesn't exist
scv-core/Resources/ebt-data.db:
	@echo "Building ebt-data.db..."
	@swift Scripts/build-ebt-data.swift

# Force rebuild ebt-data.db
build-ebt-data-db:
	@rm -f scv-core/Resources/ebt-data.db
	@$(MAKE) scv-core/Resources/ebt-data.db

test: test-all

test-all: scv-core/Resources/ebt-data.db
	@mkdir -p local
	@echo "Test run started at $$(date '+%Y-%m-%d %H:%M:%S')" > local/test-all.log
	@$(MAKE) clean build test-core test-demo-ios 2>&1 | \
	  tee -a local/test-all.log | \
	  grep -E $(TEST_ALL_FILTER) || true

test-core:
	@cd scv-core && swift test --no-parallel 2>&1 | grep -v "started\."

test-core-verbose:
	@cd scv-core && swift test --no-parallel --verbose

test-demo-ios:
	@BUILD_NUM=$$(grep CURRENT_PROJECT_VERSION \
	  scv-demo-ios/scv-demo-ios.xcodeproj/project.pbxproj | \
	  head -1 | sed 's/.*= //;s/;$$//'); \
	echo "✓ scv-demo-ios built successfully (Build $$BUILD_NUM)"

build: build-core build-demo-ios
	@swift scripts/version.swift patch

build-core:
	@cd scv-core && swift build 2>&1 | grep -E $(SWIFT_BUILD_FILTER) || true

build-demo-ios:
	@cd scv-demo-ios && \
	  xcodebuild build \
	    -scheme scv-demo-ios \
	    -configuration Debug \
	    -destination 'platform=iOS Simulator,name=iPhone 15' \
	    2>&1 | grep -E $(XCODE_BUILD_FILTER) || true

clean: clean-core clean-ui clean-demo-ios

clean-core:
	@cd scv-core && swift package clean 2>/dev/null || true

clean-ui:
	@cd scv-ui && swift package clean 2>/dev/null || true

clean-demo-ios:
	rm -rf scv-demo-iOS/build
	rm -rf scv-demo-iOS/.swiftpm
	cd scv-demo-ios && \
	  xcodebuild clean -scheme scv-demo-ios 2>/dev/null || true

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
	@echo "  make test              Run all package tests (shortcut for test-all)"
	@echo "  make test-all          Run all package tests and build validation"
	@echo "  make test-core         Run scv-core tests serially"
	@echo "  make test-core-verbose Run scv-core tests serially with verbose output"
	@echo "  make test-demo-ios     Validate scv-demo-ios build"
	@echo "  make build             Build all (core and iOS)"
	@echo "  make build-core        Build scv-core package"
	@echo "  make build-demo-ios    Build iOS app (increments patch version)"
	@echo "  make build-ebt-data-db Force rebuild ebt-data.db from source"
	@echo "  make clean             Clean all build artifacts"
	@echo "  make clean-core        Clean scv-core package"
	@echo "  make clean-ui          Clean scv-ui package"
	@echo "  make clean-demo-ios    Clean iOS app build artifacts"
	@echo "  make mock-response-view Build and launch mock-response-view app"
	@echo "  make scv-demo-ios      Clean, build, and open scv-demo-iOS in Xcode"
	@echo "  make version-major     Increment major version (X.0.0)"
	@echo "  make version-minor     Increment minor version (X.Y.0)"
	@echo "  make version-patch     Increment patch version (X.Y.Z)"
	@echo "  make commit            Review and approve commit from .commit-msg file"
