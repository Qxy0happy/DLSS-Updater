# Build and test entry points for the Flutter + Go sidecar stack.
#
# The Python/Flet application keeps its own entry points; nothing here touches
# it. Every target below runs the real stack; none succeeds with a stub.
SHELL := /bin/bash

ROOT := $(CURDIR)
VERSION := $(shell cat $(ROOT)/VERSION)
BUILD_DIR := $(ROOT)/build
BIN_DIR := $(ROOT)/backend/bin
LDFLAGS := -X github.com/Qxy0happy/DLSS-Updater/backend/internal/buildinfo.Version=$(VERSION)

# Development paths; never the real user data directory.
DEV_DATA_DIR ?= $(BUILD_DIR)/dev-data
DEV_RUNTIME_DIR ?= $(BUILD_DIR)/dev-runtime

export CGO_ENABLED := 0

.DEFAULT_GOAL := help

.PHONY: help codegen codegen-check backend-test backend-integration \
	backend-build frontend-test frontend-integration frontend-build build run-dev

help:
	@printf '%s\n' \
		'Targets:' \
		'  codegen              regenerate committed Go and Dart code from proto/' \
		'  codegen-check        regenerate, then fail if the tree differs' \
		'  backend-test         go test ./... (unit/contract packages)' \
		'  backend-integration  go test -tags=integration ./... (real dlssd over a real socket)' \
		'  backend-build        build backend/bin/dlssd (CGO_ENABLED=0)' \
		'  frontend-test        dart format check, flutter analyze, flutter test' \
		'  frontend-integration opt-in Linux app test; needs DLSS_FIXTURE_STEAM_ROOT and a display' \
		'  frontend-build       flutter build linux --release' \
		'  build                backend-build + frontend-build' \
		'  run-dev              fresh build/ dev data dir, then flutter run -d linux;' \
		'                       the app spawns backend/bin/dlssd itself. Stop with Ctrl+C.' \
		'                       See docs/spec-15-runbook.md.'

codegen:
	@./tools/codegen.sh

codegen-check:
	@./tools/codegen.sh
	@if [ -n "$$(git status --porcelain -- backend/gen frontend/lib/src/generated)" ]; then \
		echo 'codegen-check: generated code is out of date:' >&2; \
		git status --short -- backend/gen frontend/lib/src/generated >&2; \
		exit 1; \
	fi

backend-test:
	cd backend && go test ./...

# Integration tests start the real dlssd binary over a real Unix socket.
# They live under backend/integration and carry the integration build tag.
backend-integration:
	cd backend && go test -tags=integration -count=1 ./...

backend-build:
	@mkdir -p $(BIN_DIR)
	cd backend && go build -trimpath -ldflags '$(LDFLAGS)' -o $(BIN_DIR)/dlssd ./cmd/dlssd

frontend-test:
	cd frontend && flutter pub get && dart format --set-exit-if-changed . && flutter analyze && flutter test

# Opt-in: the test opens a Linux desktop window and starts the real sidecar.
# Exported paths point at a fixture Steam root and the built dlssd; the app
# itself creates a throwaway data directory. See docs/spec-15-runbook.md.
frontend-integration: backend-build
	@test -d frontend/integration_test || { \
		echo 'frontend-integration: frontend/integration_test is missing' >&2; \
		exit 1; \
	}
	@test -n "$$DLSS_FIXTURE_STEAM_ROOT" || { \
		echo 'frontend-integration: set DLSS_FIXTURE_STEAM_ROOT to a fixture Steam root' >&2; \
		exit 1; \
	}
	cd frontend && DLSS_INTEGRATION=1 \
		DLSSD_BIN=$(BIN_DIR)/dlssd \
		DLSS_EXPECTED_APP_VERSION=$(VERSION) \
		flutter test integration_test -d linux \
		--dart-define=APP_VERSION=$(VERSION)

frontend-build:
	cd frontend && flutter build linux --release --dart-define=APP_VERSION=$(VERSION)

build: backend-build frontend-build

# The frontend is the parent of dlssd and passes it the explicit paths below,
# so this target must not start a second daemon on the same socket. Every run
# starts from an empty development data directory; the real user data
# directory is never used.
run-dev:
	@case "$(DEV_DATA_DIR)" in $(BUILD_DIR)/*) ;; *) \
		echo 'run-dev: DEV_DATA_DIR must stay under $(BUILD_DIR)' >&2; exit 1;; esac
	@case "$(DEV_RUNTIME_DIR)" in $(BUILD_DIR)/*) ;; *) \
		echo 'run-dev: DEV_RUNTIME_DIR must stay under $(BUILD_DIR)' >&2; exit 1;; esac
	@rm -rf $(DEV_DATA_DIR) $(DEV_RUNTIME_DIR)
	@mkdir -p $(DEV_DATA_DIR) $(DEV_RUNTIME_DIR)
	$(MAKE) backend-build
	cd frontend && flutter run -d linux \
		--dart-define=APP_VERSION=$(VERSION) \
		--dart-define=DLSSD_BIN=$(BIN_DIR)/dlssd \
		--dart-define=DLSS_DATA_DIR=$(DEV_DATA_DIR) \
		--dart-define=DLSS_RUNTIME_DIR=$(DEV_RUNTIME_DIR)
