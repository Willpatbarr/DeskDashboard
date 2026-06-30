public protocol Theme: Sendable {
    var name: String { get }
    var defaultLayout: any Layout { get }
}
