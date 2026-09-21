import Foundation
@testable import LocalTodoApp
import Testing

struct CLIInstallerTests {
    @Test func registrationRunsBundledCLIAndTracksUpdates() throws {
        let fixture = try RegistrationFixture()
        defer { fixture.remove() }
        let source = CLIInstaller.bundledExecutable()
        try fixture.run(enabled: true, source: source)
        #expect(CLIInstaller.isRegistered(source: source, destination: fixture.destination))
        let process = Process()
        let output = Pipe()
        process.executableURL = fixture.destination
        process.arguments = ["--help"]
        process.standardOutput = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        #expect(String(data: data, encoding: .utf8)?.contains("USAGE: taskmark") == true)
        try fixture.run(enabled: true, source: source)
        try fixture.run(enabled: false, source: source)
        #expect(!FileManager.default.fileExists(atPath: fixture.destination.path))
        #expect(FileManager.default.isExecutableFile(atPath: source.path))
        try fixture.run(enabled: false, source: source)
    }

    @Test func quotesPathsAndRepairsMovedApplicationLink() throws {
        let fixture = try RegistrationFixture()
        defer { fixture.remove() }
        let oldSource = fixture.root.appendingPathComponent("Old/Taskmark.app/Contents/Helpers/taskmark")
        try FileManager.default.createDirectory(
            at: fixture.destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createSymbolicLink(at: fixture.destination, withDestinationURL: oldSource)
        let newSource = fixture.root
            .appendingPathComponent("New 'quoted' \"app\" $HOME `id` \\ folder/Taskmark.app/Contents/Helpers/taskmark")
        try FileManager.default.createDirectory(
            at: newSource.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.copyItem(at: CLIInstaller.bundledExecutable(), to: newSource)
        #expect(!CLIInstaller.isRegistered(source: newSource, destination: fixture.destination))
        try fixture.run(enabled: true, source: newSource)
        #expect(CLIInstaller.isRegistered(source: newSource, destination: fixture.destination))
        // An in-place app update is immediately visible through the registered symlink.
        try Data("updated executable".utf8).write(to: newSource, options: .atomic)
        #expect(try Data(contentsOf: fixture.destination) == Data("updated executable".utf8))
        try fixture.run(enabled: false, source: newSource)
        #expect(try Data(contentsOf: newSource) == Data("updated executable".utf8))
    }

    @Test func preservesExistingFilesAndUnrelatedLinks() throws {
        let fixture = try RegistrationFixture()
        defer { fixture.remove() }
        let files = FileManager.default
        let source = CLIInstaller.bundledExecutable()
        try files.createDirectory(
            at: fixture.destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let original = Data("existing command".utf8)
        try original.write(to: fixture.destination)
        for enabled in [true, false] {
            #expect(try fixture.status(enabled: enabled, source: source) != 0)
            #expect(try Data(contentsOf: fixture.destination) == original)
        }
        try files.removeItem(at: fixture.destination)
        let foreign = fixture.root.appendingPathComponent("other-command")
        try original.write(to: foreign)
        try files.createSymbolicLink(at: fixture.destination, withDestinationURL: foreign)
        for enabled in [true, false] {
            #expect(try fixture.status(enabled: enabled, source: source) != 0)
            #expect(try files.destinationOfSymbolicLink(atPath: fixture.destination.path) == foreign.path)
            #expect(try Data(contentsOf: foreign) == original)
        }
    }

    @Test func missingSourceDoesNotChangeRegistration() throws {
        let fixture = try RegistrationFixture()
        defer { fixture.remove() }
        let source = CLIInstaller.bundledExecutable()
        try fixture.run(enabled: true, source: source)
        #expect(try fixture.status(enabled: true, source: fixture.root.appendingPathComponent("missing")) != 0)
        #expect(CLIInstaller.isRegistered(source: source, destination: fixture.destination))
    }

    @Test func appleScriptPreservesShellCommandQuoting() throws {
        let fixture = try RegistrationFixture()
        defer { fixture.remove() }
        let command = CLIRegistrationScript.command(
            enabled: true, source: CLIInstaller.bundledExecutable(), destination: fixture.destination
        )
        // Exercise the real AppleScript-to-shell boundary without modifying system paths or asking for privileges.
        let text = CLIRegistrationScript.authorizationScript(command: command)
            .replacingOccurrences(of: " with administrator privileges", with: "")
        let script = try #require(NSAppleScript(source: text))
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        #expect(error == nil)
        #expect(CLIInstaller.isRegistered(source: CLIInstaller.bundledExecutable(), destination: fixture.destination))
    }
}

private struct RegistrationFixture {
    let root: URL
    var destination: URL {
        root.appendingPathComponent("bin 'quoted' \"double\" $HOME \\ folder/taskmark")
    }

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("taskmark-registration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }

    func run(enabled: Bool, source: URL) throws {
        #expect(try status(enabled: enabled, source: source) == 0)
    }

    func status(enabled: Bool, source: URL) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c",
            CLIRegistrationScript.command(enabled: enabled, source: source, destination: destination),
        ]
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}
