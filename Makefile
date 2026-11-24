.PHONY: bootstrap generate format lint test test-unit test-macos test-ios test-ios-unit test-ios-phone test-ios-tablet \
	test-release-scripts build build-ios check-ios-destinations check-ios-phone check-ios-tablet prepare-ios-phone \
	prepare-ios-tablet check run-cli

XCODEBUILD_ARGS ?= -destination 'platform=macOS'
XCODE_TEST_ARGS ?=
IOS_SIMULATOR_NAME ?= iPhone 16 Pro
IOS_SIMULATOR_ID = $(shell xcrun simctl list devices available | sed -nE 's/^[[:space:]]+$(IOS_SIMULATOR_NAME) \(([0-9A-F-]+)\).*/\1/p' | head -n 1)
IOS_DESTINATION ?= platform=iOS Simulator,id=$(IOS_SIMULATOR_ID)
IOS_TABLET_SIMULATOR_ID = $(shell xcrun simctl list devices available | sed -nE 's/^[[:space:]]+iPad.* \(([0-9A-F-]+)\) \((Booted|Shutdown)\).*/\1/p' | head -n 1)
IOS_TABLET_DESTINATION ?= platform=iOS Simulator,id=$(IOS_TABLET_SIMULATOR_ID)
IOS_TEST_RESULT_DIR ?=
IOS_TEST_RESULT_ARGS = $(if $(IOS_TEST_RESULT_DIR),-resultBundlePath '$(IOS_TEST_RESULT_DIR)/LocalTodoIOSApp-$(1).xcresult')
IOS_TEST = xcodebuild -project LocalTodo.xcodeproj -scheme LocalTodoIOSApp -configuration Debug test CODE_SIGNING_ALLOWED=NO

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

test: test-unit test-macos

test-unit:
	swift test

test-macos: generate
	xcodebuild -project LocalTodo.xcodeproj -scheme LocalTodoApp -configuration Debug test CODE_SIGNING_ALLOWED=NO $(XCODEBUILD_ARGS) $(XCODE_TEST_ARGS)

build: generate
	xcodebuild -project LocalTodo.xcodeproj -scheme LocalTodoApp -configuration Debug build CODE_SIGNING_ALLOWED=NO $(XCODEBUILD_ARGS)

check-ios-destinations: check-ios-phone check-ios-tablet

check-ios-phone:
	@if [ -z "$(IOS_SIMULATOR_ID)" ]; then echo "No available $(IOS_SIMULATOR_NAME) simulator found."; exit 1; fi

check-ios-tablet:
	@if [ -z "$(IOS_TABLET_SIMULATOR_ID)" ]; then echo "No available iPad simulator found."; exit 1; fi

prepare-ios-phone: generate check-ios-phone
	$(if $(IOS_TEST_RESULT_DIR),mkdir -p '$(IOS_TEST_RESULT_DIR)')
	bash scripts/wait-for-ios-test-simulator '$(IOS_DESTINATION)'

prepare-ios-tablet: generate check-ios-tablet
	$(if $(IOS_TEST_RESULT_DIR),mkdir -p '$(IOS_TEST_RESULT_DIR)')
	bash scripts/wait-for-ios-test-simulator '$(IOS_TABLET_DESTINATION)'

test-ios: test-ios-unit test-ios-phone test-ios-tablet

test-ios-unit: prepare-ios-phone
	$(IOS_TEST) -destination '$(IOS_DESTINATION)' -parallel-testing-enabled NO \
		$(call IOS_TEST_RESULT_ARGS,Unit) -only-testing:LocalTodoIOSAppTests

test-ios-phone: prepare-ios-phone
	$(IOS_TEST) -destination '$(IOS_DESTINATION)' \
		$(call IOS_TEST_RESULT_ARGS,Phone) -only-testing:LocalTodoIOSAppUITests

test-ios-tablet: prepare-ios-tablet
	$(IOS_TEST) -destination '$(IOS_TABLET_DESTINATION)' -parallel-testing-enabled NO \
		$(call IOS_TEST_RESULT_ARGS,Tablet) \
		-only-testing:LocalTodoIOSAppUITests/TaskmarkIOSUITests/testTabletAdaptiveWorkspaceShowsSidebarListAndDetail \
		-only-testing:LocalTodoIOSAppUITests/SampleVaultUITests

build-ios: generate
	xcodebuild -project LocalTodo.xcodeproj -scheme LocalTodoIOSApp -configuration Debug build CODE_SIGNING_ALLOWED=NO -destination '$(IOS_DESTINATION)'

test-release-scripts:
	python3 -B scripts/test-appcast.py
	python3 -B scripts/test-commit-validation.py
	python3 scripts/test-release-scripts.py
	python3 scripts/test-release-source.py
	python3 scripts/test-ci-signing.py
	python3 -B scripts/test-github-actions-config.py
	python3 -B scripts/test-ios-test-simulator.py
	python3 -B scripts/test-make-test-lanes.py
	bash -n scripts/check-macos-runner
	bash -n scripts/install-ci-swiftformat
	bash -n scripts/wait-for-ios-test-simulator
	bash -n scripts/package-macos-release
	bash -n scripts/notarytool-with-keychain
	bash -n scripts/resolve-release-source
	bash -n scripts/setup-ci-signing

check: lint test-release-scripts test build test-ios build-ios

run-cli:
	swift run taskmark --help
