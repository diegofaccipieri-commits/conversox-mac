import Foundation

enum DateParser {
    static func parse(_ value: String) -> Date? {
        let iso8601 = ISO8601DateFormatter()
        return iso8601.date(from: value)
    }
}
