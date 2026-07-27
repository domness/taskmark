.PHONY: bootstrap generate format lint test build check run-cli

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
	xcodebuild -project LocalTodo.xcodeproj -scheme LocalTodoApp -configuration Debug test CODE_SIGNING_ALLOWED=NO

build: generate
	xcodebuild -project LocalTodo.xcodeproj -scheme LocalTodoApp -configuration Debug build CODE_SIGNING_ALLOWED=NO

check: lint test build

run-cli:
	swift run localtodo --help
