import LocalTodoDomain

extension WorkspaceModel {
    var currentTaskSort: TaskSort {
        if route == .filters {
            return filterState.editor.sort
        }
        if case let .savedFilter(name) = route {
            return filterState.record?.filters.first { $0.name == name }?.query.sort ?? .path
        }
        return currentTaskListDisplayOptions.sort ?? route.defaultSort
    }

    func setTaskSort(_ sort: TaskSort) {
        disableCustomTaskOrder()
        if case let .savedFilter(name) = route {
            beginFilterEditing(name: name)
            disableCustomTaskOrder()
        }
        if route == .filters {
            filterState.editor.sort = sort
        } else {
            updateTaskListDisplayOptions { $0.sort = sort }
        }
    }

    var currentTaskListDisplayOptions: TaskListDisplayOptions {
        taskListDisplayOptionsByRoute[route.listPreferencesKey] ?? .defaults(for: route)
    }

    func setTaskListMetadata(_ field: TaskListMetadataField, isVisible: Bool) {
        updateTaskListDisplayOptions { options in
            switch field {
            case .project: options.showsProject = isVisible
            case .area: options.showsArea = isVisible
            case .tags: options.showsTags = isVisible
            }
        }
    }

    func setTaskListGrouping(_ grouping: TaskListGrouping) {
        updateTaskListDisplayOptions { $0.grouping = grouping }
    }

    func projectDisplayTitle(_ path: VaultPath) -> String {
        guard let project = snapshot?.projects[path]?.value else { return "Missing Project: \(path.value)" }
        let hasDuplicateTitle = snapshot?.projects.values.contains {
            $0.value.path != path && $0.value.title == project.title
        } == true
        return hasDuplicateTitle ? "\(project.title) (\(path.value))" : project.title
    }

    func areaDisplayTitle(_ path: VaultPath) -> String {
        guard let area = snapshot?.areas[path]?.value else { return "Missing Area: \(path.value)" }
        let hasDuplicateTitle = snapshot?.areas.values.contains {
            $0.value.path != path && $0.value.title == area.title
        } == true
        return hasDuplicateTitle ? "\(area.title) (\(path.value))" : area.title
    }

    private func updateTaskListDisplayOptions(_ update: (inout TaskListDisplayOptions) -> Void) {
        var options = currentTaskListDisplayOptions
        update(&options)
        taskListDisplayOptionsByRoute[route.listPreferencesKey] = options
        taskListDisplayPreferences.save(taskListDisplayOptionsByRoute)
    }
}
