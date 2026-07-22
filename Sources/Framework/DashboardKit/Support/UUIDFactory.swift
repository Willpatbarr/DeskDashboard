import Foundation

enum UUIDFactory {
    static func makeID(prefix: String) -> String {
        "\(prefix)-\(UUID().uuidString)"
    }
}
