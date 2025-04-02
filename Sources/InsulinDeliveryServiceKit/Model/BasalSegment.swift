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
    public var duration: TimeInterval
    
    public init(index: UInt8, rate: Double, duration: TimeInterval) {
        self.index = index
        self.rate = rate
        self.duration = duration
    }
}

public extension Array where Element == BasalSegment {
    var totalDuration: TimeInterval {
        return self.reduce(into: 0) { result, segment in
            result += segment.duration
        }
    }
    
    var isComplete: Bool {
        totalDuration == TimeInterval.days(1)
    }
    
    func rate(at date: Date) -> Double? {
        let secondsFromStartOfDate = date.timeIntervalSince(Calendar.current.startOfDay(for: date))
        var secondsToCurrentSegment: TimeInterval = 0
        for segment in self {
            if (secondsFromStartOfDate - secondsToCurrentSegment) < segment.duration {
                return segment.rate
            }
            secondsToCurrentSegment += segment.duration
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
                scheduleOffset = scheduleOffset + basalSegment.duration
                if currentOffset <= scheduleOffset {
                    basalSegment.duration = scheduleOffset > endOffset ? (endOffset - currentOffset) : (scheduleOffset - currentOffset)
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
