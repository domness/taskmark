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

@Test(arguments: [".config/Task.md", ".config\\Task.md", "Tasks/Bad\0Name.md", "\0Task.md"])
func vaultPathRejectsReservedAndNULValues(value: String) {
    #expect(throws: DomainValidationError.invalidVaultPath) {
        try VaultPath(value)
    }
}

@Test(arguments: ["Tasks/.config/Task.md", ".config.md", ".config-backup/Task.md", "Tasks/Case.md"])
func vaultPathPreservesAllowedValues(value: String) throws {
    #expect(try VaultPath(value).value == value)
}
