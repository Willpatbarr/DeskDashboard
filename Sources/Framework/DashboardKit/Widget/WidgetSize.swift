public enum WidgetSize: Equatable, Sendable {
    case automatic
    case small
    case medium
    case large
    case custom(width: Int, height: Int)
}
