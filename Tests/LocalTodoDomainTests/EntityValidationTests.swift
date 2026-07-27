import LocalTodoDomain
import Testing

@Test func taskRejectsDuplicateAndInvalidTags() throws {
    #expect(throws: DomainValidationError.duplicateTag("swift")) {
        try makeTask(tags: ["swift", "swift"])
    }
    #expect(throws: DomainValidationError.invalidTag("#swift")) {
        try makeTask(tags: ["#swift"])
    }
}

@Test func taskRejectsInconsistentCompletionTimestamp() throws {
    #expect(throws: DomainValidationError.invalidCompletionState) {
        try TodoTask(
            path: VaultPath("Tasks/Test.md"),
            title: "Test",
            status: .done,
            createdAt: testNow,
            updatedAt: testNow
        )
    }
}

@Test func projectAndAreaValidateTitles() throws {
    #expect(throws: DomainValidationError.emptyTitle) {
        try Project(
            path: VaultPath("Projects/Test.md"),
            title: "  ",
            status: .active,
            createdAt: testNow,
            updatedAt: testNow
        )
    }
    #expect(throws: DomainValidationError.emptyTitle) {
        try Area(
            path: VaultPath("Areas/Test.md"),
            title: "\n",
            status: .active,
            createdAt: testNow,
            updatedAt: testNow
        )
    }
}
