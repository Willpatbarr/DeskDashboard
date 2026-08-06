// DevWebRenderer.swift — Dev renderer: serves the dashboard as a live-updating web page.

import DashboardHTTPServer
import DashboardKit
import Foundation

// MARK: - Renderer

/// Development-only renderer: serves the dashboard as a live-updating web page
/// over the local network. The page is styled from the active Theme's tokens
/// and lays widgets out from their GridLayout slots, so theme and layout become
/// visible during development without a real UI stack.
public final class DevWebRenderer: DashboardRenderer, @unchecked Sendable {
    private let server: HTTPServer
    private let lock = NSLock()
    private var payloadJSON = Data(#"{"tiles":[]}"#.utf8)

    public init(
        theme: any Theme,
        port: UInt16 = 8642
    ) {
        self.server = HTTPServer(port: port)

        let page = Data(Self.page(for: theme).utf8)
        server.register(path: "/") {
            HTTPResponse(
                contentType: "text/html; charset=utf-8",
                body: page
            )
        }
        server.register(path: "/snapshots") { [weak self] in
            HTTPResponse(
                contentType: "application/json",
                body: self?.currentPayloadJSON() ?? Data(#"{"tiles":[]}"#.utf8)
            )
        }
    }

    /// Register a POST ingest endpoint (e.g. a sensor pushing readings).
    public func registerPost(
        path: String,
        handler: @escaping (Data) -> HTTPResponse
    ) {
        server.registerPost(path: path, handler: handler)
    }

    public func start() throws {
        try server.start()
        print("DeskDashboard dev renderer: http://127.0.0.1:\(server.port)")
    }

    public func stop() {
        server.stop()
    }

    public func render(
        _ snapshots: [AttachedWidgetSnapshot]
    ) {
        let payload = DevTilePayload(
            tiles: snapshots.map(DevTile.init)
        )
        guard let data = try? JSONEncoder().encode(payload) else {
            return
        }

        lock.lock()
        payloadJSON = data
        lock.unlock()
    }

    private func currentPayloadJSON() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return payloadJSON
    }
}

// MARK: - Payload encoding (snapshot -> JSON the page polls)

private struct DevTilePayload: Encodable {
    var tiles: [DevTile]
}

private struct DevTile: Encodable {
    struct Metadata: Encodable {
        var label: String
        var value: String
    }

    var id: String
    var title: String?
    var primaryText: String?
    var secondaryText: String?
    var accessoryText: String?
    var metadata: [Metadata]
    var visible: Bool
    var column: Int?
    var row: Int?
    var columnSpan: Int?
    var rowSpan: Int?

    init(
        snapshot: AttachedWidgetSnapshot
    ) {
        id = snapshot.id.rawValue
        title = snapshot.content?.title ?? snapshot.configuration.title
        primaryText = snapshot.content?.primaryText
        secondaryText = snapshot.content?.secondaryText
        accessoryText = snapshot.content?.accessoryText
        metadata = (snapshot.content?.metadata ?? []).map {
            Metadata(label: $0.label, value: $0.value)
        }
        visible = snapshot.placement.visibility == .visible
        column = snapshot.placement.gridSlot?.column
        row = snapshot.placement.gridSlot?.row
        columnSpan = snapshot.placement.gridSlot?.columnSpan
        rowSpan = snapshot.placement.gridSlot?.rowSpan
    }
}

// MARK: - HTML page (theme tokens -> CSS, grid slots -> CSS Grid)

extension DevWebRenderer {
    private static func cssEasing(
        _ easing: String
    ) -> String {
        switch easing {
        case "easeInOut": "ease-in-out"
        case "easeIn": "ease-in"
        case "easeOut": "ease-out"
        case "linear": "linear"
        default: "ease"
        }
    }

    /// A reference size rendered as a viewport-relative CSS length, so the page
    /// scales like the native UI does — same basis, same clamp bounds.
    ///
    /// `vw`/`vh` are the CSS equivalents of `width / refWidth` and
    /// `height / refHeight`; `ThemeMetrics.Basis` decides which one (or the
    /// `min()` of both) applies, and `clamp()` mirrors
    /// `minimumScale`/`maximumScale`.
    private static func responsive(
        _ size: Double,
        _ metrics: ThemeMetrics
    ) -> String {
        let reference = metrics.referenceViewport
        guard size > 0, reference.width > 0, reference.height > 0 else {
            return "\(px(size))"
        }

        let vw = "\(round(size / reference.width * 100))vw"
        let vh = "\(round(size / reference.height * 100))vh"
        let relative = switch metrics.basis {
        case .width: vw
        case .height: vh
        case .fit: "min(\(vw), \(vh))"
        }
        return """
        clamp(\(px(size * metrics.minimumScale)), \
        \(relative), \
        \(px(size * metrics.maximumScale)))
        """
    }

    /// Trims a computed size to 3 decimals and appends `px` (CSS chokes on
    /// Swift's full `Double` description for some values).
    private static func px(
        _ value: Double
    ) -> String {
        "\(round(value))px"
    }

    private static func round(
        _ value: Double
    ) -> String {
        String(format: "%.3f", value)
    }

    private static func page(
        for theme: any Theme
    ) -> String {
        let colors = theme.colors
        let typography = theme.typography
        let spacing = theme.spacing
        let shape = theme.shape
        let metrics = theme.metrics
        let animation = theme.animation

        return """
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>DeskDashboard — Dev Renderer</title>
        <style>
          :root {
            --background: \(colors.background);
            --surface: \(colors.surface);
            --primary: \(colors.primary);
            --secondary: \(colors.secondary);
            --accent: \(colors.accent);
            --text: \(colors.text);
            --muted: \(colors.mutedText);
            /* Sizes are the theme's reference values (authored at
               \(round(metrics.referenceViewport.width))×\(round(metrics.referenceViewport.height)))
               expressed relative to the window, so resizing the browser scales
               the whole page the way a different screen scales the native UI. */
            --gap: \(responsive(spacing.widgetGap, metrics));
            --pad: \(responsive(spacing.tilePadding, metrics));
            --margin: \(responsive(spacing.sectionMargin, metrics));
            --radius: \(responsive(shape.cornerRadius, metrics));
            --border-width: \(px(shape.borderWidth));
            --fs-hero: \(responsive(typography.headingSize * 2, metrics));
            --fs-heading: \(responsive(typography.headingSize, metrics));
            --fs-body: \(responsive(typography.bodySize, metrics));
            --fs-caption: \(responsive(typography.captionSize, metrics));
            --transition: \(animation.transitionDuration)s \(cssEasing(animation.easing));
          }
          * { box-sizing: border-box; }
          body {
            margin: 0; background: var(--background); color: var(--text);
            /* Same stack as the design mock, so the preview and the reference
               render in the same face: Roboto on Linux, SF on Apple platforms. */
            font-family: \(typography.fontFamily), -apple-system, BlinkMacSystemFont,
                         "Segoe UI", Roboto, Arial, sans-serif;
          }
          header {
            display: flex; justify-content: space-between; align-items: baseline;
            padding: var(--margin) var(--margin) calc(var(--margin) / 2);
          }
          header h1 {
            margin: 0; font-size: var(--fs-caption);
            font-weight: \(typography.bodyWeight); color: var(--secondary);
            text-transform: uppercase; letter-spacing: .12em;
          }
          header h1 span { color: var(--muted); text-transform: none; letter-spacing: 0; }
          #status { font-size: var(--fs-caption); color: var(--muted); }
          #status.live { color: var(--accent); }
          #grid {
            display: flex; gap: var(--gap); align-items: stretch;
            padding: 0 var(--margin) var(--margin);
          }
          .tile {
            flex: 1 1 0; min-width: 0;
            position: relative; display: flex; flex-direction: column;
            gap: calc(var(--gap) * .5);
            background: var(--surface); border-radius: var(--radius);
            border: var(--border-width) solid color-mix(in srgb, var(--secondary) 18%, transparent);
            padding: var(--pad); transition: all var(--transition);
            container-type: inline-size; overflow: hidden;
          }
          .tile .title {
            font-size: var(--fs-caption); font-weight: \(typography.bodyWeight);
            color: var(--secondary); text-transform: uppercase; letter-spacing: .1em;
          }
          .tile .primary {
            /* Window-scaled hero size, still capped by the tile's own width so a
               long value can't overflow a narrow tile. */
            font-size: min(var(--fs-hero), 15cqw);
            font-weight: \(typography.headingWeight);
            color: var(--primary); line-height: 1.1;
            font-variant-numeric: tabular-nums; white-space: nowrap;
          }
          .tile .secondary {
            font-size: var(--fs-body); font-weight: \(typography.bodyWeight);
            color: var(--text);
          }
          .tile .meta {
            margin-top: auto; font-size: var(--fs-caption); color: var(--muted);
          }
          .tile .badge {
            position: absolute; top: var(--pad); right: var(--pad);
            background: var(--accent); color: var(--background);
            font-size: var(--fs-caption); font-weight: 700;
            padding: calc(var(--pad) * .2) calc(var(--pad) * .6); border-radius: 999px;
            animation: pulse 1s infinite var(--transition);
          }
          @keyframes pulse { 50% { opacity: .45; } }
        </style>
        </head>
        <body>
        <header>
          <h1>DeskDashboard <span>· \(theme.name) · dev renderer</span></h1>
          <div id="status">connecting…</div>
        </header>
        <div id="grid"></div>
        <script>
          const grid = document.getElementById("grid");
          const status = document.getElementById("status");

          function tileNode(t) {
            const el = document.createElement("div");
            el.className = "tile";
            if (t.column != null) {
              el.style.gridColumn = (t.column + 1) + " / span " + (t.columnSpan || 1);
              el.style.gridRow = (t.row + 1) + " / span " + (t.rowSpan || 1);
            }
            const add = (cls, text) => {
              if (!text) return;
              const n = document.createElement("div");
              n.className = cls;
              n.textContent = text;
              el.appendChild(n);
            };
            add("title", t.title);
            add("primary", t.primaryText || "…");
            add("secondary", t.secondaryText);
            if (t.metadata && t.metadata.length) {
              add("meta", t.metadata.map(m => m.label + ": " + m.value).join(" · "));
            }
            if (t.accessoryText) {
              const badge = document.createElement("div");
              badge.className = "badge";
              badge.textContent = t.accessoryText;
              el.appendChild(badge);
            }
            return el;
          }

          function draw(tiles) {
            const visible = tiles.filter(t => t.visible);
            let cols = 1;
            for (const t of visible) {
              if (t.column != null) cols = Math.max(cols, t.column + (t.columnSpan || 1));
            }
            grid.style.gridTemplateColumns = "repeat(" + cols + ", minmax(0, 1fr))";
            grid.replaceChildren(...visible.map(tileNode));
          }

          async function refresh() {
            try {
              const res = await fetch("/snapshots", { cache: "no-store" });
              const data = await res.json();
              draw(data.tiles || []);
              status.textContent = "● live";
              status.className = "live";
            } catch (e) {
              status.textContent = "○ disconnected";
              status.className = "";
            }
          }

          refresh();
          setInterval(refresh, 1000);
        </script>
        </body>
        </html>
        """
    }
}
