//
//  IDHistoryDataHandlerTests.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-07-23.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
import BluetoothCommonKit
@testable import InsulinDeliveryServiceKit

class IDHistoryDataHandlerTests: XCTestCase {

    private var testE2EProtection = TestE2EProtection()
    private let recordNumber: UInt32 = 1
    private let relativeOffset: UInt16 = 100

    func testHandleResponseReferenceTime() {
        let timeZone = TimeZone.currentFixed
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let eventType = IDHistoryEventType.referenceTime
        let recordingReason = RecordingReason.setDateTime
        let dateComponents = DateComponents(year: 2021,
                                            month: 2,
                                            day: 3,
                                            hour: 4,
                                            minute: 5,
                                            second: 6)
        let date = calendar.date(from: dateComponents)!
        let timeZoneOffset: Int8 = timeZone.gattTimeZoneOffset
        let dstOffset: UInt8 = 255 // not known

        var auxData = Data(recordingReason.rawValue)
        auxData.append(date.gattDateTime())
        auxData.append(timeZoneOffset)
        auxData.append(dstOffset)

        let response = createPumpHistoryEvent(forType: eventType, withAuxData: auxData)

        let result = IDHistoryDataHandler.handleData(response, e2eProtectionSupported: false)
        guard let referenceTimeEvent = pumpHistoryEvent(ofType: eventType, fromResult: result) as? ReferenceTimeHistoryEvent else {
            XCTAssert(false)
            return
        }
        XCTAssertEqual(referenceTimeEvent.recordingReason, recordingReason)
        XCTAssertEqual(referenceTimeEvent.date(using: .utc), date)
    }

    func testHandleResponseBolusProgrammed() {
        // part 1
        var eventType = IDHistoryEventType.bolusProgrammedPart1
        let bolusID: BolusID = 2
        let bolusType: BolusType = .fast
        let fastAmount: Double = 2.5
        let extendedAmount: Double = 0
        let duration: UInt16 = 0

        var auxData = Data(bolusID)
        auxData.append(bolusType.rawValue)
        auxData.append(fastAmount.sfloat)
        auxData.append(extendedAmount.sfloat)
        auxData.append(duration)

        var response = createPumpHistoryEvent(forType: eventType, withAuxData: auxData)

        var result = IDHistoryDataHandler.handleData(response, e2eProtectionSupported: false)
        guard let bolusProgrammedPart1 = pumpHistoryEvent(ofType: eventType, fromResult: result) as? BolusProgrammedPart1HistoryEvent else {
            XCTAssert(false)
            return
        }
        XCTAssertEqual(bolusProgrammedPart1.bolusID, bolusID)
        XCTAssertEqual(bolusProgrammedPart1.bolusType, bolusType)
        XCTAssertEqual(bolusProgrammedPart1.fastAmount, fastAmount)
        XCTAssertEqual(bolusProgrammedPart1.extendedAmount, extendedAmount)
        XCTAssertEqual(bolusProgrammedPart1.duration, TimeInterval.seconds(Int(duration)))

        // part 2
        eventType = IDHistoryEventType.bolusProgrammedPart2
        let flags: BolusFlag = [.deliveryReasonCorrection]
        let delayTime: UInt16 = 0

        auxData = Data(flags.rawValue)
        auxData.append(delayTime)

        response = createPumpHistoryEvent(forType: eventType, withAuxData: auxData)

        result = IDHistoryDataHandler.handleData(response, e2eProtectionSupported: false)
        guard let bolusProgrammedPart2 = pumpHistoryEvent(ofType: eventType, fromResult: result) as? BolusProgrammedPart2HistoryEvent else {
            XCTAssert(false)
            return
        }
        XCTAssertEqual(bolusProgrammedPart2.flags, flags)
        XCTAssertEqual(bolusProgrammedPart2.delayTime, TimeInterval.minutes(Int(delayTime)))

        // joined parts
        guard let bolusProgrammed = BolusProgrammedHistoryEvent(part1: bolusProgrammedPart1, part2: bolusProgrammedPart2) else {
            XCTAssert(false)
            return
        }

        XCTAssertEqual(bolusProgrammed.recordNumbers, [bolusProgrammedPart1.recordNumber, bolusProgrammedPart2.recordNumber])
        XCTAssertEqual(bolusProgrammed.relativeOffset, bolusProgrammedPart1.relativeOffset)
        XCTAssertEqual(bolusProgrammed.bolusID, bolusID)
        XCTAssertEqual(bolusProgrammed.bolusType, bolusType)
        XCTAssertEqual(bolusProgrammed.fastAmount, fastAmount)
        XCTAssertEqual(bolusProgrammed.extendedAmount, extendedAmount)
        XCTAssertEqual(bolusProgrammed.duration, TimeInterval.seconds(Int(duration)))
        XCTAssertEqual(bolusProgrammed.flags, flags)
        XCTAssertEqual(bolusProgrammed.delayTime, TimeInterval.minutes(Int(delayTime)))
    }

    func testHandleResponseBolusDelivered() {
        // part 1
        var eventType = IDHistoryEventType.bolusDeliveredPart1
        let bolusID: BolusID = 2
        let bolusType: BolusType = .fast
        let fastAmount: Double = 2.5
        let extendedAmount: Double = 0
        let duration: UInt16 = 0

        var auxData = Data(bolusID)
        auxData.append(bolusType.rawValue)
        auxData.append(fastAmount.sfloat)
        auxData.append(extendedAmount.sfloat)
        auxData.append(duration)

        var response = createPumpHistoryEvent(forType: eventType, withAuxData: auxData)

        var result = IDHistoryDataHandler.handleData(response, e2eProtectionSupported: false)
        guard let bolusDeliveredPart1 = pumpHistoryEvent(ofType: eventType, fromResult: result) as? BolusDeliveredPart1HistoryEvent else {
            XCTAssert(false)
            return
        }
        XCTAssertEqual(bolusDeliveredPart1.bolusID, bolusID)
        XCTAssertEqual(bolusDeliveredPart1.bolusType, bolusType)
        XCTAssertEqual(bolusDeliveredPart1.fastAmount, fastAmount)
        XCTAssertEqual(bolusDeliveredPart1.extendedAmount, extendedAmount)
        XCTAssertEqual(bolusDeliveredPart1.duration, TimeInterval.seconds(Int(duration)))

        // part 2
        eventType = IDHistoryEventType.bolusDeliveredPart2
        let flags: BolusDeliveredFlag = [.endReasonPresent]
        let startTimeOffset: UInt32 = 1000
        let endReason: BolusEndReason = .canceled

        auxData = Data(flags.rawValue)
        auxData.append(startTimeOffset)
        auxData.append(endReason.rawValue)

        response = createPumpHistoryEvent(forType: eventType, withAuxData: auxData)

        result = IDHistoryDataHandler.handleData(response, e2eProtectionSupported: false)
        guard let bolusDeliveredPart2 = pumpHistoryEvent(ofType: eventType, fromResult: result) as? BolusDeliveredPart2HistoryEvent else {
            XCTAssert(false)
            return
        }
        XCTAssertEqual(bolusDeliveredPart2.flags, flags)
        XCTAssertEqual(bolusDeliveredPart2.startTimeOffset, TimeInterval.seconds(Int(startTimeOffset)))
        XCTAssertEqual(bolusDeliveredPart2.endReason, endReason)

        // joined parts
        guard let bolusDelivered = BolusDeliveredHistoryEvent(part1: bolusDeliveredPart1, part2: bolusDeliveredPart2) else {
            XCTAssert(false)
            return
        }
        XCTAssertEqual(bolusDelivered.recordNumbers, [bolusDeliveredPart1.recordNumber, bolusDeliveredPart2.recordNumber])
        XCTAssertEqual(bolusDelivered.relativeOffset, bolusDeliveredPart1.relativeOffset)
        XCTAssertEqual(bolusDelivered.flags, flags)
        XCTAssertEqual(bolusDelivered.startTimeOffset, TimeInterval.seconds(Int(startTimeOffset)))
        XCTAssertEqual(bolusDelivered.endReason, endReason)
        XCTAssertEqual(bolusDelivered.bolusID, bolusID)
        XCTAssertEqual(bolusDelivered.bolusType, bolusType)
        XCTAssertEqual(bolusDelivered.fastAmount, fastAmount)
        XCTAssertEqual(bolusDelivered.extendedAmount, extendedAmount)
        XCTAssertEqual(bolusDelivered.duration, TimeInterval.seconds(Int(duration)))
    }

    func testHandleResponseTempBasalAdjustmentChanged() {
        let eventType = IDHistoryEventType.tempBasalRateAdjustmentChanged
        let flags: TempBasalFlag = []
        let tempBasalType = TempBasalType.absolute
        let rate: Double = 1.5
        let programmedDuration: UInt16 = 30
        let elapsedDuration: UInt16 = 5

        var auxData = Data(flags.rawValue)
        auxData.append(tempBasalType.rawValue)
        auxData.append(rate.sfloat)
        auxData.append(programmedDuration)
        auxData.append(elapsedDuration)

        let response = createPumpHistoryEvent(forType: eventType, withAuxData: auxData)

        let result = IDHistoryDataHandler.handleData(response, e2eProtectionSupported: false)
        guard let tempBasalAdjustmentChanged = pumpHistoryEvent(ofType: eventType, fromResult: result) as? TempBasalAdjustmentChangedHistoryEvent else {
            XCTAssert(false)
            return
        }
        XCTAssertEqual(tempBasalAdjustmentChanged.flags, flags)
        XCTAssertEqual(tempBasalAdjustmentChanged.tempBasalType, tempBasalType)
        XCTAssertEqual(tempBasalAdjustmentChanged.rate, rate)
        XCTAssertEqual(tempBasalAdjustmentChanged.programmedDuration, TimeInterval.minutes(Int(programmedDuration)))
        XCTAssertEqual(tempBasalAdjustmentChanged.elapsedDuration, TimeInterval.minutes(Int(elapsedDuration)))
    }

    func testHandleResponseTempBasalAdjustmentEnded() {
        let eventType = IDHistoryEventType.tempBasalRateAdjustmentEnded
        let flags: TempBasalEndedFlag = []
        let lastSetType = TempBasalType.absolute
        let effectiveDuration: UInt16 = 30
        let endReason: TempBasalEndReason = .programmedDurationOver

        var auxData = Data(flags.rawValue)
        auxData.append(lastSetType.rawValue)
        auxData.append(effectiveDuration)
        auxData.append(endReason.rawValue)

        let response = createPumpHistoryEvent(forType: eventType, withAuxData: auxData)

        let result = IDHistoryDataHandler.handleData(response, e2eProtectionSupported: false)
        guard let tempBasalAdjustmentEnded = pumpHistoryEvent(ofType: eventType, fromResult: result) as? TempBasalAdjustmentEndedHistoryEvent else {
            XCTAssert(false)
            return
        }
        XCTAssertEqual(tempBasalAdjustmentEnded.flags, flags)
        XCTAssertEqual(tempBasalAdjustmentEnded.lastSetType, lastSetType)
        XCTAssertEqual(tempBasalAdjustmentEnded.effectiveDuration, TimeInterval.minutes(Int(effectiveDuration)))
        XCTAssertEqual(tempBasalAdjustmentEnded.endReason, endReason)
    }

    func testHandleResponseTempBasalAdjustmentStarted() {
        let eventType = IDHistoryEventType.tempBasalRateAdjustmentStarted
        let flags: TempBasalFlag = []
        let tempBasalType = TempBasalType.absolute
        let rate: Double = 1.5
        let programmedDuration: UInt16 = 30

        var auxData = Data(flags.rawValue)
        auxData.append(tempBasalType.rawValue)
        auxData.append(rate.sfloat)
        auxData.append(programmedDuration)

        let response = createPumpHistoryEvent(forType: eventType, withAuxData: auxData)

        let result = IDHistoryDataHandler.handleData(response, e2eProtectionSupported: false)
        guard let tempBasalAdjustmentStarted = pumpHistoryEvent(ofType: eventType, fromResult: result) as? TempBasalAdjustmentStartedHistoryEvent else {
            XCTAssert(false)
            return
        }
        XCTAssertEqual(tempBasalAdjustmentStarted.flags, flags)
        XCTAssertEqual(tempBasalAdjustmentStarted.tempBasalType, tempBasalType)
        XCTAssertEqual(tempBasalAdjustmentStarted.rate, rate)
        XCTAssertEqual(tempBasalAdjustmentStarted.programmedDuration, TimeInterval.minutes(Int(programmedDuration)))
    }

    func testHandleResponseTotalDailyInsulinDelivery() {
        let eventType = IDHistoryEventType.totalDailyInsulinDelivery
        let flags: TotalDailyInsulinDeliveryFlag = [.dateTimeChangedWarning]
        let totalBolusDelivered = 42.5
        let totalBasalDelivered = 20.5
        let year: UInt16 = 2021
        let month: UInt8 = 2
        let day: UInt8 = 4
        let date = Calendar.current.date(from: DateComponents(year: Int(year), month: Int(month), day: Int(day)))

        var auxData = Data(flags.rawValue)
        auxData.append(totalBolusDelivered.sfloat)
        auxData.append(totalBasalDelivered.sfloat)
        auxData.append(year)
        auxData.append(month)
        auxData.append(day)

        let response = createPumpHistoryEvent(forType: eventType, withAuxData: auxData)

        let result = IDHistoryDataHandler.handleData(response, e2eProtectionSupported: false)
        guard let totalDailyInsulinDelivery = pumpHistoryEvent(ofType: eventType, fromResult: result) as? TotalDailyInsulinDeliveryHistoryEvent else {
            XCTAssert(false)
            return
        }
        XCTAssertEqual(totalDailyInsulinDelivery.flags, flags)
        XCTAssertEqual(totalDailyInsulinDelivery.totalBolusDelivered, totalBolusDelivered)
        XCTAssertEqual(totalDailyInsulinDelivery.totalBasalDelivered, totalBasalDelivered)
        XCTAssertEqual(totalDailyInsulinDelivery.forDate, date)
    }

    func testHandleResponseTherapyControlStateChanged() {
        let eventType = IDHistoryEventType.therapyControlStateChanged
        let oldState: InsulinTherapyControlState = .stop
        let newState: InsulinTherapyControlState = .run

        var auxData = Data(oldState.rawValue)
        auxData.append(newState.rawValue)

        let response = createPumpHistoryEvent(forType: eventType, withAuxData: auxData)

        let result = IDHistoryDataHandler.handleData(response, e2eProtectionSupported: false)
        guard let therapyControlStateChanged = pumpHistoryEvent(ofType: eventType, fromResult: result) as? TherapyControlStateChangedHistoryEvent else {
            XCTAssert(false)
            return
        }
        XCTAssertEqual(therapyControlStateChanged.oldState, oldState)
        XCTAssertEqual(therapyControlStateChanged.newState, newState)
    }

    func testHandleResponseOperationalControlStateChanged() {
        let eventType = IDHistoryEventType.operationalStateChanged
        let oldState: PumpOperationalState = .waiting
        let newState: PumpOperationalState = .priming

        var auxData = Data(oldState.rawValue)
        auxData.append(newState.rawValue)

        let response = createPumpHistoryEvent(forType: eventType, withAuxData: auxData)

        let result = IDHistoryDataHandler.handleData(response, e2eProtectionSupported: false)
        guard let operationalStateChanged = pumpHistoryEvent(ofType: eventType, fromResult: result) as? OperationalStateChangedHistoryEvent else {
            XCTAssert(false)
            return
        }
        XCTAssertEqual(operationalStateChanged.oldState, oldState)
        XCTAssertEqual(operationalStateChanged.newState, newState)
    }

    func testHandleResponseReservoirRemainingAmountChanged() {
        let eventType = IDHistoryEventType.reservoirRemainingAmountChanged
        let remainingAmount = 87.6
        let auxData = Data(remainingAmount.sfloat)

        let response = createPumpHistoryEvent(forType: eventType, withAuxData: auxData)

        let result = IDHistoryDataHandler.handleData(response, e2eProtectionSupported: false)
        guard let reservoirRemainingAmountChanged = pumpHistoryEvent(ofType: eventType, fromResult: result) as? ReservoirRemainingAmountChangedHistoryEvent else {
            XCTAssert(false)
            return
        }
        XCTAssertEqual(reservoirRemainingAmountChanged.remainingAmount, remainingAmount)
    }

    func testHandleResponseAnnunciationStatusChanged() {
        // part 1
        var eventType = IDHistoryEventType.annunciationStatusChangedPart1
        let flagPart1: AnnunciationStatusChangedPart1Flag = [.auxInfo1Present, .auxInfo2Present]
        let annunciationIdentifier: AnnunciationIdentifier = 16
        let annunciationType: AnnunciationType = .batteryEmpty
        let annunciationStatus: AnnunciationStatus = .confirmed
        let auxInfo1 = Data([0x00, 0x01])
        let auxInfo2 = Data([0x02, 0x03])

        var auxData = Data(flagPart1.rawValue)
        auxData.append(annunciationIdentifier)
        auxData.append(annunciationType.rawValue)
        auxData.append(annunciationStatus.rawValue)
        auxData.append(auxInfo1)
        auxData.append(auxInfo2)

        var response = createPumpHistoryEvent(forType: eventType, withAuxData: auxData)

        var result = IDHistoryDataHandler.handleData(response, e2eProtectionSupported: false)
        guard let annunciationStatusChangedPart1 = pumpHistoryEvent(ofType: eventType, fromResult: result) as? AnnunciationStatusChangedPart1HistoryEvent else {
            XCTAssert(false)
            return
        }
        XCTAssertEqual(annunciationStatusChangedPart1.flag, flagPart1)
        XCTAssertEqual(annunciationStatusChangedPart1.annunciationIdentifier, annunciationIdentifier)
        XCTAssertEqual(annunciationStatusChangedPart1.annunciationType, annunciationType)
        XCTAssertEqual(annunciationStatusChangedPart1.annunciationStatus, annunciationStatus)
        XCTAssertEqual(annunciationStatusChangedPart1.auxInfo1, auxInfo1)
        XCTAssertEqual(annunciationStatusChangedPart1.auxInfo2, auxInfo2)

        // part 2
        eventType = IDHistoryEventType.annunciationStatusChangedPart2
        let flagPart2: AnnunciationStatusChangedPart2Flag = [.auxInfo3Present, .auxInfo4Present, .auxInfo5Present]
        let auxInfo3 = Data([0x04, 0x05])
        let auxInfo4 = Data([0x06, 0x07])
        let auxInfo5 = Data([0x08, 0x09])

        auxData = Data(flagPart2.rawValue)
        auxData.append(auxInfo3)
        auxData.append(auxInfo4)
        auxData.append(auxInfo5)

        response = createPumpHistoryEvent(forType: eventType, withAuxData: auxData)

        result = IDHistoryDataHandler.handleData(response, e2eProtectionSupported: false)
        guard let annunciationStatusChangedPart2 = pumpHistoryEvent(ofType: eventType, fromResult: result) as? AnnunciationStatusChangedPart2HistoryEvent else {
            XCTAssert(false)
            return
        }
        XCTAssertEqual(annunciationStatusChangedPart2.flag, flagPart2)
        XCTAssertEqual(annunciationStatusChangedPart2.auxInfo3, auxInfo3)
        XCTAssertEqual(annunciationStatusChangedPart2.auxInfo4, auxInfo4)
        XCTAssertEqual(annunciationStatusChangedPart2.auxInfo5, auxInfo5)

        // joined parts
        guard let annunciationStatusChanged = AnnunciationStatusChangedHistoryEvent(part1: annunciationStatusChangedPart1, part2: annunciationStatusChangedPart2) else {
            XCTAssert(false)
            return
        }
        XCTAssertEqual(annunciationStatusChanged.recordNumbers, [annunciationStatusChangedPart1.recordNumber, annunciationStatusChangedPart2.recordNumber])
        XCTAssertEqual(annunciationStatusChanged.relativeOffset, annunciationStatusChangedPart1.relativeOffset)
        XCTAssertEqual(annunciationStatusChanged.flag, AnnunciationStatusFlag([.presentAnnunciation, .presentAuxInfo1, .presentAuxInfo2, .presentAuxInfo3, .presentAuxInfo4, .presentAuxInfo5]))
        XCTAssertEqual(annunciationStatusChanged.annunciationIdentifier, annunciationIdentifier)
        XCTAssertEqual(annunciationStatusChanged.annunciationType, annunciationType)
        XCTAssertEqual(annunciationStatusChanged.annunciationStatus, annunciationStatus)
        XCTAssertEqual(annunciationStatusChanged.auxInfo1, auxInfo1)
        XCTAssertEqual(annunciationStatusChanged.auxInfo2, auxInfo2)
        XCTAssertEqual(annunciationStatusChanged.auxInfo3, auxInfo3)
        XCTAssertEqual(annunciationStatusChanged.auxInfo4, auxInfo4)
        XCTAssertEqual(annunciationStatusChanged.auxInfo5, auxInfo5)
    }

    func testHandleResponseDataCorruption() {
        let eventType = IDHistoryEventType.dataCorruption
        let response = createPumpHistoryEvent(forType: eventType)

        let result = IDHistoryDataHandler.handleData(response, e2eProtectionSupported: false)
        guard pumpHistoryEvent(ofType: eventType, fromResult: result) as? DataCorruptionHistoryEvent != nil else {
            XCTAssert(false)
            return
        }
    }

    func testHandleResponseDeliveredBasalRateChanged() {
        let eventType = IDHistoryEventType.deliveredBasalRateChanged
        let flag: DeliveredBasalRateChangedFlag = .allZeros
        let oldRate = 1.5
        let newRate = 1.25
        var auxData = Data(flag.rawValue)
        auxData.append(oldRate.sfloat)
        auxData.append(newRate.sfloat)
        let response = createPumpHistoryEvent(forType: eventType, withAuxData: auxData)

        let result = IDHistoryDataHandler.handleData(response, e2eProtectionSupported: false)
        guard let deliveryedBasalRateChanged = pumpHistoryEvent(ofType: eventType, fromResult: result) as? DeliveredBasalRateChangedHistoryEvent else {
            XCTAssert(false)
            return
        }
        XCTAssertEqual(deliveryedBasalRateChanged.flag, flag)
        XCTAssertEqual(deliveryedBasalRateChanged.oldRate, oldRate)
        XCTAssertEqual(deliveryedBasalRateChanged.newRate, newRate)
    }

    func testHandleResponseProfileTemplateActivated() {
        let eventType = IDHistoryEventType.profileTemplateActivated
        let templateType: ProfileTemplateType = .basalRate
        let oldTemplateNumber: UInt8 = 1
        let newTemplateNumber: UInt8 = 2
        var auxData = Data(templateType.rawValue)
        auxData.append(oldTemplateNumber)
        auxData.append(newTemplateNumber)
        let response = createPumpHistoryEvent(forType: eventType, withAuxData: auxData)

        let result = IDHistoryDataHandler.handleData(response, e2eProtectionSupported: false)
        guard let profileTemplateActivated = pumpHistoryEvent(ofType: eventType, fromResult: result) as? ProfileTemplateActivatedHistoryEvent else {
            XCTAssert(false)
            return
        }
        XCTAssertEqual(profileTemplateActivated.templateType, templateType)
        XCTAssertEqual(profileTemplateActivated.oldTemplateNumber, Int(oldTemplateNumber))
        XCTAssertEqual(profileTemplateActivated.newTemplateNumber, Int(newTemplateNumber))
    }

    func testHandleResponseBasalRateProfileTimeBlockChanged() {
        let eventType = IDHistoryEventType.basalRateProfileTimeBlockChanged
        let templateNumber: UInt8 = 1
        let timeBlockNumber: UInt8 = 2
        let duration: UInt16 = 300
        let rate = 2.5
        var auxData = Data(templateNumber)
        auxData.append(timeBlockNumber)
        auxData.append(duration)
        auxData.append(rate.sfloat)
        let response = createPumpHistoryEvent(forType: eventType, withAuxData: auxData)

        let result = IDHistoryDataHandler.handleData(response, e2eProtectionSupported: false)
        guard let basalRateProfileTimeBlockChanged = pumpHistoryEvent(ofType: eventType, fromResult: result) as? BasalRateProfileTimeBlockChangedHistoryEvent else {
            XCTAssert(false)
            return
        }
        XCTAssertEqual(basalRateProfileTimeBlockChanged.templateNumber, Int(templateNumber))
        XCTAssertEqual(basalRateProfileTimeBlockChanged.timeBlockNumber, Int(timeBlockNumber))
        XCTAssertEqual(basalRateProfileTimeBlockChanged.duration, TimeInterval.minutes(Int(duration)))
        XCTAssertEqual(basalRateProfileTimeBlockChanged.rate, rate)
    }

    func testHandleResponsePrimingStarted() {
        let eventType = IDHistoryEventType.primingStarted
        let programmedAmount: Double = 0.8
        let auxData = Data(programmedAmount.sfloat)
        let response = createPumpHistoryEvent(forType: eventType, withAuxData: auxData)

        let result = IDHistoryDataHandler.handleData(response, e2eProtectionSupported: false)
        guard let primingStarted = pumpHistoryEvent(ofType: eventType, fromResult: result) as? PrimingStartedHistoryEvent else {
            XCTAssert(false)
            return
        }
        XCTAssertEqual(primingStarted.programmedAmount, programmedAmount)
    }

    func testHandleResponsePrimingDone() {
        let eventType = IDHistoryEventType.primingDone
        let flag: PrimingDoneFlag = .allZeros
        let deliveredAmount: Double = 0.8
        let terminationReason = PrimingTerminationReason.programmedAmountReached
        var auxData = Data(flag.rawValue)
        auxData.append(deliveredAmount.sfloat)
        auxData.append(terminationReason.rawValue)
        let response = createPumpHistoryEvent(forType: eventType, withAuxData: auxData)

        let result = IDHistoryDataHandler.handleData(response, e2eProtectionSupported: false)
        guard let primingDone = pumpHistoryEvent(ofType: eventType, fromResult: result) as? PrimingDoneHistoryEvent else {
            XCTAssert(false)
            return
        }
        XCTAssertEqual(primingDone.flag, flag)
        XCTAssertEqual(primingDone.deliveredAmount, deliveredAmount)
        XCTAssertEqual(primingDone.terminationReason, terminationReason)
    }

    func testHandleResponseGeneric() {
        let eventType = IDHistoryEventType.generic
        let response = createPumpHistoryEvent(forType: eventType)

        let result = IDHistoryDataHandler.handleData(response, e2eProtectionSupported: false)
        guard pumpHistoryEvent(ofType: eventType, fromResult: result) as? GenericHistoryEvent != nil else {
            XCTAssert(false)
            return
        }
    }
}

extension IDHistoryDataHandlerTests {
    func createPumpHistoryEvent(forType type: IDHistoryEventType, withAuxData auxData: Data? = nil) -> Data {
        var response = Data(type.rawValue)
        response.append(recordNumber)
        response.append(relativeOffset)
        if let auxData = auxData {
            response.append(auxData)
        }
        response = response.appendingCRC()

        return response
    }

    func pumpHistoryEvent(ofType type: IDHistoryEventType, fromResult result: DeviceCommResult<PumpHistoryEvent>) -> PumpHistoryEvent? {
        switch result {
        case .success(let pumpHistoryEvent):
            XCTAssertEqual(pumpHistoryEvent.type, type)
            XCTAssertEqual(pumpHistoryEvent.recordNumber, recordNumber)
            XCTAssertEqual(pumpHistoryEvent.relativeOffset, TimeInterval.seconds(Int(relativeOffset)))
            return pumpHistoryEvent
        case .failure(_):
            return nil
        }
    }
}
