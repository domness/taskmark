// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LocalTodo",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        .library(name: "LocalTodoDomain", targets: ["LocalTodoDomain"]),
        .library(name: "LocalTodoMarkdown", targets: ["LocalTodoMarkdown"]),
        .library(name: "LocalTodoWorkspace", targets: ["LocalTodoWorkspace"]),
        .library(name: "LocalTodoPresentation", targets: ["LocalTodoPresentation"]),
        .executable(name: "taskmark", targets: ["LocalTodoCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/jpsim/Yams", from: "6.0.2"),
    ],
    targets: [
        .target(name: "LocalTodoDomain"),
        .target(
            name: "LocalTodoMarkdown",
            dependencies: [
                "LocalTodoDomain",
                .product(name: "Yams", package: "Yams"),
            ]
        ),
        .target(
            name: "LocalTodoWorkspace",
            dependencies: ["LocalTodoDomain", "LocalTodoMarkdown"]
        ),
        .target(name: "LocalTodoPresentation"),
        .executableTarget(
            name: "LocalTodoCLI",
            dependencies: [
                "LocalTodoDomain",
                "LocalTodoMarkdown",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "LocalTodoDomainTests",
            dependencies: ["LocalTodoDomain"]
        ),
        .testTarget(
            name: "LocalTodoMarkdownTests",
            dependencies: ["LocalTodoMarkdown"],
            resources: [.process("Fixtures")]
        ),
        .testTarget(
            name: "LocalTodoWorkspaceTests",
            dependencies: ["LocalTodoWorkspace", "LocalTodoMarkdown"]
        ),
        .testTarget(
            name: "LocalTodoPresentationTests",
            dependencies: ["LocalTodoPresentation"]
        ),
        .testTarget(
            name: "LocalTodoCLITests",
            dependencies: ["LocalTodoCLI", "LocalTodoMarkdown"]
        ),
    ]
)
