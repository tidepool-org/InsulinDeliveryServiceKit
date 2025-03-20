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
public enum IDHistoryEventType: UInt16, CaseIterable, CustomStringConvertible, Codable {
    case referenceTime = 0x000f
    case referenceTimeBaseOffset = 0x0033
    case bolusCalculatedPart1 = 0x003c
    case bolusCalculatedPart2 = 0x0055
    case bolusProgrammedPart1 = 0x005a
    case bolusProgrammedPart2 = 0x0066
    case bolusDeliveredPart1 = 0x0069
    case bolusDeliveredPart2 = 0x0096
    case deliveredBasalRateChanged = 0x0099
    case tempBasalRateAdjustmentStarted = 0x00a5
    case tempBasalRateAdjustmentEnded = 0x00aa
    case tempBasalRateAdjustmentChanged = 0x00c3
    case profileTemplateActivated = 0x00cc
    case basalRateProfileTimeBlockChanged = 0x00f0
    case totalDailyInsulinDelivery = 0x00ff
    case therapyControlStateChanged = 0x0303
    case operationalStateChanged = 0x030c
    case reservoirRemainingAmountChanged = 0x0330
    case annunciationStatusChangedPart1 = 0x033f
    case annunciationStatusChangedPart2 = 0x0356
    case isfProfileTemplateTimeBlockChanged = 0x0359
    case i2choProfileTemplateTimeBlockChanged = 0x0365
    case targetGlucoseRangeProfileTemplateTimeBlockChanged = 0x036a
    case primingStarted = 0x0395
    case primingDone = 0x039a
    case dataCorruption = 0x03a6
    case pointerEvent = 0x03a9
    case bolusTemplateChangedPart1 = 0x03c0
    case bolusTemplateChangedPart2 = 0x03cf
    case tempBasalRateTemplateChanged = 0x03f3
    case maxBolusAmountChanged = 0x03fc
    case generic = 0xffff // upper end of range

    public var description: String {
        switch self {
        case .referenceTime: return "referenceTime"
        case .referenceTimeBaseOffset: return "referenceTimeBaseOffset"
        case .bolusCalculatedPart1: return "bolusCalculatedPart1"
        case .bolusCalculatedPart2: return "bolusCalculatedPart2"
        case .bolusProgrammedPart1: return "bolusProgrammedPart1"
        case .bolusProgrammedPart2: return "bolusProgrammedPart2"
        case .bolusDeliveredPart1: return "bolusDeliveredPart1"
        case .bolusDeliveredPart2: return "bolusDeliveredPart2"
        case .deliveredBasalRateChanged: return "deliveredBasalRateChanged"
        case .tempBasalRateAdjustmentStarted: return "tempBasalRateAdjustmentStarted"
        case .tempBasalRateAdjustmentEnded: return "tempBasalRateAdjustmentEnded"
        case .tempBasalRateAdjustmentChanged: return "tempBasalRateAdjustmentChanged"
        case .profileTemplateActivated: return "profileTemplateActivated"
        case .basalRateProfileTimeBlockChanged: return "basalRateProfileTimeBlockChanged"
        case .totalDailyInsulinDelivery: return "totalDailyInsulinDelivery"
        case .therapyControlStateChanged: return "therapyControlStateChanged"
        case .operationalStateChanged: return "operationalStateChanged"
        case .reservoirRemainingAmountChanged: return "reservoirRemainingAmountChanged"
        case .annunciationStatusChangedPart1: return "annunciationStatusChangedPart1"
        case .annunciationStatusChangedPart2: return "annunciationStatusChangedPart2"
        case .isfProfileTemplateTimeBlockChanged: return "isfProfileTemplateTimeBlockChanged"
        case .i2choProfileTemplateTimeBlockChanged: return "i2choProfileTemplateTimeBlockChanged"
        case .targetGlucoseRangeProfileTemplateTimeBlockChanged: return "targetGlucoseRangeProfileTemplateTimeBlockChanged"
        case .primingStarted: return "primingStarted"
        case .primingDone: return "primingDone"
        case .dataCorruption: return "dataCorruption"
        case .pointerEvent: return "pointerEvent"
        case .bolusTemplateChangedPart1: return "bolusTemplateChangedPart1"
        case .bolusTemplateChangedPart2: return "bolusTemplateChangedPart2"
        case .tempBasalRateTemplateChanged: return "tempBasalRateTemplateChanged"
        case .maxBolusAmountChanged: return "maxBolusAmountChanged"
        case .generic: return "generic"
        }
    }
}
