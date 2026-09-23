import SwiftUI

/// Fits tokens to the inspector width, wrapping complete tokens onto the next line.
struct TagFlowLayout: Layout {
    var spacing: CGFloat = 6
    var alignment: HorizontalAlignment = .leading

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        arrange(subviews, width: proposal.width ?? 300).size
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let result = arrange(subviews, width: bounds.width)
        let rowEnds = result.frames.reduce(into: [CGFloat: CGFloat]()) { rows, frame in
            rows[frame.minY] = max(rows[frame.minY] ?? 0, frame.maxX)
        }
        for (index, subview) in subviews.enumerated() {
            let frame = result.frames[index]
            let rowEnd = rowEnds[frame.minY] ?? 0
            let offset = alignment == .trailing ? max(0, bounds.width - rowEnd) : 0
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX + offset, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> (size: CGSize, frames: [CGRect]) {
        var frames: [CGRect] = []
        var originX: CGFloat = 0
        var originY: CGFloat = 0
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if originX > 0, originX + size.width > width {
                originX = 0
                originY += lineHeight + spacing
                lineHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: originX, y: originY), size: size))
            originX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return (CGSize(width: width, height: originY + lineHeight), frames)
    }
}
