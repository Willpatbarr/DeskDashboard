//
//  WidgetModel.swift
//  DeskDashboard
//
//  Created by William Patrick Cluff Barr on 6/26/26.
//

protocol WidgetModel: AnyObject {
    func activate()
    func deactivate()
}

extension WidgetModel {
    func activate() {}
    func deactivate() {}
}
