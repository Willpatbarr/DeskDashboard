import DashboardKit
import Foundation

/// Development-only renderer: draws snapshots as text tiles in the terminal.
public struct ConsoleRenderer {
    public init() {}

    public func render(
        _ snapshots: [AttachedWidgetSnapshot]
    ) {
        var output = "\u{001B}[2J\u{001B}[H"

        for snapshot in snapshots {
            guard snapshot.placement.visibility == .visible,
                  let content = snapshot.content else {
                continue
            }

            output += tile(for: content)
            output += "\n"
        }

        print(output, terminator: "")
    }

    private func tile(
        for content: WidgetContent
    ) -> String {
        var lines: [String] = [content.primaryText]

        if let secondaryText = content.secondaryText {
            lines.append(secondaryText)
        }

        if !content.metadata.isEmpty {
            lines.append(
                content.metadata
                    .map { "\($0.label): \($0.value)" }
                    .joined(separator: " · ")
            )
        }

        let title = content.title ?? ""
        let width = max(
            lines.map(\.count).max() ?? 0,
            title.count + 2
        )

        var tile = "┌─ \(title) " + String(
            repeating: "─",
            count: max(width - title.count - 2, 0)
        ) + "─┐\n"

        for line in lines {
            let padding = String(
                repeating: " ",
                count: width - line.count
            )
            tile += "│ \(line)\(padding) │\n"
        }

        tile += "└" + String(repeating: "─", count: width + 2) + "┘\n"
        return tile
    }
}
