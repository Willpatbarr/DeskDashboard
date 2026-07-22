/// A widget whose display is driven by a `WidgetModel` fed from a service.
///
/// This captures the lifecycle every service-backed widget shares — resolve the
/// service from the environment (or fall back), build the model, and forward
/// `activate`/`update`/`tick`/`deactivate` — so a conforming widget only writes
/// its distinctive parts: the service key, how to make its model and fallback
/// service, and how to `render`. Authoring a new widget needs no lifecycle
/// boilerplate.
///
/// ```swift
/// public struct FooWidget: ServiceBackedWidget {
///     public var configuration = WidgetConfiguration(title: "Foo")
///     public var model: FooModel?
///     public var serviceKey: ServiceKey<any FooService> { FooServiceKeys.foo }
///     public func makeModel(_ service: any FooService) -> FooModel { FooModel(service: service) }
///     public func makeFallbackService() -> any FooService { SimulatedFooService() }
///     public func render(environment: DashboardEnvironment) -> WidgetContent { ... }
/// }
/// ```
public protocol ServiceBackedWidget: RenderableWidget {
    associatedtype Model: WidgetModel
    associatedtype Service

    /// The environment key this widget's service is registered under (used when
    /// no service is bound directly to the widget).
    var serviceKey: ServiceKey<Service> { get }

    /// A service bound directly to this widget via `.service(_:)`. Takes
    /// precedence over the environment. `nil` when unset.
    var boundService: Service? { get set }

    /// The live model. The scaffold sets this on `attach` and clears it on
    /// `detach`; widgets don't touch it directly.
    var model: Model? { get set }

    /// Builds the model around a resolved service.
    func makeModel(_ service: Service) -> Model

    /// The service to use when none is registered (a simulated/local default).
    func makeFallbackService() -> Service
}

public extension ServiceBackedWidget {
    /// Binds a service to this widget directly, instead of registering it on the
    /// dashboard's environment — so the widget and its data source read together:
    ///
    /// ```swift
    /// MusicWidget().title("Music").service(musicStore)
    /// ```
    func service(_ service: Service) -> Self {
        var copy = self
        copy.boundService = service
        return copy
    }

    mutating func attach(environment: DashboardEnvironment) {
        // Resolution order: bound directly on the widget, else from the
        // environment, else a local/simulated fallback.
        let service = boundService
            ?? environment.service(for: serviceKey)
            ?? makeFallbackService()
        let model = makeModel(service)
        model.activate()
        self.model = model
    }

    mutating func update(environment: DashboardEnvironment) {
        model?.update(environment: environment)
    }

    mutating func tick(_ tick: DashboardTick, environment: DashboardEnvironment) {
        model?.tick(tick, environment: environment)
    }

    mutating func detach() {
        model?.deactivate()
        model = nil
    }
}
