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

@Test(arguments: [".localtodo/Task.md", ".localtodo\\Task.md", "Tasks/Bad\0Name.md", "\0Task.md"])
func vaultPathRejectsReservedAndNULValues(value: String) {
    #expect(throws: DomainValidationError.invalidVaultPath) {
        try VaultPath(value)
    }
}

@Test(arguments: ["Tasks/.localtodo/Task.md", ".localtodo.md", ".localtodo-backup/Task.md", "Tasks/Case.md"])
func vaultPathPreservesAllowedValues(value: String) throws {
    #expect(try VaultPath(value).value == value)
}
