// DateService.swift
import Foundation

public struct DateService {
    public static func parse(_ query: String) -> Date? {
        let lower = query.lowercased()
        if lower == "today" { return .now }
        if lower == "tomorrow" { return Calendar.current.date(byAdding: .day, value: 1, to: .now) }
        return nil
    }
}
