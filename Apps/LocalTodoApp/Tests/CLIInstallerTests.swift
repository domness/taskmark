import Foundation
@testable import LocalTodoApp
import Testing

@Test func bundledCLIInstallsAndRunsOutsideTheApp() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("taskmark-cli-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let destination = root.appendingPathComponent("taskmark")
    let source = CLIInstaller.bundledExecutable()
    try CLIInstaller.install(from: source, to: destination)
    #expect(FileManager.default.isExecutableFile(atPath: destination.path))
    #expect(try Data(contentsOf: source) == Data(contentsOf: destination))
    let process = Process()
    let output = Pipe()
    process.executableURL = destination
    process.arguments = ["--help"]
    process.standardOutput = output
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    #expect(process.terminationStatus == 0)
    #expect(String(data: data, encoding: .utf8)?.contains("USAGE: taskmark") == true)
    // Reinstall replaces an existing file with the current bundled executable.
    try Data("old version".utf8).write(to: destination)
    try CLIInstaller.install(from: source, to: destination)
    #expect(try Data(contentsOf: destination) == Data(contentsOf: source))
}

@Test func missingCLILeavesExistingDestinationUntouched() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("taskmark-cli-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let destination = root.appendingPathComponent("taskmark")
    let original = Data("existing command".utf8)
    try original.write(to: destination)
    #expect(throws: CLIInstallationError.self) {
        try CLIInstaller.install(from: root.appendingPathComponent("missing"), to: destination)
    }
    #expect(try Data(contentsOf: destination) == original)
    #expect(throws: CLIInstallationError.self) {
        try CLIInstaller.install(from: CLIInstaller.bundledExecutable(), to: CLIInstaller.bundledExecutable())
    }
}
