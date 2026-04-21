// DateService.swift
import Foundation

public struct DateService {
    public static func parse(_ query: String) -> Date? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let matches = detector?.matches(in: query, options: [], range: NSRange(location: 0, length: query.utf16.count))
        return matches?.first?.date
    }
}
