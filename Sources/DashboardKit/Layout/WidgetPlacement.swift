//
//  WidgetPlacement.swift
//  DeskDashboard
//
//  Created by William Barr on 6/30/26.
//

public struct WidgetPlacement: Equatable, Sendable {
    public var visibility: WidgetVisibility
    public var region: LayoutRegion?
    public var gridSlot: WidgetGridSlot?
    
    public init(
        visibility: WidgetVisibility = .visible,
        region: LayoutRegion? = nil,
        gridSlot: WidgetGridSlot? = nil,
    ) {
        self.visibility = visibility
        self.region = region
        self.gridSlot = gridSlot
    }
}

public struct WidgetGridSlot: Equatable, Sendable {
    public var column: Int
    public var row: Int
    public var columnSpan: Int
    public var rowSpan: Int

    public init(
        column: Int,
        row: Int,
        columnSpan: Int = 1,
        rowSpan: Int = 1
    ) {
        self.column = column
        self.row = row
        self.columnSpan = columnSpan
        self.rowSpan = rowSpan
    }
}
