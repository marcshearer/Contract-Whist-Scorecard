//
//  Date Extensions.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 17/07/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import Foundation

extension Date {
    
    static let fullDateFormat = "yyyy-MM-dd HH:mm:ss.SSS ZZZZ"
    
    init(from dateString: String, format: String = "dd/MM/yyyy") {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        self = formatter.date(from: dateString) ?? Date(timeIntervalSince1970: 0)
    }

    init(fullDate dateString: String) {
        self.init(from: dateString, format: Date.fullDateFormat)
    }
    
    func toString(format: String = "dd/MM/yyyy", localized: Bool = true) -> String {
        let formatter = DateFormatter()
        if localized {
            formatter.setLocalizedDateFormatFromTemplate(format)
        } else {
            formatter.dateFormat = format
        }
        return formatter.string(from: self)
    }
    
    func toFullString() -> String {
        return self.toString(format: Date.fullDateFormat, localized: false)
    }
    
    static public func startOfMinute(addMinutes: Int = 0, onlyAddIfRounded: Bool = false, rounding: Int = 1, from date: Date = Date()) -> Date {
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: date)
        var rounded = Int(minute / rounding) * rounding
        if minute != rounded || !onlyAddIfRounded {
            rounded += addMinutes
        }
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        components.minute = rounded
        return calendar.date(from: components)!
    }
    
    static public func startOfDay(days: Int = 0, from date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: days, to: startOfDay)
    }
    
    static public func endOfDay(days: Int = 0, from date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        if let startOfNextDay = calendar.date(byAdding: .day, value: days + 1, to: startOfDay) {
            return Date(timeInterval: -1, since: startOfNextDay)
        } else {
            return nil
        }
    }
    
    static public func startOfWeek(weeks: Int = 0, from date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        guard let sunday = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) else { return nil }
        return calendar.date(byAdding: .day, value: (weeks * 7), to: sunday)
    }
    
    static public func startOfMonth(months: Int = 0, from date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        guard let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else { return nil}
        return calendar.date(byAdding: .month, value: months, to: firstOfMonth)
    }
    
    static public func startOfYear(years: Int = 0, from date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        guard let firstOfYear = calendar.date(from: calendar.dateComponents([.year], from: date)) else { return nil}
        return calendar.date(byAdding: .year, value: years, to: firstOfYear)
    }
    
}
