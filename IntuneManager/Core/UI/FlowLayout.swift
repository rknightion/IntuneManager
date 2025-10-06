import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (rowIndex, element) in result.rows.enumerated() {
            let rowY = result.yOffsets[rowIndex]
            var x = bounds.minX
            for (elementIndex, subviewIndex) in element.indices.enumerated() {
                let subviewSize = element.sizes[elementIndex]
                let proposal = ProposedViewSize(subviewSize)
                subviews[subviewIndex]
                    .place(at: CGPoint(x: x, y: bounds.minY + rowY), proposal: proposal)
                x += subviewSize.width + (elementIndex < element.indices.count - 1 ? spacing : 0)
            }
        }
    }

    struct FlowResult {
        var rows: [Row] = []
        var yOffsets: [CGFloat] = []
        var size: CGSize = .zero

        struct Row {
            var indices: [Int] = []
            var sizes: [CGSize] = []
            var height: CGFloat = 0
        }

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var current = Row()
            var x: CGFloat = 0
            var y: CGFloat = 0
            var subviewIndex = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > width && !current.indices.isEmpty {
                    finishRow(&current, y: &y, yOffsets: &yOffsets, rows: &rows, spacing: spacing)
                    x = 0
                    current = Row()
                }

                current.indices.append(subviewIndex)
                current.sizes.append(size)
                current.height = max(current.height, size.height)
                x += size.width + spacing
                subviewIndex += 1
            }

            if !current.indices.isEmpty {
                finishRow(&current, y: &y, yOffsets: &yOffsets, rows: &rows, spacing: spacing)
            }

            size = CGSize(width: width, height: y)
        }

        private func finishRow(_ row: inout Row, y: inout CGFloat, yOffsets: inout [CGFloat], rows: inout [Row], spacing: CGFloat) {
            yOffsets.append(y)
            rows.append(row)
            y += row.height + spacing
        }
    }
}