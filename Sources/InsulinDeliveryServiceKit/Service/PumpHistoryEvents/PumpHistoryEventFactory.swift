//
//  PumpHistoryEventFactory.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

struct PumpHistoryEventFactory {
    static func createPumpHistoryEvent<T:PumpHistoryEvent>(ofType: T.Type,
                                                           sequenceNumber: HistoryEventSequenceNumber,
                                                           relativeOffet: TimeInterval,
                                                           auxData: Data) -> PumpHistoryEvent
    {
        return T(sequenceNumber: sequenceNumber, relativeOffset: relativeOffet, auxData: auxData)
    }

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
    // TODO add the remaining to this list
    var PumpHistoryEvent: PumpHistoryEvent.Type? {
        switch self {
        case .annunciationStatusChangedPart1: return AnnunciationStatusChangedPart1HistoryEvent.self
        case .annunciationStatusChangedPart2: return AnnunciationStatusChangedPart2HistoryEvent.self
        case .basalRateProfileTimeBlockChanged: return BasalRateProfileTimeBlockChangedHistoryEvent.self
        case .bolusDeliveredPart1: return BolusDeliveredPart1HistoryEvent.self
        case .bolusDeliveredPart2: return BolusDeliveredPart2HistoryEvent.self
        case .bolusProgrammedPart1: return BolusProgrammedPart1HistoryEvent.self
        case .bolusProgrammedPart2: return BolusProgrammedPart2HistoryEvent.self
        case .dataCorruption: return DataCorruptionHistoryEvent.self
        case .deliveredBasalRateChanged: return DeliveredBasalRateChangedHistoryEvent.self
        case .operationalStateChanged: return OperationalStateChangedHistoryEvent.self
        case .primingDone: return PrimingDoneHistoryEvent.self
        case .primingStarted: return PrimingStartedHistoryEvent.self
        case .profileTemplateActivated: return ProfileTemplateActivatedHistoryEvent.self
        case .referenceTime: return ReferenceTimeHistoryEvent.self
        case .reservoirRemainingAmountChanged: return ReservoirRemainingAmountChangedHistoryEvent.self
        case .tempBasalRateAdjustmentChanged: return TempBasalAdjustmentChangedHistoryEvent.self
        case .tempBasalRateAdjustmentEnded: return TempBasalAdjustmentEndedHistoryEvent.self
        case .tempBasalRateAdjustmentStarted: return TempBasalAdjustmentStartedHistoryEvent.self
        case .therapyControlStateChanged: return TherapyControlStateChangedHistoryEvent.self
        case .totalDailyInsulinDelivery: return TotalDailyInsulinDeliveryHistoryEvent.self
        default:
            return nil
        }
    }
}
