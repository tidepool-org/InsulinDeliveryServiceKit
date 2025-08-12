//
//  PumpHistoryEventManagerTests.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-07-23.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
@testable import InsulinDeliveryServiceKit

class PumpHistoryEventManagerTests: XCTestCase {

    private var pumpHistoryEventManager: PumpHistoryEventManager!
    private var nextHistoryEventRecordNumber: RecordNumber = 12345
    private var referenceDate = Date()
    private var relativeOffset = TimeInterval.minutes(1)
    private var didUpdateConfiguration = false
    private var bolusProgrammedAmount: Double!
    private var bolusStartTime: Date!
    private var didDetectBolusDelivered = false
    private var bolusDeliveredAmount: Double!
    private var bolusDuration: TimeInterval!
    private var tempBasalStarted: Bool?
    private var tempBasalChanged: Bool?
    private var tempBasalEnded: Bool?
    private var tempBasalRate: Double?
    private var tempBasalDuration: TimeInterval?
    private var tempBasalElaspedDuration: TimeInterval?
    private var suspendedAt: Date?
    private var annunciation: GeneralAnnunciation?
    private var annunciationDate: Date?

    func setupPumpHistoryEventManager(withCachedPumpHistoryEvents cachedPumpHistoryEvents: [IDHistoryEventType: PumpHistoryEvent] = [:]) {
        pumpHistoryEventManager = PumpHistoryEventManager(lastReceivedHistoryEventRecordNumber: nextHistoryEventRecordNumber, referenceDate: referenceDate, cachedPumpHistoryEvents: cachedPumpHistoryEvents)
        pumpHistoryEventManager.delegate = self
        nextHistoryEventRecordNumber+=1
    }

    func testHistoryEventTypesToReport() {
        let historyEventTypesToReport = PumpHistoryEventManager.historyEventTypesToReport
        XCTAssertEqual(historyEventTypesToReport.count, 10)
        XCTAssertTrue(historyEventTypesToReport.contains(.annunciationStatusChangedPart1))
        XCTAssertTrue(historyEventTypesToReport.contains(.annunciationStatusChangedPart2))
        XCTAssertTrue(historyEventTypesToReport.contains(.bolusDeliveredPart1))
        XCTAssertTrue(historyEventTypesToReport.contains(.bolusDeliveredPart2))
        XCTAssertTrue(historyEventTypesToReport.contains(.bolusProgrammedPart1))
        XCTAssertTrue(historyEventTypesToReport.contains(.bolusProgrammedPart2))
        XCTAssertTrue(historyEventTypesToReport.contains(.tempBasalRateAdjustmentChanged))
        XCTAssertTrue(historyEventTypesToReport.contains(.tempBasalRateAdjustmentEnded))
        XCTAssertTrue(historyEventTypesToReport.contains(.tempBasalRateAdjustmentStarted))
        XCTAssertTrue(historyEventTypesToReport.contains(.therapyControlStateChanged))
    }

    func testReset() {
        let lastReceivedHistoryEventRecordNumber = nextHistoryEventRecordNumber
        let cachedPumpHistoryEvents: [IDHistoryEventType: PumpHistoryEvent] = [.generic: GenericHistoryEvent(recordNumber: lastReceivedHistoryEventRecordNumber, relativeOffset: .minutes(1), eventData: Data())]
        let expectedStorablePumpHistoryEvents:  [IDHistoryEventType: StorablePumpHistoryEvent] = [.generic: StorablePumpHistoryEvent(pumpHistoryEvent: GenericHistoryEvent(recordNumber: lastReceivedHistoryEventRecordNumber, relativeOffset: .minutes(1), eventData: Data()))!]
        setupPumpHistoryEventManager(withCachedPumpHistoryEvents: cachedPumpHistoryEvents)

        XCTAssertEqual(pumpHistoryEventManager.configuration.lastReceivedHistoryEventRecordNumber, lastReceivedHistoryEventRecordNumber)
        XCTAssertEqual(pumpHistoryEventManager.configuration.referenceDate, referenceDate)
        XCTAssertEqual(pumpHistoryEventManager.configuration.storablePumpHistoryEvents, expectedStorablePumpHistoryEvents)

        pumpHistoryEventManager.reset()

        XCTAssertNil(pumpHistoryEventManager.configuration.lastReceivedHistoryEventRecordNumber)
        XCTAssertNil(pumpHistoryEventManager.configuration.referenceDate)
        XCTAssertEqual(pumpHistoryEventManager.configuration.storablePumpHistoryEvents, [:])
    }

    func testProcessPumpHistoryEventReferenceTime() {
        setupPumpHistoryEventManager()
        var calendar = Calendar.current
        calendar.timeZone = .utc
        let dateComponents = DateComponents(calendar: calendar, year: 2021, month: 2, day: 3, hour: 4, minute: 5, second: 6)
        let date = calendar.date(from: dateComponents)!
        let referenceTimeHistoryEvent = createReferenceTimeHistoryEvent(forUTCDate: date)

        pumpHistoryEventManager.referenceDate = nil
        pumpHistoryEventManager.processPumpHistoryEvent(referenceTimeHistoryEvent)
        XCTAssertEqual(pumpHistoryEventManager.lastReceivedHistoryEventRecordNumber, nextHistoryEventRecordNumber)
        XCTAssertEqual(pumpHistoryEventManager.referenceDate, date)

        // reference time history events are not cached
        XCTAssertEqual(pumpHistoryEventManager.configuration.storablePumpHistoryEvents, [:])
    }

    func testProcessPumpHistoryEventReferenceTimeLoss() {
        setupPumpHistoryEventManager()
        let dateComponents = DateComponents(calendar: Calendar.current, year: 2021, month: 2, day: 3, hour: 4, minute: 5, second: 6)
        let date = Calendar.current.date(from: dateComponents)!
        let referenceTimeHistoryEvent = createReferenceTimeHistoryEvent(forUTCDate: date, recordingReason: .dateTimeLoss)

        pumpHistoryEventManager.processPumpHistoryEvent(referenceTimeHistoryEvent)
        XCTAssertEqual(pumpHistoryEventManager.lastReceivedHistoryEventRecordNumber, nextHistoryEventRecordNumber)
        XCTAssertNil(pumpHistoryEventManager.referenceDate)

        // reference time history events are not cached
        XCTAssertEqual(pumpHistoryEventManager.configuration.storablePumpHistoryEvents, [:])
    }

    func testProcessPumpHistoryEventReferenceTimeSet() {
        setupPumpHistoryEventManager()
        let dateComponents = DateComponents(calendar: Calendar.current, year: 2021, month: 2, day: 3, hour: 4, minute: 5, second: 6)
        let date = Calendar.current.date(from: dateComponents)!
        pumpHistoryEventManager.referenceDate = date

        relativeOffset = 30
        let referenceTimeHistoryEvent = createReferenceTimeHistoryEvent(forUTCDate: date, recordingReason: .setDateTime)
        pumpHistoryEventManager.processPumpHistoryEvent(referenceTimeHistoryEvent)
        XCTAssertEqual(pumpHistoryEventManager.lastReceivedHistoryEventRecordNumber, nextHistoryEventRecordNumber)
        XCTAssertEqual(pumpHistoryEventManager.referenceDate, date.addingTimeInterval(relativeOffset))

        // reference time history events are not cached
        XCTAssertEqual(pumpHistoryEventManager.configuration.storablePumpHistoryEvents, [:])
    }

    func testProcessPumpHistoryEventBolusDeliveredPart1() {
        setupPumpHistoryEventManager()
        let bolusDeliveredPart1HistoryEvent = createBolusDeliveredPart1HistoryEvent(withBolusID: 2)

        pumpHistoryEventManager.processPumpHistoryEvent(bolusDeliveredPart1HistoryEvent)
        XCTAssertEqual(pumpHistoryEventManager.lastReceivedHistoryEventRecordNumber, nextHistoryEventRecordNumber)
        XCTAssertEqual(pumpHistoryEventManager.configuration.storablePumpHistoryEvents, [.bolusDeliveredPart1: StorablePumpHistoryEvent(pumpHistoryEvent: bolusDeliveredPart1HistoryEvent)])
    }

    func testProcessPumpHistoryEventBolusDeliveredPart2() {
        let bolusID: BolusID = 2
        let bolusProgrammedPart1HistoryEvent = createBolusProgrammedPart1HistoryEvent(withBolusID: bolusID)
        let bolusDeliveredPart1HistoryEvent = createBolusDeliveredPart1HistoryEvent(withBolusID: bolusID)
        nextHistoryEventRecordNumber+=1
        setupPumpHistoryEventManager(withCachedPumpHistoryEvents: [.bolusProgrammedPart1: bolusProgrammedPart1HistoryEvent, .bolusDeliveredPart1: bolusDeliveredPart1HistoryEvent])
        let bolusDeliveredPart2HistoryEvent = createBolusDeliveredPart2HistoryEvent()

        pumpHistoryEventManager.processPumpHistoryEvent(bolusDeliveredPart2HistoryEvent)
        XCTAssertEqual(pumpHistoryEventManager.lastReceivedHistoryEventRecordNumber, nextHistoryEventRecordNumber)
        XCTAssertEqual(pumpHistoryEventManager.configuration.storablePumpHistoryEvents, [:])
    }

    func testProcessPumpHistoryEventBolusProgrammedPart1() {
        let bolusID: BolusID = 2
        setupPumpHistoryEventManager()
        let bolusProgrammedPart1HistoryEvent = createBolusProgrammedPart1HistoryEvent(withBolusID: bolusID)

        pumpHistoryEventManager.processPumpHistoryEvent(bolusProgrammedPart1HistoryEvent)
        XCTAssertEqual(pumpHistoryEventManager.lastReceivedHistoryEventRecordNumber, nextHistoryEventRecordNumber)
        XCTAssertEqual(pumpHistoryEventManager.configuration.storablePumpHistoryEvents, [.bolusProgrammedPart1: StorablePumpHistoryEvent(pumpHistoryEvent: bolusProgrammedPart1HistoryEvent)])
    }

    func testProcessPumpHistoryEventBolusProgrammedPart2() {
        let bolusID: BolusID = 2
        let bolusProgrammedPart1HistoryEvent = createBolusProgrammedPart1HistoryEvent(withBolusID: bolusID)
        nextHistoryEventRecordNumber+=1
        setupPumpHistoryEventManager(withCachedPumpHistoryEvents: [.bolusProgrammedPart1: bolusProgrammedPart1HistoryEvent])
        let bolusProgrammedPart2HistoryEvent = createBolusProgrammedPart2HistoryEvent()

        pumpHistoryEventManager.processPumpHistoryEvent(bolusProgrammedPart2HistoryEvent)
        XCTAssertEqual(pumpHistoryEventManager.lastReceivedHistoryEventRecordNumber, nextHistoryEventRecordNumber)
        XCTAssertEqual(pumpHistoryEventManager.configuration.storablePumpHistoryEvents, [.bolusProgrammedPart1: StorablePumpHistoryEvent(pumpHistoryEvent: bolusProgrammedPart1HistoryEvent)])
    }

    func testProcessPumpHistoryEventOtherHistoryEvent() {
        setupPumpHistoryEventManager()
        pumpHistoryEventManager.processPumpHistoryEvent(GenericHistoryEvent(recordNumber: nextHistoryEventRecordNumber, relativeOffset: .minutes(1), eventData: Data()))

        XCTAssertEqual(pumpHistoryEventManager.lastReceivedHistoryEventRecordNumber, nextHistoryEventRecordNumber)
        XCTAssertEqual(pumpHistoryEventManager.configuration.storablePumpHistoryEvents, [:])
    }

    func testDidUpdateConfiguration() {
        setupPumpHistoryEventManager()
        pumpHistoryEventManager.lastReceivedHistoryEventRecordNumber = 2
        XCTAssertTrue(didUpdateConfiguration)
    }

    func testDidDetectBolusProgrammed() {
        let bolusID: BolusID = 2
        let bolusAmount = 2.5
        let bolusProgrammedPart1HistoryEvent = createBolusProgrammedPart1HistoryEvent(withBolusID: bolusID, amount: bolusAmount)
        nextHistoryEventRecordNumber+=1
        setupPumpHistoryEventManager(withCachedPumpHistoryEvents: [.bolusProgrammedPart1: bolusProgrammedPart1HistoryEvent])
        pumpHistoryEventManager.processPumpHistoryEvent(createBolusProgrammedPart2HistoryEvent())
        XCTAssertEqual(bolusProgrammedAmount, bolusAmount)
        XCTAssertEqual(bolusStartTime, referenceDate.addingTimeInterval(relativeOffset))
    }

    func testDidDetectBolusDelivered() {
        let bolusID: BolusID = 2
        let bolusAmount = 1.5
        let bolusProgrammedPart1HistoryEvent = createBolusProgrammedPart1HistoryEvent(withBolusID: bolusID)
        let startTime = referenceDate.addingTimeInterval(relativeOffset)
        nextHistoryEventRecordNumber+=1
        let duration: TimeInterval = .seconds(15)
        relativeOffset += duration
        let bolusDeliveredPart1HistoryEvent = createBolusDeliveredPart1HistoryEvent(withBolusID: bolusID, amount: bolusAmount)
        nextHistoryEventRecordNumber+=1

        setupPumpHistoryEventManager(withCachedPumpHistoryEvents: [.bolusProgrammedPart1: bolusProgrammedPart1HistoryEvent, .bolusDeliveredPart1: bolusDeliveredPart1HistoryEvent])
        pumpHistoryEventManager.processPumpHistoryEvent(createBolusDeliveredPart2HistoryEvent())
        XCTAssertTrue(didDetectBolusDelivered)
        XCTAssertEqual(bolusDeliveredAmount, bolusAmount)
        XCTAssertEqual(bolusStartTime, startTime)
        XCTAssertEqual(bolusDuration, duration)
    }

    func testConfigurationRawValue() {
        let lastReceivedHistoryEventRecordNumber = nextHistoryEventRecordNumber
        let bolusID: BolusID = 2
        let cachedPumpHistoryEvents: [IDHistoryEventType: PumpHistoryEvent] = [
            .generic: GenericHistoryEvent(recordNumber: nextHistoryEventRecordNumber, relativeOffset: .minutes(1), eventData: Data()),
            .bolusDeliveredPart1: createBolusDeliveredPart1HistoryEvent(withBolusID: bolusID)
        ]

        var expectedEqutableCodableCachedPumpHistoryEvents: [IDHistoryEventType: StorablePumpHistoryEvent] = [:]
        for (pumpHistoryEventType, pumpHistoryEvent) in cachedPumpHistoryEvents {
            expectedEqutableCodableCachedPumpHistoryEvents[pumpHistoryEventType] = StorablePumpHistoryEvent(pumpHistoryEvent: pumpHistoryEvent)!
        }

        setupPumpHistoryEventManager(withCachedPumpHistoryEvents: cachedPumpHistoryEvents)

        let rawValue = pumpHistoryEventManager.configuration.rawValue

        XCTAssertEqual(rawValue["referenceDate"] as! Date, referenceDate)
        XCTAssertEqual(rawValue["lastReceivedHistoryEventRecordNumber"] as! RecordNumber, lastReceivedHistoryEventRecordNumber)
        XCTAssertEqual(try! PropertyListDecoder().decode([IDHistoryEventType: StorablePumpHistoryEvent].self, from: (rawValue["storablePumpHistoryEvents"] as! Data)), expectedEqutableCodableCachedPumpHistoryEvents)
    }

    func testRestoreConfigurationFromRawValue() {
        let bolusID: BolusID = 2
        let lastReceivedHistoryEventRecordNumber = nextHistoryEventRecordNumber
        let cachedPumpHistoryEvents: [IDHistoryEventType: PumpHistoryEvent] = [
            .generic: GenericHistoryEvent(recordNumber: nextHistoryEventRecordNumber, relativeOffset: .minutes(1), eventData: Data()),
            .bolusDeliveredPart1: createBolusDeliveredPart1HistoryEvent(withBolusID: bolusID)
        ]

        var expectedEqutableCodableCachedPumpHistoryEvents: [IDHistoryEventType: StorablePumpHistoryEvent] = [:]
        for (pumpHistoryEventType, pumpHistoryEvent) in cachedPumpHistoryEvents {
            expectedEqutableCodableCachedPumpHistoryEvents[pumpHistoryEventType] = StorablePumpHistoryEvent(pumpHistoryEvent: pumpHistoryEvent)!
        }

        let rawValue: [String: Any] = [
            "referenceDate": referenceDate,
            "lastReceivedHistoryEventRecordNumber": lastReceivedHistoryEventRecordNumber,
            "storablePumpHistoryEvents":  try! PropertyListEncoder().encode(expectedEqutableCodableCachedPumpHistoryEvents)
        ]

        let pumpHistoryEventManagerConfiguration = PumpHistoryEventManager.Configuration(rawValue: rawValue)

        XCTAssertNotNil(pumpHistoryEventManagerConfiguration)
        XCTAssertEqual(pumpHistoryEventManagerConfiguration?.referenceDate, referenceDate)
        XCTAssertEqual(pumpHistoryEventManagerConfiguration?.lastReceivedHistoryEventRecordNumber, lastReceivedHistoryEventRecordNumber)
        XCTAssertEqual(pumpHistoryEventManagerConfiguration?.storablePumpHistoryEvents, expectedEqutableCodableCachedPumpHistoryEvents)
    }

    func testProcessTempBasalAdjustmentStartedHistoryEvent() {
        setupPumpHistoryEventManager()
        let duration = TimeInterval.minutes(15)
        pumpHistoryEventManager.processPumpHistoryEvent(createTempBasalAdjustmentStartedHistoryEvent(duration: duration))

        XCTAssertEqual(pumpHistoryEventManager.lastReceivedHistoryEventRecordNumber, nextHistoryEventRecordNumber)
        XCTAssertEqual(pumpHistoryEventManager.configuration.storablePumpHistoryEvents, [:])

        XCTAssertEqual(tempBasalStarted, true)
        XCTAssertEqual(tempBasalDuration, duration)
    }

    func testProcessTempBasalAdjustmentChangedHistoryEvent() {
        setupPumpHistoryEventManager()
        let duration = TimeInterval.minutes(15)
        let elaspedDuration = TimeInterval.minutes(5)
        pumpHistoryEventManager.processPumpHistoryEvent(createTempBasalAdjustmentChangedHistoryEvent(duration: duration, elaspedDuration: elaspedDuration))

        XCTAssertEqual(pumpHistoryEventManager.lastReceivedHistoryEventRecordNumber, nextHistoryEventRecordNumber)
        XCTAssertEqual(pumpHistoryEventManager.configuration.storablePumpHistoryEvents, [:])

        XCTAssertEqual(tempBasalChanged, true)
        XCTAssertEqual(tempBasalDuration, duration)
        XCTAssertEqual(tempBasalElaspedDuration, elaspedDuration)
    }

    func testProcessTempBasalAdjustmentEndedHistoryEvent() {
        setupPumpHistoryEventManager()
        let duration = TimeInterval.minutes(15)
        pumpHistoryEventManager.processPumpHistoryEvent(createTempBasalAdjustmentEndedHistoryEvent(duration: duration))

        XCTAssertEqual(pumpHistoryEventManager.lastReceivedHistoryEventRecordNumber, nextHistoryEventRecordNumber)
        XCTAssertEqual(pumpHistoryEventManager.configuration.storablePumpHistoryEvents, [:])

        XCTAssertEqual(tempBasalEnded, true)
        XCTAssertEqual(tempBasalDuration, duration)
    }

    func testProcessTherapyControlStateChangedHistoryEvent() {
        setupPumpHistoryEventManager()
        relativeOffset = .minutes(30)

        pumpHistoryEventManager.processPumpHistoryEvent(createTherapyControlStateChangedHistoryEvent(oldState: .run, newState: .stop))

        XCTAssertNotNil(suspendedAt)
        XCTAssertEqual(suspendedAt, referenceDate.addingTimeInterval(relativeOffset))
    }

    func testProcessAnnunciationStatusChangedHistoryEvent() {
        setupPumpHistoryEventManager()

        let expectedAnnunciation = GeneralAnnunciation(type: .tempBasalCanceled, identifier: 123, status: .pending, auxiliaryData: Data())
        pumpHistoryEventManager.processPumpHistoryEvent(createAnnunciationStatusChanged1HistoryEvent(annunciation: expectedAnnunciation, status: .pending))
        nextHistoryEventRecordNumber+=1
        pumpHistoryEventManager.processPumpHistoryEvent(createAnnunciationStatusChanged2HistoryEvent())

        XCTAssertEqual(annunciation, expectedAnnunciation)
        XCTAssertEqual(annunciationDate, referenceDate.addingTimeInterval(relativeOffset))
    }
}

extension PumpHistoryEventManagerTests: PumpHistoryEventManagerDelegate {
    func pumpHistoryEventManagerDidUpdateConfiguration(_ pumpHistoryEventManager: PumpHistoryEventManager) {
        didUpdateConfiguration = true
    }

    func pumpHistoryEventManagerDidDetectBolusProgrammed(_ pumpHistoryEventManager: PumpHistoryEventManager, bolusID: BolusID, insulinProgrammed: Double, at date: Date) {
        bolusProgrammedAmount = insulinProgrammed
        bolusStartTime = date
    }

    func pumpHistoryEventManagerDidDetectBolusDelivered(_ pumpHistoryEventManager: PumpHistoryEventManager, bolusID: BolusID, insulinProgrammed: Double, insulinDelivered: Double, startTime: Date, duration: TimeInterval) {
        didDetectBolusDelivered = true
        bolusProgrammedAmount = insulinProgrammed
        bolusDeliveredAmount = insulinDelivered
        bolusStartTime = startTime
        bolusDuration = duration
    }

    func pumpHistoryEventManagerDidDetectTempBasalStarted(_ pumpHistoryEventManager: PumpHistoryEventManager, at startTime: Date, rate: Double, duration: TimeInterval) {
        tempBasalStarted = true
        tempBasalRate = rate
        tempBasalDuration = duration
    }
    
    func pumpHistoryEventManagerDidDetectTempBasalChanged(_ pumpHistoryEventManager: PumpHistoryEventManager, at startTime: Date, rate: Double, programmedDuration: TimeInterval, elapsedDuration: TimeInterval) {
        tempBasalChanged = true
        tempBasalRate = rate
        tempBasalDuration = programmedDuration
        tempBasalElaspedDuration = elapsedDuration
    }

    func pumpHistoryEventManagerDidDetectTempBasalEnded(_ pumpHistoryEventManager: PumpHistoryEventManager, duration: TimeInterval, endReason: TempBasalEndReason) {
        tempBasalEnded = true
        tempBasalDuration = duration
    }

    func pumpHistoryEventManagerDidDetectInsulinDeliverySuspended(_ pumpHistoryEventManager: PumpHistoryEventManager, suspendedAt: Date) {
        self.suspendedAt = suspendedAt
    }

    func pumpHistoryEventManagerDidDetectAnnunciation(_ pumpHistoryEventManager: PumpHistoryEventManager, annunciation: Annunciation, at date: Date?) {
        self.annunciation = annunciation as? GeneralAnnunciation
        annunciationDate = date
    }
}

extension PumpHistoryEventManagerTests {
    func createReferenceTimeHistoryEvent(forUTCDate utcDate: Date, using timeZone: TimeZone = TimeZone.current, recordingReason: RecordingReason = .setDateTime) -> ReferenceTimeHistoryEvent {
        let recordingReason = recordingReason
        let timeZoneOffset = timeZone.gattTimeZoneOffset
        let dstOffset = timeZone.dstOffset

        var eventData = Data(recordingReason.rawValue)
        eventData.append(utcDate.gattDateTime(using: .utc))
        eventData.append(timeZoneOffset)
        eventData.append(dstOffset.rawValue)

        return ReferenceTimeHistoryEvent(recordNumber: nextHistoryEventRecordNumber, relativeOffset: relativeOffset, eventData: eventData)
    }

    func createBolusDeliveredPart1HistoryEvent(withBolusID bolusID: BolusID, amount: Double = 1.5) -> BolusDeliveredPart1HistoryEvent {
        let bolusType: BolusType = .fast
        let extendedAmount: Double = 0
        let duration: UInt16 = 0 // fast boluses are considered to have 0 duration

        var eventData = Data(bolusID)
        eventData.append(bolusType.rawValue)
        eventData.append(amount.sfloat)
        eventData.append(extendedAmount.sfloat)
        eventData.append(duration)

        return BolusDeliveredPart1HistoryEvent(recordNumber: nextHistoryEventRecordNumber, relativeOffset: relativeOffset, eventData: eventData)
    }

    func createBolusDeliveredPart2HistoryEvent() -> BolusDeliveredPart2HistoryEvent {
        let flags: BolusDeliveredFlag = [.endReasonPresent]
        let startTimeOffset: UInt32 = 1000
        let endReason: BolusEndReason = .canceled

        var eventData = Data(flags.rawValue)
        eventData.append(startTimeOffset)
        eventData.append(endReason.rawValue)

        return BolusDeliveredPart2HistoryEvent(recordNumber: nextHistoryEventRecordNumber, relativeOffset: relativeOffset, eventData: eventData)
    }

    func createBolusProgrammedPart1HistoryEvent(withBolusID bolusID: BolusID, amount: Double = 2.5) -> BolusProgrammedPart1HistoryEvent {
        let bolusType: BolusType = .fast
        let extendedAmount: Double = 0
        let duration: UInt16 = 0 // fast boluses are considered to have 0 duration

        var eventData = Data(bolusID)
        eventData.append(bolusType.rawValue)
        eventData.append(amount.sfloat)
        eventData.append(extendedAmount.sfloat)
        eventData.append(duration)

        return BolusProgrammedPart1HistoryEvent(recordNumber: nextHistoryEventRecordNumber, relativeOffset: relativeOffset, eventData: eventData)
    }

    func createBolusProgrammedPart2HistoryEvent() -> BolusProgrammedPart2HistoryEvent {
        let flags: BolusFlag = [.deliveryReasonCorrection]
        let delayTime: UInt16 = 0

        var eventData = Data(flags.rawValue)
        eventData.append(delayTime)

        return BolusProgrammedPart2HistoryEvent(recordNumber: nextHistoryEventRecordNumber, relativeOffset: relativeOffset, eventData: eventData)
    }

    func createTempBasalAdjustmentStartedHistoryEvent(duration: TimeInterval) -> TempBasalAdjustmentStartedHistoryEvent {
        let flags: TempBasalFlag = .allZeros
        let tempBasalType = TempBasalType.absolute
        let rate = 2.0

        var eventData = Data(flags.rawValue)
        eventData.append(tempBasalType.rawValue)
        eventData.append(rate.sfloat)
        eventData.append(UInt16(duration.minutes))

        return TempBasalAdjustmentStartedHistoryEvent(recordNumber: nextHistoryEventRecordNumber, relativeOffset: relativeOffset, eventData: eventData)
    }

    func createTempBasalAdjustmentChangedHistoryEvent(duration: TimeInterval, elaspedDuration: TimeInterval) -> TempBasalAdjustmentChangedHistoryEvent {
        let flags: TempBasalFlag = [.changeTempBasal]
        let tempBasalType = TempBasalType.absolute
        let rate = 2.0

        var eventData = Data(flags.rawValue)
        eventData.append(tempBasalType.rawValue)
        eventData.append(rate.sfloat)
        eventData.append(UInt16(duration.minutes))
        eventData.append(UInt16(elaspedDuration.minutes))

        return TempBasalAdjustmentChangedHistoryEvent(recordNumber: nextHistoryEventRecordNumber, relativeOffset: relativeOffset, eventData: eventData)
    }

    func createTempBasalAdjustmentEndedHistoryEvent(duration: TimeInterval) -> TempBasalAdjustmentEndedHistoryEvent {
        let flags = TempBasalEndedFlag.allZeros
        let lastSetType = TempBasalType.absolute
        let durationInMinutes: UInt16 = UInt16(duration.minutes)
        let endReason = TempBasalEndReason.programmedDurationOver

        var eventData = Data(flags.rawValue)
        eventData.append(lastSetType.rawValue)
        eventData.append(durationInMinutes)
        eventData.append(endReason.rawValue)

        return TempBasalAdjustmentEndedHistoryEvent(recordNumber: nextHistoryEventRecordNumber, relativeOffset: relativeOffset, eventData: eventData)
    }

    func createTherapyControlStateChangedHistoryEvent(oldState: InsulinTherapyControlState, newState: InsulinTherapyControlState) -> TherapyControlStateChangedHistoryEvent {
        var eventData = Data(oldState.rawValue)
        eventData.append(newState.rawValue)

        return TherapyControlStateChangedHistoryEvent(recordNumber: nextHistoryEventRecordNumber, relativeOffset: relativeOffset, eventData: eventData)
    }

    func createAnnunciationStatusChanged1HistoryEvent(annunciation: Annunciation, status: AnnunciationStatus) -> AnnunciationStatusChangedPart1HistoryEvent {
        var eventData = Data(AnnunciationStatusChangedPart1Flag.allZeros.rawValue)
        eventData.append(annunciation.identifier)
        eventData.append(annunciation.type.rawValue)
        eventData.append(status.rawValue)

        return AnnunciationStatusChangedPart1HistoryEvent(recordNumber: nextHistoryEventRecordNumber, relativeOffset: relativeOffset, eventData: eventData)
    }

    func createAnnunciationStatusChanged2HistoryEvent() -> AnnunciationStatusChangedPart2HistoryEvent {
        let eventData = Data(AnnunciationStatusChangedPart2Flag.allZeros.rawValue)

        return AnnunciationStatusChangedPart2HistoryEvent(recordNumber: nextHistoryEventRecordNumber, relativeOffset: relativeOffset, eventData: eventData)
    }

}
