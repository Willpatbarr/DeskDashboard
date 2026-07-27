# Adding a new widget (service + model + widget)

A repeatable checklist for adding a widget to DeskDashboard. Written from the
Indoor Temperature widget as the worked example — copy its shape when in doubt.

## Mental model (read this first)

Every data-driven widget is a three-layer pipeline. Keeping the layers separate
is the whole point — each is swappable and testable on its own:

```
Service            WidgetModel                 Widget
(DATA)      ──▶    (TRANSFORM)         ──▶     (DISPLAY)
raw values         raw → display strings       WidgetContent (title/primary/…)
swappable source   unit conversion, staleness  render() only
```

- **Service** — *where the data comes from*. A protocol plus one or more
  interchangeable implementations (push, polling, simulated). Canonical units,
  no formatting. The widget never knows which implementation it got.
- **WidgetModel** — *turns raw data into display-ready strings*. Owns formatting,
  unit conversion, staleness, etc. A class (reference type) with an
  `activate`/`tick` lifecycle. Owned privately by the widget.
- **Widget** — *the display layer*. Holds configuration, resolves its service,
  builds its model, and implements `render()` → `WidgetContent`. The
  `ServiceBackedWidget` scaffold provides all the lifecycle boilerplate.

The runner ticks each widget on its refresh rate; `render()` returns a
`WidgetContent`; the renderer lays that out via the widget's `WidgetLayout`
(see [adding-themes-and-layouts.md](adding-themes-and-layouts.md)).

### Files / layout

Widgets live one-folder-each under the widgets target:

```
Sources/App/DeskDashboardWidgets/<Name>/
    <Name>Service.swift        # data contract + implementations + ServiceKey
    <Name>WidgetModel.swift    # transform layer
    <Name>Widget.swift         # display layer + modifiers
```

Wiring points:

| Concern | File |
| --- | --- |
| Register the widget in the dashboard | `Sources/App/DeskDashboardComposition/Composition.swift` |
| (Push widgets) ingest endpoint | `Sources/App/DeskDashboardIngest/PushIngest.swift` |
| Core protocols | `Sources/Framework/DashboardKit/Widget/*.swift` |

> **Do I even need a service + model?** If the widget shows something purely
> static or self-contained (no external source, no formatting worth isolating),
> skip them: conform directly to `RenderableWidget` (`Widget` + `render()`) and
> return a `WidgetContent`. Everything below is the full, data-backed path.

---

## Step 1 — The service (DATA layer)

Define the data shape, the protocol, a typed `ServiceKey`, and at least one
implementation. Put it all in `<Name>Service.swift`.

```swift
import DashboardKit
import Foundation

// The value your source produces. Store canonical units (e.g. Celsius, seconds);
// the model formats for display.
public struct FooReading: Equatable, Sendable {
    public var value: Double
    public var timestamp: Date
    public init(value: Double, timestamp: Date) {
        self.value = value
        self.timestamp = timestamp
    }
}

// The contract. Implementations are interchangeable; the widget only sees this.
public protocol FooService: AnyObject {
    func currentReading() -> FooReading?
}

// Typed handle used to resolve the service from the environment.
public enum FooServiceKeys {
    public static let foo = ServiceKey<any FooService>("foo")
}
```

Then provide implementations **as your case needs** (this part is genuinely
case-by-case):

- **Simulated** (always add one — it's the dev fallback and makes the tile
  non-empty with no hardware):

  ```swift
  public final class SimulatedFooService: FooService {
      public init() {}
      public func currentReading() -> FooReading? {
          FooReading(value: 42, timestamp: Date())
      }
  }
  ```

- **Push** (data arrives from outside via an HTTP POST — like indoor temp /
  music). Must be thread-safe: pushes land on a server thread, the widget reads
  on main.

  ```swift
  public final class PushFooService: FooService, @unchecked Sendable {
      private let lock = NSLock()
      private var latest: FooReading?
      public init(initialReading: FooReading? = nil) { latest = initialReading }
      public func update(_ reading: FooReading) {
          lock.lock(); latest = reading; lock.unlock()
      }
      public func currentReading() -> FooReading? {
          lock.lock(); defer { lock.unlock() }; return latest
      }
  }
  ```

- **Polling** (the service fetches on its own, e.g. an HTTP API like
  `OpenMeteoOutdoorService`). Fetch off the render path and cache the latest
  reading behind `currentReading()`.

Keep the service pure-Foundation (no HomeKit/AppKit/GTK) so it builds on the Pi
and in the static-musl dev binary. Platform-specific data comes in via a push
producer, not by importing a framework here.

---

## Step 2 — The model (TRANSFORM layer)

In `<Name>WidgetModel.swift`. A `final class` conforming to `WidgetModel`. It
holds the service, exposes display-ready strings, and refreshes on tick.

```swift
import DashboardKit
import Foundation

public final class FooWidgetModel: WidgetModel {
    static let stalenessThreshold: TimeInterval = 150   // tune to refresh rate

    private let service: any FooService
    private let displayOptions: FooDisplayOptions

    private(set) var displayValue: String?
    private(set) var isStale = false

    init(service: any FooService, displayOptions: FooDisplayOptions) {
        self.service = service
        self.displayOptions = displayOptions
    }

    public func activate() { refresh(at: Date()) }               // first paint
    public func tick(_ tick: DashboardTick, environment: DashboardEnvironment) {
        refresh(at: tick.date)                                   // every refresh cycle
    }

    func refresh(at date: Date) {
        guard let reading = service.currentReading() else {
            displayValue = nil; isStale = false; return
        }
        displayValue = "\(Int(reading.value.rounded()))"          // do formatting here
        isStale = date.timeIntervalSince(reading.timestamp) > Self.stalenessThreshold
    }
}
```

Rules of thumb: the model does *all* formatting/conversion/staleness; it never
imports UI; reads must be cheap (called every tick). `deactivate()` is available
if you need to tear down (timers, observers).

---

## Step 3 — The widget (DISPLAY layer)

In `<Name>Widget.swift`. Conform to `ServiceBackedWidget` — the scaffold handles
attach/tick/detach; you only supply the distinctive parts.

```swift
import DashboardKit
import Foundation

public struct FooWidget: ServiceBackedWidget {
    public var configuration: WidgetConfiguration
    private var displayOptions: FooDisplayOptions
    public var boundService: (any FooService)?     // set by .service(_:)
    public var model: FooWidgetModel?              // set by the scaffold

    public init(
        configuration: WidgetConfiguration = WidgetConfiguration(
            title: "Foo",
            size: .medium,
            refreshRate: .seconds(30)              // how often tick() fires
        ),
        displayOptions: FooDisplayOptions = FooDisplayOptions()
    ) {
        self.configuration = configuration
        self.displayOptions = displayOptions
    }

    // --- service-backed wiring (the 3 required hooks) ---
    public var serviceKey: ServiceKey<any FooService> { FooServiceKeys.foo }
    public func makeModel(_ service: any FooService) -> FooWidgetModel {
        FooWidgetModel(service: service, displayOptions: displayOptions)
    }
    public func makeFallbackService() -> any FooService { SimulatedFooService() }

    // --- rendering: model state -> semantic content ---
    public func render(environment: DashboardEnvironment) -> WidgetContent {
        WidgetContent(
            title: configuration.title,
            primaryText: model?.displayValue ?? "—",
            secondaryText: model?.displayValue == nil ? "No data" : nil,
            accessoryText: (model?.isStale ?? false) ? "STALE" : nil,
            metadata: [WidgetContentMetadata(label: "Source", value: "Foo")]
        )
    }
}

// Options + fluent modifiers (composition over configuration)
public struct FooDisplayOptions { public init() {} /* unit toggles, etc. */ }

extension FooWidget {
    public func someOption(_ on: Bool = true) -> Self {
        var copy = self; /* mutate copy.displayOptions */ ; return copy
    }
}
```

Service resolution order (handled by the scaffold): **bound via `.service(_:)`**
→ **registered on the environment** for `serviceKey` → **`makeFallbackService()`**.

`WidgetContent` fields map to layout roles: `title` → `.title`, `primaryText` →
`.primary`/`.hero`, `secondaryText` → `.secondary`, `accessoryText` → `.badge`,
`metadata` → `.caption`.

---

## Step 4 — Register it in the composition

In `Composition.swift`, add the widget inside the `.widgets { … }` block and bind
its service with `.service(_:)` (keeps the data source next to the widget):

```swift
let foo = PushFooService(initialReading: FooReading(value: 42, timestamp: Date()))
// ...
.widgets {
    // existing widgets…
    FooWidget()
        .id("foo")                 // stable id (used by renderers/snapshots)
        .title("Foo")
        .size(.medium)
        .layout(.stat)             // pick a WidgetLayout (default .standard)
        .service(foo)              // bind the source; omit to use fallback
}
```

Available chained modifiers: `.id`, `.title`, `.size`, `.priority`, `.hidden`,
`.refreshRate`, `.layout`, `.service` (+ any widget-specific ones you added).

If your service is a push store you'll want it seeded and handed back for the
ingest endpoints — mirror how `indoorTemperature`/`music` are created and
returned in `DeskDashboardSystem`.

---

## Step 5 — (Push widgets only) the ingest endpoint

If the source is pushed in over HTTP, add an endpoint in `PushIngest.swift` and
wire it into `registerPushIngest`:

```swift
public static func registerFoo(registerPost: RegisterPost, store: PushFooService) {
    struct Payload: Decodable { var value: Double }
    registerPost("/ingest/foo") { body in
        guard let p = try? JSONDecoder().decode(Payload.self, from: body) else {
            return HTTPResponse(contentType: "application/json",
                                body: Data(#"{"error":"expected {value}"}"#.utf8))
        }
        store.update(FooReading(value: p.value, timestamp: Date()))
        print("[ingest] foo <- \(p.value)")
        return HTTPResponse(contentType: "application/json",
                            body: Data(#"{"stored":\#(p.value)}"#.utf8))
    }
}
```

Then call it from `registerPushIngest(...)` in `Composition.swift`, passing the
seeded store. The endpoint is served on `:8642` (both the dev web renderer and
the real UI app register the same ingest set). Your external producer POSTs JSON
there; the launchd/systemd producer setup is the same pattern as the existing
temp/music producers.

---

## Build, run, verify

```bash
# fast text/web check (dev renderer, no GUI): shows the tile + live data
swift run deskdashboard-dev            # then open the printed http://…:8642

# the real native app
swift build -c release --product deskdashboard-ui
.build/release/deskdashboard-ui
```

For a push widget, verify the pipeline end-to-end with a curl:

```bash
curl -s -XPOST localhost:8642/ingest/foo -d '{"value":73}'
```

Deploy to the Pi: pull + `CONFIG=debug JOBS=1 bash scripts/build-ui-pi.sh` +
`sudo systemctl restart deskdashboard-ui` (see
[adding-themes-and-layouts.md](adding-themes-and-layouts.md) for the full Pi
recipe).

---

## Conventions & gotchas

- **Layer discipline.** Service = canonical raw values, Model = all formatting,
  Widget = `render()` only. Don't format in the service or fetch in `render()`.
- **Always ship a simulated service.** It's the fallback and lets the widget
  render with no hardware/producer attached.
- **Push services must be thread-safe** (`NSLock` + `@unchecked Sendable`) —
  writes arrive on a server thread, reads happen on the UI thread.
- **Pure-Foundation services only.** No HomeKit/AppKit/GTK imports, or the Pi /
  static-musl builds break. Platform data comes in via a push producer.
- **Staleness.** For pushed/polled data, mark `isStale` when the timestamp is
  older than ~a few refresh cycles, and surface it (e.g. an `accessoryText`
  badge) so a dead producer is visible.
- **`refreshRate`** throttles `tick()` — match it to how fast the data actually
  changes (30s for temperature, 1s for a clock).
- **`render()` must be pure & cheap.** It's called to build every snapshot; read
  from the model, don't do work.
- **Give every widget a stable `.id`.** Renderers and snapshots key off it.
