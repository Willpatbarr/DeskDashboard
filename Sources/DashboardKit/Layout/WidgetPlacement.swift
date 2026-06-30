//
//  WidgetPlacement.swift
//  DeskDashboard
//
//  Created by William Barr on 6/30/26.
//

public struct WidgetPlacement: Equatable, Sendable {
    public var visibility: WidgetVisibility
    public var region: LayoutRegion?
    
    public init(
        visibility: WidgetVisibility = .visible,
        region: LayoutRegion? = nil,
    ) {
        self.visibility = visibility
        self.region = region
    }
}
