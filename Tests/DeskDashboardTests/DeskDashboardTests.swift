import Testing
@testable import DashboardKit

@Test func widgetModifiersReturnConfiguredCopies() {
    let widget = TestWidget()
        .id("clock")
        .title("Clock")
        .size(.large)
        .priority(.high)
        .hidden()
        .refreshRate(.seconds(1))

    #expect(widget.configuration.id?.rawValue == "clock")
    #expect(widget.configuration.title == "Clock")
    #expect(widget.configuration.size == .large)
    #expect(widget.configuration.priority == .high)
    #expect(widget.configuration.isHidden)
    #expect(widget.configuration.refreshRate == .seconds(1))
}

@Test func dashboardThemeAppliesThemeDefaultLayoutUntilLayoutIsPinned() {
    let focusLayout = TestLayout(name: "focus")
    let sidebarLayout = TestLayout(name: "sidebar")
    let theme = TestTheme(name: "lightDesk", defaultLayout: focusLayout)

    let themedDashboard = Dashboard().theme(theme)
    #expect(themedDashboard.configuration.theme.name == "lightDesk")
    #expect(themedDashboard.configuration.layout.name == "focus")

    let pinnedDashboard = Dashboard()
        .layout(sidebarLayout)
        .theme(theme)

    #expect(pinnedDashboard.configuration.theme.name == "lightDesk")
    #expect(pinnedDashboard.configuration.layout.name == "sidebar")
}

private final class TestWidgetModel: WidgetModel {}

//private struct TestWidget: Widget {
//    var configuration = WidgetConfiguration()
//
//    func makeModel(
//        environment: DashboardEnvironment
//    ) -> TestWidgetModel {
//        TestWidgetModel()
//    }
//}
private struct TestWidget: Widget {
    var configuration = WidgetConfiguration()
    let tracker: ModelTracker

    init(
        configuration: WidgetConfiguration = WidgetConfiguration(),
        tracker: ModelTracker = ModelTracker()
    ) {
        self.configuration = configuration
        self.tracker = tracker
    }
    
    func makeModel(environment: DashboardEnvironment) -> LifecycleTestModel {
        tracker.makeModelCount += 1
        tracker.receivedEnvironment = environment
        return LifecycleTestModel(tracker: tracker)
    }
}

private struct TestLayout: Layout {
    let name: String
}

private struct TestTheme: Theme {
    let name: String
    let defaultLayout: any Layout
}

//add method tests

// helpers
private final class ModelTracker {
    var makeModelCount: Int = 0
    var activateCount: Int = 0
    var receivedEnvironment: DashboardEnvironment?
    var deactivateCount: Int = 0
}

private final class LifecycleTestModel: WidgetModel {
    let tracker: ModelTracker
    
    init(tracker: ModelTracker) {
        self.tracker = tracker
    }
    
    func activate() {
        tracker.activateCount += 1
    }
    
    func deactivate() {
        tracker.deactivateCount += 1
    }
}

// 1.1.a adding a widget will create and activate a model
@Test func addingWidgetCreatesAndActivatesModel() {
    //setup
    let tracker = ModelTracker()
    let widget = TestWidget(tracker: tracker)
    
    var dashboard = Dashboard()
    
    //exercise
    dashboard.add(widget)
    
    //verify
    #expect(tracker.makeModelCount == 1)
    #expect(tracker.activateCount == 1)
}

// 1.2.a adding a widget passes the environment to the widget
@Test func addingWidgetPassesEnvironmentToWidget() {
    //setup
    let tracker = ModelTracker()
    let widget = TestWidget(tracker: tracker)
        .id("clock")
        .refreshRate(.seconds(5))
    
    var dashboard = Dashboard(
        configuration: DashboardConfiguration(
            id: DashboardID("desk"),
            refreshRate: .seconds(1),
        )
    )
    
    //exercise
    dashboard.add(widget)
    
    //verify
    #expect(tracker.receivedEnvironment?.dashboardID.rawValue == "desk")
    #expect(tracker.receivedEnvironment?.widgetID.rawValue == "clock")
    #expect(tracker.receivedEnvironment?.refreshRate == .seconds(5))
}

// 1.3 adding a widget uses the dashboard refresh rate when no override provided
@Test func addingWidgetUsesDashboardRefreshRateWhenNoOverrideProvided() {
    //setup
    let tracker = ModelTracker()
    let widget = TestWidget(tracker: tracker)
    
    var dashboard = Dashboard(
        configuration: DashboardConfiguration(
            id: DashboardID("desk"),
            refreshRate: .seconds(10),
        )
    )
    
    //exercise
    dashboard.add(widget)
    
    //verify
    #expect(tracker.receivedEnvironment?.refreshRate == .seconds(10))
}

// 1.4 removing a widget deactivates the model
@Test func removingWidgetDeactivatesModel() {
    //setup
    let tracker = ModelTracker()
    let widget = TestWidget(tracker: tracker)
        .id("clock")
    
    var dashboard = Dashboard()
    dashboard.add(widget)
    
    //exercise
    dashboard.remove(widget: WidgetID("clock"))
    
    //verify
    #expect(tracker.activateCount == 1)
    #expect(tracker.deactivateCount == 1)
}

// 1.5 removing a missing widget does nothing
@Test func removingNonExistingWidgetDoesNothing() {
    //setup
    var dashboard = Dashboard()
    
    //exercise
    dashboard.remove(widget: WidgetID("missing"))
    
    //verify
    #expect(true)
}

@Test func creatingWidgetDoesNotCreateOrActivateModel() {
    let tracker = ModelTracker()

    _ = TestWidget(tracker: tracker)

    #expect(tracker.makeModelCount == 0)
    #expect(tracker.activateCount == 0)
    #expect(tracker.deactivateCount == 0)
}

@Test func addingTwoWidgetsCreatesTwoSeparateModels() {
    let firstTracker = ModelTracker()
    let secondTracker = ModelTracker()

    let firstWidget = TestWidget(tracker: firstTracker)
        .id("first")

    let secondWidget = TestWidget(tracker: secondTracker)
        .id("second")

    var dashboard = Dashboard()

    dashboard.add(firstWidget)
    dashboard.add(secondWidget)

    #expect(firstTracker.makeModelCount == 1)
    #expect(firstTracker.activateCount == 1)

    #expect(secondTracker.makeModelCount == 1)
    #expect(secondTracker.activateCount == 1)
}


