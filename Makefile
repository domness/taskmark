.PHONY: bootstrap generate format lint test test-release-scripts build check run-cli

XCODEBUILD_ARGS ?= -destination 'platform=macOS'
XCODE_TEST_ARGS ?=

bootstrap:
	swift package resolve
	xcodegen generate
	git config core.hooksPath .githooks

generate:
	xcodegen generate

format:
	swiftformat Apps Sources Tests Package.swift

lint:
	swiftformat Apps Sources Tests Package.swift --lint
	swiftlint lint --strict

test: generate
	swift test
	xcodebuild -project LocalTodo.xcodeproj -scheme LocalTodoApp -configuration Debug test CODE_SIGNING_ALLOWED=NO $(XCODEBUILD_ARGS) $(XCODE_TEST_ARGS)

build: generate
	xcodebuild -project LocalTodo.xcodeproj -scheme LocalTodoApp -configuration Debug build CODE_SIGNING_ALLOWED=NO $(XCODEBUILD_ARGS)

test-release-scripts:
	python3 scripts/test-release-scripts.py
	bash -n scripts/check-macos-runner
	bash -n scripts/package-macos-release
	bash -n scripts/notarytool-with-keychain

check: lint test-release-scripts test build

run-cli:
	swift run localtodo --help
