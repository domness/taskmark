import LocalTodoDomain
import SwiftUI

struct ProjectSidebarSection: View {
    let model: WorkspaceModel

    var body: some View {
        let paths = model.orderedCollectionPaths(.project)
        let session = model.vaultSession
        Section("Projects") {
            ForEach(paths, id: \.self) { path in
                if let project = model.snapshot?.projects[path]?.value {
                    projectRoute(project)
                }
            }
            .onMove { offsets, destination in
                _ = model.moveCollections(from: offsets, to: destination, in: .project, paths: paths, session: session)
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
            Divider()
            Button("Delete Project", role: .destructive) {
                Task { await model.deleteCollection(at: project.path) }
            }
        }
    }
}
