//
//  BasalSegment.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

public struct BasalSegment: Equatable {
    let index: UInt8
    let rate: Double
    let durationInMinutes: UInt16
}

extension Array where Element == BasalSegment {
    func rate(at date: Date) -> Double? {
        let secondsFromStartOfDate = date.timeIntervalSince(Calendar.current.startOfDay(for: date))
        var secondsToCurrentSegment: TimeInterval = 0
        for segment in self {
            let segmentDurationInSeconds = TimeInterval(minutes: Double(segment.durationInMinutes))
            if (secondsFromStartOfDate - secondsToCurrentSegment) < segmentDurationInSeconds {
                return segment.rate
            }
            secondsToCurrentSegment += segmentDurationInSeconds
        }
        return nil
    }
}
