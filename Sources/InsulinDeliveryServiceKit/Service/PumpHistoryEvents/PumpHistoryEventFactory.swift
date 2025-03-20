//
//  PumpHistoryEventFactory.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

struct PumpHistoryEventFactory {
    // TODO how to handle creation of extensions
    static func createPumpHistoryEvent(type: IDHistoryEventType,
                                       sequenceNumber: HistoryEventSequenceNumber,
                                       relativeOffet: TimeInterval,
                                       auxData: Data) -> PumpHistoryEvent?
    {
        guard let PumpHistoryEvent = type.PumpHistoryEvent else { return nil }
        return PumpHistoryEvent.init(sequenceNumber: sequenceNumber, relativeOffset: relativeOffet, auxData: auxData)
    }
}

extension IDHistoryEventType {
    var PumpHistoryEvent: PumpHistoryEvent.Type? {
        switch self {
        case .annunciationStatusChangedPart1: return AnnunciationStatusChangedPart1HistoryEvent.self
        case .annunciationStatusChangedPart2: return AnnunciationStatusChangedPart2HistoryEvent.self
        case .basalRateProfileTimeBlockChanged: return BasalRateProfileTimeBlockChangedHistoryEvent.self
        case .bolusCalculatedPart1: return BolusCalculatedPart1HistoryEvent.self
        case .bolusCalculatedPart2: return BolusCalculatedPart2HistoryEvent.self
        case .bolusDeliveredPart1: return BolusDeliveredPart1HistoryEvent.self
        case .bolusDeliveredPart2: return BolusDeliveredPart2HistoryEvent.self
        case .bolusProgrammedPart1: return BolusProgrammedPart1HistoryEvent.self
        case .bolusProgrammedPart2: return BolusProgrammedPart2HistoryEvent.self
        case .bolusTemplateChangedPart1: return BolusTemplateChangedPart1HistoryEvent.self
        case .bolusTemplateChangedPart2: return BolusTemplateChangedPart2HistoryEvent.self
        case .dataCorruption: return DataCorruptionHistoryEvent.self
        case .deliveredBasalRateChanged: return DeliveredBasalRateChangedHistoryEvent.self
        case .i2choProfileTemplateTimeBlockChanged: return I2CHORatioProfileTemplateTimeBlockChangedHistoryEvent.self
        case .isfProfileTemplateTimeBlockChanged: return ISFProfileTemplateTimeBlockChangedHistoryEvent.self
        case .maxBolusAmountChanged: return MaxBolusAmountChangedHistoryEvent.self
        case .operationalStateChanged: return OperationalStateChangedHistoryEvent.self
        case .pointerEvent: return PointerHistoryEvent.self
        case .primingDone: return PrimingDoneHistoryEvent.self
        case .primingStarted: return PrimingStartedHistoryEvent.self
        case .profileTemplateActivated: return ProfileTemplateActivatedHistoryEvent.self
        case .referenceTime: return ReferenceTimeHistoryEvent.self
        case .referenceTimeBaseOffset: return ReferenceTimeBaseOffsetHistoryEvent.self
        case .reservoirRemainingAmountChanged: return ReservoirRemainingAmountChangedHistoryEvent.self
        case .targetGlucoseRangeProfileTemplateTimeBlockChanged: return TargetGlucoseRangeProfileTemplateTimeBlockChangedHistoryEvent.self
        case .tempBasalRateAdjustmentChanged: return TempBasalAdjustmentChangedHistoryEvent.self
        case .tempBasalRateAdjustmentEnded: return TempBasalAdjustmentEndedHistoryEvent.self
        case .tempBasalRateAdjustmentStarted: return TempBasalAdjustmentStartedHistoryEvent.self
        case .tempBasalRateTemplateChanged: return TempBasalTemplateChangedHistoryEvent.self
        case .therapyControlStateChanged: return TherapyControlStateChangedHistoryEvent.self
        case .totalDailyInsulinDelivery: return TotalDailyInsulinDeliveryHistoryEvent.self
        default:
            return nil
        }
    }
}
