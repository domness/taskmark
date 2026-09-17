import LocalTodoDomain
import SwiftUI

struct ProjectSidebarSection: View {
    let model: WorkspaceModel

    var body: some View {
        Section("Projects") {
            ForEach(model.orderedCollectionPaths(.project), id: \.self) { path in
                if let project = model.snapshot?.projects[path]?.value {
                    projectRoute(project)
                }
            }
            if !model.inactiveProjects.isEmpty {
                DisclosureGroup("Inactive Projects") {
                    ForEach(model.inactiveProjects, id: \.path) { project in
                        projectRoute(project)
                    }
                }
            }
            Button("New Project", systemImage: "plus") { model.newEntityKind = .project }
        }
    }

    private func projectRoute(_ project: Project) -> some View {
        SidebarAssignmentRoute(
            model: model, route: .project(project.path),
            title: model.projectDisplayTitle(project.path)
                + (project.status == .active ? "" : " — \(project.status.rawValue.capitalized)"),
            systemImage: project.status == .done ? "checkmark.circle" : "square.stack",
            target: .project(project.path)
        )
        .contextMenu {
            Button("Edit Project") {
                model.route = .project(project.path)
                model.editProject()
            }
            CollectionOrderActions(model: model, path: project.path, collection: .project)
        }
    }
}
