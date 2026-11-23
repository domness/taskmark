import SwiftUI

/// SwiftUI Text renders inline styles and links; image runs need a separate native view.
struct TaskMarkdownText: View {
    let text: AttributedString
    let imageContext: TaskMarkdownImageContext?

    var body: some View {
        if text.runs.contains(where: { $0.imageURL != nil }) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    if let url = segment.url {
                        TaskMarkdownImage(
                            destination: url,
                            altText: String(segment.text.characters),
                            context: imageContext
                        )
                    } else if !segment.text.characters.allSatisfy(\.isWhitespace) {
                        Text(segment.text)
                    }
                }
            }
        } else {
            Text(text)
        }
    }

    private var segments: [Segment] {
        var result: [Segment] = []
        for run in text.runs {
            let slice = text[run.range]
            if let last = result.indices.last, result[last].url == run.imageURL {
                result[last].text.append(AttributedString(slice))
            } else {
                result.append(Segment(url: run.imageURL, text: AttributedString(slice)))
            }
        }
        return result
    }

    private struct Segment {
        let url: URL?
        var text: AttributedString
    }
}
