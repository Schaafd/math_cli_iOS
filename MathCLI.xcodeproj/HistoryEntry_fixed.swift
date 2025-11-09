//
//  HistoryEntry.swift
//  MathCLI
//
//  SwiftData model for calculation history
//

import Foundation
import SwiftData
import Combine

@Model
final class HistoryEntry {
    @Attribute(.unique) var id: UUID
    var command: String
    var result: String
    var timestamp: Date
    var isBookmarked: Bool
    var bookmarkName: String?
    var sessionId: UUID

    init(command: String, result: String, timestamp: Date = Date(), isBookmarked: Bool = false, bookmarkName: String? = nil, sessionId: UUID = UUID()) {
        self.id = UUID()
        self.command = command
        self.result = result
        self.timestamp = timestamp
        self.isBookmarked = isBookmarked
        self.bookmarkName = bookmarkName
        self.sessionId = sessionId
    }

    var displayText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return "[\(formatter.string(from: timestamp))] \(command) = \(result)"
    }
}