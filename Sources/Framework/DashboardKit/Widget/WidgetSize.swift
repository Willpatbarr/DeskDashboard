// WidgetSize.swift — How much grid space a widget asks for (automatic, small, medium, large, custom).

public enum WidgetSize: Equatable, Sendable {
    case automatic
    case small
    case medium
    case large
    case custom(width: Int, height: Int)
}
