.PHONY: _init test test-app test-core test-core-verbose test-ui test-build test-tasks\
				test-zstd-integration test-nlp test-content\
				build build-core build-ui build-build build-nlp build-ios build-ios-app build-before build-tasks\
        clean clean-core clean-build clean-ui clean-ios clean-cache clean-lemmatizer\
				format mock-response-view rebuild rebuild-raw \
        version-major version-minor version-patch \
				commit build-zst content build-db clean-db

SWIFT_BUILD_FILTER = '(✘ Test|Suite.*after|error:|warning:|Build complete)'
XCODE_BUILD_FILTER = '(error:|warning:|BUILD SUCCEEDED|BUILD FAILED|Test Suite)'
TEST_ALL_FILTER = '(✘|Suite.*after|error:|warning:|Build complete|BUILD SUCCEEDED|BUILD FAILED|✔ Test run|failed|✓|NOTE:|Found unhandled|=== MAKE)'
LOG_FILE = $(CURDIR)/local/build/make.log

# Initialize make.log at start of top-level invocation
_init:
	@mkdir -p $(CURDIR)/local/build
	@echo "=== MAKE START $$(date '+%Y-%m-%d %H:%M:%S') ===" > ${LOG_FILE}

summary: 
	@echo
	@echo MAKE SUMMARY:
	@grep -E $(TEST_ALL_FILTER) $(LOG_FILE) < ${LOG_FILE} || true

_end:
	@echo "=== MAKE END $$(date '+%Y-%m-%d %H:%M:%S') ===" 2>&1 >> ${LOG_FILE} 
	@make summary

# Build test database if it doesn't exist
scv-core/Sources/Resources/ebt-en-soma.db.zst:
	@echo "Building test database..."
	@scripts/build-ebt-data en:soma

test-app: _init _test-app _end

_test-app: scv-core/Sources/Resources/ebt-en-soma.db.zst _test-core _test-ui _test-content

test-core: _init _test-core _end

_test-core: _build-core
	@echo "=== MAKE test-core..." | tee -a $(LOG_FILE)
	@cd scv-core && swift test --no-parallel --skip ZstdIntegrationTests 2>&1 | tee -a $(LOG_FILE)

test-core-verbose: _init _build-core _end
	@cd scv-core && swift test --no-parallel --verbose

test-ui: _init _test-ui _end

_test-ui:
	@echo "=== MAKE test-ui..." | tee -a $(LOG_FILE)
	@cd scv-ui && swift test --no-parallel 2>&1 | tee -a $(LOG_FILE)

test-tools: _init _test-tools _end

_test-tools:
	@echo "=== MAKE test-tools..." | tee -a $(LOG_FILE)
	@cd scv-build && swift test --no-parallel 2>&1 | tee -a $(LOG_FILE)

test-tasks: _init _test-tasks _end

_test-tasks:
	@echo "=== MAKE test-tasks..." | tee -a $(LOG_FILE)
	@cd scv-tasks && swift test --no-parallel 2>&1 | tee -a $(LOG_FILE)

test-zstd-integration:
	@cd scv-core && swift test --no-parallel --filter ZstdIntegrationTests 2>&1 | grep -v "started\."

test-nlp: build-nlp
	@echo "=== MAKE test-nlp..." | tee -a $(LOG_FILE)
	@cd scv-nlp && swift test --no-parallel 2>&1 | tee -a $(LOG_FILE)
	@grep -E $(TEST_ALL_FILTER) $(LOG_FILE) | tail -20 || true

test-content: _init _test-content _end

_test-content:
	@echo "=== MAKE test-content..." | tee -a $(LOG_FILE)
	@cd scv-build && PROJECT_ROOT=$(CURDIR) swift run verify-manifest 2>&1 | tee -a $(CURDIR)/local/build/make.log

# build-macros:
# 	@cd scv-macros && swift build 2>&1 | grep -E $(SWIFT_BUILD_FILTER) || true
# Note: scv-macros is a compiler plugin that rarely changes.
# Uncomment above to rebuild when macro code changes.
# Macro plugin is not currently used due to SPM cross-package limitations (see scv-macros/Sources/scvMacros/CCOK1.swift)

# Rebuild all .zst files from latest ebt-data content and regenerate manifest
build-content: _init _build-content _end

_build-content: build-tools
	@echo "Pulling latest ebt-data..." | tee -a $(LOG_FILE)
	@(cd local/ebt-data && git pull) 2>&1 | tee -a $(LOG_FILE)
	@echo "Rebuilding all databases from latest content..." | tee -a $(LOG_FILE)
	@scripts/build-ebt-data --rebuild-from-manifest 2>&1 | tee -a $(LOG_FILE)
	@echo "Regenerating db-manifest.json with schema versions..." | tee -a $(LOG_FILE)
	@scripts/build-ebt-data --build-manifest 2>&1 | tee -a $(LOG_FILE)
	@echo "✓ All .zst files rebuilt and manifest regenerated" | tee -a $(LOG_FILE)
	@echo "" | tee -a $(LOG_FILE)
	@echo "=== Available Translations ===" | tee -a $(LOG_FILE)
	@scripts/ebt-translations.sh 2>&1 | tee -a $(LOG_FILE)

content: _init _content _end

_content: _clean-content _build-content _test-content

build-db: _init _build-db _end

_build-db:
	@if [ -z "$(DB)" ]; then \
		echo "Usage: make build-db DB=lang:author"; \
		echo "Example: make build-db DB=en:sujato"; \
		exit 1; \
	fi
	@echo "Building database: $(DB)..." 2>&1 | tee -a $(LOG_FILE)
	@scripts/build-ebt-data $(DB) 2>&1 | tee -a $(LOG_FILE)

build-tools: _init _build-tools _end

_build-tools: _build-core
	@echo "=== MAKE build-tools..." | tee -a $(LOG_FILE)
	@cd scv-build && swift build 2>&1 | tee -a $(LOG_FILE)
	@grep -E $(SWIFT_BUILD_FILTER) $(LOG_FILE) | tail -10 || true

build-tasks: _init _build-tasks _end

_build-tasks:
	@echo "=== MAKE build-tasks..." | tee -a $(LOG_FILE)
	@cd scv-tasks && swift build 2>&1 | tee -a $(LOG_FILE)
	@grep -E $(SWIFT_BUILD_FILTER) $(LOG_FILE) | tail -10 || true

build-core: _init _build-core _end

_build-core: 
	@echo "=== MAKE build-core..." | tee -a $(LOG_FILE)
	@cd scv-core && swift build 2>&1 | tee -a $(LOG_FILE)

build-ui: _init _build-ui _end

_build-ui: _build-core
	@echo "=== MAKE build-ui..." | tee -a $(LOG_FILE)
	@cd scv-ui && swift build 2>&1 | tee -a $(LOG_FILE)
	@grep -E $(SWIFT_BUILD_FILTER) $(LOG_FILE) | tail -10 || true

build-nlp: 
	@echo "=== MAKE build-nlp..." | tee -a $(LOG_FILE)
	@cd scv-nlp && swift build 2>&1 | tee -a $(LOG_FILE)
	@grep -E $(SWIFT_BUILD_FILTER) $(LOG_FILE) | tail -10 || true

build-ios: _init _build-ios _end

_build-ios: _build-ui 
	@echo "=== MAKE build-ios..." | tee -a $(LOG_FILE)
	@cd scv-ios && \
	  xcodebuild build \
	    -scheme scv-ios \
	    -configuration Debug \
	    -destination 'generic/platform=iOS Simulator' \
	    2>&1 | tee -a $(LOG_FILE)

rebuild: _init _rebuild _end

_rebuild: scv-core/Sources/Resources/ebt-en-soma.db.zst 
	@echo "=== MAKE rebuild" | tee -a $(LOG_FILE)
	@scripts/version patch 2>&1 | tee -a ${LOG_FILE}
	@$(MAKE) _clean 2>&1 | tee -a $(LOG_FILE); \
	if [ $$? -ne 0 ]; then echo "=== MAKE BUILD FAILED" | tee -a $(LOG_FILE); exit 1; fi
	@echo "Test run started at $$(date '+%Y-%m-%d %H:%M:%S')" | tee -a $(LOG_FILE)
	@$(MAKE) _test-app 2>&1 | tee -a $(LOG_FILE); \
	if [ $$? -ne 0 ]; then echo "=== MAKE TEST FAILED" | tee -a $(LOG_FILE); exit 1; fi
	@$(MAKE) _build-ios 2>&1 | tee -a $(LOG_FILE); \

# clean-macros:
# 	@cd scv-macros && swift package clean 2>/dev/null || true

clean-cache: _init _clean-cache _end

_clean-cache:
	@echo "=== MAKE clean-cache..." 2>&1 | tee -a ${LOG_FILE}
	@rm -f ~/Library/Caches/ebt-*.db 2>/dev/null || true
	@echo "Cleared database caches from ~/Library/Caches" 2>&1 | tee -a ${LOG_FILE}

clean-lemmatizer: _init _clean-lemmatizer _end

_clean-lemmatizer:
	@echo "=== MAKE clean-lemmatizer..." 2>&1 | tee -a ${LOG_FILE}
	@find scv-core/Sources/Resources -name "*-lemmas.json" -delete 2>/dev/null || true
	@find scv-core/.build -name "*-lemmas.json" -delete 2>/dev/null || true
	@find scv-build/.build -name "*-lemmas.json" -delete 2>/dev/null || true
	@find scv-ui/.build -name "*-lemmas.json" -delete 2>/dev/null || true
	@echo "Cleared lemmatizer cache files" 2>&1 | tee -a ${LOG_FILE}

clean-db:
	@if [ -z "$(DB)" ]; then \
		echo "Usage: make clean-db DB=lang:author"; \
		echo "Example: make clean-db DB=en:sujato"; \
		exit 1; \
	fi
	@echo "Cleaning database: $(DB)..."
	@rm -f ~/Library/Caches/ebt-$(subst :,-,$(DB)).db 2>/dev/null || true
	@rm -f local/build/ebt-$(subst :,-,$(DB)).db 2>/dev/null || true
	@rm -f scv-core/Sources/Resources/ebt-$(subst :,-,$(DB)).db 2>/dev/null || true
	@rm -f scv-core/Sources/Resources/ebt-$(subst :,-,$(DB)).db.zst 2>/dev/null || true
	@echo "Cleaned database files for $(DB)"

clean: _init _clean _end

_clean: _clean-core _clean-ui _clean-ios _format 

format: _init _format _end

_format: 
	@swiftformat . --exclude Pods

clean-core: _init _clean-core _end

_clean-core:
	@echo "=== MAKE clean-core..." 2>&1 | tee -a ${LOG_FILE}
	@cd scv-core && swift package clean 2>/dev/null || true

clean-content: _init _clean-content _end

_clean-content: _clean-lemmatizer _clean-cache
	@echo "=== MAKE clean-content..." 2>&1 | tee -a ${LOG_FILE}
	@rm -f scv-core/Sources/Resources/*.db.zst 2>/dev/null || true
	@echo "Cleared .zst database resource files" 2>&1 | tee -a ${LOG_FILE}
	@rm -f scv-core/Sources/Resources/*.db 2>/dev/null || true
	@echo "Cleared .db database resource files" 2>&1 | tee -a ${LOG_FILE}
	@cd scv-build && swift package clean 2>/dev/null || true

clean-ui: _init _clean-ui _end

_clean-ui:
	@echo "=== MAKE clean-ui..."
	@cd scv-ui && swift package clean 2>/dev/null || true

clean-ios: _init _clean-ios _end

_clean-ios:
	@echo "=== MAKE clean-ios..."  2>&1 | tee -a ${LOG_FILE}
	rm -rf scv-ios/build  2>&1 | tee -a ${LOG_FILE}
	rm -rf scv-ios/.swiftpm  2>&1 | tee -a ${LOG_FILE}
	cd scv-ios && \
	  xcodebuild clean -scheme scv-ios 2>&1 | tee -a ${LOG_FILE} || true

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
	@echo "  make test              Run all package tests (shortcut for test-app)"
	@echo "  make test-app          Run all application tests"
	@echo "  make test-core         Run scv-core tests serially (excludes integration tests)"
	@echo "  make test-core-verbose Run scv-core tests serially with verbose output"
	@echo "  make test-tools        Run scv-build tests serially"
	@echo "  make test-tasks        Run scv-tasks tests serially"
	@echo "  make test-ui           Run scv-ui tests serially"
	@echo "  make test-zstd-integration Run zstd integration tests (database decompression)"
	@echo "  make test-content      Verify all manifest databases are present in build"
	@echo "  make build             Build all (core and iOS) with new version"
	@echo "  make build-core        Build scv-core package"
	@echo "  make build-ui	        Build scv-ui package"
	@echo "  make build-tools 			Build scv-build package (build tools)"
	@echo "  make build-tasks       Build scv-tasks package (task CLI)"
	@echo "  make build-ios         Build scv-ios app with new version"
	@echo "  make build-db DB=lang:author    Build single database (e.g. make build-db DB=en:sujato)"
	@echo "  make content						Pull latest ebt-data and rebuild all databases from manifest"
	@echo "  make clean             Clean all build artifacts and apply SwiftFormat"
	@echo "  make clean-core        Clean scv-core package"
	@echo "  make clean-content 		Clean database content"
	@echo "  make clean-ui          Clean scv-ui package"
	@echo "  make clean-ios         Clean scv-ios app build artifacts"
	@echo "  make clean-db DB=lang:author    Clean database caches (e.g. make clean-db DB=en:sujato)"
	@echo "  make clean-cache       Clean all app caches from ~/Library/Caches"
	@echo "  make clean-lemmatizer  Clean all lemmatizer cache files"
	@echo "  make format            Apply SwiftFormat to project"
	@echo "  make mock-response-view Build and launch mock-response-view app"
	@echo "  make version-major     Increment major version (X.0.0)"
	@echo "  make version-minor     Increment minor version (X.Y.0)"
	@echo "  make version-patch     Increment patch version (X.Y.Z)"
	@echo "  make commit            Review and approve commit from .commit-msg file"
