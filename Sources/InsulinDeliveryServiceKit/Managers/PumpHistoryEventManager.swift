//
//  PumpHistoryEventManager.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit

protocol PumpHistoryEventManagerDelegate: AnyObject {
    func pumpHistoryEventManagerDidUpdateConfiguration(_ pumpHistoryEventManager: PumpHistoryEventManager)
    func pumpHistoryEventManagerDidDetectBolusProgrammed(_ pumpHistoryEventManager: PumpHistoryEventManager, bolusID: BolusID, insulinProgrammed: Double, at date: Date)
    func pumpHistoryEventManagerDidDetectBolusDelivered(_ pumpHistoryEventManager: PumpHistoryEventManager, bolusID: BolusID, insulinProgrammed: Double, insulinDelivered: Double, startTime: Date, duration: TimeInterval)
    func pumpHistoryEventManagerDidDetectTempBasalStarted(_ pumpHistoryEventManager: PumpHistoryEventManager, at startTime: Date, rate: Double, duration: TimeInterval)
    func pumpHistoryEventManagerDidDetectTempBasalChanged(_ pumpHistoryEventManager: PumpHistoryEventManager, at startTime: Date, rate: Double, programmedDuration: TimeInterval, elapsedDuration: TimeInterval)
    func pumpHistoryEventManagerDidDetectTempBasalEnded(_ pumpHistoryEventManager: PumpHistoryEventManager, duration: TimeInterval, endReason: TempBasalEndReason)
    func pumpHistoryEventManagerDidDetectInsulinDeliverySuspended(_ pumpHistoryEventManager: PumpHistoryEventManager, suspendedAt: Date)
    func pumpHistoryEventManagerDidDetectAnnunciation(_ pumpHistoryEventManager: PumpHistoryEventManager, annunciation: Annunciation, at date: Date?)
}

public class PumpHistoryEventManager {

    static var historyEventTypesToReport: [IDHistoryEventType] {
        // Only report pump history events:
        // - that affect insulin delivery (e.g., bolus, therapy state)
        // - that can happen when the pump is not connected
        // - that are not detected when connection is re-established (e.g., therapy state and reservoir level are requested with each connection)
        // all other events originate from Tidepool Loop and are accounted for (e.g., temp basal started and changed) or not applicable to Tidepool Loop (e.g., bluetooth bonding, generic).
        [.annunciationStatusChangedPart1, .annunciationStatusChangedPart2, .bolusDeliveredPart1, .bolusDeliveredPart2, .bolusProgrammedPart1, .bolusProgrammedPart2, .tempBasalRateAdjustmentChanged, .tempBasalRateAdjustmentEnded, .tempBasalRateAdjustmentStarted, .therapyControlStateChanged]
    }

    weak var delegate: PumpHistoryEventManagerDelegate?

    private var lockedConfiguration: Locked<Configuration>

    var configuration: Configuration {
        get {
            return lockedConfiguration.value
        }
        set {
            if lockedConfiguration.value != newValue {
                lockedConfiguration.value = newValue
                delegate?.pumpHistoryEventManagerDidUpdateConfiguration(self)
            }
        }
    }

    var lastReceivedHistoryEventRecordNumber: RecordNumber? {
        get {
            configuration.lastReceivedHistoryEventRecordNumber
        }
        set {
            configuration.lastReceivedHistoryEventRecordNumber = newValue
        }
    }

    var referenceDate: Date? {
        get {
            configuration.referenceDate
        }
        set {
            configuration.referenceDate = newValue
        }
    }

    private var cachedPumpHistoryEvents: [IDHistoryEventType: PumpHistoryEvent] {
        get {
            configuration.cachedPumpHistoryEvents
        }
        set {
            configuration.cachedPumpHistoryEvents = newValue
        }
    }

    func shouldReportHistoryEvent(_ pumpHistoryEvent: PumpHistoryEvent) -> Bool {
        PumpHistoryEventManager.historyEventTypesToReport.contains(pumpHistoryEvent.type)
    }

    func reset() {
        configuration = Configuration()
        cachedPumpHistoryEvents = [:]
    }

    public init(lastReceivedHistoryEventRecordNumber: RecordNumber? = nil,
                referenceDate: Date? = nil,
                cachedPumpHistoryEvents: [IDHistoryEventType: PumpHistoryEvent] = [:])
    {
        self.lockedConfiguration = Locked(Configuration(lastReceivedHistoryEventRecordNumber: lastReceivedHistoryEventRecordNumber, referenceDate: referenceDate, cachedPumpHistoryEvents: cachedPumpHistoryEvents))
    }

    public init(configuration: Configuration = Configuration()) {
        self.lockedConfiguration = Locked(configuration)
    }

    func processPumpHistoryEvent(_ pumpHistoryEvent: PumpHistoryEvent) {
        lastReceivedHistoryEventRecordNumber = pumpHistoryEvent.recordNumber
        guard pumpHistoryEvent.type != .referenceTime else {
            if let referenceTimeHistoryEvent = pumpHistoryEvent as? ReferenceTimeHistoryEvent {
                guard referenceTimeHistoryEvent.recordingReason != .dateTimeLoss else {
                    // If date time has been lost, the included offset does not reference the last reference time event but instead it is set to 0
                    // Also, the date and time of the pump has been reset to a default value and cannot be trusted.
                    // The pump is not in an operational state at this point and to get into an operational state, its time needs to be set.
                    // As such, delete the trusted reference date since it will be set with the next reference time event.
                    // No insulin delivery is possible between these reference time events.
                    self.referenceDate = nil
                    return
                }

                guard let referenceDate = referenceDate else {
                    // The reference time history event is always in UTC
                    self.referenceDate = referenceTimeHistoryEvent.date(using: .utc)
                    return
                }

                // all reference time events include an offset from the last reference time event. Apply that offset to the trusted reference date
                self.referenceDate = referenceDate.addingTimeInterval(referenceTimeHistoryEvent.relativeOffset)
            }
            return
        }

        guard shouldReportHistoryEvent(pumpHistoryEvent) else { return }

        switch pumpHistoryEvent.type {
        case .annunciationStatusChangedPart1:
            cachedPumpHistoryEvents[pumpHistoryEvent.type] = pumpHistoryEvent
        case .annunciationStatusChangedPart2:
            guard let annunciationStatusChangedPart1HistoryEvent = cachedPumpHistoryEvents[.annunciationStatusChangedPart1] as? AnnunciationStatusChangedPart1HistoryEvent,
                  let annunciationStatusChangedPart2HistoryEvent = pumpHistoryEvent as? AnnunciationStatusChangedPart2HistoryEvent,
                  let annunciationStatusChangedHistoryEvent = AnnunciationStatusChangedHistoryEvent(part1: annunciationStatusChangedPart1HistoryEvent, part2: annunciationStatusChangedPart2HistoryEvent)
            else { return }

            cachedPumpHistoryEvents[.annunciationStatusChangedPart1] = nil

            let date = referenceDate?.addingTimeInterval(annunciationStatusChangedHistoryEvent.relativeOffset)
            delegate?.pumpHistoryEventManagerDidDetectAnnunciation(self, annunciation: annunciationStatusChangedHistoryEvent.annunciation, at: date)
        case .bolusDeliveredPart1:
            cachedPumpHistoryEvents[pumpHistoryEvent.type] = pumpHistoryEvent
        case .bolusDeliveredPart2:
            guard let bolusProgrammedPart1HistoryEvent = cachedPumpHistoryEvents[.bolusProgrammedPart1] as? BolusProgrammedPart1HistoryEvent,
                  let bolusDeliveredPart1HistoryEvent = cachedPumpHistoryEvents[.bolusDeliveredPart1] as? BolusDeliveredPart1HistoryEvent,
                  let bolusDeliveredPart2HistoryEvent = pumpHistoryEvent as? BolusDeliveredPart2HistoryEvent,
                  let bolusDeliveredHistoryEvent = BolusDeliveredHistoryEvent(part1: bolusDeliveredPart1HistoryEvent, part2: bolusDeliveredPart2HistoryEvent),
                  let referenceDate = referenceDate
            else { return }

            cachedPumpHistoryEvents[.bolusProgrammedPart1] = nil
            cachedPumpHistoryEvents[.bolusDeliveredPart1] = nil

            let bolusID = bolusDeliveredHistoryEvent.bolusID
            let insulinProgrammed = bolusProgrammedPart1HistoryEvent.fastAmount
            let insulinDelivered = bolusDeliveredHistoryEvent.fastAmount
            let startTime = referenceDate.addingTimeInterval(bolusProgrammedPart1HistoryEvent.relativeOffset)
            let duration = max(0, bolusDeliveredHistoryEvent.relativeOffset - bolusProgrammedPart1HistoryEvent.relativeOffset)

            delegate?.pumpHistoryEventManagerDidDetectBolusDelivered(self, bolusID: bolusID, insulinProgrammed: insulinProgrammed, insulinDelivered: insulinDelivered, startTime: startTime, duration: duration)
        case .bolusProgrammedPart1:
            cachedPumpHistoryEvents[pumpHistoryEvent.type] = pumpHistoryEvent
        case .bolusProgrammedPart2:
            guard let bolusProgrammedPart1HistoryEvent = cachedPumpHistoryEvents[.bolusProgrammedPart1] as? BolusProgrammedPart1HistoryEvent,
                  let bolusProgrammedPart2HistoryEvent = pumpHistoryEvent as? BolusProgrammedPart2HistoryEvent,
                  let bolusProgrammedHistoryEvent = BolusProgrammedHistoryEvent(part1: bolusProgrammedPart1HistoryEvent, part2: bolusProgrammedPart2HistoryEvent),
                  let referenceDate = referenceDate
            else { return }

            delegate?.pumpHistoryEventManagerDidDetectBolusProgrammed(self, bolusID: bolusProgrammedPart1HistoryEvent.bolusID, insulinProgrammed: bolusProgrammedHistoryEvent.fastAmount, at: referenceDate.addingTimeInterval(bolusProgrammedHistoryEvent.relativeOffset))
        case .tempBasalRateAdjustmentStarted:
            guard let tempBasalRateAdjustmentStarted = pumpHistoryEvent as? TempBasalAdjustmentStartedHistoryEvent,
                  let referenceDate = referenceDate
            else { return }

            let startTime = referenceDate.addingTimeInterval(tempBasalRateAdjustmentStarted.relativeOffset)
            delegate?.pumpHistoryEventManagerDidDetectTempBasalStarted(self, at: startTime, rate: tempBasalRateAdjustmentStarted.rate, duration: tempBasalRateAdjustmentStarted.programmedDuration)
        case .tempBasalRateAdjustmentChanged:
            guard let tempBasalRateAdjustmentChanged = pumpHistoryEvent as? TempBasalAdjustmentChangedHistoryEvent,
                  let referenceDate = referenceDate
            else { return }

            let startTime = referenceDate.addingTimeInterval(tempBasalRateAdjustmentChanged.relativeOffset)
            delegate?.pumpHistoryEventManagerDidDetectTempBasalChanged(self, at: startTime, rate: tempBasalRateAdjustmentChanged.rate, programmedDuration: tempBasalRateAdjustmentChanged.programmedDuration, elapsedDuration: tempBasalRateAdjustmentChanged.elapsedDuration)
        case .tempBasalRateAdjustmentEnded:
            guard let tempBasalRateAdjustmentEnded = pumpHistoryEvent as? TempBasalAdjustmentEndedHistoryEvent
            else { return }

            delegate?.pumpHistoryEventManagerDidDetectTempBasalEnded(self, duration: tempBasalRateAdjustmentEnded.effectiveDuration, endReason: tempBasalRateAdjustmentEnded.endReason)
        case .therapyControlStateChanged:
            guard let therapyControlStateChanged = pumpHistoryEvent as? TherapyControlStateChangedHistoryEvent,
                  let referenceDate = referenceDate
            else { return }

            // report any suspend to insulin delivery, since it may have happened out of comms
            if therapyControlStateChanged.oldState == .run,
               therapyControlStateChanged.newState == .stop
            {
                let suspendedAt = referenceDate.addingTimeInterval(therapyControlStateChanged.relativeOffset)
                delegate?.pumpHistoryEventManagerDidDetectInsulinDeliverySuspended(self, suspendedAt: suspendedAt)
            }
        default:
            break
        }
    }
}

extension PumpHistoryEventManager {
    public struct Configuration: RawRepresentable {
        public typealias RawValue = [String:Any]

        private enum PumpHistoryEventManagerConfigurationKey: String {
            case storablePumpHistoryEvents
            case lastReceivedHistoryEventRecordNumber
            case referenceDate
        }


        var lastReceivedHistoryEventRecordNumber: RecordNumber?

        var referenceDate: Date?

        fileprivate var cachedPumpHistoryEvents: [IDHistoryEventType: PumpHistoryEvent]

        var storablePumpHistoryEvents: [IDHistoryEventType: StorablePumpHistoryEvent] {
            var storablePumpHistoryEvents: [IDHistoryEventType: StorablePumpHistoryEvent] = [:]

            for pumpHistoryEvent in cachedPumpHistoryEvents.values {
                storablePumpHistoryEvents[pumpHistoryEvent.type] = StorablePumpHistoryEvent(pumpHistoryEvent: pumpHistoryEvent)
            }
            return storablePumpHistoryEvents
        }

        public init(lastReceivedHistoryEventRecordNumber: RecordNumber? = nil,
                    referenceDate: Date? = nil,
                    cachedPumpHistoryEvents: [IDHistoryEventType: PumpHistoryEvent] = [:])
        {
            self.lastReceivedHistoryEventRecordNumber = lastReceivedHistoryEventRecordNumber
            self.referenceDate = referenceDate
            self.cachedPumpHistoryEvents = cachedPumpHistoryEvents
        }

        public init?(rawValue: RawValue) {
            let referenceDate = rawValue[PumpHistoryEventManagerConfigurationKey.referenceDate.rawValue] as? Date
            let lastReceivedHistoryEventRecordNumber = rawValue[PumpHistoryEventManagerConfigurationKey.lastReceivedHistoryEventRecordNumber.rawValue] as? RecordNumber
            self.lastReceivedHistoryEventRecordNumber = lastReceivedHistoryEventRecordNumber
            self.referenceDate = referenceDate

            self.cachedPumpHistoryEvents = [:]
            if let rawStorablePumpHistoryEvents = rawValue[PumpHistoryEventManagerConfigurationKey.storablePumpHistoryEvents.rawValue] as? Data,
               let storablePumpHistoryEvents = try? PropertyListDecoder().decode([IDHistoryEventType: StorablePumpHistoryEvent].self, from: rawStorablePumpHistoryEvents)
            {
                for (pumpHistoryEventType, pumpHistoryEvent) in storablePumpHistoryEvents {
                    self.cachedPumpHistoryEvents[pumpHistoryEventType] = pumpHistoryEvent
                }
            }
        }

        public var rawValue: RawValue {
            var rawValue: RawValue = [:]
            rawValue[PumpHistoryEventManagerConfigurationKey.lastReceivedHistoryEventRecordNumber.rawValue] = lastReceivedHistoryEventRecordNumber
            rawValue[PumpHistoryEventManagerConfigurationKey.referenceDate.rawValue] = referenceDate

            let rawStorablePumpHistoryEvents = try? PropertyListEncoder().encode(storablePumpHistoryEvents)
            rawValue[PumpHistoryEventManagerConfigurationKey.storablePumpHistoryEvents.rawValue] = rawStorablePumpHistoryEvents
            return rawValue
        }

    }
}

extension PumpHistoryEventManager.Configuration: Equatable {
    public static func == (lhs: PumpHistoryEventManager.Configuration, rhs: PumpHistoryEventManager.Configuration) -> Bool {

        return lhs.referenceDate == rhs.referenceDate &&
        lhs.lastReceivedHistoryEventRecordNumber == rhs.lastReceivedHistoryEventRecordNumber &&
        lhs.storablePumpHistoryEvents == rhs.storablePumpHistoryEvents
    }
}
