//
//  BasalManagerDelegate.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit
import os.log

protocol BasalManagerDelegate: AnyObject {
    func basalManagerDidUpdateStatus(_ basalManager: BasalManager)
    func isActiveBasalRate(_ activeBasalRate: Double) -> Bool
}

public enum TempBasalProgressState: String, Codable {
    case completed
    case inProgress
    case noActiveTempBasal
}

public struct TempBasalDeliveryStatus: Equatable, RawRepresentable, Codable {
    
    public typealias RawValue = [String: Any]
    
    private enum TempBasalDeliveryStatusKey: String {
        case duration
        case rate
        case startTime
        case progressState
        case insulinDelivered
    }
    
    public var progressState: TempBasalProgressState
    public var duration: TimeInterval
    public let rate: Double
    public var insulinDelivered: Double
    public var startTime: Date?
    public var isTempBasalActive: Bool {
        progressState != .noActiveTempBasal
    }
    
    public init(progressState: TempBasalProgressState,
                duration: TimeInterval,
                rate: Double,
                startTime: Date?,
                insulinDelivered: Double)
    {
        self.progressState = progressState
        self.duration = duration
        self.rate = rate
        self.startTime = startTime
        self.insulinDelivered = insulinDelivered
    }
    
    public init?(rawValue: [String : Any]) {
        guard let rawProgressState = rawValue[TempBasalDeliveryStatusKey.progressState.rawValue] as? TempBasalProgressState.RawValue,
              let progressState = TempBasalProgressState(rawValue: rawProgressState),
              let duration = rawValue[TempBasalDeliveryStatusKey.duration.rawValue] as? TimeInterval,
              let rate = rawValue[TempBasalDeliveryStatusKey.rate.rawValue] as? Double,
              let insulinDelivered = rawValue[TempBasalDeliveryStatusKey.insulinDelivered.rawValue] as? Double
        else {
            return nil
        }

        self.progressState = progressState
        self.duration = duration
        self.rate = rate
        self.insulinDelivered = insulinDelivered
        self.startTime = rawValue[TempBasalDeliveryStatusKey.startTime.rawValue] as? Date
    }
    
    public var rawValue: RawValue {
        var rawValue: RawValue = [
            TempBasalDeliveryStatusKey.progressState.rawValue: progressState.rawValue,
            TempBasalDeliveryStatusKey.duration.rawValue: duration,
            TempBasalDeliveryStatusKey.rate.rawValue: rate,
            TempBasalDeliveryStatusKey.insulinDelivered.rawValue: insulinDelivered,
        ]
        rawValue[TempBasalDeliveryStatusKey.startTime.rawValue] = startTime

        return rawValue
    }
    
    public static var noActiveTempBasal: TempBasalDeliveryStatus {
        TempBasalDeliveryStatus(progressState: .noActiveTempBasal,
                                duration: 0,
                                rate: 0,
                                startTime: nil,
                                insulinDelivered: 0)
    }
}

public class BasalManager: RequestHandler {
    
    private let log = OSLog(category: "BasalManager")
    
    weak var delegate: BasalManagerDelegate?
    
    let basalRateProfileTemplateNumber: UInt8
    
    let numberOfBasalRateProfiles: UInt8 = 1
    
    private(set) var activeTempBasalDeliveryStatus = TempBasalDeliveryStatus.noActiveTempBasal {
        didSet {
            if activeTempBasalDeliveryStatus != oldValue {
                delegate?.basalManagerDidUpdateStatus(self)
            }
        }
    }
    
    private(set) var totalBasalDelivered: Double {
        didSet {
            if totalBasalDelivered != oldValue {
                delegate?.basalManagerDidUpdateStatus(self)
            }
        }
    }
    
    private(set) var lastTempBasalRate: Double {
        didSet {
            if lastTempBasalRate != oldValue {
                delegate?.basalManagerDidUpdateStatus(self)
            }
        }
    }
    
    public init(activeTempBasalDeliveryStatus: TempBasalDeliveryStatus? = nil,
                totalBasalDelivered: Double = 0,
                lastTempBasalRate: Double = 0,
                basalRateProfileTemplateNumber: UInt8 = 1)
    {
        self.activeTempBasalDeliveryStatus = activeTempBasalDeliveryStatus ?? .noActiveTempBasal
        self.totalBasalDelivered = totalBasalDelivered
        self.lastTempBasalRate = lastTempBasalRate
        self.basalRateProfileTemplateNumber = basalRateProfileTemplateNumber
    }
    
    func reset() {
        activeTempBasalDeliveryStatus = .noActiveTempBasal
        totalBasalDelivered = 0
        lastTempBasalRate = 0
    }
    
    func createSetTempBasalAdjustmentRequest(unitsPerHour: Double,
                                             durationInMinutes: UInt16,
                                             deliveryContext: BasalDeliveryContext,
                                             replaceExisting: Bool = false) -> Data
    {
        lastTempBasalRate = unitsPerHour
        
        let flags: TempBasalFlag = replaceExisting ? [.changeTempBasal, .deliveryContextPresent] : [.deliveryContextPresent]
        var operand = Data(flags.rawValue)
        operand.append(TempBasalType.absolute.rawValue)
        operand.append(unitsPerHour.sfloat)
        operand.append(durationInMinutes)
        operand.append(deliveryContext.rawValue)

        return BasalManager.buildControlPointRequest(opcode: IDCommandControlPointOpcode.setTempBasalAdjustment, operand: operand)
    }
    
    static func createCancelTempBasalAdjustmentRequest() -> Data {
        buildControlPointRequest(opcode: IDCommandControlPointOpcode.cancelTempBasalAdjustment)
    }
    
    func handleResponse(_ response: Data, with opcode: IDStatusReaderOpcode) -> DeviceCommResult<Void> {
        guard opcode == .getDeliveredInsulinResponse ||
                opcode == .getActiveBasalRateDeliveryResponse
        else {
            fatalError("can only handle a set or cancel bolus response")
        }
        
        switch opcode {
        case .getDeliveredInsulinResponse:
            guard response.count == 13 else { return .failure(.invalidFormat) }
            
            // skipping total bolus delivered, since it is currently unused
            let totalBasalDelivered = Data(response[response.startIndex.advanced(by: 6)...].to(FLOAT.self)).floatToDouble()
            
            updateTotalBasalDelivered(totalBasalDelivered)
            
            return .success
        case .getActiveBasalRateDeliveryResponse:
            guard response.count >= 9 else { return .failure(.invalidFormat) }
            var index = 2
            
            let flags = ActiveBasalRateFlag(rawValue: response[response.startIndex.advanced(by: index)...].to(ActiveBasalRateFlag.RawValue.self))
            index += 1
            index += 1 // skipping profile template number since it is always 1
            
            let activeBasalRate = Data(response[response.startIndex.advanced(by: index)...].to(SFLOAT.self)).sfloatToDouble()
            index += 2
            
            if flags.contains(.tbrPresent) {
                guard response.count >= index+7 else { return .failure(.invalidFormat) }
                
                index += 1 // skipping temp basal type, since it is always absolute
                
                let tempBasalRate = Data(response[response.startIndex.advanced(by: index)...].to(SFLOAT.self)).sfloatToDouble()
                index += 2
                
                guard tempBasalRate == lastTempBasalRate else { return .failure(.procedureNotApplicable) }
                
                let tempBasalDurationProgrammed = TimeInterval.minutes(Int(response[response.startIndex.advanced(by: index)...].to(UInt16.self)))
                index += 2
                
                // skipping temp basal duration remaining, since it is currently unused

                activeTempBasalDeliveryStatus = TempBasalDeliveryStatus(progressState: .inProgress, duration: tempBasalDurationProgrammed, rate: tempBasalRate, startTime: Date(), insulinDelivered: 0)
                
                return .success
            } else {
                if activeTempBasalDeliveryStatus != .noActiveTempBasal {
                    activeTempBasalDeliveryStatus.progressState = .completed
                    activeTempBasalDeliveryStatus = .noActiveTempBasal
                }
            }
            
            return (delegate?.isActiveBasalRate(activeBasalRate) ?? false) ? .success : .failure(.procedureNotApplicable)
        default:
            return .failure(.opcodeNotImplemented)
        }
    }
    
    func updateTotalBasalDelivered(_ totalBasalDelivered: Double) {
        guard totalBasalDelivered != self.totalBasalDelivered else { return }
        
        let basalDeliveredSinceLastUpdate: Double
        if totalBasalDelivered < self.totalBasalDelivered {
            // do not allow negative basal delivered
            basalDeliveredSinceLastUpdate = totalBasalDelivered
        } else {
            basalDeliveredSinceLastUpdate = totalBasalDelivered - self.totalBasalDelivered
        }
        
        self.totalBasalDelivered = totalBasalDelivered
        if activeTempBasalDeliveryStatus.progressState != .noActiveTempBasal {
            activeTempBasalDeliveryStatus.insulinDelivered += basalDeliveredSinceLastUpdate
        }
    }
    
    func cancelTempBasal(insulinDelivered: Double) {
        if activeTempBasalDeliveryStatus.progressState != .noActiveTempBasal {
            var activeTempBasalDeliveryStatus = self.activeTempBasalDeliveryStatus
            activeTempBasalDeliveryStatus.insulinDelivered = insulinDelivered
            activeTempBasalDeliveryStatus.progressState = .completed
            self.activeTempBasalDeliveryStatus = activeTempBasalDeliveryStatus
        }
    }
}

struct TempBasalFlag: OptionSet, Hashable, CustomStringConvertible, Sendable {
    let rawValue: UInt8
    
    static let templateNumberPresent = TempBasalFlag(rawValue: 1 << 0)
    static let deliveryContextPresent = TempBasalFlag(rawValue: 1 << 1)
    static let changeTempBasal  = TempBasalFlag(rawValue: 1 << 2)
    static let allZeros = TempBasalFlag([])
    
    static let debugDescriptions: [TempBasalFlag:String] = {
        var descriptions = [TempBasalFlag:String]()
        descriptions[.templateNumberPresent] = "templateNumberPresent"
        descriptions[.deliveryContextPresent] = "deliveryContextPresent"
        descriptions[.changeTempBasal] = "changeTempBasal"
        return descriptions
    }()
    
    public var description: String {
        var result = [String]()
        for (key, value) in TempBasalFlag.debugDescriptions {
            guard self.contains(key) else {
                continue
            }
            result.append(value)
        }
        return "TempBasalFlag: \(result)"
    }
}

public struct ActiveBasalRateFlag: OptionSet, Hashable, CustomStringConvertible, Sendable {
    public let rawValue: UInt8
    
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    static public let tbrPresent = ActiveBasalRateFlag(rawValue: 1 << 0)
    static public let tbrTemplateNumberPresent = ActiveBasalRateFlag(rawValue: 1 << 1)
    static public let deliveryContextPresent = ActiveBasalRateFlag(rawValue: 1 << 2)
    static public let allZeros = ActiveBasalRateFlag([])
    
    static let debugDescriptions: [ActiveBasalRateFlag:String] = {
        var descriptions = [ActiveBasalRateFlag:String]()
        descriptions[.tbrPresent] = "tbrPresent"
        descriptions[.tbrTemplateNumberPresent] = "tbrTemplateNumberPresent"
        descriptions[.deliveryContextPresent] = "deliveryContextPresent"
        return descriptions
    }()
    
    public var description: String {
        var result = [String]()
        for (key, value) in ActiveBasalRateFlag.debugDescriptions {
            guard self.contains(key) else {
                continue
            }
            result.append(value)
        }
        return "ActiveBasalRateFlag: \(result)"
    }
}

public enum TempBasalType: UInt8 {
    case undetermined = 0x0f
    case absolute = 0x33
    case relative = 0x3c
    
    public var description: String {
        switch self {
        case .undetermined: return "undetermined"
        case .absolute: return "absolute"
        case .relative: return "relative"
        }
    }
}

public enum BasalDeliveryContext: UInt8 {
    case undetermined = 0x0f
    case deviceBased = 0x33
    case remoteControl = 0x3c
    case aidController = 0x55
    
    public var description: String {
        switch self {
        case .undetermined: return "Unknown"
        case .deviceBased: return "deviceBased"
        case .remoteControl: return "remoteControl"
        case .aidController: return "aidController"
        }
    }
}
