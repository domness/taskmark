enum TagValidation {
    static func validate(_ tags: [String]) throws {
        var seen = Set<String>()

        for tag in tags {
            guard !tag.isEmpty, tag == tag.trimmingCharacters(in: .whitespacesAndNewlines), !tag.hasPrefix("#") else {
                throw DomainValidationError.invalidTag(tag)
            }
            guard seen.insert(tag).inserted else {
                throw DomainValidationError.duplicateTag(tag)
            }
        }
    }
}
