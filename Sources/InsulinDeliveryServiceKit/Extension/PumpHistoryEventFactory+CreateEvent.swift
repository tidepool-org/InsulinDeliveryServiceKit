//
//  PumpHistoryEventFactory+CreateEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-04-16.
//

import Foundation
import BluetoothCommonKit

extension ReferenceTimeHistoryEvent {
    static public func createEventData(_ referenceTime: Date,
                                       reason: RecordingReason,
                                       timeZone: TimeZone = .utc,
                                       dstOffet: UInt8) -> Data
    {
        var eventData = Data(reason.rawValue)
        eventData.append(referenceTime.gattDateTime(using: timeZone))
        eventData.append(timeZone.gattTimeZoneOffset)
        eventData.append(dstOffet)
        return eventData
    }
}

extension BolusCalculatedHistoryEvent {
    static public func createEventDataPart1(recommendedFastMeal: Double,
                                            recommendedFastCorrection: Double,
                                            recommendedExtendedMeal: Double,
                                            recommendedExtendedCorrection: Double) -> Data
    {
        var eventData = Data(recommendedFastMeal.sfloat)
        eventData.append(recommendedFastCorrection.sfloat)
        eventData.append(recommendedExtendedMeal.sfloat)
        eventData.append(recommendedExtendedCorrection.sfloat)
        return eventData
    }

    static public func createEventDataPart2(confirmedFastMeal: Double,
                                            confirmedFastCorrection: Double,
                                            confirmedExtendedMeal: Double,
                                            confirmedExtendedCorrection: Double) -> Data
    {
        var eventData = Data(confirmedFastMeal.sfloat)
        eventData.append(confirmedFastCorrection.sfloat)
        eventData.append(confirmedExtendedMeal.sfloat)
        eventData.append(confirmedExtendedCorrection.sfloat)
        return eventData
    }
}

extension BolusProgrammedHistoryEvent {
    static public func createEventDataPart1(id: BolusID,
                                            type: BolusType,
                                            fastAmount: Double,
                                            extendedAmount: Double,
                                            duration: TimeInterval) -> Data
    {
        var eventData = Data(id)
        eventData.append(type.rawValue)
        eventData.append(fastAmount.sfloat)
        eventData.append(extendedAmount.sfloat)
        eventData.append(UInt16(duration.minutes))
        return eventData
    }
    
    static public func createEventDataPart2(delayTime: TimeInterval? = nil,
                                            templateNumber: TemplateNumber? = nil,
                                            activationType: IDBolusActivationType? = nil) -> Data
    {
        var flags: BolusFlag = .allZeros
        var eventData = Data()
        if let delayTime {
            flags.insert(.delayTimePresent)
            eventData.append(UInt16(delayTime.minutes))
        }
        if let templateNumber {
            flags.insert(.templateNumberPresent)
            eventData.append(templateNumber)
        }
        if let activationType {
            flags.insert(.activationTypePresent)
            eventData.append(activationType.rawValue)
        }
        eventData.insert(flags.rawValue, at: 0)
        return eventData
    }
}

extension BolusDeliveredHistoryEvent {
    static public func createEventDataPart1(id: BolusID,
                                            type: BolusType,
                                            fastAmount: Double,
                                            extendedAmount: Double,
                                            duration: TimeInterval) -> Data
    {
        var eventData = Data(id)
        eventData.append(type.rawValue)
        eventData.append(fastAmount.sfloat)
        eventData.append(extendedAmount.sfloat)
        eventData.append(UInt16(duration.minutes))
        return eventData
    }
    
    static public func createEventDataPart2(timeOffset: TimeInterval,
                                            activationType: IDBolusActivationType? = nil,
                                            endReason: BolusEndReason? = nil,
                                            annunciationID: AnnunciationIdentifier? = nil) -> Data
    {
        var flags: BolusDeliveredFlag = .allZeros
        var eventData = Data(UInt32(timeOffset.seconds))
        if let activationType {
            flags.insert(.activationTypePresent)
            eventData.append(activationType.rawValue)
        }
        if let endReason {
            flags.insert(.endReasonPresent)
            eventData.append(endReason.rawValue)
        }
        if let annunciationID {
            flags.insert(.annunciationIDPresent)
            eventData.append(annunciationID)
        }
        eventData.insert(flags.rawValue, at: 0)
        return eventData
    }
}

extension DeliveredBasalRateChangedHistoryEvent {
    static public func createEventData(oldRate: Double,
                                       newRate: Double,
                                       deliveryContext: BasalDeliveryContext? = nil) -> Data
    {
        var flags: DeliveredBasalRateChangedFlag = .allZeros
        var eventData = Data(oldRate.sfloat)
        eventData.append(newRate.sfloat)
        if let deliveryContext {
            flags.insert(.deliveryContentPresent)
            eventData.append(deliveryContext.rawValue)
        }
        return eventData
    }
}

extension TempBasalAdjustmentStartedHistoryEvent {
    static public func createEventData(type: TempBasalType,
                                       rate: Double,
                                       duration: TimeInterval,
                                       templateNumber: TemplateNumber? = nil) -> Data
    {
        var flags: TempBasalFlag = .allZeros
        var eventData = Data(type.rawValue)
        eventData.append(rate.sfloat)
        eventData.append(UInt16(duration.minutes))
        if let templateNumber {
            flags.insert(.templateNumberPresent)
            eventData.append(templateNumber)
        }
        eventData.insert(flags.rawValue, at: 0)
        return eventData
    }
}

extension TempBasalAdjustmentEndedHistoryEvent {
    static public func createEventData(type: TempBasalType,
                                       effectiveDuration: TimeInterval,
                                       endReason: TempBasalEndReason,
                                       templateNumber: TemplateNumber? = nil,
                                       annunciationID: AnnunciationIdentifier? = nil) -> Data
    {
        var flags: TempBasalEndedFlag = .allZeros
        var eventData = Data(type.rawValue)
        eventData.append(UInt16(effectiveDuration.minutes))
        eventData.append(endReason.rawValue)
        if let templateNumber {
            flags.insert(.lastSetTemplateNumberPresent)
            eventData.append(templateNumber)
        }
        if let annunciationID {
            flags.insert(.annunciationIDPresent)
            eventData.append(annunciationID)
        }
        eventData.insert(flags.rawValue, at: 0)
        return eventData
    }
}

extension TempBasalAdjustmentChangedHistoryEvent {
    static public func createEventData(type: TempBasalType,
                                       rate: Double,
                                       durationProgrammed: TimeInterval,
                                       durationElapsed: TimeInterval,
                                       templateNumber: TemplateNumber? = nil) -> Data
    {
        var flags: TempBasalFlag = .allZeros
        var eventData = Data(type.rawValue)
        eventData.append(rate.sfloat)
        eventData.append(UInt16(durationProgrammed.minutes))
        eventData.append(UInt16(durationElapsed.minutes))
        if let templateNumber {
            flags.insert(.templateNumberPresent)
            eventData.append(templateNumber)
        }
        eventData.insert(flags.rawValue, at: 0)
        return eventData
    }
}

extension ProfileTemplateActivatedHistoryEvent {
    static func createEventData(type: ProfileTemplateType,
                                oldTemplateNumber: TemplateNumber,
                                newTemplateNumber: TemplateNumber) -> Data
    {
        var eventData = Data(type.rawValue)
        eventData.append(oldTemplateNumber)
        eventData.append(newTemplateNumber)
        return eventData
    }
}

extension BasalRateProfileTimeBlockChangedHistoryEvent {
    static public func createEventData(templateNumber: TemplateNumber,
                                       timeBlockNumber: UInt8,
                                       duration: TimeInterval,
                                       rate: Double) -> Data
    {
        var eventData = Data(templateNumber)
        eventData.append(UInt8(timeBlockNumber))
        eventData.append(UInt16(duration.minutes))
        eventData.append(rate.sfloat)
        return eventData
    }
}

extension TotalDailyInsulinDeliveryHistoryEvent {
    static public func createEventData(bolusDelivered: Double,
                                       basalDelivered: Double,
                                       year: Int,
                                       month: Int,
                                       day: Int,
                                       dateTimeChange: Bool) -> Data
    {
        var flags: TotalDailyInsulinDeliveryFlag = .allZeros
        var eventData = Data(bolusDelivered.sfloat)
        eventData.append(basalDelivered.sfloat)
        eventData.append(UInt16(year))
        eventData.append(UInt8(month))
        eventData.append(UInt8(day))
        if dateTimeChange {
            flags.insert(.dateTimeChangedWarning)
        }
        eventData.insert(flags.rawValue, at: 0)
        return eventData
    }
}

extension TherapyControlStateChangedHistoryEvent {
    static public func createEventData(from oldState: InsulinTherapyControlState,
                                       to newState: InsulinTherapyControlState) -> Data {
        var eventData = Data(oldState.rawValue)
        eventData.append(newState.rawValue)
        return eventData
    }
}

extension OperationalStateChangedHistoryEvent {
    static public func createEventData(from oldState: PumpOperationalState,
                                       to newState: PumpOperationalState) -> Data {
        var eventData = Data(oldState.rawValue)
        eventData.append(newState.rawValue)
        return eventData
    }
}

extension ReservoirRemainingAmountChangedHistoryEvent {
    static public func createEventData(remainingAmount: Double) -> Data {
        Data(remainingAmount.sfloat)
    }
}

extension AnnunciationStatusChangedHistoryEvent {
    static public func createEventDataPart1(identifier: AnnunciationIdentifier,
                                            type: AnnunciationType,
                                            status: AnnunciationStatus,
                                            auxInfo1: Data? = nil,
                                            auxInfo2: Data? = nil) -> Data
    {
        var flags: AnnunciationStatusFlag = .allZeros
        var eventData = Data(identifier)
        eventData.append(type.rawValue)
        eventData.append(status.rawValue)
        if let auxInfo1 {
            flags.insert(.presentAuxInfo1)
            eventData.append(contentsOf: auxInfo1)
        }
        if let auxInfo2 {
            flags.insert(.presentAuxInfo2)
            eventData.append(contentsOf: auxInfo2)
        }
        eventData.insert(flags.rawValue, at: 0)
        return eventData
    }
    
    static public func createEventDataPart2(auxInfo3: Data? = nil,
                                            auxInfo4: Data? = nil,
                                            auxInfo5: Data? = nil) -> Data
    {
        var flags: AnnunciationStatusFlag = .allZeros
        var eventData = Data()
        if let auxInfo3 {
            flags.insert(.presentAuxInfo3)
            eventData.append(contentsOf: auxInfo3)
        }
        if let auxInfo4 {
            flags.insert(.presentAuxInfo4)
            eventData.append(contentsOf: auxInfo4)
        }
        if let auxInfo5 {
            flags.insert(.presentAuxInfo5)
            eventData.append(contentsOf: auxInfo5)
        }
        eventData.insert(flags.rawValue, at: 0)
        return eventData
    }
}

extension ISFProfileTemplateTimeBlockChangedHistoryEvent {
    static public func createEventData(templateNumber: TemplateNumber,
                                       timeBlockNumber: UInt8,
                                       duration: TimeInterval,
                                       isf: Double) -> Data
    {
        var eventData = Data(templateNumber)
        eventData.append(UInt8(timeBlockNumber))
        eventData.append(UInt16(duration.minutes))
        eventData.append(isf.sfloat)
        return eventData
    }
}

extension I2CHORatioProfileTemplateTimeBlockChangedHistoryEvent {
    static public func createEventData(templateNumber: TemplateNumber,
                                       timeBlockNumber: UInt8,
                                       duration: TimeInterval,
                                       ratio: Double) -> Data
    {
        var eventData = Data(templateNumber)
        eventData.append(UInt8(timeBlockNumber))
        eventData.append(UInt16(duration.minutes))
        eventData.append(ratio.sfloat)
        return eventData
    }
}

extension TargetGlucoseRangeProfileTemplateTimeBlockChangedHistoryEvent {
    static public func createEventData(templateNumber: TemplateNumber,
                                       timeBlockNumber: UInt8,
                                       duration: TimeInterval,
                                       lowerTarget: Double,
                                       upperTarget: Double) -> Data
    {
        var eventData = Data(templateNumber)
        eventData.append(UInt8(timeBlockNumber))
        eventData.append(UInt16(duration.minutes))
        eventData.append(lowerTarget.sfloat)
        eventData.append(upperTarget.sfloat)
        return eventData
    }
}

extension PrimingStartedHistoryEvent {
    static public func createEventData(amount: Double) -> Data {
        Data(amount.sfloat)
    }
}

extension PrimingDoneHistoryEvent {
    static public func createEventData(deliveredAmount: Double,
                                       terminationReason: PrimingTerminationReason,
                                       annunciationID: AnnunciationIdentifier? = nil) -> Data
    {
        var flags: PrimingDoneFlag = .allZeros
        var eventData = Data(deliveredAmount.sfloat)
        eventData.append(terminationReason.rawValue)
        if let annunciationID {
            flags.insert(.annunciationIDPresent)
            eventData.append(annunciationID)
        }
        eventData.insert(flags.rawValue, at: 0)
        return eventData
    }
}

extension BolusTemplateChangedHistoryEvent {
    static public func createEventDataPart1(templateNumber: TemplateNumber,
                                            type: BolusType,
                                            fastAmount: Double,
                                            extendedAmount: Double,
                                            duration: TimeInterval) -> Data
    {
        var eventData = Data(templateNumber)
        eventData.append(type.rawValue)
        eventData.append(fastAmount.sfloat)
        eventData.append(extendedAmount.sfloat)
        eventData.append(UInt16(duration.minutes))
        return eventData
    }
    
    static public func createEventDataPart2(delayTime: TimeInterval? = nil) -> Data
    {
        var flags: BolusTemplateFlag = .allZeros
        var eventData = Data()
        if let delayTime {
            flags.insert(.delayTimePresent)
            eventData.append(UInt16(delayTime.minutes))
        }
        return eventData
    }
}

extension TempBasalTemplateChangedHistoryEvent {
    static public func createEventData(templateNumber: TemplateNumber,
                                       type: BolusType,
                                       rate: Double,
                                       duration: TimeInterval) -> Data
    {
        var eventData = Data(templateNumber)
        eventData.append(type.rawValue)
        eventData.append(rate.sfloat)
        eventData.append(UInt16(duration.minutes))
        return eventData
    }
}

extension MaxBolusAmountChangedHistoryEvent {
    static public func createEventData(oldAmount: Double,
                                       newAmount: Double) -> Data
    {
        var eventData = Data(oldAmount.sfloat)
        eventData.append(newAmount.sfloat)
        return eventData
    }
}
