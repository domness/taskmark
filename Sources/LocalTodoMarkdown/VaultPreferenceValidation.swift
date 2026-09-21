import LocalTodoDomain

enum VaultPreferenceValidation {
    static func validate(_ preferences: [String: ConfigurationValue]) throws {
        try validateScalars(preferences)
        try validateOrders(preferences)
        try validateViews(preferences["views"])
    }

    private static func validateScalars(_ preferences: [String: ConfigurationValue]) throws {
        let enums = [
            "appearance": ["system", "light", "dark"],
            "theme": ["standard", "slate", "forest", "sand", "catppuccin", "dracula"],
            "date_format": ["system", "iso", "dayFirst", "monthFirst"],
            "time_format": ["system", "twelveHour", "twentyFourHour"],
            "initial_view": ["today", "inbox", "next", "upcoming", "waiting", "someday", "all", "search"],
        ]
        for (key, choices) in enums {
            if let value = preferences[key] {
                guard case let .string(raw) = value, choices.contains(raw) else { throw invalid(key) }
            }
        }
        if let value = preferences["week_start"] {
            guard case let .integer(day) = value, (1 ... 7).contains(day) else { throw invalid("week_start") }
        }
        if let value = preferences["vault_stylesheet"] {
            guard case .bool = value else { throw invalid("vault_stylesheet") }
        }
    }

    private static func validateOrders(_ preferences: [String: ConfigurationValue]) throws {
        let sidebar = try mapping(preferences["sidebar_order"], field: "sidebar_order")
        for key in ["project", "area"] {
            if let value = sidebar[key] {
                try paths(value, field: "sidebar_order.\(key)")
            }
        }
        for (_, value) in try mapping(preferences["custom_order"], field: "custom_order") {
            let order = try mapping(value, field: "custom_order entry")
            guard case .bool = order["isEnabled"], let entries = order["paths"] else { throw invalid("custom_order") }
            try paths(entries, field: "custom_order.paths")
        }
    }

    private static func validateViews(_ value: ConfigurationValue?) throws {
        for (_, value) in try mapping(value, field: "views") {
            let view = try mapping(value, field: "views entry")
            for key in ["showsProject", "showsArea", "showsTags"] {
                guard case .bool = view[key] else { throw invalid("views.\(key)") }
            }
            guard case let .string(group) = view["grouping"], ["none", "project", "area"].contains(group) else {
                throw invalid("views.grouping")
            }
            if let sort = view["sort"], sort != .null {
                guard case let .string(raw) = sort, TaskSort(rawValue: raw) != nil else { throw invalid("views.sort") }
            }
        }
    }

    private static func mapping(_ value: ConfigurationValue?, field: String) throws -> [String: ConfigurationValue] {
        guard let value else { return [:] }
        guard case let .object(mapping) = value else { throw invalid(field) }
        return mapping
    }

    private static func paths(_ value: ConfigurationValue, field: String) throws {
        guard case let .array(entries) = value else { throw invalid(field) }
        var seen = Set<String>()
        for entry in entries {
            guard case let .string(path) = entry, seen.insert(path).inserted else { throw invalid(field) }
            _ = try VaultPath(path)
        }
    }

    private static func invalid(_ field: String) -> VaultStoreError {
        .invalidVault("Invalid shared preference: \(field)")
    }
}
