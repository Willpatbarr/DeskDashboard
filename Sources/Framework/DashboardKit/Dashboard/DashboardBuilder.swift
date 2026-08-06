// DashboardBuilder.swift — Result builder behind the `.widgets { … }` declarative syntax.

/// A SwiftUI-style result builder for declaring a dashboard's widgets:
///
/// ```swift
/// Dashboard()
///     .service(store, for: .someKey)
///     .widgets {
///         ClockWidget().title("Clock").size(.large)
///         MusicWidget().title("Music")
///     }
/// ```
///
/// Supports `if`/`if let`/`for` inside the block, so a dashboard's widget list
/// can be conditional or generated.
@resultBuilder
public enum DashboardBuilder {
    public static func buildExpression(_ widget: some Widget) -> [any Widget] {
        [widget]
    }

    public static func buildExpression(_ widgets: [any Widget]) -> [any Widget] {
        widgets
    }

    public static func buildBlock(_ groups: [any Widget]...) -> [any Widget] {
        groups.flatMap { $0 }
    }

    public static func buildOptional(_ widgets: [any Widget]?) -> [any Widget] {
        widgets ?? []
    }

    public static func buildEither(first widgets: [any Widget]) -> [any Widget] {
        widgets
    }

    public static func buildEither(second widgets: [any Widget]) -> [any Widget] {
        widgets
    }

    public static func buildArray(_ groups: [[any Widget]]) -> [any Widget] {
        groups.flatMap { $0 }
    }
}

extension Dashboard {
    /// Declares the dashboard's widgets. Add services *before* this in the chain
    /// — widgets read them from the environment as they attach.
    public func widgets(
        @DashboardBuilder _ make: () -> [any Widget]
    ) -> Self {
        var copy = self
        for widget in make() {
            copy.add(widget)
        }
        return copy
    }
}
