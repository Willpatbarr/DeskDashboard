// WidgetModel.swift — Widget model lifecycle: activate, update, tick, deactivate.

//
//  WidgetModel.swift
//  DeskDashboard
//
//  Created by William Patrick Cluff Barr on 6/26/26.
//

public protocol WidgetModel: AnyObject {
    func activate()
    func deactivate()
    func update(environment: DashboardEnvironment)
    func tick(
        _ tick: DashboardTick,
        environment: DashboardEnvironment
    )
}

public extension WidgetModel {
    func activate() {}
    func deactivate() {}
    func update(environment: DashboardEnvironment) {}
    func tick(
        _ tick: DashboardTick,
        environment: DashboardEnvironment
    ) {}
}
