//
//  MockIDPumpStatus.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-23.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit

public struct MockIDPumpStatus {

    public var pumpState: IDPumpState

    public var totalInsulinDelivered: Double {
        return basalDelivered + bolusDelivered + activeBolusDeliveryStatus.insulinDelivered
    }

    public var basalDelivered: Double

    public var bolusDelivered: Double

    public var totalPrimingInsulin: Double

    public var basalSegments: [BasalSegment]?
    
    public var basalRateScheduleStartDate: Date?

    public private(set) var tempBasal: UnfinalizedDose? {
        didSet {
            if let oldValue = oldValue {
                pumpState.activeTempBasalDeliveryStatus.insulinDelivered = oldValue.units * oldValue.progress(at: Date())
            }
        }
    }

    // used for tracking the bolus being delivered
    private var bolus: UnfinalizedDose?
    // used for reporting bolus delivery
    public private(set) var activeBolusDeliveryStatus: BolusDeliveryStatus {
        get {
            pumpState.activeBolusDeliveryStatus
        }
        set {
            if newValue != pumpState.activeBolusDeliveryStatus {
                pumpState.activeBolusDeliveryStatus = newValue
            }
        }
    }

    public var activeBolusUpdateHandler: ((BolusDeliveryStatus) -> Void)?
    
    var estimatedBolusDeliveryRate: Double
    
    var reservoirLevelWarningThresholdInUnits: Int
    
    var expiryWarningDuration: TimeInterval

    private var lastDeliveryUpdate: Date

    public var initialReservoirLevel: Int {
        didSet {
            resetDeliveredInsulin()
            updateReservoirLevel()
        }
    }
    
    public var lifespan: TimeInterval

    public var isAuthenticated: Bool

    public init(pumpState: IDPumpState = IDPumpState(),
                basalDelivered: Double = 0,
                bolusDelivered: Double = 0,
                totalPrimingInsulin: Double = 0,
                basalSegments: [BasalSegment]? = nil,
                basalRateScheduleStartDate: Date? = nil,
                tempBasal: UnfinalizedDose? = nil,
                lastDeliveryUpdate: Date = Date(),
                initialReservoirLevel: Int = 200,
                isAuthenticated: Bool = false,
                lifespan: TimeInterval = .days(10),
                estimatedBolusDeliveryRate: Double = 2.5 / TimeInterval.minutes(1),
                expiryWarningDuration: TimeInterval = .days(1),
                reservoirLevelWarningThresholdInUnits: Int = 25)
    {
        self.pumpState = pumpState
        self.basalDelivered = basalDelivered
        self.bolusDelivered = bolusDelivered
        self.estimatedBolusDeliveryRate = estimatedBolusDeliveryRate
        self.expiryWarningDuration = expiryWarningDuration
        self.reservoirLevelWarningThresholdInUnits = reservoirLevelWarningThresholdInUnits
        self.totalPrimingInsulin = totalPrimingInsulin
        self.basalSegments = basalSegments
        self.basalRateScheduleStartDate = basalRateScheduleStartDate
        self.tempBasal = tempBasal
        self.lastDeliveryUpdate = lastDeliveryUpdate
        self.initialReservoirLevel = initialReservoirLevel
        self.isAuthenticated = isAuthenticated
        self.lifespan = lifespan
        self.bolus = pumpState.activeBolusDeliveryStatus.unfinalizedBolus(estimatedBolusDeliveryRate: estimatedBolusDeliveryRate)

        self.pumpState.deviceInformation?.reservoirLevel = Double(initialReservoirLevel)
    }

    static var deviceInformation: DeviceInformation {
        DeviceInformation(identifier: MockIDPumpStatus.identifier,
                          serialNumber: MockIDPumpStatus.serialNumber,
                          firmwareRevision: "1.0",
                          hardwareRevision: "1.0",
                          batteryLevel: 100,
                          therapyControlState: .stop,
                          pumpOperationalState: .waiting,
                          reservoirLevel: 200,
                          reportedRemainingLifetime: .days(10))
    }

    static var serialNumber: String { "12345678" }

    static var identifier: UUID { UUID(uuidString: "330A42B1-F4B8-43C6-91FA-1D67A4CB9ECF")! }

    public static var withoutBasalSchedule: MockIDPumpStatus {
        MockIDPumpStatus(pumpState: IDPumpState(deviceInformation: deviceInformation))
    }

    public static var withBasalSchedule: MockIDPumpStatus {
        var mockIDPumpStatus = MockIDPumpStatus.withoutBasalSchedule

        mockIDPumpStatus.basalSegments = [BasalSegment(index: 1, rate: 1.0, durationInMinutes: 1440)]
        mockIDPumpStatus.basalRateScheduleStartDate = Date()
        return mockIDPumpStatus
    }

    mutating func updateDeliveryIfNeeded() {
        // only force an update if a bolus is running and it has been 10 seconds since the last update
        guard activeBolusDeliveryStatus.progressState.isOngoing,
              abs(lastDeliveryUpdate.timeIntervalSinceNow) > 10
        else { return }
        
        updateDelivery()
    }
    
    mutating func updateDelivery(until now: Date = Date()) {
        updateTempBasalDelivery(until: now)
        updateBasalDelivery(until: now)
        updateBolusDelivery(until: now)
        updateReservoirLevel()
        lastDeliveryUpdate = now
    }
    
    mutating private func updateBasalDelivery(until now: Date = Date()) {
        guard let basalSegments = basalSegments else { return }
        
        // Prevent crash when time has changed, and now is before lastDeliveryUpdate
        guard lastDeliveryUpdate < now else {
            return
        }

        // creates an array of segments that were delivered with a duration of the time delivered
        let deliveredBasalSegmentsSinceLastUpdate = basalSegments.segmentsDeliveredBetween(start: lastDeliveryUpdate, end: now)

        // calculate the basal delivered
        for deliveredBasalSegment in deliveredBasalSegmentsSinceLastUpdate {
            basalDelivered += TimeInterval(minutes:Int(deliveredBasalSegment.durationInMinutes)).hours * deliveredBasalSegment.rate
        }
    }

    mutating private func updateTempBasalDelivery(until now: Date = Date()) {
        if let tempBasal = tempBasal, tempBasal.isFinished(at: now) {
            basalDelivered += tempBasal.units
            basalRateScheduleStartDate = tempBasal.endTime
            lastDeliveryUpdate = tempBasal.endTime ?? now
            self.tempBasal = nil
        }
    }

    mutating func setTempBasal(unitsPerHour: Double, durationInMinutes: UInt16, at now: Date = Date()) {
        updateDelivery(until: now)
        basalRateScheduleStartDate = nil
        tempBasal = UnfinalizedDose(tempBasalRate: unitsPerHour,
                                    startTime: now,
                                    duration: .minutes(Int(durationInMinutes)),
                                    scheduledCertainty: .certain)
    }

    mutating func cancelTempBasal(at now: Date = Date(), completion: @escaping ProcedureResultCompletion) {
        guard var tempBasal = tempBasal else { return }

        tempBasal.cancel(at: now)
        basalDelivered += tempBasal.units
        updateReservoirLevel()
        self.tempBasal = nil
        basalRateScheduleStartDate = now
        completion(.success)
    }

    mutating func endTempBasal(at now: Date = Date(), completion: @escaping (TimeInterval) -> Void) {
        guard var tempBasal = tempBasal else { return }

        tempBasal.cancel(at: now)
        basalDelivered += tempBasal.units
        updateReservoirLevel()
        self.tempBasal = nil
        basalRateScheduleStartDate = now
        let tempBasalDuration = tempBasal.duration ?? now.timeIntervalSince(tempBasal.startTime)
        completion(tempBasalDuration)
    }


    mutating func startEstimatingBolusProgress() {
        activeBolusDeliveryStatus.progressState = .estimatingProgress
        self.bolus?.scheduledCertainty = .uncertain
        activeBolusUpdateHandler?(activeBolusDeliveryStatus)
    }

    mutating func isActiveBolusDeliveryInProgress() -> Bool {
        guard activeBolusDeliveryStatus.progressState == .estimatingProgress else { return activeBolusDeliveryStatus.progressState == .inProgress }

        activeBolusDeliveryStatus.progressState = .inProgress
        updateBolusDelivery()
        return activeBolusDeliveryStatus.progressState == .inProgress
    }

    mutating private func updateBolusDelivery(until now: Date = Date()) {
        if let bolus = bolus,
           activeBolusDeliveryStatus != .noActiveBolus,
           activeBolusDeliveryStatus.progressState != .estimatingProgress
        {
            self.bolus?.scheduledCertainty = .certain
            if bolus.isFinished(at: now) {
                bolusDelivered += bolus.units
                activeBolusDeliveryStatus.insulinDelivered = bolus.units
                activeBolusDeliveryStatus.endTime = now
                activeBolusDeliveryStatus.progressState = .completed
                activeBolusUpdateHandler?(activeBolusDeliveryStatus)
                resetBolusDeliveryStatus()
            } else if let startTime = activeBolusDeliveryStatus.startTime,
                      now.timeIntervalSince(startTime) >= 0
            {
                let insulinDelivered = now.timeIntervalSince(startTime) * estimatedBolusDeliveryRate
                let remainingDuration = (activeBolusDeliveryStatus.insulinProgrammed - insulinDelivered) / estimatedBolusDeliveryRate
                self.bolus?.endTime = now.addingTimeInterval(remainingDuration)

                let progress = insulinDelivered / activeBolusDeliveryStatus.insulinProgrammed
                activeBolusDeliveryStatus.insulinDelivered = insulinDelivered.roundedToHundredths
                activeBolusDeliveryStatus.progressState = progress > 0 ? .inProgress : .noActiveBolus
                activeBolusUpdateHandler?(activeBolusDeliveryStatus)
            } else {
                // bolus has not started yet
                activeBolusDeliveryStatus.insulinDelivered = 0
                activeBolusDeliveryStatus.progressState = .noActiveBolus
                activeBolusUpdateHandler?(activeBolusDeliveryStatus)
            }
        }
    }

    mutating public func setBolus(_ amount: Double, at now: Date = Date()) {
        self.bolus = UnfinalizedDose(bolusAmount: amount,
                                     startTime: now,
                                     scheduledCertainty: .certain,
                                     estimatedBolusDeliveryRate: estimatedBolusDeliveryRate)
        activeBolusDeliveryStatus = BolusDeliveryStatus(id: (activeBolusDeliveryStatus.id ?? 0) + 1,
                                                        progressState: .inProgress,
                                                        type: .fast,
                                                        insulinProgrammed: amount,
                                                        insulinDelivered: 0,
                                                        startTime: now)
    }

    mutating private func resetBolusDeliveryStatus() {
        activeBolusUpdateHandler = nil
        activeBolusDeliveryStatus = .noActiveBolus
        self.bolus = nil
    }

    mutating func cancelBolus(at now: Date = Date(), completion: @escaping (DeviceCommResult<BolusDeliveryStatus>) -> Void) {
        guard var bolus = bolus else {
            return
        }

        if bolus.isFinished(at: now) {
            updateBolusDelivery(until: now)
            completion(.success(activeBolusDeliveryStatus))
            activeBolusDeliveryStatus = .noActiveBolus
            return
        }

        bolus.cancel(at: now)

        bolusDelivered += bolus.units
        activeBolusDeliveryStatus.insulinDelivered = bolus.units
        activeBolusDeliveryStatus.progressState = .canceled
        activeBolusDeliveryStatus.endTime = now

        activeBolusUpdateHandler?(activeBolusDeliveryStatus)
        completion(.success(activeBolusDeliveryStatus))

        resetBolusDeliveryStatus()
    }

    mutating private func updateReservoirLevel() {
        let reservoirLevel = max(Double(initialReservoirLevel) - totalInsulinDelivered - totalPrimingInsulin, 0)
        pumpState.deviceInformation?.reservoirLevel = reservoirLevel
    }

    mutating public func reservoirPrimed(_ amount: Double) {
        totalPrimingInsulin += amount
        updateReservoirLevel()
    }

    mutating public func cannulaPrimed(_ amount: Double) {
        totalPrimingInsulin += amount
        updateReservoirLevel()
    }

    mutating private func resetDeliveredInsulin() {
        basalDelivered = 0
        bolusDelivered = 0
        totalPrimingInsulin = 0
    }

    mutating public func startInsulinDelivery(at now: Date = Date()) {
        basalRateScheduleStartDate = now
    }

    mutating public func suspendInsulinDelivery(at now: Date = Date()) {
        cancelBolus(at: now, completion: { _ in })
        cancelTempBasal(at: now, completion: { _ in })
        updateDelivery(until: now)
        basalRateScheduleStartDate = nil
    }

    mutating public func updateReservoirRemaining(_ reservoirRemaining: Double) {
        basalDelivered = Double(initialReservoirLevel) - reservoirRemaining - bolusDelivered - activeBolusDeliveryStatus.insulinDelivered - totalPrimingInsulin
        updateReservoirLevel()
    }
}

extension MockIDPumpStatus: RawRepresentable {
    public typealias RawValue = [String: Any]

    private enum MockIDPumpStatusKey: String {
        case basalDelivered
        case basalSegments
        case basalRateScheduleStartDate
        case bolusDelivered
        case estimatedBolusDeliveryRate
        case expiryWarningDuration
        case initialReservoirLevel
        case isAuthenticated
        case lastDeliveryUpdate
        case lifespan
        case pumpState
        case reservoirLevelWarningThresholdInUnits
        case tempBasal
        case totalPrimingInsulin
    }

    public init?(rawValue: RawValue) {
        guard
            let basalDelivered = rawValue[MockIDPumpStatusKey.basalDelivered.rawValue] as? Double,
            let bolusDelivered = rawValue[MockIDPumpStatusKey.bolusDelivered.rawValue] as? Double,
            let estimatedBolusDeliveryRate = rawValue[MockIDPumpStatusKey.estimatedBolusDeliveryRate.rawValue] as? Double,
            let expiryWarningDuration = rawValue[MockIDPumpStatusKey.expiryWarningDuration.rawValue] as? TimeInterval,
            let reservoirLevelWarningThresholdInUnits = rawValue[MockIDPumpStatusKey.reservoirLevelWarningThresholdInUnits.rawValue] as? Int,
            let initialReservoirLevel = rawValue[MockIDPumpStatusKey.initialReservoirLevel.rawValue] as? Int,
            let isAuthenticated = rawValue[MockIDPumpStatusKey.isAuthenticated.rawValue] as? Bool,
            let lastDeliveryUpdate = rawValue[MockIDPumpStatusKey.lastDeliveryUpdate.rawValue] as? Date,
            let lifespan = rawValue[MockIDPumpStatusKey.lifespan.rawValue] as? TimeInterval,
            let rawPumpState = rawValue[MockIDPumpStatusKey.pumpState.rawValue] as? IDPumpState.RawValue,
            let pumpState = IDPumpState(rawValue: rawPumpState),
            let totalPrimingInsulin = rawValue[MockIDPumpStatusKey.totalPrimingInsulin.rawValue] as? Double
        else {
            return nil
        }

        self.basalDelivered = basalDelivered
        self.basalSegments = rawValue[MockIDPumpStatusKey.basalSegments.rawValue] as? [BasalSegment]
        self.basalRateScheduleStartDate = rawValue[MockIDPumpStatusKey.basalRateScheduleStartDate.rawValue] as? Date

        if let rawTempBasal = rawValue[MockIDPumpStatusKey.tempBasal.rawValue] as? UnfinalizedDose.RawValue {
            self.tempBasal = UnfinalizedDose(rawValue: rawTempBasal)
        }

        self.bolus = pumpState.activeBolusDeliveryStatus.unfinalizedBolus(estimatedBolusDeliveryRate: estimatedBolusDeliveryRate)
        self.bolusDelivered = bolusDelivered
        self.estimatedBolusDeliveryRate = estimatedBolusDeliveryRate
        self.expiryWarningDuration = expiryWarningDuration
        self.reservoirLevelWarningThresholdInUnits = reservoirLevelWarningThresholdInUnits
        self.initialReservoirLevel = initialReservoirLevel
        self.isAuthenticated = isAuthenticated
        self.lastDeliveryUpdate = lastDeliveryUpdate
        self.lifespan = lifespan
        self.pumpState = pumpState
        self.totalPrimingInsulin = totalPrimingInsulin
    }

    public var rawValue: RawValue {
        var rawValue: RawValue = [
            MockIDPumpStatusKey.basalDelivered.rawValue: basalDelivered,
            MockIDPumpStatusKey.bolusDelivered.rawValue: bolusDelivered,
            MockIDPumpStatusKey.estimatedBolusDeliveryRate.rawValue: estimatedBolusDeliveryRate,
            MockIDPumpStatusKey.expiryWarningDuration.rawValue: expiryWarningDuration,
            MockIDPumpStatusKey.reservoirLevelWarningThresholdInUnits.rawValue: reservoirLevelWarningThresholdInUnits,
            MockIDPumpStatusKey.initialReservoirLevel.rawValue: initialReservoirLevel,
            MockIDPumpStatusKey.isAuthenticated.rawValue: isAuthenticated,
            MockIDPumpStatusKey.lastDeliveryUpdate.rawValue: lastDeliveryUpdate,
            MockIDPumpStatusKey.lifespan.rawValue: lifespan,
            MockIDPumpStatusKey.pumpState.rawValue: pumpState.rawValue,
            MockIDPumpStatusKey.totalPrimingInsulin.rawValue: totalPrimingInsulin,
        ]

        rawValue[MockIDPumpStatusKey.basalSegments.rawValue] = basalSegments
        rawValue[MockIDPumpStatusKey.basalRateScheduleStartDate.rawValue] = basalRateScheduleStartDate
        rawValue[MockIDPumpStatusKey.tempBasal.rawValue] = tempBasal?.rawValue

        return rawValue
    }
}

fileprivate extension TimeInterval {
    var fromStartOfDay: TimeInterval {
        self.truncatingRemainder(dividingBy: TimeInterval.days(1))
    }
}

extension MockIDPumpStatus: Equatable {
    public static func == (lhs: MockIDPumpStatus, rhs: MockIDPumpStatus) -> Bool {
        return lhs.pumpState == rhs.pumpState &&
        lhs.basalDelivered == rhs.basalDelivered &&
        lhs.bolusDelivered == rhs.bolusDelivered &&
        lhs.totalPrimingInsulin == rhs.totalPrimingInsulin &&
        lhs.basalSegments == rhs.basalSegments &&
        lhs.basalRateScheduleStartDate == rhs.basalRateScheduleStartDate &&
        lhs.tempBasal == rhs.tempBasal &&
        lhs.bolus == rhs.bolus &&
        lhs.activeBolusDeliveryStatus == rhs.activeBolusDeliveryStatus &&
        lhs.lastDeliveryUpdate == rhs.lastDeliveryUpdate &&
        lhs.initialReservoirLevel == rhs.initialReservoirLevel &&
        lhs.estimatedBolusDeliveryRate == rhs.estimatedBolusDeliveryRate &&
        lhs.expiryWarningDuration == rhs.expiryWarningDuration &&
        lhs.lifespan == rhs.lifespan &&
        lhs.reservoirLevelWarningThresholdInUnits == rhs.reservoirLevelWarningThresholdInUnits
    }
}

extension UnfinalizedDose {
    func bolusDeliveryStatus(at now: Date = Date()) -> BolusDeliveryStatus {
        let progressState: BolusProgressState
        let progress = progress(at: now)
        let programmedUnits = programmedUnits ?? units
        if progress >= 1 {
            progressState = .completed
        } else if progress > 0 {
            progressState = .inProgress
        } else {
            progressState = .noActiveBolus
        }
        return BolusDeliveryStatus(id: 1,
                                   progressState: progressState,
                                   type: .fast,
                                   insulinProgrammed: programmedUnits,
                                   insulinDelivered: progress * programmedUnits)
    }
}
