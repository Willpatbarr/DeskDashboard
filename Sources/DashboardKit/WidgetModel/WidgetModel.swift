//
//  WidgetModel.swift
//  DeskDashboard
//
//  Created by William Patrick Cluff Barr on 6/26/26.
//

public protocol WidgetModel: AnyObject {
    func activate()
    func deactivate()
}

public extension WidgetModel {
    func activate() {}
    func deactivate() {}
}
