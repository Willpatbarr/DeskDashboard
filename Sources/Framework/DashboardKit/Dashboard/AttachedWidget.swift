// AttachedWidget.swift — A widget bound into a running dashboard, plus the snapshot renderers consume.

//
//  AttachedWidget.swift
//  DeskDashboard
//
//  Created by William Barr on 6/29/26.
//

import Foundation

struct AttachedWidget {
    let id: WidgetID
    var widget: any Widget
    var placement: WidgetPlacement
    var lastTickDate: Date?
}

public struct AttachedWidgetSnapshot: Equatable, Sendable {
    public let id: WidgetID
    public let configuration: WidgetConfiguration
    public let placement: WidgetPlacement
    public let content: WidgetContent?

    public init(
        id: WidgetID,
        configuration: WidgetConfiguration,
        placement: WidgetPlacement,
        content: WidgetContent? = nil
    ) {
        self.id = id
        self.configuration = configuration
        self.placement = placement
        self.content = content
    }
}
