//
//  BolusManager.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit
import os.log

public typealias BolusID = UInt16

protocol BolusManagerDelegate: AnyObject {
    func estimatedBolusDelivery(for elapsedTime: TimeInterval) -> Double?
    func bolusManagerDidUpdateActiveBolusDeliveryStatus(_ bolusManager: BolusManager)
}

public class BolusManager: RequestHandler {

    private let log = OSLog(category: "BolusManager")

    weak var delegate: BolusManagerDelegate?
    
    private var lastProgrammedAmount: Double = 0
    
    public init(activeBolusDeliveryStatus: BolusDeliveryStatus? = nil) {
        self.activeBolusDeliveryStatus = activeBolusDeliveryStatus ?? .noActiveBolus
    }
    
    func reset() {
        lastProgrammedAmount = 0
        resetActiveBolus()
    }
    
    func resetActiveBolus() {
        activeBolusDeliveryStatus = .noActiveBolus
        activeBolusDeliveryUpdateHandler = nil
    }

    // MARK: - Create Bolus Requests

    func createBolusRequest(fastAmount: Double = 0,
                            extendedAmount: Double = 0,
                            durationInMinutes: UInt16 = 0,
                            delayTimeInMinutes: UInt16? = nil,
                            reason: BolusReason? = nil,
                            activationType: IDBolusActivationType? = nil) -> Data
    {
        guard !fastAmount.isZero || !extendedAmount.isZero else {
            fatalError("Cannot request a bolus with neither a fast nor extended amount")
        }
        
        guard extendedAmount.isZero && durationInMinutes == 0 ||
            !extendedAmount.isZero && durationInMinutes != 0 else
        {
            fatalError("Cannot request an extended bolus without a duration")
        }
        
        lastProgrammedAmount = fastAmount + extendedAmount
        
        // bolus flag
        var bolusFlags = delayTimeInMinutes != nil ? BolusFlag.delayTimePresent : BolusFlag.allZeros
        
        if reason == BolusReason.correction {
            bolusFlags.insert(.deliveryReasonCorrection)
        } else if reason == BolusReason.meal {
            bolusFlags.insert(.deliveryReasonMeal)
        }

        if activationType != nil {
            bolusFlags.insert(.activationTypePresent)
        }

        var operand = Data(bolusFlags.rawValue)
        
        // bolus type
        let bolusType: BolusType
        if fastAmount != 0 && extendedAmount != 0 {
            bolusType = .multiwave
        } else if extendedAmount != 0 {
            bolusType = .extended
        } else {
            bolusType = .fast
        }
        operand.append(bolusType.rawValue)
        
        // fast bolus
        operand.append(fastAmount.sfloat)
        
        // extended amount
        operand.append(extendedAmount.sfloat)
        
        // duration
        operand.append(durationInMinutes)
        
        // delay
        if let delayTimeInMinutes = delayTimeInMinutes {
            operand.append(delayTimeInMinutes)
        }

        // activation type
        if let activationType = activationType {
            operand.append(activationType.rawValue)
        }

        return BolusManager.buildControlPointRequest(opcode: IDCommandControlPointOpcode.setBolus, operand: operand)
    }
    // only fast bolus delivery is currently supported
    func createFastBolusRequest(for amount: Double, activationType: IDBolusActivationType) -> Data {
        return createBolusRequest(fastAmount: amount, activationType: activationType)
    }
    
    func createDelayedFastBolusRequest(for amount: Double, delayInMinutes: UInt16) -> Data {
        return createBolusRequest(fastAmount: amount, delayTimeInMinutes: delayInMinutes)
    }
    
    func createExtendedBolusRequest(for amount: Double, durationInMinutes: UInt16) -> Data {
        return createBolusRequest(extendedAmount: amount, durationInMinutes: durationInMinutes)
    }
    
    func createMultiwaveBolusRequest(fastAmount: Double,
                                     extendedAmount: Double,
                                     durationInMinutes: UInt16) -> Data
    {
        return createBolusRequest(fastAmount: fastAmount, extendedAmount: extendedAmount, durationInMinutes: durationInMinutes)
    }
    
    func createCancelBolusRequest(for bolusID: BolusID) -> Data {
        let operand = Data(bolusID)
        return BolusManager.buildControlPointRequest(opcode: IDCommandControlPointOpcode.cancelBolus, operand: operand)
    }
    
    func createCancelCurrentBolusRequest() -> Data? {
        guard let bolusID = activeBolusDeliveryStatus.id, // a bolus ID must exist to create a cancel bolus request
              !isDeliveryEstimatingProgress // if the bolus delivery is estimatingProgress, the cancel bolus request will fail
        else {
            return nil
        }
        return createCancelBolusRequest(for: bolusID)
    }
    
    func createGetActiveBolusDeliveryRequest(bolusValueSelection: BolusValueSelection) -> Data? {
        guard let activeBolusID = activeBolusDeliveryStatus.id else {
            return nil
        }
        var operand = Data(activeBolusID)
        operand.append(bolusValueSelection.rawValue)
        return BolusManager.buildControlPointRequest(opcode: IDStatusReaderOpcode.getActiveBolusDelivery, operand: operand)
    }
    
    func sendingActiveBolusRequest(_ bolusValueSelection: BolusValueSelection) {
        currentBolusValueSelection = bolusValueSelection
    }

    // MARK: - Active Bolus Delivery Management
    public var isBolusActive: Bool {
        activeBolusDeliveryStatus.progressState.isOngoing
    }

    var isDeliveryEstimatingProgress: Bool {
        activeBolusDeliveryStatus.progressState == .estimatingProgress
    }

    var isReportingBolus: Bool {
        return isBolusActive && activeBolusDeliveryUpdateHandler != nil
    }

    var activeBolusDeliveryStatus = BolusDeliveryStatus.noActiveBolus {
        didSet {
            if activeBolusDeliveryStatus != oldValue {
                delegate?.bolusManagerDidUpdateActiveBolusDeliveryStatus(self)
            }
        }
    }

    var activeBolusDeliveryUpdateHandler: ((BolusDeliveryStatus) -> Void)?

    private var currentBolusValueSelection: BolusValueSelection?

    func startEstimatingBolusProgress() {
        guard isBolusActive else {
            activeBolusDeliveryUpdateHandler?(activeBolusDeliveryStatus)
            return
        }
        
        activeBolusDeliveryStatus.progressState = .estimatingProgress
        updateEstimatedBolusDeliveryStatus()
    }
    
    func updateEstimatedBolusDeliveryStatus() {
        guard activeBolusDeliveryStatus.progressState == .estimatingProgress else { return }
        guard let startTime = activeBolusDeliveryStatus.startTime else { return }
        
        let elapsedTime = -startTime.timeIntervalSinceNow
        
        activeBolusDeliveryStatus.insulinDelivered = max(min(delegate?.estimatedBolusDelivery(for: elapsedTime) ?? 0, activeBolusDeliveryStatus.insulinProgrammed), 0)
        
        guard activeBolusDeliveryStatus.insulinDelivered < activeBolusDeliveryStatus.insulinProgrammed else {
            activeBolusDeliveryStatus.progressState = .completed
            activeBolusDeliveryStatus.insulinDelivered = activeBolusDeliveryStatus.insulinProgrammed
            activeBolusDeliveryStatus.endTime = Date()
            activeBolusDeliveryUpdateHandler?(activeBolusDeliveryStatus)
            resetActiveBolus()
            return
        }
        
        activeBolusDeliveryUpdateHandler?(activeBolusDeliveryStatus)
    }

    func activeBolusDeliveryCanceled(canceledBolusDeliveryStatus: BolusDeliveryStatus) {
        if canceledBolusDeliveryStatus.id == activeBolusDeliveryStatus.id {
            var tempActiveBolusDeliveryStatus = activeBolusDeliveryStatus
            tempActiveBolusDeliveryStatus.endTime = canceledBolusDeliveryStatus.endTime
            tempActiveBolusDeliveryStatus.progressState = .canceled
            activeBolusDeliveryStatus = tempActiveBolusDeliveryStatus
        }

        activeBolusDeliveryUpdateHandler?(canceledBolusDeliveryStatus)
        resetActiveBolus()
    }

    func handleTherapyControlState(_ therapyControlState: InsulinTherapyControlState) {
        if  therapyControlState == .stop,
            isBolusActive
        {
            activeBolusDeliveryStatus.progressState = .canceled
            activeBolusDeliveryUpdateHandler?(activeBolusDeliveryStatus)
        }
    }

    func createActiveBolusDeliveryStatus(withID bolusID: BolusID, insulinProgrammed: Double, type: BolusType = .fast, at date: Date = Date()) {
        activeBolusDeliveryStatus = BolusDeliveryStatus(id: bolusID,
                                                        progressState: .inProgress,
                                                        type: type,
                                                        insulinProgrammed: insulinProgrammed,
                                                        insulinDelivered: 0,
                                                        startTime: date,
                                                        endTime: nil)
    }

    // MARK: - Response Handler
    
    func handleResponse(_ response: Data, with opcode: IDCommandControlPointOpcode) -> DeviceCommResult<Void> {
        guard opcode == .setBolusResponse || opcode == .cancelBolusResponse else {
            fatalError("can only handle a set or cancel bolus response")
        }
        
        let expectedResponseLength = 7
        guard response.count == expectedResponseLength else {
            return .failure(.invalidFormat)
        }
        
        let bolusID = response[response.startIndex.advanced(by: 2)...].to(BolusID.self)
        switch opcode {
        case .setBolusResponse:
            createActiveBolusDeliveryStatus(withID: bolusID, insulinProgrammed: lastProgrammedAmount)
            activeBolusDeliveryUpdateHandler?(activeBolusDeliveryStatus)
            log.debug("bolus set successful %{public}@", String(describing: activeBolusDeliveryStatus))
        case .cancelBolusResponse:
            activeBolusDeliveryStatus.progressState = .canceled
            activeBolusDeliveryStatus.endTime = Date()
            log.debug("bolus cancel successful %{public}@", String(describing: activeBolusDeliveryStatus))
            activeBolusDeliveryUpdateHandler?(activeBolusDeliveryStatus)
        default:
            return .failure(.opcodeNotImplemented)
        }

        return .success
    }
    
    func handleGetActiveBolusDeliveryNotApplicable() -> DeviceCommResult<Void> {
        handleBolusNoLongerActive()
        return .success
    }
    
    private func handleBolusNoLongerActive() {
        if activeBolusDeliveryStatus.progressState.isOngoing {
            // the bolus was active, but now not active as delivery is completed
            var tempActiveBolusDeliveryStatus = activeBolusDeliveryStatus
            tempActiveBolusDeliveryStatus.progressState = .completed
            tempActiveBolusDeliveryStatus.endTime = Date()
            tempActiveBolusDeliveryStatus.insulinDelivered = activeBolusDeliveryStatus.insulinProgrammed
            activeBolusDeliveryStatus = tempActiveBolusDeliveryStatus
            activeBolusDeliveryUpdateHandler?(activeBolusDeliveryStatus)
        }

        resetActiveBolus()
    }

    func completeBolus(for bolusID: BolusID,
                       insulinProgrammed: Double,
                       insulinDelivered: Double,
                       startTime: Date,
                       duration: TimeInterval)
    {
        if activeBolusDeliveryStatus.id == bolusID {
            var tempActiveBolusDeliveryStatus = activeBolusDeliveryStatus
            tempActiveBolusDeliveryStatus.insulinDelivered = insulinProgrammed
            tempActiveBolusDeliveryStatus.insulinDelivered = insulinDelivered
            tempActiveBolusDeliveryStatus.progressState = insulinProgrammed == insulinDelivered ? .completed : .canceled
            tempActiveBolusDeliveryStatus.endTime = startTime.addingTimeInterval(duration)
            activeBolusDeliveryStatus = tempActiveBolusDeliveryStatus
            activeBolusDeliveryUpdateHandler?(activeBolusDeliveryStatus)
            resetActiveBolus()
        }
    }

    func handleResponse(_ response: Data, with opcode: IDStatusReaderOpcode) -> DeviceCommResult<Void> {
        switch opcode {
        case .getActiveBolusDeliveryResponse:
            let expectedMinimumResponseLength = 13
            guard response.count >= expectedMinimumResponseLength else {
                return .failure(.invalidFormat)
            }

            // only fast bolus are currently supported
            let bolusAmountFast = Data(response[response.startIndex.advanced(by: 6)...].to(SFLOAT.self)).sfloatToDouble()
            guard !bolusAmountFast.isNaN else {
                return .failure(.invalidFormat)
            }

            if currentBolusValueSelection == .programmed {
                activeBolusDeliveryStatus.insulinProgrammed = bolusAmountFast
            } else if currentBolusValueSelection == .delivered {
                activeBolusDeliveryStatus.insulinDelivered = bolusAmountFast
            }

            currentBolusValueSelection = nil
            if activeBolusDeliveryStatus.progressState == .estimatingProgress {
                // no longer estimating progress
                activeBolusDeliveryStatus.progressState = .inProgress
            }
            activeBolusDeliveryUpdateHandler?(activeBolusDeliveryStatus)
            log.debug("Updated bolus status %{public}@", String(describing: activeBolusDeliveryStatus))
            return .success
        case .getActiveBolusIDsResponse:
            let expectedMinimumResponseLength = 1
            guard response.count >= expectedMinimumResponseLength else {
                return .failure(.invalidFormat)
            }

            let numberOfActiveBoluses = response[response.startIndex.advanced(by: 2)...].to(UInt8.self)

            if numberOfActiveBoluses == 0 && activeBolusDeliveryStatus.progressState != .noActiveBolus {
                log.debug("resetting active bolus, since there is no active bolus")
                handleBolusNoLongerActive()
                return .success
            }

            // only 1 fast bolus can be delivered at a time
            guard numberOfActiveBoluses == 1 else { return .success }

            let bolusID = response[response.startIndex.advanced(by: 3)...].to(BolusID.self)

            if activeBolusDeliveryStatus == .noActiveBolus {
                // this is a bolus programmed directly on the pump
                createActiveBolusDeliveryStatus(withID: bolusID, insulinProgrammed: 0)
            }

            log.debug("get active bolus IDs successful %{public}@", String(describing: activeBolusDeliveryStatus))
            return .success
        default:
            log.error("handler not implemented yet")
            return .failure(.opcodeNotImplemented)
        }
    }
}

public struct BolusFlag: OptionSet, Hashable, CustomStringConvertible, Sendable {
    public let rawValue: UInt8
    
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    static public let delayTimePresent = BolusFlag(rawValue: 1 << 0)
    static public let templateNumberPresent = BolusFlag(rawValue: 1 << 1)
    static public let activationTypePresent  = BolusFlag(rawValue: 1 << 2)
    static public let deliveryReasonCorrection = BolusFlag(rawValue: 1 << 3)
    static public let deliveryReasonMeal = BolusFlag(rawValue: 1 << 4)
    static public let allZeros = BolusFlag([])
    
    static let debugDescriptions: [BolusFlag:String] = {
        var descriptions = [BolusFlag:String]()
        descriptions[.delayTimePresent] = "delayTimePresent"
        descriptions[.templateNumberPresent] = "templateNumberPresent"
        descriptions[.activationTypePresent] = "activationTypePresent"
        descriptions[.deliveryReasonCorrection] = "deliveryReasonCorrection"
        descriptions[.deliveryReasonMeal] = "deliveryReasonMeal"
        return descriptions
    }()
    
    public var description: String {
        var result = [String]()
        for (key, value) in BolusFlag.debugDescriptions {
            guard self.contains(key) else {
                continue
            }
            result.append(value)
        }
        return "\(result)"
    }
}

public enum BolusType: UInt8, Codable {
    case undetermined = 0x0f
    case fast = 0x33
    case extended = 0x3c
    case multiwave = 0x55
    
    public var description: String {
        switch self {
        case .undetermined: return "undetermined"
        case .fast: return "fast"
        case .extended: return "extended"
        case .multiwave: return "multiwave"
        }
    }
}

public enum IDBolusActivationType: UInt8 {
    case undetermined = 0x0f
    case manualBolus = 0x33
    case recommendedBolus = 0x3c
    case manuallyChangedRecommendedBolus = 0x55
    case aidController = 0x5a
}

enum BolusReason: UInt8 {
    case correction
    case meal
}
