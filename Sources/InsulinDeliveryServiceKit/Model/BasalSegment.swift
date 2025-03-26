//
//  BasalSegment.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

public struct BasalSegment: Equatable {
    public let index: UInt8
    public let rate: Double
    public var durationInMinutes: UInt16
    
    public init(index: UInt8, rate: Double, durationInMinutes: UInt16) {
        self.index = index
        self.rate = rate
        self.durationInMinutes = durationInMinutes
    }
}

public extension Array where Element == BasalSegment {
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
    
    func segmentsDeliveredBetween(start startDate: Date, end endDate: Date) -> [BasalSegment] {
        guard startDate <= endDate else {
            return []
        }

        var basalSegments: [BasalSegment] = []
        var currentOffset = startDate.timeIntervalFromStartOfDay
        let endOffset = currentOffset + endDate.timeIntervalSince(startDate)
        var scheduleOffset: TimeInterval = 0
        
        while currentOffset < endOffset {
            for var basalSegment in self {
                let basalSegmentInterval = TimeInterval.minutes(Int(basalSegment.durationInMinutes))
                scheduleOffset = scheduleOffset + basalSegmentInterval
                if currentOffset <= scheduleOffset {
                    basalSegment.durationInMinutes = UInt16(scheduleOffset > endOffset ? (TimeInterval(minutes: Int(basalSegment.durationInMinutes)) + endOffset - scheduleOffset).minutes : (scheduleOffset - currentOffset).minutes)
                    currentOffset = scheduleOffset
                    basalSegments.append(basalSegment)
                }
                if currentOffset >= endOffset {
                    break
                }
            }
        }
        
        return basalSegments
    }
}
