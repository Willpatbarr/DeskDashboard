// LayoutRegion.swift — Named region of a layout a widget can be placed into.

//
//  LayoutRegion.swift
//  DeskDashboard
//
//  Created by William Barr on 6/30/26.
//

public struct LayoutRegion: Hashable, Sendable {
    public var rawValue: String
    
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}
