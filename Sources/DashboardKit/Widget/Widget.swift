//
//  Widget.swift
//  DeskDashboard
//
//  Created by William Patrick Cluff Barr on 6/26/26.
//

protocol Widget  {
    associatedtype Model: WidgetModel
    
    func makeModel(
        environment: DashboardEnvironment
    ) -> Model
}
