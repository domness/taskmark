import LocalTodoMarkdown
import Testing

@Test func vaultConfigurationRoundTripsThroughYAML() throws {
    let configuration = VaultConfiguration(timezone: "Europe/London")

    let yaml = try configuration.encoded()
    let decoded = try VaultConfiguration.decode(yaml: yaml)

    #expect(decoded == configuration)
}
