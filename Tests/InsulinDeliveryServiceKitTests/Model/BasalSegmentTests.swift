//
//  BasalSegmentTests.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-24.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import InsulinDeliveryServiceKit

final class BasalSegmentTests: XCTestCase {
    
    private let basalSegments: [BasalSegment] = [
        BasalSegment(index: 1, rate: 0.2, duration: .minutes(120)),
        BasalSegment(index: 2, rate: 0.4, duration: .minutes(120)),
        BasalSegment(index: 3, rate: 0.6, duration: .minutes(120)),
        BasalSegment(index: 4, rate: 0.8, duration: .minutes(120)),
        BasalSegment(index: 5, rate: 1.0, duration: .minutes(120)),
        BasalSegment(index: 6, rate: 1.2, duration: .minutes(120)),
        BasalSegment(index: 7, rate: 1.4, duration: .minutes(120)),
        BasalSegment(index: 8, rate: 1.6, duration: .minutes(120)),
        BasalSegment(index: 9, rate: 1.8, duration: .minutes(120)),
        BasalSegment(index: 10, rate: 2.0, duration: .minutes(120)),
        BasalSegment(index: 11, rate: 2.2, duration: .minutes(120)),
        BasalSegment(index: 12, rate: 2.4, duration: .minutes(120)),
    ]
        
    func testRateAt() {
        var now = Calendar.current.startOfDay(for: Date()).addingTimeInterval(.minutes(15))
        XCTAssertEqual(0.2, basalSegments.rate(at: now))
        
        now.addTimeInterval(.hours(4))
        XCTAssertEqual(0.6, basalSegments.rate(at: now))
        
        now.addTimeInterval(.hours(4))
        XCTAssertEqual(1.0, basalSegments.rate(at: now))
        
        now.addTimeInterval(.hours(4))
        XCTAssertEqual(1.4, basalSegments.rate(at: now))
    }
    
    func testBetween() {
        // Fixed dates clear of any DST change: the schedule runs in elapsed time, so a 23 or 25 hour day shifts
        // every offset after it (the relative dates used before failed the day after fall-back).
        let startDate = date(2026, 1, 13, 17, 0)   // 17:00 two days before
        let endDate = date(2026, 1, 15, 11, 30)    // 11:30

        let basalSegmentsDeliveredBetween = basalSegments.segmentsDeliveredBetween(start: startDate, end: endDate)
        XCTAssertEqual(22, basalSegmentsDeliveredBetween.count)
        XCTAssertEqual(1.8, basalSegmentsDeliveredBetween.first?.rate)
        XCTAssertEqual(60, basalSegmentsDeliveredBetween.first?.duration.minutes)
        XCTAssertEqual(1.2, basalSegmentsDeliveredBetween.last?.rate)
        XCTAssertEqual(90, basalSegmentsDeliveredBetween.last?.duration.minutes)
    }

    /// A start exactly on a segment boundary begins with the next segment, not a zero-length one.
    func testBetweenStartingOnASegmentBoundary() {
        let startDate = date(2026, 1, 13, 18, 0)
        let endDate = date(2026, 1, 13, 21, 0)

        let segments = basalSegments.segmentsDeliveredBetween(start: startDate, end: endDate)
        XCTAssertEqual(2, segments.count)
        XCTAssertEqual(2.0, segments.first?.rate)
        XCTAssertEqual(120, segments.first?.duration.minutes)
        XCTAssertEqual(2.2, segments.last?.rate)
        XCTAssertEqual(60, segments.last?.duration.minutes)
        XCTAssertFalse(segments.contains { $0.duration == 0 })
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
