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

    /// First-fit occupancy packing: each widget takes the top-most,
    /// left-most slot its span fits into, so spanned widgets never overlap.
    public func placements(
        for items: [LayoutItem]
    ) -> [WidgetID: WidgetPlacement] {
        var occupiedCells = Set<GridCell>()
        var placements: [WidgetID: WidgetPlacement] = [:]

        for item in items {
            let span = gridSpan(for: item.configuration.size)
            let slot = firstFreeSlot(
                columnSpan: min(span.columnSpan, columns),
                rowSpan: max(1, span.rowSpan),
                occupiedCells: occupiedCells
            )

            occupiedCells.formUnion(cells(in: slot))
            placements[item.id] = WidgetPlacement(
                visibility: visibility(
                    for: item.id,
                    configuration: item.configuration
                ),
                gridSlot: slot
            )
        }

        return placements
    }

    private struct GridCell: Hashable {
        let column: Int
        let row: Int
    }

    private func firstFreeSlot(
        columnSpan: Int,
        rowSpan: Int,
        occupiedCells: Set<GridCell>
    ) -> WidgetGridSlot {
        var row = 0

        while true {
            for column in 0...(columns - columnSpan) {
                let slot = WidgetGridSlot(
                    column: column,
                    row: row,
                    columnSpan: columnSpan,
                    rowSpan: rowSpan
                )

                if cells(in: slot).isDisjoint(with: occupiedCells) {
                    return slot
                }
            }

            row += 1
        }
    }

    private func cells(
        in slot: WidgetGridSlot
    ) -> Set<GridCell> {
        var cells = Set<GridCell>()

        for row in slot.row ..< slot.row + slot.rowSpan {
            for column in slot.column ..< slot.column + slot.columnSpan {
                cells.insert(GridCell(column: column, row: row))
            }
        }

        return cells
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
