//
//  AttachedWidget.swift
//  DeskDashboard
//
//  Created by William Barr on 6/29/26.
//

struct AttachedWidget {
    let id: WidgetID
    var widget: any Widget
    var visibility: WidgetVisibility
    var placement: WidgetPlacement
}
