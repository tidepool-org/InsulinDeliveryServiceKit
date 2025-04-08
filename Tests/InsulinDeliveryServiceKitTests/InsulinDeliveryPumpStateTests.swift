//
//  InsulinDeliveryPumpStateTests.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-19.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
import CoreBluetooth
import BluetoothCommonKit
@testable import InsulinDeliveryServiceKit

class InsulinDeliveryPumpStateTests: XCTestCase {

    private var securityManagerConfiguration: SecurityManager.Configuration!
    private var uuidToHandleMap: [CBUUID: UInt16]!
    private var deviceInformation: DeviceInformation!
    
    override func setUp() {
        deviceInformation = DeviceInformation(identifier: UUID(uuidString: "1B0AB8B8-A209-96A5-106A-9994CCB99A04") ?? UUID(),
                                              serialNumber: "abc123",
                                              firmwareRevision: nil,
                                              hardwareRevision: nil,
                                              batteryLevel: nil,
                                              reportedRemainingLifetime: .days(10))
        uuidToHandleMap = [ACCharacteristicUUID.service.cbUUID: 24576,
                           ACCharacteristicUUID.status.cbUUID: 24577,
                           ACCharacteristicUUID.dataIn.cbUUID: 24578,
                           ACCharacteristicUUID.dataOutNotify.cbUUID: 24579]
        securityManagerConfiguration = SecurityManager.Configuration()
    }
    
    func testInitialization() {
        var state = IDPumpState()
        XCTAssertNil(state.deviceInformation)
        XCTAssertEqual(state.uuidToHandleMap, [:])
        
        state = IDPumpState(deviceInformation: deviceInformation,
                            uuidToHandleMap: uuidToHandleMap)
        XCTAssertEqual(state.deviceInformation, deviceInformation)
        XCTAssertEqual(state.uuidToHandleMap, uuidToHandleMap)
        XCTAssertEqual(state.activeBolusDeliveryStatus, .noActiveBolus)
        XCTAssertEqual(state.setupCompleted, false)
        XCTAssertNil(state.lastCommsDate)
    }
    
    func testRawValue() {
        let state = IDPumpState(deviceInformation: deviceInformation,   
                                uuidToHandleMap: uuidToHandleMap,
                                setupCompleted: true,
                                lastCommsDate: Date.distantPast)
        let rawValue = state.rawValue
        XCTAssertEqual(try! PropertyListDecoder().decode(DeviceInformation.self, from: (rawValue["deviceInformation"] as! Data)), deviceInformation)
        XCTAssertEqual(try! PropertyListDecoder().decode([String: UInt16].self, from: (rawValue["uuidStringToHandleMap"] as! Data)).toCBUUIDKeys(), uuidToHandleMap)
        XCTAssertEqual(rawValue["idCommandNextE2ECounter"] as! UInt8, IDCommandControlPointDataHandler.e2eCounterInitalValue)
        XCTAssertEqual(rawValue["idStatusReaderNextE2ECounter"] as! UInt8, IDStatusReaderControlPointDataHandler.e2eCounterInitalValue)
        XCTAssertEqual(BolusDeliveryStatus(rawValue: rawValue["activeBolusDeliveryStatus"] as! BolusDeliveryStatus.RawValue), BolusDeliveryStatus.noActiveBolus)
        XCTAssertTrue(rawValue["setupCompleted"] as! Bool)
        XCTAssertEqual(rawValue["lastCommsDate"] as! Date, Date.distantPast)
    }
    
    func testRestoreFromRawValueValid() {
        let idcNextE2ECounter: UInt8 = 24
        let idsrNextE2ECounter: UInt8 = 123
        let racpNextE2ECounter: UInt8 = 222
        let securityManagerConfiguration = SecurityManager.Configuration()
        let activeBolusDeliveryStatus = BolusDeliveryStatus(id: 2, progressState: .estimatingProgress, type: .fast, insulinProgrammed: 2, insulinDelivered: 0.5)
        let activeTempBasalDeliveryStatus = TempBasalDeliveryStatus(progressState: .inProgress, duration: .minutes(30), rate: 2.4, startTime: Date().addingTimeInterval(-1*TimeInterval.minutes(10)), insulinDelivered: 0)
        let totalBasalDelivered = 55.3
        let lastTempBasalRate = 3.2
        let initialReservoirLevel: Int = 140
        let pumpHistoryEventManagerConfiguration = PumpHistoryEventManager.Configuration(lastReceivedHistoryEventRecordNumber: 1234, referenceDate: Date(), cachedPumpHistoryEvents: [.bolusProgrammedPart1: BolusProgrammedPart1HistoryEvent(recordNumber: 1234, relativeOffset: .minutes(1), eventData: Data(UInt16(1)))])
        let features: IDFeatureFlag = [.supportedE2EProtection]
        var rawValue: [String: Any] = ["deviceInformation": try! PropertyListEncoder().encode(deviceInformation!),
                                       "features": features.rawValue,
                                       "uuidStringToHandleMap": try! PropertyListEncoder().encode(uuidToHandleMap.toCBUUIDStringKeys()),
                                       "idCommandNextE2ECounter": idcNextE2ECounter,
                                       "idStatusReaderNextE2ECounter": idsrNextE2ECounter,
                                       "recordAccessNextE2ECounter": racpNextE2ECounter,
                                       "securityManagerConfiguration": securityManagerConfiguration.rawValue,
                                       "activeBolusDeliveryStatus": activeBolusDeliveryStatus.rawValue,
                                       "activeTempBasalDeliveryStatus": activeTempBasalDeliveryStatus.rawValue,
                                       "totalBasalDelivered": totalBasalDelivered,
                                       "lastTempBasalRate": lastTempBasalRate,
                                       "initialReservoirLevel": initialReservoirLevel,
                                       "pumpHistoryEventManagerConfiguration": pumpHistoryEventManagerConfiguration.rawValue,
                                       "setupCompleted": false,
                                       "authorizationControlRequired": true,
                                       "lastCommsDate": Date.distantPast]
        var state = IDPumpState.init(rawValue: rawValue)!
        XCTAssertEqual(state.deviceInformation, deviceInformation)
        XCTAssertEqual(state.features, features)
        XCTAssertEqual(state.uuidToHandleMap, uuidToHandleMap)
        XCTAssertEqual(state.idCommandNextE2ECounter, idcNextE2ECounter)
        XCTAssertEqual(state.idStatusReaderNextE2ECounter, idsrNextE2ECounter)
        XCTAssertEqual(state.recordAccessNextE2ECounter, racpNextE2ECounter)
        XCTAssertEqual(state.securityManagerConfiguration, securityManagerConfiguration)
        XCTAssertEqual(state.activeBolusDeliveryStatus, activeBolusDeliveryStatus)
        XCTAssertEqual(state.activeTempBasalDeliveryStatus, activeTempBasalDeliveryStatus)
        XCTAssertEqual(state.totalBasalDelivered, totalBasalDelivered)
        XCTAssertEqual(state.lastTempBasalRate, lastTempBasalRate)
        XCTAssertEqual(state.initialReservoirLevel, initialReservoirLevel)
        XCTAssertEqual(state.pumpHistoryEventManagerConfiguration, pumpHistoryEventManagerConfiguration)
        XCTAssertFalse(state.setupCompleted)
        XCTAssertTrue(state.isAuthorizationControlRequired)
        XCTAssertEqual(state.lastCommsDate, Date.distantPast)

        rawValue = ["uuidStringToHandleMap": try! PropertyListEncoder().encode(uuidToHandleMap.toCBUUIDStringKeys()),
                    "features": features.rawValue,
                    "idCommandNextE2ECounter": idcNextE2ECounter,
                    "idStatusReaderNextE2ECounter": idsrNextE2ECounter,
                    "recordAccessNextE2ECounter": racpNextE2ECounter,
                    "securityManagerConfiguration": securityManagerConfiguration.rawValue,
                    "activeBolusDeliveryStatus": activeBolusDeliveryStatus.rawValue,
                    "activeTempBasalDeliveryStatus": activeTempBasalDeliveryStatus.rawValue,
                    "totalBasalDelivered": totalBasalDelivered,
                    "lastTempBasalRate": lastTempBasalRate,
                    "initialReservoirLevel": initialReservoirLevel,
                    "setupCompleted": true,
                    "authorizationControlRequired": false]
        state = IDPumpState.init(rawValue: rawValue)!
        XCTAssertNil(state.deviceInformation)
        XCTAssertEqual(state.features, features)
        XCTAssertEqual(state.uuidToHandleMap, uuidToHandleMap)
        XCTAssertEqual(state.idCommandNextE2ECounter, idcNextE2ECounter)
        XCTAssertEqual(state.idStatusReaderNextE2ECounter, idsrNextE2ECounter)
        XCTAssertEqual(state.recordAccessNextE2ECounter, racpNextE2ECounter)
        XCTAssertEqual(state.securityManagerConfiguration, securityManagerConfiguration)
        XCTAssertEqual(state.activeBolusDeliveryStatus, activeBolusDeliveryStatus)
        XCTAssertEqual(state.activeTempBasalDeliveryStatus, activeTempBasalDeliveryStatus)
        XCTAssertEqual(state.totalBasalDelivered, totalBasalDelivered)
        XCTAssertEqual(state.lastTempBasalRate, lastTempBasalRate)
        XCTAssertEqual(state.initialReservoirLevel, initialReservoirLevel)
        XCTAssertEqual(state.pumpHistoryEventManagerConfiguration, PumpHistoryEventManager.Configuration())
        XCTAssertTrue(state.setupCompleted)
        XCTAssertFalse(state.isAuthorizationControlRequired)
        XCTAssertNil(state.lastCommsDate)
    }
    
    func testRestoreFromRawValueInvalid() {
        let rawValue = ["UUIDToHandleMap": uuidToHandleMap!]
        let state = IDPumpState.init(rawValue: rawValue)
        XCTAssertNil(state)
    }
}
