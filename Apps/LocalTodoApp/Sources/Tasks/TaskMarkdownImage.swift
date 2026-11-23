import Foundation
import ImageIO
import SwiftUI

struct TaskMarkdownImageContext {
    let vault: URL
    let taskPath: String

    func localImageURL(_ destination: URL) -> URL? {
        guard destination.scheme == nil, destination.host == nil,
              !destination.path.isEmpty, !destination.path.hasPrefix("/")
        else { return nil }
        let root = vault.resolvingSymlinksInPath().standardizedFileURL
        let image = root.appendingPathComponent(taskPath).deletingLastPathComponent()
            .appendingPathComponent(destination.path).standardizedFileURL
        let directory = root.pathComponents
        let relative = image.pathComponents.dropFirst(directory.count)
        guard image.pathComponents.starts(with: directory),
              let first = relative.first,
              first.lowercased() != ".config"
        else { return nil }
        var component = root
        for name in relative {
            component.appendPathComponent(name)
            if (try? component.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
                return nil
            }
        }
        return image
    }
}

struct TaskMarkdownImage: View {
    let destination: URL
    let altText: String
    let context: TaskMarkdownImageContext?
    @State private var thumbnail: CGImage?

    var body: some View {
        let label = altText.isEmpty ? "Markdown image" : altText
        let file = context?.localImageURL(destination)
        Group {
            if ["https", "http"].contains(destination.scheme?.lowercased() ?? "") {
                Link(destination: destination) { Label(label, systemImage: "photo") }
                    .help("Open image in your browser")
            } else if let thumbnail {
                Image(thumbnail, scale: 1, label: Text(label))
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
            } else {
                Label(label, systemImage: "photo")
            }
        }
        .task(id: file) {
            thumbnail = nil
            guard let file else { return }
            let image = await Task.detached(priority: .utility) { loadMarkdownThumbnail(file) }.value
            if !Task.isCancelled {
                thumbnail = image
            }
        }
    }
}

private func loadMarkdownThumbnail(_ file: URL) -> CGImage? {
    guard let values = try? file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
          values.isRegularFile == true,
          let size = values.fileSize, size <= 25 * 1024 * 1024,
          let source = CGImageSourceCreateWithURL(file as CFURL, nil)
    else { return nil }
    return CGImageSourceCreateThumbnailAtIndex(source, 0, [
        kCGImageSourceThumbnailMaxPixelSize: 1200,
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
    ] as CFDictionary)
}
