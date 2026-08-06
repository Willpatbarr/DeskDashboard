// UUIDFactory.swift — Generates the unique ids widgets and dashboards are stamped with.

import Foundation

enum UUIDFactory {
    static func makeID(prefix: String) -> String {
        "\(prefix)-\(UUID().uuidString)"
    }
}
