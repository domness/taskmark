import LocalTodoMarkdown
import Testing

@Test func vaultConfigurationRoundTripsThroughYAML() throws {
    let configuration = VaultConfiguration(timezone: "Europe/London")

    let yaml = try configuration.encoded()
    let decoded = try VaultConfiguration.decode(yaml: yaml)

    #expect(decoded == configuration)
}

@Test(arguments: ["true", "false"])
func dockBadgePreferenceRoundTrips(value: String) throws {
    let configuration = try VaultConfiguration.decode(yaml: "schema: 2\npreferences:\n  dock_badge: \(value)\n")
    #expect(configuration.preferences["dock_badge"] == .bool(value == "true"))
    #expect(try VaultConfiguration.decode(yaml: configuration.encoded()) == configuration)
}

@Test(arguments: ["null", "1", "enabled", "[]", "{}"])
func invalidDockBadgePreferenceIsRejected(value: String) {
    #expect(throws: (any Error).self) {
        try VaultConfiguration.decode(yaml: "schema: 2\npreferences:\n  dock_badge: \(value)\n")
    }
}
