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

//MARK: - Support Server Implementation
class IDHistoryDataCharacteristic {
    public weak var e2eDelegate: E2EProtectionDelegate?
    
    var messageQueue: MessagingQueue

    public init(messageQueue: MessagingQueue) {
        self.messageQueue = messageQueue
    }
    
    func sendHistoryEvent(_ historyEvent: PumpHistoryEvent) {
        sendResponse(historyEvent.data)
    }
    
    public func sendResponse(_ response: Data) {
        if messageQueue.gattServer.isCharacteristicSubscribed(InsulinDeliveryCharacteristicUUID.historyData.cbUUID) == true {
            var response = response
            if e2eDelegate?.isE2EProtectionSupported ?? false {
                response = response.appendingCRC()
            }
            messageQueue.addQueueItem(
                UUIDValuePair(
                    uuid: InsulinDeliveryCharacteristicUUID.historyData.cbUUID,
                    value: response
                )
            )
        } else {
            ConsoleOut.shared.logMessage(message: "\(#function): ID History Data characteristic is not configured for indications")
        }
    }
}

//MARK: - Support Client Implementation
public class IDHistoryDataHandler {
    static private let log = OSLog(category: "IDHistoryData")

    //MARK: - Response Handling
    public static func handleData(_ data: Data, e2eProtectionSupported: Bool) -> DeviceCommResult<PumpHistoryEvent> {
        guard !e2eProtectionSupported || data.isCRCValid else {
            return .failure(.invalidCRC)
        }

        guard data.count >= (e2eProtectionSupported ? 10 : 8)  else {
            return .failure(.invalidFormat)
        }

        guard let eventType = eventType(forResponse: data) else {
            log.debug("History event not known. Complete response: %{public}@", data.hexadecimalString)
            return .failure(.invalidOperand)
        }

        guard let pumpHistoryEvent = PumpHistoryEventFactory.createPumpHistoryEvent(type: eventType, recordNumber: recordNumber(forResponse: data), relativeOffet: relativeOffset(forResponse: data), eventData: eventData(forResponse: data, e2eProtectionSupported: e2eProtectionSupported)) else {
            return .failure(.commandFailed("the event type \(eventType) is not handled yet"))
        }

        log.debug("received pumpHistoryEvent: %{public}@", String(describing: pumpHistoryEvent))

        return .success(pumpHistoryEvent)
    }

    static private func eventType(forResponse response: Data) -> IDHistoryEventType? {
        IDHistoryEventType(rawValue: response[response.startIndex...].to(IDHistoryEventType.RawValue.self))
    }

    static private func recordNumber(forResponse response: Data) -> RecordNumber {
        response[response.startIndex.advanced(by: 2)...].to(UInt32.self)
    }

    static private func relativeOffset(forResponse response: Data) -> TimeInterval {
        .seconds(Int(response[response.startIndex.advanced(by: 6)...].to(UInt16.self)))
    }

    static private func eventData(forResponse response: Data, e2eProtectionSupported: Bool) -> Data {
        guard response.count > (e2eProtectionSupported ? 10 : 8) else { return Data() }
        
        var responseWithoutCRC = response
        
        if e2eProtectionSupported {
            // remove CRC
            responseWithoutCRC = response.dropLast(2)
        }

        return Data(responseWithoutCRC[responseWithoutCRC.startIndex.advanced(by: 8)...])
    }
}

//MARK: - Enumerations
public struct IDHistoryEventType: RawRepresentable, Equatable, Hashable, CustomStringConvertible, Codable, Sendable {
    public var rawValue: UInt16
    
    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }
    
    public static let referenceTime = IDHistoryEventType(rawValue: 0x000f)
    public static let referenceTimeBaseOffset = IDHistoryEventType(rawValue: 0x0033)
    public static let bolusCalculatedPart1 = IDHistoryEventType(rawValue: 0x003c)
    public static let bolusCalculatedPart2 = IDHistoryEventType(rawValue: 0x0055)
    public static let bolusProgrammedPart1 = IDHistoryEventType(rawValue: 0x005a)
    public static let bolusProgrammedPart2 = IDHistoryEventType(rawValue: 0x0066)
    public static let bolusDeliveredPart1 = IDHistoryEventType(rawValue: 0x0069)
    public static let bolusDeliveredPart2 = IDHistoryEventType(rawValue: 0x0096)
    public static let deliveredBasalRateChanged = IDHistoryEventType(rawValue: 0x0099)
    public static let tempBasalRateAdjustmentStarted = IDHistoryEventType(rawValue: 0x00a5)
    public static let tempBasalRateAdjustmentEnded = IDHistoryEventType(rawValue: 0x00aa)
    public static let tempBasalRateAdjustmentChanged = IDHistoryEventType(rawValue: 0x00c3)
    public static let profileTemplateActivated = IDHistoryEventType(rawValue: 0x00cc)
    public static let basalRateProfileTimeBlockChanged = IDHistoryEventType(rawValue: 0x00f0)
    public static let totalDailyInsulinDelivery = IDHistoryEventType(rawValue: 0x00ff)
    public static let therapyControlStateChanged = IDHistoryEventType(rawValue: 0x0303)
    public static let operationalStateChanged = IDHistoryEventType(rawValue: 0x030c)
    public static let reservoirRemainingAmountChanged = IDHistoryEventType(rawValue: 0x0330)
    public static let annunciationStatusChangedPart1 = IDHistoryEventType(rawValue: 0x033f)
    public static let annunciationStatusChangedPart2 = IDHistoryEventType(rawValue: 0x0356)
    public static let isfProfileTemplateTimeBlockChanged = IDHistoryEventType(rawValue: 0x0359)
    public static let i2choProfileTemplateTimeBlockChanged = IDHistoryEventType(rawValue: 0x0365)
    public static let targetGlucoseRangeProfileTemplateTimeBlockChanged = IDHistoryEventType(rawValue: 0x036a)
    public static let primingStarted = IDHistoryEventType(rawValue: 0x0395)
    public static let primingDone = IDHistoryEventType(rawValue: 0x039a)
    public static let dataCorruption = IDHistoryEventType(rawValue: 0x03a6)
    public static let pointerEvent = IDHistoryEventType(rawValue: 0x03a9)
    public static let bolusTemplateChangedPart1 = IDHistoryEventType(rawValue: 0x03c0)
    public static let bolusTemplateChangedPart2 = IDHistoryEventType(rawValue: 0x03cf)
    public static let tempBasalRateTemplateChanged = IDHistoryEventType(rawValue: 0x03f3)
    public static let maxBolusAmountChanged = IDHistoryEventType(rawValue: 0x03fc)
    public static let generic = IDHistoryEventType(rawValue: 0xffff) // upper end of range
    
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
