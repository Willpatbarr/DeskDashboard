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
    private var model: LifecycleTestModel?

    init(
        configuration: WidgetConfiguration = WidgetConfiguration(),
        tracker: ModelTracker = ModelTracker()
    ) {
        self.configuration = configuration
        self.tracker = tracker
    }

    mutating func attach(environment: DashboardEnvironment) {
        tracker.makeModelCount += 1
        tracker.receivedEnvironment = environment
        model = LifecycleTestModel(tracker: tracker)
        model?.activate()
    }

    mutating func update(environment: DashboardEnvironment) {
        model?.update(environment: environment)
    }

    mutating func detach() {
        model?.deactivate()
        model = nil
    }
}

private struct TestLayout: Layout {
    let name: String
}

private struct HidingLayout: Layout {
    let name = "hiding"
    let hiddenWidgetID: WidgetID

    func visibility(
        for widgetID: WidgetID,
        configuration: WidgetConfiguration
    ) -> WidgetVisibility {
        widgetID == hiddenWidgetID ? .hidden : .visible
    }
}

private struct RegionLayout: Layout {
    let name = "region"
    let region: LayoutRegion

    func placement(
        for widgetID: WidgetID,
        configuration: WidgetConfiguration
    ) -> WidgetPlacement {
        WidgetPlacement(
            visibility: configuration.isHidden ? .hidden : .visible,
            region: region
        )
    }
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
    var updateCount: Int = 0
    var updatedEnvironment: DashboardEnvironment?
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

    func update(environment: DashboardEnvironment) {
        tracker.updateCount += 1
        tracker.updatedEnvironment = environment
    }
}

// 1.1.a adding a widget attaches and activates it
@Test func addingWidgetAttachesAndActivatesWidget() {
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

// 1.4 removing a widget detaches it
@Test func removingWidgetDetachesWidget() {
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

// 1.5 removing a missing widget does not touch attached widgets
@Test func removingNonExistingWidgetDoesNotDeactivateAttachedWidgets() {
    //setup
    let tracker = ModelTracker()
    let widget = TestWidget(tracker: tracker)
        .id("clock")

    var dashboard = Dashboard()
    dashboard.add(widget)

    //exercise
    dashboard.remove(widget: WidgetID("missing"))

    //verify
    #expect(tracker.activateCount == 1)
    #expect(tracker.deactivateCount == 0)
    #expect(dashboard.attachedWidgetCount == 1)
}

@Test func creatingWidgetDoesNotCreateOrActivateModel() {
    let tracker = ModelTracker()

    _ = TestWidget(tracker: tracker)

    #expect(tracker.makeModelCount == 0)
    #expect(tracker.activateCount == 0)
    #expect(tracker.deactivateCount == 0)
}

@Test func addingTwoWidgetsAttachesEachWidgetIndependently() {
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

@Test func addingWidgetWithDuplicateIDReplacesAndDetachesOldWidget() {
    let firstTracker = ModelTracker()
    let secondTracker = ModelTracker()

    let firstWidget = TestWidget(tracker: firstTracker)
        .id("clock")

    let secondWidget = TestWidget(tracker: secondTracker)
        .id("clock")

    var dashboard = Dashboard()

    dashboard.add(firstWidget)
    dashboard.add(secondWidget)

    #expect(firstTracker.activateCount == 1)
    #expect(firstTracker.deactivateCount == 1)

    #expect(secondTracker.activateCount == 1)
    #expect(secondTracker.deactivateCount == 0)
}

@Test func addingWidgetIncreasesAttachedWidgetCount() {
    let widget = TestWidget()
        .id("clock")

    var dashboard = Dashboard()
    dashboard.add(widget)

    #expect(dashboard.attachedWidgetCount == 1)
}

@Test func removingWidgetDecreasesAttachedWidgetCount() {
    let widget = TestWidget()
        .id("clock")

    var dashboard = Dashboard()
    dashboard.add(widget)
    dashboard.remove(widget: WidgetID("clock"))

    #expect(dashboard.attachedWidgetCount == 0)
}

@Test func replacingWidgetWithDuplicateIDKeepsAttachedWidgetCountAtOne() {
    let firstWidget = TestWidget()
        .id("clock")

    let secondWidget = TestWidget()
        .id("clock")

    var dashboard = Dashboard()
    dashboard.add(firstWidget)
    dashboard.add(secondWidget)

    #expect(dashboard.attachedWidgetCount == 1)
}

@Test func updatingAttachedWidgetEnvironmentsUpdatesWidgets() {
    let tracker = ModelTracker()
    let widget = TestWidget(tracker: tracker)
        .id("clock")

    var dashboard = Dashboard(
        configuration: DashboardConfiguration(
            id: DashboardID("desk"),
            refreshRate: .seconds(1),
        )
    )

    dashboard.add(widget)

    dashboard = dashboard.refreshRate(.seconds(5))
    dashboard.updateAttachedWidgetEnvironments()

    #expect(tracker.makeModelCount == 1)
    #expect(tracker.activateCount == 1)
    #expect(tracker.updateCount == 1)
    #expect(tracker.updatedEnvironment?.dashboardID.rawValue == "desk")
    #expect(tracker.updatedEnvironment?.widgetID.rawValue == "clock")
    #expect(tracker.updatedEnvironment?.refreshRate == .seconds(5))
}

@Test func applyingRefreshRateUpdatesAttachedWidgets() {
    let tracker = ModelTracker()
    let widget = TestWidget(tracker: tracker)
        .id("clock")

    var dashboard = Dashboard(
        configuration: DashboardConfiguration(
            id: DashboardID("desk"),
            refreshRate: .seconds(1),
        )
    )

    dashboard.add(widget)

    dashboard.applyRefreshRate(.seconds(5))

    #expect(tracker.makeModelCount == 1)
    #expect(tracker.activateCount == 1)
    #expect(tracker.updateCount == 1)
    #expect(tracker.updatedEnvironment?.refreshRate == .seconds(5))
}

@Test func applyingThemeUpdatesAttachedWidgets() {
    let tracker = ModelTracker()
    let widget = TestWidget(tracker: tracker)
        .id("clock")

    let theme = TestTheme(
        name: "lightDesk",
        defaultLayout: TestLayout(name: "focus")
    )

    var dashboard = Dashboard()
    dashboard.add(widget)

    dashboard.applyTheme(theme)

    #expect(tracker.makeModelCount == 1)
    #expect(tracker.activateCount == 1)
    #expect(tracker.updateCount == 1)
    #expect(tracker.updatedEnvironment?.theme.name == "lightDesk")
}

@Test func applyingLayoutUpdatesAttachedWidgets() {
    let tracker = ModelTracker()
    let widget = TestWidget(tracker: tracker)
        .id("clock")

    let layout = TestLayout(name: "sidebar")

    var dashboard = Dashboard()
    dashboard.add(widget)

    dashboard.applyLayout(layout)

    #expect(tracker.makeModelCount == 1)
    #expect(tracker.activateCount == 1)
    #expect(tracker.updateCount == 1)
    #expect(tracker.updatedEnvironment?.layout.name == "sidebar")
}

@Test func applyingEnvironmentValueUpdatesAttachedWidgets() {
    let tracker = ModelTracker()
    let widget = TestWidget(tracker: tracker)
        .id("clock")

    let key = EnvironmentKey<String>("displayMode")

    var dashboard = Dashboard()
    dashboard.add(widget)

    dashboard.applyEnvironment("night", for: key)

    #expect(tracker.makeModelCount == 1)
    #expect(tracker.activateCount == 1)
    #expect(tracker.updateCount == 1)
    #expect(tracker.updatedEnvironment?.value(for: key) == "night")
}

@Test func addedWidgetIsVisibleByDefault() {
    let widget = TestWidget()
        .id("clock")

    var dashboard = Dashboard()
    dashboard.add(widget)

    #expect(dashboard.visibility(for: WidgetID("clock")) == .visible)
}

@Test func settingWidgetVisibilityDoesNotDetachWidget() {
    let tracker = ModelTracker()
    let widget = TestWidget(tracker: tracker)
        .id("music")

    var dashboard = Dashboard()
    dashboard.add(widget)

    dashboard.setVisibility(.hidden, for: WidgetID("music"))

    #expect(dashboard.visibility(for: WidgetID("music")) == .hidden)
    #expect(tracker.activateCount == 1)
    #expect(tracker.deactivateCount == 0)
}

@Test func settingVisibilityForMissingWidgetDoesNothing() {
    var dashboard = Dashboard()

    dashboard.setVisibility(.hidden, for: WidgetID("missing"))

    #expect(dashboard.visibility(for: WidgetID("missing")) == nil)
}

@Test func hiddenWidgetIsHiddenWhenAdded() {
    let tracker = ModelTracker()
    let widget = TestWidget(tracker: tracker)
        .id("clock")
        .hidden()

    var dashboard = Dashboard()
    dashboard.add(widget)

    #expect(dashboard.visibility(for: WidgetID("clock")) == .hidden)
    #expect(tracker.activateCount == 1)
    #expect(tracker.deactivateCount == 0)
}

@Test func applyingLayoutCanHideAttachedWidget() {
    let widget = TestWidget()
        .id("music")

    var dashboard = Dashboard()
    dashboard.add(widget)

    dashboard.applyLayout(
        HidingLayout(hiddenWidgetID: WidgetID("music"))
    )

    #expect(dashboard.visibility(for: WidgetID("music")) == .hidden)
}

@Test func applyingLayoutDoesNotDetachHiddenWidgets() {
    let tracker = ModelTracker()
    let widget = TestWidget(tracker: tracker)
        .id("music")

    var dashboard = Dashboard()
    dashboard.add(widget)

    dashboard.applyLayout(
        HidingLayout(hiddenWidgetID: WidgetID("music"))
    )

    #expect(dashboard.visibility(for: WidgetID("music")) == .hidden)
    #expect(tracker.activateCount == 1)
    #expect(tracker.deactivateCount == 0)
}

@Test func applyingLayoutCanRevealPreviouslyHiddenWidget() {
    let widget = TestWidget()
        .id("music")

    var dashboard = Dashboard()
    dashboard.add(widget)

    dashboard.applyLayout(
        HidingLayout(hiddenWidgetID: WidgetID("music"))
    )

    dashboard.applyLayout(
        TestLayout(name: "visible")
    )

    #expect(dashboard.visibility(for: WidgetID("music")) == .visible)
}

@Test func addedWidgetGetsDefaultPlacement() {
    let widget = TestWidget()
        .id("clock")

    var dashboard = Dashboard()
    dashboard.add(widget)

    #expect(dashboard.placement(for: WidgetID("clock")) == WidgetPlacement())
}

@Test func layoutCanAssignWidgetRegion() {
    let widget = TestWidget()
        .id("music")

    var dashboard = Dashboard(
        configuration: DashboardConfiguration(
            layout: RegionLayout(region: LayoutRegion("sidebar"))
        )
    )

    dashboard.add(widget)

    #expect(dashboard.placement(for: WidgetID("music"))?.region == LayoutRegion("sidebar"))
    #expect(dashboard.visibility(for: WidgetID("music")) == .visible)
}

@Test func applyingLayoutUpdatesWidgetPlacement() {
    let widget = TestWidget()
        .id("music")

    var dashboard = Dashboard()
    dashboard.add(widget)

    dashboard.applyLayout(RegionLayout(region: LayoutRegion("sidebar")))

    #expect(dashboard.placement(for: WidgetID("music"))?.region == LayoutRegion("sidebar"))
}
