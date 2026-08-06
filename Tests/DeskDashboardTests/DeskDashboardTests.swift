// DeskDashboardTests.swift — Tests: widget modifiers, attachment lifecycle, layout and environment.

import Foundation
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

    #expect(widget.configuration.preferredID?.rawValue == "clock")
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

@Test func darkDeskThemeProvidesPolishedDefaultTokens() {
    let theme = DarkDeskTheme()

    #expect(theme.colors.background == "#090D14")
    #expect(theme.colors.accent == "#36C2FF")
    #expect(theme.typography.headingSize == 28)
    #expect(theme.spacing.widgetGap == 12)
    #expect(theme.shape.cornerRadius == 8)
    #expect(theme.animation.transitionDuration == 0.18)
}

private final class TestWidgetModel: WidgetModel {}

private final class TestDashboardService {
    let name: String

    init(name: String) {
        self.name = name
    }
}

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

    mutating func tick(
        _ tick: DashboardTick,
        environment: DashboardEnvironment
    ) {
        model?.tick(
            tick,
            environment: environment
        )
    }

    mutating func detach() {
        model?.deactivate()
        model = nil
    }
}

private struct RenderTestWidget: RenderableWidget {
    var configuration = WidgetConfiguration(
        title: "Status",
        refreshRate: .seconds(5)
    )

    func render(environment: DashboardEnvironment) -> WidgetContent {
        WidgetContent(
            title: configuration.title,
            primaryText: "Ready",
            secondaryText: environment.theme.name,
            metadata: [
                WidgetContentMetadata(
                    label: "Refresh",
                    value: "\(Int(environment.refreshRate.seconds))s"
                ),
            ]
        )
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
    var tickCount: Int = 0
    var receivedTicks: [DashboardTick] = []
    var tickedEnvironment: DashboardEnvironment?
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

    func tick(
        _ tick: DashboardTick,
        environment: DashboardEnvironment
    ) {
        tracker.tickCount += 1
        tracker.receivedTicks.append(tick)
        tracker.tickedEnvironment = environment
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

@Test func addingWidgetReturnsPreferredRuntimeIDWhenProvided() {
    let widget = TestWidget()
        .id("clock")

    var dashboard = Dashboard()

    let widgetID = dashboard.add(widget)

    #expect(widgetID == WidgetID("clock"))
    #expect(dashboard.widgetIDs == [WidgetID("clock")])
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

@Test func dashboardTickDeliversToAttachedWidgets() {
    let tracker = ModelTracker()
    let widget = TestWidget(tracker: tracker)
        .id("clock")

    let tickDate = Date(timeIntervalSinceReferenceDate: 10)

    var dashboard = Dashboard()
    dashboard.add(widget)

    dashboard.tick(at: tickDate)

    #expect(tracker.tickCount == 1)
    #expect(tracker.receivedTicks == [
        DashboardTick(date: tickDate),
    ])
    #expect(tracker.tickedEnvironment?.widgetID == WidgetID("clock"))
}

@Test func dashboardTickDoesNotDeliverBeforeRefreshRateElapsed() {
    let tracker = ModelTracker()
    let widget = TestWidget(tracker: tracker)
        .id("weather")

    var dashboard = Dashboard(
        configuration: DashboardConfiguration(
            refreshRate: .seconds(30)
        )
    )
    dashboard.add(widget)

    dashboard.tick(at: Date(timeIntervalSinceReferenceDate: 0))
    dashboard.tick(at: Date(timeIntervalSinceReferenceDate: 1))

    #expect(tracker.tickCount == 1)
}

@Test func dashboardTickDeliversWhenRefreshRateElapsed() {
    let tracker = ModelTracker()
    let widget = TestWidget(tracker: tracker)
        .id("weather")

    var dashboard = Dashboard(
        configuration: DashboardConfiguration(
            refreshRate: .seconds(30)
        )
    )
    dashboard.add(widget)

    dashboard.tick(at: Date(timeIntervalSinceReferenceDate: 0))
    dashboard.tick(at: Date(timeIntervalSinceReferenceDate: 30))

    #expect(tracker.tickCount == 2)
}

@Test func dashboardTickUsesPerWidgetRefreshRateOverride() {
    let fastTracker = ModelTracker()
    let slowTracker = ModelTracker()

    let fastWidget = TestWidget(tracker: fastTracker)
        .id("clock")
        .refreshRate(.seconds(1))

    let slowWidget = TestWidget(tracker: slowTracker)
        .id("weather")
        .refreshRate(.seconds(30))

    var dashboard = Dashboard(
        configuration: DashboardConfiguration(
            refreshRate: .seconds(10)
        )
    )

    dashboard.add(fastWidget)
    dashboard.add(slowWidget)

    dashboard.tick(at: Date(timeIntervalSinceReferenceDate: 0))
    dashboard.tick(at: Date(timeIntervalSinceReferenceDate: 1))

    #expect(fastTracker.tickCount == 2)
    #expect(slowTracker.tickCount == 1)
}

@Test func dashboardTickDoesNotDeliverToHiddenWidgets() {
    let tracker = ModelTracker()
    let widget = TestWidget(tracker: tracker)
        .id("clock")
        .hidden()

    var dashboard = Dashboard()
    dashboard.add(widget)

    dashboard.tick(at: Date(timeIntervalSinceReferenceDate: 0))

    #expect(tracker.tickCount == 0)
}

@Test func dashboardRunnerStartsClockUsingDashboardRefreshRate() {
    let clock = ManualDashboardClock()
    let dashboard = Dashboard(
        configuration: DashboardConfiguration(
            refreshRate: .seconds(2)
        )
    )

    let runner = DashboardRunner(
        dashboard: dashboard,
        clock: clock
    )

    runner.start()

    #expect(runner.isRunning)
    #expect(clock.isRunning)
    #expect(clock.refreshRate == .seconds(2))
}

@Test func dashboardRunnerForwardsClockTicksToDashboard() {
    let clock = ManualDashboardClock()
    let tracker = ModelTracker()
    let widget = TestWidget(tracker: tracker)
        .id("clock")

    let runner = DashboardRunner(
        dashboard: Dashboard(),
        clock: clock
    )
    runner.add(widget)
    runner.start()

    clock.advance(
        to: Date(timeIntervalSinceReferenceDate: 0)
    )

    #expect(tracker.tickCount == 1)
}

@Test func dashboardRunnerStopPreventsFurtherClockTicks() {
    let clock = ManualDashboardClock()
    let tracker = ModelTracker()
    let widget = TestWidget(tracker: tracker)
        .id("clock")

    let runner = DashboardRunner(
        dashboard: Dashboard(),
        clock: clock
    )
    runner.add(widget)
    runner.start()
    runner.stop()

    clock.advance(
        to: Date(timeIntervalSinceReferenceDate: 0)
    )

    #expect(runner.isRunning == false)
    #expect(tracker.tickCount == 0)
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

@Test func addingWidgetWithoutPreferredIDReturnsGeneratedRuntimeID() {
    let widget = TestWidget()

    var dashboard = Dashboard()

    let widgetID = dashboard.add(widget)

    #expect(dashboard.attachedWidgetCount == 1)
    #expect(dashboard.widgetIDs == [widgetID])
}

@Test func addingTwoWidgetsWithoutPreferredIDsCreatesDistinctRuntimeIDs() {
    var dashboard = Dashboard()

    let firstID = dashboard.add(TestWidget())
    let secondID = dashboard.add(TestWidget())

    #expect(firstID != secondID)
    #expect(dashboard.attachedWidgetCount == 2)
    #expect(Set(dashboard.widgetIDs) == Set([firstID, secondID]))
}

@Test func widgetIDsPreserveAttachmentOrder() {
    var dashboard = Dashboard()

    dashboard.add(TestWidget().id("first"))
    dashboard.add(TestWidget().id("second"))
    dashboard.add(TestWidget().id("third"))

    #expect(dashboard.widgetIDs == [
        WidgetID("first"),
        WidgetID("second"),
        WidgetID("third"),
    ])
}

@Test func replacingWidgetPreservesAttachmentOrder() {
    var dashboard = Dashboard()

    dashboard.add(TestWidget().id("first"))
    dashboard.add(TestWidget().id("second"))
    dashboard.add(TestWidget().id("first"))

    #expect(dashboard.widgetIDs == [
        WidgetID("first"),
        WidgetID("second"),
    ])
}

@Test func removingWidgetRemovesIDFromAttachmentOrder() {
    var dashboard = Dashboard()

    dashboard.add(TestWidget().id("first"))
    dashboard.add(TestWidget().id("second"))
    dashboard.add(TestWidget().id("third"))

    dashboard.remove(widget: WidgetID("second"))

    #expect(dashboard.widgetIDs == [
        WidgetID("first"),
        WidgetID("third"),
    ])
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

@Test func applyingThemeAppliesDefaultLayoutWhenLayoutIsNotPinned() {
    let tracker = ModelTracker()
    let widget = TestWidget(tracker: tracker)
        .id("music")

    let theme = TestTheme(
        name: "focusDesk",
        defaultLayout: RegionLayout(region: LayoutRegion("focus"))
    )

    var dashboard = Dashboard()
    dashboard.add(widget)

    dashboard.applyTheme(theme)

    #expect(dashboard.configuration.theme.name == "focusDesk")
    #expect(dashboard.configuration.layout.name == "region")
    #expect(dashboard.placement(for: WidgetID("music"))?.region == LayoutRegion("focus"))
    #expect(tracker.updatedEnvironment?.theme.name == "focusDesk")
    #expect(tracker.updatedEnvironment?.layout.name == "region")
}

@Test func applyingThemePreservesPinnedLayout() {
    let tracker = ModelTracker()
    let widget = TestWidget(tracker: tracker)
        .id("music")

    let theme = TestTheme(
        name: "focusDesk",
        defaultLayout: RegionLayout(region: LayoutRegion("focus"))
    )

    var dashboard = Dashboard()
    dashboard.applyLayout(RegionLayout(region: LayoutRegion("sidebar")))
    dashboard.add(widget)

    dashboard.applyTheme(theme)

    #expect(dashboard.configuration.theme.name == "focusDesk")
    #expect(dashboard.configuration.layout.name == "region")
    #expect(dashboard.placement(for: WidgetID("music"))?.region == LayoutRegion("sidebar"))
    #expect(tracker.updatedEnvironment?.theme.name == "focusDesk")
    #expect(tracker.updatedEnvironment?.layout.name == "region")
}

@Test func applyingThemeUpdatesAttachedWidgetSnapshotsWithDefaultLayoutPlacement() {
    let widget = TestWidget()
        .id("music")

    let theme = TestTheme(
        name: "focusDesk",
        defaultLayout: RegionLayout(region: LayoutRegion("focus"))
    )

    var dashboard = Dashboard()
    dashboard.add(widget)

    dashboard.applyTheme(theme)

    let snapshot = dashboard.attachedWidgetSnapshots.first

    #expect(snapshot?.id == WidgetID("music"))
    #expect(snapshot?.placement.region == LayoutRegion("focus"))
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

@Test func dashboardServiceModifierPassesServiceToAddedWidget() {
    let tracker = ModelTracker()
    let widget = TestWidget(tracker: tracker)
        .id("music")

    let key = ServiceKey<TestDashboardService>("music")
    let service = TestDashboardService(name: "now-playing")

    var dashboard = Dashboard()
        .service(service, for: key)

    dashboard.add(widget)

    #expect(tracker.receivedEnvironment?.service(for: key) === service)
}

@Test func applyingServiceUpdatesAttachedWidgets() {
    let tracker = ModelTracker()
    let widget = TestWidget(tracker: tracker)
        .id("music")

    let key = ServiceKey<TestDashboardService>("music")
    let service = TestDashboardService(name: "now-playing")

    var dashboard = Dashboard()
    dashboard.add(widget)

    dashboard.applyService(service, for: key)

    #expect(tracker.makeModelCount == 1)
    #expect(tracker.activateCount == 1)
    #expect(tracker.updateCount == 1)
    #expect(tracker.updatedEnvironment?.service(for: key) === service)
}

@Test func missingServiceReturnsNil() {
    let key = ServiceKey<TestDashboardService>("music")
    let environment = DashboardEnvironment(
        dashboardID: DashboardID("desk"),
        widgetID: WidgetID("music"),
        theme: DarkDeskTheme(),
        layout: TestLayout(name: "main"),
        refreshRate: .seconds(1)
    )

    #expect(environment.service(for: key) == nil)
}

@Test func addedWidgetIsVisibleByDefault() {
    let widget = TestWidget()
        .id("clock")

    var dashboard = Dashboard()
    dashboard.add(widget)

    #expect(dashboard.placement(for: WidgetID("clock"))?.visibility == .visible)
}

@Test func hiddenWidgetIsHiddenWhenAdded() {
    let tracker = ModelTracker()
    let widget = TestWidget(tracker: tracker)
        .id("clock")
        .hidden()

    var dashboard = Dashboard()
    dashboard.add(widget)

    #expect(dashboard.placement(for: WidgetID("clock"))?.visibility == .hidden)
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

    #expect(dashboard.placement(for: WidgetID("music"))?.visibility == .hidden)
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

    #expect(dashboard.placement(for: WidgetID("music"))?.visibility == .hidden)
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

    #expect(dashboard.placement(for: WidgetID("music"))?.visibility == .visible)
}

@Test func addedWidgetGetsDefaultPlacement() {
    let widget = TestWidget()
        .id("clock")

    var dashboard = Dashboard()
    dashboard.add(widget)

    #expect(dashboard.placement(for: WidgetID("clock"))?.visibility == .visible)
    #expect(dashboard.placement(for: WidgetID("clock"))?.gridSlot == WidgetGridSlot(column: 0, row: 0))
}

@Test func gridLayoutAssignsOrderedGridSlots() {
    var dashboard = Dashboard(
        configuration: DashboardConfiguration(
            layout: GridLayout(columns: 2)
        )
    )

    dashboard.add(TestWidget().id("first"))
    dashboard.add(TestWidget().id("second"))
    dashboard.add(TestWidget().id("third"))

    #expect(dashboard.placement(for: WidgetID("first"))?.gridSlot == WidgetGridSlot(column: 0, row: 0))
    #expect(dashboard.placement(for: WidgetID("second"))?.gridSlot == WidgetGridSlot(column: 1, row: 0))
    #expect(dashboard.placement(for: WidgetID("third"))?.gridSlot == WidgetGridSlot(column: 0, row: 1))
}

@Test func gridLayoutUsesWidgetSizeAsSpanHint() {
    var dashboard = Dashboard(
        configuration: DashboardConfiguration(
            layout: GridLayout(columns: 4)
        )
    )

    dashboard.add(
        TestWidget()
            .id("clock")
            .size(.large)
    )

    #expect(dashboard.placement(for: WidgetID("clock"))?.gridSlot == WidgetGridSlot(
        column: 0,
        row: 0,
        columnSpan: 2,
        rowSpan: 2
    ))
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
    #expect(dashboard.placement(for: WidgetID("music"))?.visibility == .visible)
}

@Test func applyingLayoutUpdatesWidgetPlacement() {
    let widget = TestWidget()
        .id("music")

    var dashboard = Dashboard()
    dashboard.add(widget)

    dashboard.applyLayout(RegionLayout(region: LayoutRegion("sidebar")))

    #expect(dashboard.placement(for: WidgetID("music"))?.region == LayoutRegion("sidebar"))
}

@Test func attachedWidgetSnapshotsContainRuntimeWidgetID() {
    let widget = TestWidget()
        .id("clock")

    var dashboard = Dashboard()
    dashboard.add(widget)

    #expect(dashboard.attachedWidgetSnapshots.count == 1)
    #expect(dashboard.attachedWidgetSnapshots.first?.id == WidgetID("clock"))
}

@Test func attachedWidgetSnapshotsContainWidgetConfiguration() {
    let widget = TestWidget()
        .id("clock")
        .title("Desk Clock")
        .size(.large)

    var dashboard = Dashboard()
    dashboard.add(widget)

    let snapshot = dashboard.attachedWidgetSnapshots.first

    #expect(snapshot?.configuration.title == "Desk Clock")
    #expect(snapshot?.configuration.size == .large)
}

@Test func attachedWidgetSnapshotsContainRenderableWidgetContent() {
    var dashboard = Dashboard()
    dashboard.add(
        RenderTestWidget()
            .id("status")
    )

    let snapshot = dashboard.attachedWidgetSnapshots.first

    #expect(snapshot?.content?.title == "Status")
    #expect(snapshot?.content?.primaryText == "Ready")
    #expect(snapshot?.content?.secondaryText == "darkDesk")
    #expect(snapshot?.content?.metadata == [
        WidgetContentMetadata(label: "Refresh", value: "5s"),
    ])
}

@Test func attachedWidgetSnapshotsLeaveContentEmptyForNonRenderableWidgets() {
    var dashboard = Dashboard()
    dashboard.add(
        TestWidget()
            .id("plain")
    )

    let snapshot = dashboard.attachedWidgetSnapshots.first

    #expect(snapshot?.content == nil)
}

@Test func attachedWidgetSnapshotsContainUpdatedPlacement() {
    let widget = TestWidget()
        .id("music")

    var dashboard = Dashboard()
    dashboard.add(widget)

    dashboard.applyLayout(RegionLayout(region: LayoutRegion("sidebar")))

    let snapshot = dashboard.attachedWidgetSnapshots.first

    #expect(snapshot?.id == WidgetID("music"))
    #expect(snapshot?.placement.region == LayoutRegion("sidebar"))
}

@Test func attachedWidgetSnapshotsPreserveAttachmentOrder() {
    var dashboard = Dashboard()

    dashboard.add(TestWidget().id("first"))
    dashboard.add(TestWidget().id("second"))
    dashboard.add(TestWidget().id("third"))

    let snapshotIDs = dashboard.attachedWidgetSnapshots.map(\.id)

    #expect(snapshotIDs == [
        WidgetID("first"),
        WidgetID("second"),
        WidgetID("third"),
    ])
}

@Test func gridLayoutPacksSpannedWidgetsWithoutOverlap() {
    var dashboard = Dashboard(
        configuration: DashboardConfiguration(
            layout: GridLayout(columns: 4)
        )
    )

    dashboard.add(TestWidget().id("clock").size(.large))
    dashboard.add(TestWidget().id("alarm").size(.medium))
    dashboard.add(TestWidget().id("temp").size(.small))

    #expect(dashboard.placement(for: WidgetID("clock"))?.gridSlot == WidgetGridSlot(
        column: 0,
        row: 0,
        columnSpan: 2,
        rowSpan: 2
    ))
    #expect(dashboard.placement(for: WidgetID("alarm"))?.gridSlot == WidgetGridSlot(
        column: 2,
        row: 0,
        columnSpan: 2,
        rowSpan: 1
    ))
    #expect(dashboard.placement(for: WidgetID("temp"))?.gridSlot == WidgetGridSlot(
        column: 2,
        row: 1,
        columnSpan: 1,
        rowSpan: 1
    ))
}

@Test func removingWidgetRepacksRemainingPlacements() {
    var dashboard = Dashboard(
        configuration: DashboardConfiguration(
            layout: GridLayout(columns: 2)
        )
    )

    dashboard.add(TestWidget().id("first"))
    dashboard.add(TestWidget().id("second"))
    dashboard.add(TestWidget().id("third"))

    dashboard.remove(widget: WidgetID("first"))

    #expect(dashboard.placement(for: WidgetID("second"))?.gridSlot == WidgetGridSlot(column: 0, row: 0))
    #expect(dashboard.placement(for: WidgetID("third"))?.gridSlot == WidgetGridSlot(column: 1, row: 0))
}
