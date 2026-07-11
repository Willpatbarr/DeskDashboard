public struct GridLayout: Layout, Sendable {
    public let name: String
    public let columns: Int

    public init(
        name: String = "grid",
        columns: Int = 4
    ) {
        self.name = name
        self.columns = max(1, columns)
    }

    public func placement(
        for widgetID: WidgetID,
        configuration: WidgetConfiguration,
        at index: Int
    ) -> WidgetPlacement {
        let span = gridSpan(for: configuration.size)
        let columnSpan = min(span.columnSpan, columns)
        let rowSpan = span.rowSpan
        let baseColumn = index % columns
        let column = min(baseColumn, columns - columnSpan)
        let row = index / columns

        return WidgetPlacement(
            visibility: visibility(
                for: widgetID,
                configuration: configuration
            ),
            gridSlot: WidgetGridSlot(
                column: column,
                row: row,
                columnSpan: columnSpan,
                rowSpan: rowSpan
            )
        )
    }

    private func gridSpan(
        for size: WidgetSize
    ) -> (columnSpan: Int, rowSpan: Int) {
        switch size {
        case .automatic, .small:
            return (1, 1)
        case .medium:
            return (2, 1)
        case .large:
            return (2, 2)
        case let .custom(width, height):
            return (max(1, width), max(1, height))
        }
    }
}
