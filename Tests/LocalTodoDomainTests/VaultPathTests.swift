import LocalTodoDomain
import Testing

@Test func vaultPathNormalizesSeparators() throws {
    let path = try VaultPath("Projects\\Local Todo.md")

    #expect(path.value == "Projects/Local Todo.md")
}

@Test(arguments: ["/Task.md", "../Task.md", "Tasks/", "Task.txt", "Tasks//Task.md"])
func vaultPathRejectsUnsafeValues(value: String) {
    #expect(throws: DomainValidationError.invalidVaultPath) {
        try VaultPath(value)
    }
}
