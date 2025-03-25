//
//  MockIDPump.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-23.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import UIKit
import BluetoothCommonKit

open class MockIDPump: IDPumpComms, @unchecked Sendable {
    
    public static let defaultSchedulerTimeDelay: TimeInterval = 1.0 // set to 1 second to mimic actual pump comms

    let defaultBolusID: BolusID = 123

    public weak var delegate: IDPumpCommDelegate?

    public weak var loggingDelegate: DeviceCommLoggingDelegate?

    // TODO is this right. Was public let lockedStatus: Locked<MockIDPumpStatus>. However specific pumps will need a specific implementation of status.
    open var lockedStatus: Locked<MockIDPumpStatus>

    var lastCommsDate: Date? {
        get {
            state.lastCommsDate
        }
        set {
            status.pumpState.lastCommsDate = newValue
        }
    }

    open var status: MockIDPumpStatus {
        get {
            return lockedStatus.value
        }
        set {
            var oldStatus: MockIDPumpStatus?
            lockedStatus.mutate { status in
                oldStatus = status
                status = newValue
            }

            let newPumpState = newValue.pumpState
            guard let oldPumpState = oldStatus?.pumpState,
                  (oldPumpState != newPumpState || oldStatus != status)
            else { return }

            if isConnected {
                delegate?.pumpDidUpdateState(self)

                if oldStatus?.expiryWarningDuration != status.expiryWarningDuration ||
                    oldPumpState.deviceInformation?.estimatedExpirationDate != newPumpState.deviceInformation?.estimatedExpirationDate
                {
                    triggerExpirationIfNeeded()
                }

                if oldStatus?.reservoirLevelWarningThresholdInUnits != status.reservoirLevelWarningThresholdInUnits ||
                    oldPumpState.deviceInformation?.reservoirLevel != newPumpState.deviceInformation?.reservoirLevel
                {
                    triggerReservoirAnnunciationIfNeeded()
                }

                // check if the temp basal ended
                if let tempBasal = oldStatus?.tempBasal,
                   newValue.tempBasal == nil
                {
                    let duration = tempBasal.duration ?? Date().timeIntervalSince(tempBasal.startTime)
                    reportTempBasalEnded(tempBasalDuration: duration)
                }
            }
        }
    }

    public var state: IDPumpState {
        get {
            status.pumpState
        }
        set {
            if status.pumpState != newValue {
                status.pumpState = newValue
                if isConnected {
                    delegate?.pumpDidSync(self)
                }
            }
        }
    }

    public var isBolusActive: Bool {
        status.updateDeliveryIfNeeded()
        return status.activeBolusDeliveryStatus.progressState != .noActiveBolus
    }
    
    public var activeBolusID: BolusID? { status.activeBolusDeliveryStatus.id }

    public var isTempBasalActive: Bool { status.tempBasal != nil }

    public var isConnected: Bool = true {
        didSet {
            guard isConnected != oldValue else { return }

            if !isConnected && isBolusActive {
                status.startEstimatingBolusProgress()
            } else if isConnected && status.isActiveBolusDeliveryInProgress() {
                status.updateDelivery()
            }
            delegate?.pumpDidUpdateState(self)
            delegate?.pumpConnectionStatusChanged(self)
        }
    }

    public var isAuthenticated: Bool {
        get {
            status.isAuthenticated
        }
        set {
            if status.isAuthenticated != newValue {
                status.isAuthenticated = newValue
            }
        }
    }

    public var isAwaitingConfiguration = false
    
    public func getTime(using timeZone: TimeZone, completion: @escaping ProcedureTimeCompletion) {
        scheduleTask(after: schedulerDelay) {
            completion(.success(Date()))
        }
    }

    public func setTime(_ date: Date = Date(), using timeZone: TimeZone, completion: @escaping ProcedureResultCompletion) {
        scheduleTask(after: schedulerDelay) {
            completion(.success)
        }
    }

    public func setOOBString(_ oobString: String) {
        if let oobData = oobString.data(using: .utf8) {
            state.securityManagerConfiguration.oobRandomNumber = oobData
            prepareForNewPump()
        }
    }

    public var deviceInformation: DeviceInformation? {
        get {
            return state.deviceInformation
        }
        set {
            if state.deviceInformation != newValue {
                state.deviceInformation = newValue
            }
            if isConnected {
                triggerStoppedAnnunciationIfNeeded()
            }
        }
    }

    private let schedulerDelay: TimeInterval

    public var currentAnnunciationIdentifier: AnnunciationIdentifier = 1

    public var errorOnNextComms: DeviceCommError?

    private var lowReservoirDidAlert: Bool = false

    public var stoppedAnnunciationTimer: Timer?
    
    public var authenticationError: DeviceCommError?
    
    public var stoppedNotificationDelay = TimeInterval.hours(1)

    public var uncertainDeliveryEnabled: Bool = false {
        didSet {
            if !uncertainDeliveryEnabled {
                resolveUncertainDelivery()
            }
        }
    }

    public var uncertainDeliveryCommandReceived: Bool = false

    private var pendingResponse: (() -> Void)?

    public init(status: MockIDPumpStatus? = nil, schedulerDelay: TimeInterval = MockIDPump.defaultSchedulerTimeDelay) {
        self.schedulerDelay = schedulerDelay
        guard let status = status else {
            lockedStatus = Locked(MockIDPumpStatus())
            return
        }
        lockedStatus = Locked(status)
    }

    @Sendable
    private func scheduleTask(after time: TimeInterval, task: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + time) {
            if self.isConnected && self.errorOnNextComms == nil {
                self.lastCommsDate = Date()
            }
            task()
        }
    }

    open func prepareForNewPump() {
        loggingDelegate?.logConnectionEvent("preparing to advertise mock pump")
        reset()

        var schedulerDelay = schedulerDelay
        if schedulerDelay >= MockIDPump.defaultSchedulerTimeDelay {
            schedulerDelay = schedulerDelay + 5
        }
        scheduleTask(after: schedulerDelay) {
            self.loggingDelegate?.logConnectionEvent("mock pump is discovered")
            self.delegate?.pump(self, didDiscoverPumpWithName: "Mock Insulin Delivery Pump", identifier: MockIDPumpStatus.identifier, serialNumber: MockIDPumpStatus.serialNumber)
        }
    }

    open func connectToPump(withIdentifier identifier: UUID, andSerialNumber serialNumber: String) {
        connectToPump()
    }

    private func connectToPump() {
        scheduleTask(after: schedulerDelay) {
            self.deviceInformation = MockIDPumpStatus.deviceInformation

            self.loggingDelegate?.logConnectionEvent("mock pump is connected")
            self.isConnected = true
            self.delegate?.pumpConnectionStatusChanged(self)
            self.scheduleTask(after: self.schedulerDelay) {
                self.isAuthenticated = self.authenticationError == nil
                self.delegate?.pumpDidCompleteAuthentication(self, error: self.authenticationError)
                if self.authenticationError == nil {
                    // mimic a disconnect like the updated firmware
                    self.scheduleTask(after: self.schedulerDelay) {
                        self.delegate?.pumpDidCompleteAuthentication(self, error: self.authenticationError)
                    }
                }
                self.authenticationError = nil
            }
        }
    }

    open func prepareForDeactivation(completion: @escaping ProcedureResultCompletion) {
        reset()
        completion(.success)
    }

    open func reset() {
        deviceInformation = nil
        isAuthenticated = false
        isConnected = false
        uncertainDeliveryEnabled = false
        uncertainDeliveryCommandReceived = false
        resetCounters()
    }

    public func resetCounters() {
        state.idControlPointNextE2ECounter = 1
        state.idStatusReaderNextE2ECounter = 1
        state.recordAccessControlPointNextE2ECounter = 1
    }

    public func prepareForInsulinDelivery(reservoirLevel: Int, basalSegments: [BasalSegment], completion: @escaping ProcedureResultCompletion) {
        loggingDelegate?.logSendEvent("Preparing mock pump for insulin delivery. reservoirLevel: \(reservoirLevel), basalSegments: \(basalSegments)")

        let response: ProcedureResultCompletion = { result in
            completion(result)
            self.delegate?.pumpDidCompleteTherapyUpdate(self)
            self.loggingDelegate?.logReceiveEvent("Prepared for insulin delivery")
        }

        checkCommsStateAndRespond(response: response) { [weak self] in
            guard let self = self else { return }
            self.status.initialReservoirLevel = reservoirLevel
            self.status.basalSegments = basalSegments
            self.lowReservoirDidAlert = false
        }
    }

    public func startPrimingReservoir(_ amount: Double, completion: @escaping ProcedureResultCompletion) {
        loggingDelegate?.logSendEvent()

        let response: ProcedureResultCompletion = { result in
            self.loggingDelegate?.logReceiveEvent("Started priming reservoir")
            completion(result)
        }

        checkCommsStateAndRespond(response: response) { [weak self] in
            guard let self = self else { return }
            self.deviceInformation?.pumpOperationalState = .priming
            self.scheduleTask(after: .seconds(10)) {
                self.status.reservoirPrimed(amount)
                if self.deviceInformation?.pumpOperationalState == .priming {
                    self.deviceInformation?.pumpOperationalState = .ready
                    self.loggingDelegate?.logReceiveEvent("Priming reservoir stopped")
                }
            }
        }
    }

    public func primeCannula(_ amount: Double, completion: @escaping ProcedureResultCompletion) {
        loggingDelegate?.logSendEvent()

        let response: ProcedureResultCompletion = { result in
            self.loggingDelegate?.logReceiveEvent("Started priming cannula")
            completion(result)
        }

        checkCommsStateAndRespond(response: response) { [weak self] in
            guard let self = self else { return }
            self.deviceInformation?.pumpOperationalState = .priming

            self.scheduleTask(after: self.schedulerDelay) {
                self.status.cannulaPrimed(amount)
                self.deviceInformation?.pumpOperationalState = .ready
                self.loggingDelegate?.logReceiveEvent("Priming cannula stopped")
            }
        }
    }

    public func stopPriming(completion: @escaping ProcedureResultCompletion) {
        loggingDelegate?.logSendEvent()

        let response: ProcedureResultCompletion = { result in
            self.loggingDelegate?.logReceiveEvent("Priming stopped")
            completion(result)
        }

        checkCommsStateAndRespond(response: response) { [weak self] in
            guard let self = self else { return }
            self.deviceInformation?.pumpOperationalState = .ready
        }
    }

    public func startInsulinDelivery(completion: @escaping PumpDeliveryStatusCompletion) {
        loggingDelegate?.logSendEvent()

        guard self.deviceInformation != nil else {
            completion(.failure(.deviceNotReady))
            self.loggingDelegate?.logErrorEvent("Mock pump is not configured")
            return
        }

        let response: ProcedureResultCompletion = { result in
            switch result {
            case .success:
                self.loggingDelegate?.logReceiveEvent("Insulin delivery resumed")
                completion(.success(self.deviceInformation))
            case .failure(let error):
                completion(.failure(error))
            }
        }

        self.checkCommsStateAndRespond(insulinDeliveryCommand: true, response: response) { [weak self] in
            guard let self = self else { return }
            self.deviceInformation?.therapyControlState = .run
            self.status.startInsulinDelivery()
        }
    }

    public func suspendInsulinDelivery(completion: @escaping PumpDeliveryStatusCompletion) {
        loggingDelegate?.logSendEvent()

        guard let deviceInformation = self.deviceInformation else {
            completion(.failure(.deviceNotReady))
            self.loggingDelegate?.logErrorEvent("Mock pump is not configured")
            return
        }

        let response: ProcedureResultCompletion = { result in
            switch result {
            case .success:
                self.loggingDelegate?.logReceiveEvent("Insulin delivery suspended")
                completion(.success(deviceInformation))
                self.reportInsulinDeliveryStopped()
            case .failure(let error):
                completion(.failure(error))
            }
        }

        self.checkCommsStateAndRespond(insulinDeliveryCommand: true, response: response) { [weak self] in
            guard let self = self else { return }
            self.deviceInformation?.therapyControlState = .stop
            self.cancelTempBasal() { _ in }
            self.cancelBolus() { _ in }
            self.status.suspendInsulinDelivery()
        }
    }

    public func confirmAnnunciation(_ annunciation: Annunciation, completion: @escaping ProcedureResultCompletion) {
        self.loggingDelegate?.logSendEvent("Confirming annunciation \(annunciation)")

        let response: ProcedureResultCompletion = { result in
            self.loggingDelegate?.logReceiveEvent("annunciation \(annunciation) confirmed")
            completion(result)
        }

        checkCommsStateAndRespond(response: response)
    }

    public func getInsulinDeliveryStatus(completion: @escaping ProcedureResultCompletion) {
        loggingDelegate?.logSendEvent()

        let response: ProcedureResultCompletion = { result in
            self.loggingDelegate?.logReceiveEvent("Received insulin delivery status")
            completion(result)
        }

        checkCommsStateAndRespond(response: response)
    }

    public func setBasalRateSchedule(_ basalSegments: [BasalSegment], completion: @escaping ProcedureResultCompletion) {
        loggingDelegate?.logSendEvent("Setting basalSegments: \(basalSegments)")

        let response: ProcedureResultCompletion = { result in
            self.loggingDelegate?.logReceiveEvent("Basal rate schedule set")
            completion(result)
        }

        checkCommsStateAndRespond(response: response) { [weak self] in
            self?.status.basalSegments = basalSegments
        }
    }

    public func setBolus(_ amount: Double, activationType: IDBolusActivationType, completion: @escaping BolusDeliveryStatusCompletion) {
        loggingDelegate?.logSendEvent("Setting bolus. amount: \(amount), activation type: \(activationType)")

        let response: ProcedureResultCompletion = { result in
            switch result {
            case .success:
                self.loggingDelegate?.logReceiveEvent("Bolus set")
                completion(.success(self.state.activeBolusDeliveryStatus))
                self.reportBolusInitiated(self.state.activeBolusDeliveryStatus)
            case .failure(let error):
                completion(.failure(error))
            }
        }

        checkCommsStateAndRespond(insulinDeliveryCommand: true, response: response) { [weak self] in
            guard let self = self else { return }
            self.status.setBolus(amount)
        }
    }
    
    public func initiateBolus(_ amount: Double) {
        status.setBolus(amount)
        loggingDelegate?.logReceiveEvent("Bolus Initiated")
        reportBolusInitiated(state.activeBolusDeliveryStatus)
    }

    public func cancelBolus(completion: @escaping BolusDeliveryStatusCompletion) {
        loggingDelegate?.logSendEvent()

        var cancelledBolusStatus: BolusDeliveryStatus? = nil
        let response: ProcedureResultCompletion = { result in
            switch result {
            case .success:
                completion(.success(cancelledBolusStatus ?? .noActiveBolus))
                if let cancelledBolusStatus = cancelledBolusStatus {
                    self.loggingDelegate?.logReceiveEvent("Bolus cancelled")
                    self.issueBolusCanceledAnnunciation(bolusDeliveryStatus: cancelledBolusStatus)
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }

        checkCommsStateAndRespond(insulinDeliveryCommand: true, response: response) { [weak self] in
            guard let self = self else { return }

            self.status.cancelBolus() { result in
                switch result {
                case .success(let bolusDeliveryStatus):
                    cancelledBolusStatus = bolusDeliveryStatus
                default:
                    break
                }
            }
        }
    }

    public func updateActiveBolusDeliveryDetails(updateHandler: @escaping (BolusDeliveryStatus) -> Void) {
        loggingDelegate?.logSendEvent()

        status.activeBolusUpdateHandler = { [weak self] bolusDeliveryStatus in
            updateHandler(bolusDeliveryStatus)
            guard let self else { return }
            switch bolusDeliveryStatus.progressState {
            case  .canceled, .completed:
                self.reportBolusDelivered(bolusDeliveryStatus)
            default:
                break
            }
        }
        status.updateDelivery()
    }

    public func reportBolusInitiated(_ bolusDeliveryStatus: BolusDeliveryStatus) {
        guard isConnected else { return }
        // there is always a short delay on the pump when reporting bolus initiated in history, so do that here as well by tripling the schedulerDelay
        scheduleTask(after: schedulerDelay*3) {
            let bolusID = bolusDeliveryStatus.id ?? self.defaultBolusID
            let startTime = bolusDeliveryStatus.startTime ?? Date()
            self.delegate?.pumpDidInitiateBolus(self, bolusID: bolusID, insulinProgrammed: bolusDeliveryStatus.insulinProgrammed, startTime: startTime)
        }
    }

    public func reportBolusDelivered(_ bolusDeliveryStatus: BolusDeliveryStatus) {
        guard isConnected else { return }
        // there is always a short delay on the pump when reporting bolus delivered in history, so do that here as well by tripling the schedulerDelay
        scheduleTask(after: schedulerDelay*3) {
            let bolusID = bolusDeliveryStatus.id ?? self.defaultBolusID
            let startTime = bolusDeliveryStatus.startTime ?? Date()
            var duration = bolusDeliveryStatus.endTime?.timeIntervalSince(startTime) ?? 0
            if duration < 0 { duration = 0 }
            self.delegate?.pumpDidDeliverBolus(self, bolusID: bolusID, insulinProgrammed: bolusDeliveryStatus.insulinProgrammed, insulinDelivered: bolusDeliveryStatus.insulinDelivered, startTime: startTime, duration: duration)
        }
    }

    public func setTempBasal(unitsPerHour: Double, durationInMinutes: UInt16, replaceExisting: Bool, deliveryContext: TempBasalDeliveryContext, completion: @escaping ProcedureResultCompletion) {
        loggingDelegate?.logSendEvent("Setting temp basal. unitsPerHour: \(unitsPerHour), durationInMinutes: \(durationInMinutes), replaceExisting: \(replaceExisting), deliveryContext: \(deliveryContext)")

        let response: ProcedureResultCompletion = { result in
            self.loggingDelegate?.logReceiveEvent("Temp basal set")
            completion(result)
        }

        checkCommsStateAndRespond(insulinDeliveryCommand: true, response: response) { [weak self] in
            self?.status.setTempBasal(unitsPerHour: unitsPerHour, durationInMinutes: durationInMinutes)
        }
    }

    public func cancelTempBasal(completion: @escaping ProcedureResultCompletion) {
        loggingDelegate?.logSendEvent()

        let response: ProcedureResultCompletion = { result in
            self.loggingDelegate?.logReceiveEvent("Temp basal cancelled")
            completion(result)
            switch result {
            case .success:
                self.issueTempBasalCanceledAnnunciation()
            default:
                break
            }
        }

        checkCommsStateAndRespond(insulinDeliveryCommand: true, response: response) { [weak self] in
            guard let self = self else { return }
            self.status.cancelTempBasal() { _ in }
        }
    }

    private let emptyCompletion: ProcedureResultCompletion = { _ in }

    public func getBatteryLevel() {
        loggingDelegate?.logSendEvent()

        checkCommsStateAndRespond(response: emptyCompletion) { [weak self] in
            guard let self = self else { return }

            self.status.updateDelivery()
            guard let deviceInformation = self.deviceInformation else {
                return
            }
            self.loggingDelegate?.logReceiveEvent("Received battery level")
            switch deviceInformation.batteryLevelIndicator {
            case .low:
                self.issueAnnunciationForType(.batteryLow)
            case .empty:
                self.issueAnnunciationForType(.batteryEmpty)
            default:
                break
            }
            self.delegate?.pumpDidUpdateState(self)
        }
    }

    public func updateStatus(completion: @escaping PumpDeliveryStatusCompletion) {
        loggingDelegate?.logSendEvent()

        let response: ProcedureResultCompletion = { result in
            switch result {
            case .success:
                guard let deviceInformation = self.deviceInformation else {
                    completion(.failure(.commandFailed(LocalizedString("Could not update pump status", comment: "Message when update status fails"))))
                    return
                }
                self.loggingDelegate?.logReceiveEvent("Received status update")
                completion(.success(deviceInformation))
            case .failure(let error):
                completion(.failure(error))
            }
        }

        checkCommsStateAndRespond(response: response) { [weak self] in
            guard let self = self else { return }
            self.status.updateDelivery()
            self.delegate?.pumpDidSync(self)
        }
    }

    public func updateReservoirRemaining(_ reservoirRemaining: Double) {
        loggingDelegate?.logSendEvent()
        self.status.updateReservoirRemaining(reservoirRemaining)
        self.status.updateDelivery()
    }

    public func resolveUncertainDelivery() {
        pendingResponse?()
        pendingResponse = nil
        scheduleTask(after: schedulerDelay) {
            self.delegate?.pumpDidSync(self)
        }
    }

    public func checkCommsStateAndRespond(insulinDeliveryCommand: Bool = false,
                                          response: @escaping ProcedureResultCompletion,
                                          responseAction: (() -> Void)? = nil) {
        guard isConnected else {
            response(.failure(.disconnected))
            self.loggingDelegate?.logErrorEvent("Mock pump is disconnected")
            return
        }

        guard !(uncertainDeliveryEnabled && insulinDeliveryCommand) else {
            isConnected = false
            response(.failure(.disconnected)) // using disconnect to trigger uncertain delivery
            loggingDelegate?.logErrorEvent("Mock pump has uncertain delivery")
            if !uncertainDeliveryCommandReceived {
                loggingDelegate?.logErrorEvent("Mock pump has uncertain delivery (command not received)")
            } else {
                loggingDelegate?.logErrorEvent("Mock pump has uncertain delivery (command received)")
                self.scheduleTask(after: self.schedulerDelay) {
                    responseAction?()
                }
                pendingResponse = { response(.success) }
            }
            return
        }

        guard errorOnNextComms == nil else {
            response(.failure(errorOnNextComms!))
            loggingDelegate?.logErrorEvent("Mock pump communication error: \(String(describing: errorOnNextComms?.errorDescription))")
            errorOnNextComms = nil
            return
        }

        self.scheduleTask(after: self.schedulerDelay) {
            responseAction?()
            response(.success)
        }
    }
    
    open func issueAnnunciationForType(_ annunciationType: AnnunciationType, delayedBy: TimeInterval? = nil) {
        switch annunciationType {
        case .reservoirLow:
            issueLowReservoirAnnunciation(currentReservoirLevel: status.reservoirLevelWarningThresholdInUnits, delayedBy: delayedBy)
        case .bolusCanceled:
            issueBolusCanceledAnnunciation(bolusDeliveryStatus: status.activeBolusDeliveryStatus)
        default:
            issueGeneralAnnunciation(annunciationType: annunciationType, delayedBy: delayedBy)
        }
    }
    
    open func triggerExpirationIfNeeded(at now: Date = Date()) { }
    
    open func triggerStoppedAnnunciationIfNeeded(at now: Date = Date()) { }
}

// MARK: Annunciations

extension MockIDPump {
    public func triggerReservoirAnnunciationIfNeeded(at now: Date = Date()) {
        guard let reservoirLevel = deviceInformation?.reservoirLevel else { return }

        if reservoirLevel == 0 {
            lowReservoirDidAlert = true
            issueAnnunciationForType(.reservoirEmpty)
        } else if reservoirLevel <= Double(status.reservoirLevelWarningThresholdInUnits),
                  !lowReservoirDidAlert {
            lowReservoirDidAlert = true
            issueLowReservoirAnnunciation(currentReservoirLevel: status.reservoirLevelWarningThresholdInUnits)
        } else if reservoirLevel > Double(status.reservoirLevelWarningThresholdInUnits) {
            lowReservoirDidAlert = false
        }
    }
    
    private func issueGeneralAnnunciation(annunciationType: AnnunciationType, delayedBy: TimeInterval?) {
        let annunciation = GeneralAnnunciation(type: annunciationType, identifier: currentAnnunciationIdentifier)
        currentAnnunciationIdentifier += 1
        issueAnnunciation(annunciation, delayedBy: delayedBy)
    }

    private func issueLowReservoirAnnunciation(currentReservoirLevel: Int, delayedBy: TimeInterval? = nil) {
        let reservoirLowAnnunciation = LowReservoirAnnunciation(identifier: currentAnnunciationIdentifier, currentReservoirLevel: Double(currentReservoirLevel))
        currentAnnunciationIdentifier += 1
        issueAnnunciation(reservoirLowAnnunciation, delayedBy: delayedBy)
    }

    private func issueBolusCanceledAnnunciation(bolusDeliveryStatus: BolusDeliveryStatus) {
        let bolusCanceledAnnunciation = BolusCanceledAnnunciation(identifier: currentAnnunciationIdentifier, bolusDeliveryStatus: bolusDeliveryStatus)
        currentAnnunciationIdentifier += 1
        issueAnnunciation(bolusCanceledAnnunciation)
    }

    private func issueTempBasalCanceledAnnunciation() {
        issueAnnunciationForType(.tempBasalCanceled)
    }

    public func interruptBolus() {
        cancelBolus(completion: { _ in })
    }

    public func interruptTempBasal() {
        status.endTempBasal() { tempBasalDuration in
            self.reportTempBasalEnded(tempBasalDuration: tempBasalDuration)
        }
    }

    public func reportTempBasalEnded(tempBasalDuration: TimeInterval) {
        guard isConnected else { return }
        // there is always a short delay on the pump when reporting temp basal ended in history, so do that here as well by tripling the schedulerDelay
        scheduleTask(after: schedulerDelay*3) {
            self.delegate?.pumpTempBasalEnded(self, duration: tempBasalDuration)
        }
    }

    public func interruptInsulinDelivery() {
        interruptTempBasal()
        interruptBolus()
        suspendInsulinDelivery() { _ in }
    }

    private func reportInsulinDeliveryStopped(at now: Date = Date()) {
        guard isConnected else { return }
        // there is always a short delay on the pump when reporting insulin delivery stopped in history, so do that here as well by tripling the schedulerDelay
        scheduleTask(after: schedulerDelay*3) {
            self.delegate?.pumpDidSuspendInsulinDelivery(self, suspendedAt: now)
        }
    }

    public func issueAnnunciation(_ annunciation: Annunciation, delayedBy: TimeInterval? = nil) {
        scheduleTask(after: delayedBy ?? schedulerDelay) {
            if self.isConnected {
                self.delegate?.pump(self, didReceiveAnnunciation: annunciation)
            }
            if annunciation.type.isInsulinDeliveryStopped {
                self.interruptInsulinDelivery()
            }
        }
    }
}
