//
//  IDHistoryData.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit
import os.log

public class IDHistoryData {

    static private let expectedMinResponseLength = 10
    
    static private let log = OSLog(category: "IDHistoryData")

    //MARK: - Response Handling
    static func handleData(_ response: Data) -> DeviceCommResult<PumpHistoryEvent> {
        guard response.isCRCValid else {
            return .failure(.invalidCRC)
        }

        guard response.count >= expectedMinResponseLength else {
            return .failure(.invalidFormat)
        }

        guard let eventType = eventType(forResponse: response) else {
            log.debug("History event not known. Complete response: %{public}@", response.hexadecimalString)
            return .failure(.invalidOperand)
        }

        guard let pumpHistoryEvent = PumpHistoryEventFactory.createPumpHistoryEvent(type: eventType, sequenceNumber: sequenceNumber(forResponse: response), relativeOffet: relativeOffset(forResponse: response), auxData: auxilaryData(forResponse: response)) else {
            return .failure(.commandFailed("the event type \(eventType) is not handled yet"))
        }

        log.debug("received pumpHistoryEvent: %{public}@", String(describing: pumpHistoryEvent))

        return .success(pumpHistoryEvent)
    }

    static private func eventType(forResponse response: Data) -> IDHistoryEventType? {
        IDHistoryEventType(rawValue: response[response.startIndex...].to(IDHistoryEventType.RawValue.self))
    }

    static private func sequenceNumber(forResponse response: Data) -> HistoryEventSequenceNumber {
        response[response.startIndex.advanced(by: 2)...].to(UInt32.self)
    }

    static private func relativeOffset(forResponse response: Data) -> TimeInterval {
        .seconds(Int(response[response.startIndex.advanced(by: 6)...].to(UInt16.self)))
    }

    static private func auxilaryData(forResponse response: Data) -> Data {
        guard response.count > expectedMinResponseLength else { return Data() }

        // remove CRC
        let responseWithoutCRC = response.dropLast(2)
        return Data(responseWithoutCRC[responseWithoutCRC.startIndex.advanced(by: expectedMinResponseLength-2)...])
    }
}

//MARK: - Enumerations
public struct IDHistoryEventType: RawRepresentable, Equatable, Hashable, CustomStringConvertible, Codable, Sendable {
    public var rawValue: UInt16
    
    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }
    
    static let referenceTime = IDHistoryEventType(rawValue: 0x000f)
    static let referenceTimeBaseOffset = IDHistoryEventType(rawValue: 0x0033)
    static let bolusCalculatedPart1 = IDHistoryEventType(rawValue: 0x003c)
    static let bolusCalculatedPart2 = IDHistoryEventType(rawValue: 0x0055)
    static let bolusProgrammedPart1 = IDHistoryEventType(rawValue: 0x005a)
    static let bolusProgrammedPart2 = IDHistoryEventType(rawValue: 0x0066)
    static let bolusDeliveredPart1 = IDHistoryEventType(rawValue: 0x0069)
    static let bolusDeliveredPart2 = IDHistoryEventType(rawValue: 0x0096)
    static let deliveredBasalRateChanged = IDHistoryEventType(rawValue: 0x0099)
    static let tempBasalRateAdjustmentStarted = IDHistoryEventType(rawValue: 0x00a5)
    static let tempBasalRateAdjustmentEnded = IDHistoryEventType(rawValue: 0x00aa)
    static let tempBasalRateAdjustmentChanged = IDHistoryEventType(rawValue: 0x00c3)
    static let profileTemplateActivated = IDHistoryEventType(rawValue: 0x00cc)
    static let basalRateProfileTimeBlockChanged = IDHistoryEventType(rawValue: 0x00f0)
    static let totalDailyInsulinDelivery = IDHistoryEventType(rawValue: 0x00ff)
    static let therapyControlStateChanged = IDHistoryEventType(rawValue: 0x0303)
    static let operationalStateChanged = IDHistoryEventType(rawValue: 0x030c)
    static let reservoirRemainingAmountChanged = IDHistoryEventType(rawValue: 0x0330)
    static let annunciationStatusChangedPart1 = IDHistoryEventType(rawValue: 0x033f)
    static let annunciationStatusChangedPart2 = IDHistoryEventType(rawValue: 0x0356)
    static let isfProfileTemplateTimeBlockChanged = IDHistoryEventType(rawValue: 0x0359)
    static let i2choProfileTemplateTimeBlockChanged = IDHistoryEventType(rawValue: 0x0365)
    static let targetGlucoseRangeProfileTemplateTimeBlockChanged = IDHistoryEventType(rawValue: 0x036a)
    static let primingStarted = IDHistoryEventType(rawValue: 0x0395)
    static let primingDone = IDHistoryEventType(rawValue: 0x039a)
    static let dataCorruption = IDHistoryEventType(rawValue: 0x03a6)
    static let pointerEvent = IDHistoryEventType(rawValue: 0x03a9)
    static let bolusTemplateChangedPart1 = IDHistoryEventType(rawValue: 0x03c0)
    static let bolusTemplateChangedPart2 = IDHistoryEventType(rawValue: 0x03cf)
    static let tempBasalRateTemplateChanged = IDHistoryEventType(rawValue: 0x03f3)
    static let maxBolusAmountChanged = IDHistoryEventType(rawValue: 0x03fc)
    static let generic = IDHistoryEventType(rawValue: 0xffff) // upper end of range
    
    public var description: String {
        switch self {
        case Self.referenceTime: return "referenceTime"
        case Self.referenceTimeBaseOffset: return "referenceTimeBaseOffset"
        case Self.bolusCalculatedPart1: return "bolusCalculatedPart1"
        case Self.bolusCalculatedPart2: return "bolusCalculatedPart2"
        case Self.bolusProgrammedPart1: return "bolusProgrammedPart1"
        case Self.bolusProgrammedPart2: return "bolusProgrammedPart2"
        case Self.bolusDeliveredPart1: return "bolusDeliveredPart1"
        case Self.bolusDeliveredPart2: return "bolusDeliveredPart2"
        case Self.deliveredBasalRateChanged: return "deliveredBasalRateChanged"
        case Self.tempBasalRateAdjustmentStarted: return "tempBasalRateAdjustmentStarted"
        case Self.tempBasalRateAdjustmentEnded: return "tempBasalRateAdjustmentEnded"
        case Self.tempBasalRateAdjustmentChanged: return "tempBasalRateAdjustmentChanged"
        case Self.profileTemplateActivated: return "profileTemplateActivated"
        case Self.basalRateProfileTimeBlockChanged: return "basalRateProfileTimeBlockChanged"
        case Self.totalDailyInsulinDelivery: return "totalDailyInsulinDelivery"
        case Self.therapyControlStateChanged: return "therapyControlStateChanged"
        case Self.operationalStateChanged: return "operationalStateChanged"
        case Self.reservoirRemainingAmountChanged: return "reservoirRemainingAmountChanged"
        case Self.annunciationStatusChangedPart1: return "annunciationStatusChangedPart1"
        case Self.annunciationStatusChangedPart2: return "annunciationStatusChangedPart2"
        case Self.isfProfileTemplateTimeBlockChanged: return "isfProfileTemplateTimeBlockChanged"
        case Self.i2choProfileTemplateTimeBlockChanged: return "i2choProfileTemplateTimeBlockChanged"
        case Self.targetGlucoseRangeProfileTemplateTimeBlockChanged: return "targetGlucoseRangeProfileTemplateTimeBlockChanged"
        case Self.primingStarted: return "primingStarted"
        case Self.primingDone: return "primingDone"
        case Self.dataCorruption: return "dataCorruption"
        case Self.pointerEvent: return "pointerEvent"
        case Self.bolusTemplateChangedPart1: return "bolusTemplateChangedPart1"
        case Self.bolusTemplateChangedPart2: return "bolusTemplateChangedPart2"
        case Self.tempBasalRateTemplateChanged: return "tempBasalRateTemplateChanged"
        case Self.maxBolusAmountChanged: return "maxBolusAmountChanged"
        case Self.generic: return "generic"
        default:
            return "manufacturerSpecificEvent(\(self.rawValue))"
        }
    }
}
