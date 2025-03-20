//
//  DeviceInformation.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

public struct DeviceInformation: PumpDeliveryStatus, Equatable, Codable {
    public var identifier: UUID
    public let serialNumber: String
    public var firmwareRevision: String?
    public var hardwareRevision: String?
    public var batteryLevel: Int?
    public var therapyControlState: InsulinTherapyControlState
    public var pumpOperationalState: PumpOperationalState
    public var reservoirLevel: Double?
    public var reservoirLevelWarningThresholdInUnits: Int?

    // Last reported pump lifetime remaining. Changes when the pump reports a new value.
    public var reportedRemainingLifetime: TimeInterval

    // Records the time of the last pump report of lifetime remaining.
    public var remainingLifetimeLastReportedAt: Date

    // Expiration date based on last reported pump lifetime remaining. On subsequent reports from the pump,
    // this date may move further into the future, as the pump's remaining lifetime counter stops decreasing
    // during periods of pump suspension.
    public var estimatedExpirationDate: Date {
        return remainingLifetimeLastReportedAt.addingTimeInterval(reportedRemainingLifetime)
    }

    // This value will change on each call, as it uses an implicit Date() call to estimate
    // remaining lifetime based on time since last reported lifetime remaining. It will continue
    // to decrease during periods of no pump communication, even if the pump's remaining lifetime
    // counter is not decreasing, due to something like suspension.
    public var estimatedRemainingLifeTime: TimeInterval {
        return estimatedExpirationDate.timeIntervalSinceNow
    }

    public init(identifier: UUID,
                serialNumber: String,
                firmwareRevision: String? = nil,
                hardwareRevision: String? = nil,
                batteryLevel: Int? = nil,
                therapyControlState: InsulinTherapyControlState = .undetermined,
                pumpOperationalState: PumpOperationalState = .undetermined,
                reservoirLevel: Double? = nil,
                reservoirLevelWarningThresholdInUnits: Int? = nil,
                reportedRemainingLifetime: TimeInterval,
                remainingLifetimeLastReportedAt: Date = Date()
    ) {
        self.identifier = identifier
        self.serialNumber = serialNumber
        self.firmwareRevision = firmwareRevision
        self.hardwareRevision = hardwareRevision
        self.batteryLevel = batteryLevel
        self.therapyControlState = therapyControlState
        self.pumpOperationalState = pumpOperationalState
        self.reservoirLevel = reservoirLevel
        self.reservoirLevelWarningThresholdInUnits = reservoirLevelWarningThresholdInUnits
        self.reportedRemainingLifetime = reportedRemainingLifetime
        self.remainingLifetimeLastReportedAt = remainingLifetimeLastReportedAt
    }
    
    public var isComplete: Bool {
        firmwareRevision != nil && batteryLevel != nil
    }

    public mutating func updateExpirationDate(remainingLifetime: TimeInterval, reportedAt: Date = Date()) {
        reportedRemainingLifetime = remainingLifetime
        remainingLifetimeLastReportedAt = reportedAt
    }
    
    public mutating func updateExpirationDate(replacementDate: Date?, lifespan: TimeInterval, reportedAt: Date = Date()) {
        guard let replacementDate = replacementDate else { return }
        let remainingLifetime = lifespan + replacementDate.timeIntervalSince(reportedAt)
        updateExpirationDate(remainingLifetime: remainingLifetime, reportedAt: reportedAt)
    }
}

public extension DeviceInformation {
    enum BatteryLevelIndicator {
        case full, medium, low, empty
        
        var threshold: Int {
            switch self {
            case .full:
                return 100
            case .medium:
                return 50
            case .low:
                return 25
            case .empty:
                return 0
            }
        }
    }
    
    var batteryLevelIndicator: BatteryLevelIndicator? {
        switch batteryLevel {
        case let x? where x > BatteryLevelIndicator.medium.threshold:
            return .full
        case let x? where x > BatteryLevelIndicator.low.threshold:
            return .medium
        case let x? where x > BatteryLevelIndicator.empty.threshold:
            return .low
        case let x? where x == BatteryLevelIndicator.empty.threshold:
            return .empty
        default:
            return nil
        }
    }
    
    func isReservoirLevelEstimated(_ reservoirAccuracyLimit: Double) -> Bool {
        (reservoirLevel ?? 0) > reservoirAccuracyLimit
    }
}
