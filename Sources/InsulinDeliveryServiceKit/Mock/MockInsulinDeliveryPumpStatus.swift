//
//  MockInsulinDeliveryPumpStatus.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-23.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit

public struct MockInsulinDeliveryPumpStatus {

    var pumpState: IDPumpState

    var totalInsulinDelivered: Double {
        basalDelivered + bolusDelivered
    }

    var basalDelivered: Double
    
    var activeBasalRate: Double {
        guard let tempBasal else {
            return basalProfile?.rate(at: Date()) ?? 0
        }
        return tempBasal.rate
    }

    var bolusDelivered: Double {
        bolusDeliveredCompleted + bolusDeliveredActive
    }
    
    var bolusDeliveredCompleted: Double
    
    var bolusDeliveredActive: Double {
        activeBolusDeliveryStatus.insulinDelivered
    }

    var totalPrimingInsulin: Double

    var basalProfile: [BasalSegment]?
    
    var basalRateProfileActivated: Bool = false
    
    var basalRateScheduleStartDate: Date?
    
    var currentAnnunciation: GeneralAnnunciation? {
        annunciationStack.last
    }
    
    private var annunciationStack: [GeneralAnnunciation] = []
    
    mutating func addAnnunciation(_ annunciation: Annunciation) {
        annunciationStack.append(GeneralAnnunciation(from: annunciation))
    }
    
    func annunciation(with identifier: AnnunciationIdentifier) -> GeneralAnnunciation? {
        annunciationStack.first(where: { $0.identifier == identifier })
    }
    
    mutating func confirmAnnunciation(_ annunciation: Annunciation) {
        annunciationStack.removeAll(where: { $0.identifier == annunciation.identifier })
    }
    
    mutating func snoozeAnnunciation(_ annunciation: Annunciation) {
        guard let index = annunciationStack.firstIndex(where: { $0.identifier == annunciation.identifier}) else { return }
        var annunciationToUpdate = annunciationStack.remove(at: index)
        annunciationToUpdate.status = .snoozed
        annunciationStack.insert(annunciationToUpdate, at: index)
    }
    
    var nextBolusID: BolusID = 1
    
    var maxBolusAmount: Double = 25

    private(set) var tempBasal: UnfinalizedDose? {
        didSet {
            if let oldValue = oldValue {
                pumpState.activeTempBasalDeliveryStatus.insulinDelivered = oldValue.units * oldValue.progress(at: Date())
            }
        }
    }

    // used for tracking the bolus being delivered
    var bolus: UnfinalizedDose?
    // used for reporting bolus delivery
    private(set) var activeBolusDeliveryStatus: BolusDeliveryStatus {
        get {
            pumpState.activeBolusDeliveryStatus
        }
        set {
            if newValue != pumpState.activeBolusDeliveryStatus {
                pumpState.activeBolusDeliveryStatus = newValue
            }
        }
    }
    
    var priming: UnfinalizedDose?

    var activeBolusUpdateHandler: ((BolusDeliveryStatus) -> Void)?
    
    var estimatedDeliveryRate: Double
    
    var reservoirLevelWarningThresholdInUnits: Int
    
    var expiryWarningDuration: TimeInterval

    private var lastDeliveryUpdate: Date

    var initialReservoirLevel: Int {
        didSet {
            resetDeliveredInsulin()
            updateReservoirLevel()
        }
    }
    
    var lifespan: TimeInterval

    var isAuthenticated: Bool
    
    var therapyState: InsulinTherapyControlState {
        pumpState.deviceInformation?.therapyControlState ?? .undetermined
    }
    
    var operationalState: PumpOperationalState {
        pumpState.deviceInformation?.pumpOperationalState ?? .undetermined
    }
    
    var reservoirRemaining: Double {
        pumpState.deviceInformation?.reservoirLevel ?? 0
    }

    init(pumpState: IDPumpState = IDPumpState(),
         basalDelivered: Double = 0,
         bolusDelivered: Double = 0,
         totalPrimingInsulin: Double = 0,
         basalProfile: [BasalSegment]? = nil,
         basalRateScheduleStartDate: Date? = nil,
         tempBasal: UnfinalizedDose? = nil,
         lastDeliveryUpdate: Date = Date(),
         initialReservoirLevel: Int = 100,
         isAuthenticated: Bool = false,
         lifespan: TimeInterval = .days(10),
         estimatedDeliveryRate: Double = 2.5 / TimeInterval.minutes(1),
         expiryWarningDuration: TimeInterval = .days(1),
         reservoirLevelWarningThresholdInUnits: Int = 25)
    {
        self.pumpState = pumpState
        self.basalDelivered = basalDelivered
        self.bolusDeliveredCompleted = bolusDelivered
        self.estimatedDeliveryRate = estimatedDeliveryRate
        self.expiryWarningDuration = expiryWarningDuration
        self.reservoirLevelWarningThresholdInUnits = reservoirLevelWarningThresholdInUnits
        self.totalPrimingInsulin = totalPrimingInsulin
        self.basalProfile = basalProfile
        self.basalRateScheduleStartDate = basalRateScheduleStartDate
        self.tempBasal = tempBasal
        self.lastDeliveryUpdate = lastDeliveryUpdate
        self.initialReservoirLevel = initialReservoirLevel
        self.isAuthenticated = isAuthenticated
        self.lifespan = lifespan
        self.bolus = pumpState.activeBolusDeliveryStatus.unfinalizedBolus(estimatedBolusDeliveryRate: estimatedDeliveryRate)

        self.pumpState.deviceInformation?.reservoirLevel = Double(initialReservoirLevel)
    }

    static var deviceInformation: DeviceInformation {
        DeviceInformation(identifier: MockInsulinDeliveryPumpStatus.identifier,
                          serialNumber: MockInsulinDeliveryPumpStatus.serialNumber,
                          firmwareRevision: "1.0",
                          hardwareRevision: "1.0",
                          batteryLevel: 100,
                          therapyControlState: .stop,
                          pumpOperationalState: .waiting,
                          reservoirLevel: 100,
                          reportedRemainingLifetime: .days(10))
    }

    static var serialNumber: String { "12345678" }

    static var identifier: UUID { UUID(uuidString: "330A42B1-F4B8-43C6-91FA-1D67A4CB9ECF")! }

    static var withoutBasalProfile: MockInsulinDeliveryPumpStatus {
        MockInsulinDeliveryPumpStatus(pumpState: IDPumpState(deviceInformation: deviceInformation))
    }

    static var withBasalProfile: MockInsulinDeliveryPumpStatus {
        var mockIDPumpStatus = MockInsulinDeliveryPumpStatus.withoutBasalProfile

        mockIDPumpStatus.basalProfile = [BasalSegment(index: 1, rate: 1.0, duration: .hours(24))]
        mockIDPumpStatus.basalRateScheduleStartDate = Date()
        return mockIDPumpStatus
    }

    mutating func updateDeliveryIfNeeded() {
        // only force an update if a bolus is running, priming is running or it has been 10 seconds since the last update
        if activeBolusDeliveryStatus.progressState.isOngoing ||
            priming?.isFinished(at: Date()) == false ||
            abs(lastDeliveryUpdate.timeIntervalSinceNow) > 10
        {
            updateDelivery()
        }
    }
    
    mutating func updateDelivery(until now: Date = Date()) {
        updateTempBasalDelivery(until: now)
        updateBasalDelivery(until: now)
        updateBolusDelivery(until: now)
        updatePriming(until: now)
        updateReservoirLevel()
        lastDeliveryUpdate = now
    }
    
    mutating private func updateBasalDelivery(until now: Date = Date()) {
        guard let basalProfile = basalProfile else { return }
        
        // Prevent crash when time has changed, and now is before lastDeliveryUpdate
        guard lastDeliveryUpdate < now else {
            return
        }

        // creates an array of segments that were delivered with a duration of the time delivered
        let deliveredBasalSegmentsSinceLastUpdate = basalProfile.segmentsDeliveredBetween(start: lastDeliveryUpdate, end: now)

        // calculate the basal delivered
        for deliveredBasalSegment in deliveredBasalSegmentsSinceLastUpdate {
            basalDelivered += deliveredBasalSegment.duration.hours * deliveredBasalSegment.rate
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
        setTempBasal(unitsPerHour: unitsPerHour, duration: .minutes(Int(durationInMinutes)), at: now)
    }
    
    mutating func setTempBasal(unitsPerHour: Double, duration: TimeInterval, at now: Date = Date()) {
        updateDelivery(until: now)
        basalRateScheduleStartDate = nil
        tempBasal = UnfinalizedDose(decisionId: nil,
                                    tempBasalRate: unitsPerHour,
                                    startTime: now,
                                    duration: duration,
                                    scheduledCertainty: .certain)
    }

    mutating func cancelTempBasal(at now: Date = Date(), completion: @escaping ProcedureResultCompletion) {
        guard var tempBasal = tempBasal else {
            completion(.success)
            return
        }

        tempBasal.cancel(at: now)
        basalDelivered += tempBasal.units
        updateReservoirLevel()
        self.tempBasal = nil
        basalRateScheduleStartDate = now
        completion(.success)
    }

    mutating func endTempBasal(at now: Date = Date(), completion: @escaping (TimeInterval) -> Void) {
        guard var tempBasal = tempBasal else {
            return
        }

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
                bolusDeliveredCompleted += bolus.units
                activeBolusDeliveryStatus.insulinDelivered = bolus.units
                activeBolusDeliveryStatus.endTime = now
                activeBolusDeliveryStatus.progressState = .completed
                activeBolusUpdateHandler?(activeBolusDeliveryStatus)
                resetBolusDeliveryStatus()
            } else if let startTime = activeBolusDeliveryStatus.startTime,
                      now.timeIntervalSince(startTime) >= 0
            {
                let insulinDelivered = now.timeIntervalSince(startTime) * estimatedDeliveryRate
                let remainingDuration = (activeBolusDeliveryStatus.insulinProgrammed - insulinDelivered) / estimatedDeliveryRate
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

    mutating func setBolus(_ amount: Double, at now: Date = Date()) -> BolusDeliveryStatus {
        self.bolus = UnfinalizedDose(decisionId: nil,
                                     bolusAmount: amount,
                                     startTime: now,
                                     scheduledCertainty: .certain,
                                     estimatedBolusDeliveryRate: estimatedDeliveryRate)
        activeBolusDeliveryStatus = BolusDeliveryStatus(id: nextBolusID,
                                                        progressState: .inProgress,
                                                        type: .fast,
                                                        insulinProgrammed: amount,
                                                        insulinDelivered: 0,
                                                        startTime: now)
        nextBolusID += 1
        return activeBolusDeliveryStatus
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

        bolusDeliveredCompleted += bolus.units
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
    
    mutating func startPriming(_ amount: Double, at now: Date = Date()) {
        pumpState.deviceInformation?.pumpOperationalState = .priming
        priming = UnfinalizedDose(primeAmount: amount, startTime: now, scheduledCertainty: .certain, estimatedDeliveryRate: estimatedDeliveryRate)
    }
    
    mutating func stopPriming(at now: Date = Date()) -> Double? {
        guard priming != nil else { return nil }
        
        priming?.cancel(at: now)
        let amountPrimed = priming?.units
        updatePriming()
        
        return amountPrimed
    }
    
    mutating func updatePriming(until now: Date = Date()) {
        guard let priming else { return }
        
        if priming.isFinished(at: now) {
            totalPrimingInsulin += priming.units
            self.priming = nil
            pumpState.deviceInformation?.pumpOperationalState = (basalProfile?.isComplete ?? false) ? .ready : .waiting
        }
        
        updateReservoirLevel()
    }

    mutating func reservoirPrimed(_ amount: Double) {
        totalPrimingInsulin += amount
        priming = nil
        pumpState.deviceInformation?.pumpOperationalState = (basalProfile?.isComplete ?? false) ? .ready : .waiting
        updateReservoirLevel()
    }

    mutating func cannulaPrimed(_ amount: Double) {
        totalPrimingInsulin += amount
        priming = nil
        pumpState.deviceInformation?.pumpOperationalState = (basalProfile?.isComplete ?? false) ? .ready : .waiting
        updateReservoirLevel()
    }

    mutating private func resetDeliveredInsulin() {
        basalDelivered = 0
        bolusDeliveredCompleted = 0
        totalPrimingInsulin = 0
    }

    mutating func startInsulinDelivery(at now: Date = Date()) {
        basalRateScheduleStartDate = now
    }

    mutating func suspendInsulinDelivery(at now: Date = Date()) {
        cancelBolus(at: now, completion: { _ in })
        cancelTempBasal(at: now, completion: { _ in })
        updateDelivery(until: now)
        basalRateScheduleStartDate = nil
    }

    mutating func updateReservoirRemaining(_ reservoirRemaining: Double) {
        basalDelivered = Double(initialReservoirLevel) - reservoirRemaining - bolusDelivered - totalPrimingInsulin
        updateReservoirLevel()
    }
}

extension MockInsulinDeliveryPumpStatus: RawRepresentable {
    public typealias RawValue = [String: Any]

    private enum MockIDPumpStatusKey: String {
        case basalDelivered
        case basalProfile
        case basalRateScheduleStartDate
        case bolusDeliveredCompleted
        case estimatedDeliveryRate
        case expiryWarningDuration
        case initialReservoirLevel
        case isAuthenticated
        case lastDeliveryUpdate
        case lifespan
        case nextBolusID
        case maxBolusAmount
        case priming
        case pumpState
        case reservoirLevelWarningThresholdInUnits
        case tempBasal
        case totalPrimingInsulin
    }

    public init?(rawValue: RawValue) {
        guard
            let basalDelivered = rawValue[MockIDPumpStatusKey.basalDelivered.rawValue] as? Double,
            let bolusDeliveredCompleted = rawValue[MockIDPumpStatusKey.bolusDeliveredCompleted.rawValue] as? Double,
            let nextBolusID = rawValue[MockIDPumpStatusKey.nextBolusID.rawValue] as? BolusID,
            let maxBolusAmount = rawValue[MockIDPumpStatusKey.maxBolusAmount.rawValue] as? Double,
            let estimatedDeliveryRate = rawValue[MockIDPumpStatusKey.estimatedDeliveryRate.rawValue] as? Double,
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
        
        if let rawBasalProfile = rawValue[MockIDPumpStatusKey.basalProfile.rawValue] as? Data {
            self.basalProfile = try? PropertyListDecoder().decode([BasalSegment].self, from: rawBasalProfile)
        }
        
        self.basalRateScheduleStartDate = rawValue[MockIDPumpStatusKey.basalRateScheduleStartDate.rawValue] as? Date

        if let rawTempBasal = rawValue[MockIDPumpStatusKey.tempBasal.rawValue] as? UnfinalizedDose.RawValue {
            self.tempBasal = UnfinalizedDose(rawValue: rawTempBasal)
        }
        
        if let rawPriming = rawValue[MockIDPumpStatusKey.priming.rawValue] as? UnfinalizedDose.RawValue {
            self.priming = UnfinalizedDose(rawValue: rawPriming)
        }

        self.bolus = pumpState.activeBolusDeliveryStatus.unfinalizedBolus(estimatedBolusDeliveryRate: estimatedDeliveryRate)
        self.bolusDeliveredCompleted = bolusDeliveredCompleted
        self.nextBolusID = nextBolusID
        self.maxBolusAmount = maxBolusAmount
        self.estimatedDeliveryRate = estimatedDeliveryRate
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
            MockIDPumpStatusKey.bolusDeliveredCompleted.rawValue: bolusDeliveredCompleted,
            MockIDPumpStatusKey.nextBolusID.rawValue: nextBolusID,
            MockIDPumpStatusKey.maxBolusAmount.rawValue: maxBolusAmount,
            MockIDPumpStatusKey.estimatedDeliveryRate.rawValue: estimatedDeliveryRate,
            MockIDPumpStatusKey.expiryWarningDuration.rawValue: expiryWarningDuration,
            MockIDPumpStatusKey.reservoirLevelWarningThresholdInUnits.rawValue: reservoirLevelWarningThresholdInUnits,
            MockIDPumpStatusKey.initialReservoirLevel.rawValue: initialReservoirLevel,
            MockIDPumpStatusKey.isAuthenticated.rawValue: isAuthenticated,
            MockIDPumpStatusKey.lastDeliveryUpdate.rawValue: lastDeliveryUpdate,
            MockIDPumpStatusKey.lifespan.rawValue: lifespan,
            MockIDPumpStatusKey.pumpState.rawValue: pumpState.rawValue,
            MockIDPumpStatusKey.totalPrimingInsulin.rawValue: totalPrimingInsulin,
        ]
        
        let rawBasalProfile = try? PropertyListEncoder().encode(basalProfile)
        rawValue[MockIDPumpStatusKey.basalProfile.rawValue] = rawBasalProfile

        rawValue[MockIDPumpStatusKey.basalRateScheduleStartDate.rawValue] = basalRateScheduleStartDate
        rawValue[MockIDPumpStatusKey.tempBasal.rawValue] = tempBasal?.rawValue
        rawValue[MockIDPumpStatusKey.priming.rawValue] = priming?.rawValue

        return rawValue
    }
}

extension MockInsulinDeliveryPumpStatus: Equatable {
    public static func == (lhs: MockInsulinDeliveryPumpStatus, rhs: MockInsulinDeliveryPumpStatus) -> Bool {
        return lhs.pumpState == rhs.pumpState &&
        lhs.basalDelivered == rhs.basalDelivered &&
        lhs.bolusDeliveredCompleted == rhs.bolusDeliveredCompleted &&
        lhs.totalPrimingInsulin == rhs.totalPrimingInsulin &&
        lhs.basalProfile == rhs.basalProfile &&
        lhs.basalRateScheduleStartDate == rhs.basalRateScheduleStartDate &&
        lhs.tempBasal == rhs.tempBasal &&
        lhs.bolus == rhs.bolus &&
        lhs.nextBolusID == rhs.nextBolusID &&
        lhs.maxBolusAmount == rhs.maxBolusAmount &&
        lhs.priming == rhs.priming &&
        lhs.activeBolusDeliveryStatus == rhs.activeBolusDeliveryStatus &&
        lhs.lastDeliveryUpdate == rhs.lastDeliveryUpdate &&
        lhs.initialReservoirLevel == rhs.initialReservoirLevel &&
        lhs.estimatedDeliveryRate == rhs.estimatedDeliveryRate &&
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
