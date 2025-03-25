//
//  InsulinDeliveryServiceTests.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-19.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import XCTest
import CoreBluetooth
import BluetoothCommonKit
@testable import InsulinDeliveryServiceKit

class InsulinDeliveryServiceTests: XCTestCase {
    
    private var pump: InsulinDeliveryService!
    private var securityManager: SecurityManager!
    private var bluetoothManager: BluetoothManager!
    private var bolusManager: BolusManager!
    private var basalManager: BasalManager!
    private var pumpHistoryEventManager: PumpHistoryEventManager!
    private var acControlPoint: ACControlPoint!
    private var acData: ACData!
    private var pumpState: IDPumpState!
    private var updatedState: IDPumpState!
    private var annunciationsIssued: [Annunciation] = []
    private var completionCalled = false
    private var didCompleteConfigurationCalled = false
    private var bolusDelivered = false
    private var bolusProgrammedAmount: Double!
    private var bolusDeliveredAmount: Double!
    private var bolusStartTime: Date!
    private var bolusDuration: TimeInterval!
    private var tempBasalStarted: Bool?
    private var tempBasalEnded: Bool?
    private var tempBasalStartTime: Date?
    private var tempBasalDuration: TimeInterval?
    private var tempBasalRate: Double?
    private var suspendedAt: Date?
    internal var isInReplacementWorkflow: Bool = false
    private var pumpDidSync: Bool?
    private var pumpSyncDate: Date?
    private var annunciation: GeneralAnnunciation?
    private var annunciationDate: Date?
    private var isConnected = true
    private var isAuthenticated = false
    private var activeTempBasalDeliveryStatus: TempBasalDeliveryStatus = .noActiveTempBasal
    private var totalBasalDelivered = 0.0
    internal var estimatedBolusDeliveryRate = 2.5 / TimeInterval.minutes(1)
    internal var sharedKeyData: Data?
    
    override func setUp() {
        completionCalled = false

        securityManager = SecurityManager()

        bluetoothManager = BluetoothManager(peripheralConfiguration: .insulinDeliveryServiceConfiguration, servicesToDiscover: [InsulinDeliveryCharacteristicUUID.service.cbUUID], restoreOptions: nil)
        bluetoothManager.peripheralManager = PeripheralManager()
        acControlPoint = ACControlPoint(securityManager: securityManager, maxRequestSize: 19)
        acData = ACData(securityManager: securityManager, maxRequestSize: 19)
        bolusManager = BolusManager()
        basalManager = BasalManager()
        pumpHistoryEventManager = PumpHistoryEventManager()
        pumpState = IDPumpState(deviceInformation: DeviceInformation(identifier: UUID(), serialNumber: "abc123", firmwareRevision: "1", batteryLevel: 100, reportedRemainingLifetime: .days(10)), uuidToHandleMap: [DeviceTimeCharacteristicUUID.controlPoint.cbUUID: 1, InsulinDeliveryCharacteristicUUID.commandControlPoint.cbUUID: 2, InsulinDeliveryCharacteristicUUID.statusReaderControlPoint.cbUUID: 3, InsulinDeliveryCharacteristicUUID.status.cbUUID: 4, InsulinDeliveryCharacteristicUUID.recordAccessControlPoint.cbUUID: 5, InsulinDeliveryCharacteristicUUID.statusChanged.cbUUID: 6, InsulinDeliveryCharacteristicUUID.annunciationStatus.cbUUID: 7,ACCharacteristicUUID.controlPoint.cbUUID: 8], authorizationControlRequired: true)
    }
    
    private func setUpGeneralPump(isAuthenticated: Bool = false) {
        self.isAuthenticated = isAuthenticated
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: basalManager,
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: pumpState,
                                      isConnectedHandler: { self.isConnected },
                                      isAuthenticatedHandler: { self.isAuthenticated })
    }
    
    func testOOBStringConvertion() {
        setUpGeneralPump()

        let oobString = "ABCDEFGHIJ"
        let oobData = oobString.data(using: .utf8)!
        
        pump.setOOBString(oobString)
        XCTAssertEqual(securityManager.configuration.oobRandomNumber, oobData)
    }
    
    func testInitializationWithState() {
        setUpGeneralPump()

        let deviceInformation = DeviceInformation(identifier: UUID(uuidString: "1B0AB8B8-A209-96A5-106A-9994CCB99A04") ?? UUID(),
                                                  serialNumber: "abc123",
                                                  firmwareRevision: nil,
                                                  hardwareRevision: nil,
                                                  batteryLevel: nil,
                                                  reportedRemainingLifetime: .days(10))
        let uuidToHandleMap: [CBUUID: UInt16] = [ACCharacteristicUUID.service.cbUUID: 24576,
                                                 ACCharacteristicUUID.status.cbUUID: 24577,
                                                 ACCharacteristicUUID.dataIn.cbUUID: 24578,
                                                 ACCharacteristicUUID.dataOutNotify.cbUUID: 24579]
        var securityManagerConfiguration = SecurityManager.Configuration()
        securityManagerConfiguration.macSize = 16
        securityManagerConfiguration.nonceSizeOctetsVariable = 16
        let pumpState = IDPumpState(deviceInformation: deviceInformation,
                                      uuidToHandleMap: uuidToHandleMap,
                                      setupCompleted: true)
        securityManager = SecurityManager()
        let bluetoothManager = BluetoothManager(peripheralConfiguration: .insulinDeliveryServiceConfiguration, servicesToDiscover: [InsulinDeliveryCharacteristicUUID.service.cbUUID], restoreOptions: nil)
        let acControlPoint = ACControlPoint(securityManager: securityManager, maxRequestSize: 19)
        let acData = ACData(securityManager: securityManager, maxRequestSize: 19)
        
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: pumpState)
        XCTAssertEqual(pump.state, pumpState)
    }
    
    func testStateDidUpdate() {
        setUpGeneralPump()

        let deviceInformation = DeviceInformation(identifier: UUID(uuidString: "1B0AB8B8-A209-96A5-106A-9994CCB99A04") ?? UUID(),
                                                  serialNumber: "abc123",
                                                  firmwareRevision: nil,
                                                  hardwareRevision: nil,
                                                  batteryLevel: nil,
                                                  reportedRemainingLifetime: .days(10))
        let uuidToHandleMap: [CBUUID: UInt16] = [ACCharacteristicUUID.service.cbUUID: 24576,
                                                 ACCharacteristicUUID.status.cbUUID: 24577,
                                                 ACCharacteristicUUID.dataIn.cbUUID: 24578,
                                                 ACCharacteristicUUID.dataOutNotify.cbUUID: 24579]
        var securityManagerConfiguration = SecurityManager.Configuration()
        securityManagerConfiguration.macSize = 16
        securityManagerConfiguration.nonceSizeOctetsVariable = 16
        let pumpState = IDPumpState(deviceInformation: deviceInformation,
                                    uuidToHandleMap: uuidToHandleMap,
                                    securityManagerConfiguration: securityManagerConfiguration)
        pump.delegate = self
        pump.state = pumpState
        XCTAssertEqual(updatedState, pumpState)
    }
    
    func testDeviceInformationDidUpdate() {
        setUpGeneralPump()

        let deviceInformation = DeviceInformation(identifier: UUID(uuidString: "1B0AB8B8-A209-96A5-106A-9994CCB99A04") ?? UUID(),
                                                  serialNumber: "abc123",
                                                  firmwareRevision: nil,
                                                  hardwareRevision: nil,
                                                  batteryLevel: nil,
                                                  reportedRemainingLifetime: .days(10))
        pump.delegate = self
        pump.state.deviceInformation = deviceInformation
        XCTAssertEqual(updatedState.deviceInformation, deviceInformation)
    }
    
    func testAnnunciationReceivedPending() {
        setUpGeneralPump()

        let annunciationID: UInt16 = 1
        let annunciation = GeneralAnnunciation(type: AnnunciationType.batteryLow, identifier: annunciationID)
        
        var annunciationData = Data(AnnunciationStatusFlag.presentAnnunciation.rawValue)
        annunciationData.append(annunciation.identifier)
        annunciationData.append(annunciation.type.rawValue)
        annunciationData.append(AnnunciationStatus.pending.rawValue)
        annunciationData.append(pump.idControlPoint.e2eCounter)
        annunciationData = annunciationData.appendingCRC()
        
        pump.delegate = self
        pump.manageInsulinDeliveryAnnunciationStatusData(annunciationData)
        XCTAssertEqual(annunciationsIssued.count, 1)
        XCTAssertEqual(annunciationsIssued.first?.type, annunciation.type)
        XCTAssertEqual(annunciationsIssued.first?.identifier, annunciationID)
    }

    func testAnnunciationReceivedReservoirLow() {
        setUpGeneralPump()
        pump.state.deviceInformation?.reservoirLevelWarningThresholdInUnits = 20

        let annunciationID: UInt16 = 1
        var annunciationData = Data(AnnunciationStatusFlag.presentAnnunciation.rawValue)
        annunciationData.append(annunciationID)
        annunciationData.append(AnnunciationType.reservoirLow.rawValue)
        annunciationData.append(AnnunciationStatus.pending.rawValue)
        annunciationData.append(pump.idControlPoint.e2eCounter)
        annunciationData = annunciationData.appendingCRC()
        
        pump.delegate = self
        pump.manageInsulinDeliveryAnnunciationStatusData(annunciationData)
        XCTAssertEqual(annunciationsIssued.count, 1)
        XCTAssertEqual(annunciationsIssued.first?.type, .reservoirLow)
        XCTAssertEqual(annunciationsIssued.first?.identifier, annunciationID)
        XCTAssertEqual(["20.0"], annunciationsIssued.first?.annunciationMessageCauseArgs.map { String(format: "%@", $0)})
    }
    
    func testAnnunciationReceivedEndOfLifetime() {
        setUpGeneralPump()
        pump.state.deviceInformation?.updateExpirationDate(remainingLifetime: .hours(23.1))

        let annunciationID: UInt16 = 1
        var annunciationData = Data(AnnunciationStatusFlag.presentAnnunciation.rawValue)
        annunciationData.append(annunciationID)
        annunciationData.append(AnnunciationType.endOfLifetime.rawValue)
        annunciationData.append(AnnunciationStatus.pending.rawValue)
        annunciationData.append(pump.idControlPoint.e2eCounter)
        annunciationData = annunciationData.appendingCRC()
        
        pump.delegate = self
        pump.manageInsulinDeliveryAnnunciationStatusData(annunciationData)
        XCTAssertEqual(annunciationsIssued.count, 1)
        XCTAssertEqual(annunciationsIssued.first?.type, .endOfLifetime)
        XCTAssertEqual(annunciationsIssued.first?.identifier, annunciationID)
        XCTAssertEqual(["in 23 hours"], annunciationsIssued.first?.annunciationMessageCauseArgs.map { String(format: "%@", $0)})
    }
    
    func testAnnunciationReceivedEndOfLifetimeDefault() {
        setUpGeneralPump()

        let annunciationID: UInt16 = 1
        var annunciationData = Data(AnnunciationStatusFlag.presentAnnunciation.rawValue)
        annunciationData.append(annunciationID)
        annunciationData.append(AnnunciationType.endOfLifetime.rawValue)
        annunciationData.append(AnnunciationStatus.pending.rawValue)
        annunciationData.append(pump.idControlPoint.e2eCounter)
        annunciationData = annunciationData.appendingCRC()
        
        pump.delegate = self
        pump.manageInsulinDeliveryAnnunciationStatusData(annunciationData)
        XCTAssertEqual(annunciationsIssued.count, 1)
        XCTAssertEqual(annunciationsIssued.first?.type, .endOfLifetime)
        XCTAssertEqual(annunciationsIssued.first?.identifier, annunciationID)
        XCTAssertEqual(["in 10 days"], annunciationsIssued.first?.annunciationMessageCauseArgs.map { String(format: "%@", $0)})
    }
    
    func testAnnunciationReceivedSnoozed() {
        setUpGeneralPump()

        let annunciationID: UInt16 = 1
        let annunciation = GeneralAnnunciation(type: AnnunciationType.batteryLow, identifier: annunciationID)
        
        var annunciationData = Data(AnnunciationStatusFlag.presentAnnunciation.rawValue)
        annunciationData.append(annunciation.identifier)
        annunciationData.append(annunciation.type.rawValue)
        annunciationData.append(AnnunciationStatus.snoozed.rawValue)
        annunciationData.append(pump.idControlPoint.e2eCounter)
        annunciationData = annunciationData.appendingCRC()
        
        pump.delegate = self
        pump.manageInsulinDeliveryAnnunciationStatusData(annunciationData)
        XCTAssertTrue(annunciationsIssued.isEmpty)
    }
    
    func testAnnunciationReceivedConfirmed() {
        setUpGeneralPump()

        let annunciationID: UInt16 = 1
        let annunciation = GeneralAnnunciation(type: AnnunciationType.batteryLow, identifier: annunciationID)
        
        var annunciationData = Data(AnnunciationStatusFlag.presentAnnunciation.rawValue)
        annunciationData.append(annunciation.identifier)
        annunciationData.append(annunciation.type.rawValue)
        annunciationData.append(AnnunciationStatus.confirmed.rawValue)
        annunciationData.append(pump.idControlPoint.e2eCounter)
        annunciationData = annunciationData.appendingCRC()
        
        pump.delegate = self
        pump.manageInsulinDeliveryAnnunciationStatusData(annunciationData)
        XCTAssertTrue(annunciationsIssued.isEmpty)
    }
    
    func testPrepareForDeactivation() {
        let testExpectation = XCTestExpectation(description: #function)
        setUpGeneralPump()
        pump.prepareForDeactivation() { result in
            switch result {
            case .success:
                testExpectation.fulfill()
            case .failure(_):
                XCTAssert(false)
            }
        }
        
        // get remaining lifetime response
        let remainingLifetime = TimeInterval.days(4)
        var response = Data(IDStatusReaderOpcode.getCounterResponse.rawValue)
        response.append(CounterType.lifetime.rawValue)
        response.append(CounterValueSelection.remaining.rawValue)
        response.append(Int32(remainingLifetime.minutes))
        response.append(pump.idStatusReader.e2eCounter)
        response = response.appendingCRC()
        pump.manageInsulinDeliveryStatusReaderResponse(response)
        
        // invalidate key response
        response = Data(ACControlPointOpcode.responseCode.rawValue)
        response.append(ACControlPointOpcode.invalidateKey.rawValue)
        response.append(ACControlPointResponseCode.success.rawValue)
        pump.manageACControlPointResponse(response: response, isSegmented: false)
        
        wait(for: [testExpectation], timeout: 1)
        XCTAssertNil(pump.state.deviceInformation)
        XCTAssertEqual(pump.state.uuidToHandleMap, [:])
        XCTAssertEqual(pump.idControlPoint.e2eCounter, 1)
    }
    
    func testPrepareForNewPump() {
        setUpGeneralPump()

        pump.state.deviceInformation = DeviceInformation(identifier: UUID(), serialNumber: "serialnumber", reportedRemainingLifetime: .days(10))
        pump.state.uuidToHandleMap = [CBUUID(string: "1234"): 1, CBUUID(string: "5678"): 2]
        pump.idControlPoint.e2eCounter = 100
        pump.idStatusReader.e2eCounter = 100
        pump.recordAccessControlPoint.e2eCounter = 100
        pump.idControlPoint.appendToRequestQueue(Data(IDControlPointOpcode.stopPriming.rawValue), completion: nil)
        pump.prepareForNewPump()
        XCTAssertNil(pump.state.deviceInformation)
        XCTAssertFalse(pump.state.setupCompleted)
        XCTAssertEqual(pump.state.uuidToHandleMap, [:])
        XCTAssertEqual(pump.idControlPoint.e2eCounter, 1)
        XCTAssertEqual(pump.idStatusReader.e2eCounter, 1)
        XCTAssertEqual(pump.recordAccessControlPoint.e2eCounter, 1)
        XCTAssertTrue(pump.idControlPoint.requestQueue.isEmpty)
        XCTAssertEqual(pump.state.activeTempBasalDeliveryStatus, .noActiveTempBasal)
        XCTAssertEqual(pump.state.activeBolusDeliveryStatus, .noActiveBolus)
        XCTAssertEqual(pump.state.totalBasalDelivered, 0)
    }
    
    func testResetCounters() {
        setUpGeneralPump()

        pump.idControlPoint.e2eCounter = 100
        pump.idStatusReader.e2eCounter = 100
        pump.recordAccessControlPoint.e2eCounter = 100
        pump.resetCounters()
        XCTAssertEqual(pump.idControlPoint.e2eCounter, 1)
        XCTAssertEqual(pump.idStatusReader.e2eCounter, 1)
        XCTAssertEqual(pump.recordAccessControlPoint.e2eCounter, 1)
    }

    func testPendingProcedureCompletionSetTherapyControlState() {
        var pumpDeliveryStatus: PumpDeliveryStatus?
        let setTherapyControlStateCompletions: PumpDeliveryStatusCompletion = { result in
            switch result {
            case .success(let deliveryStatus):
                pumpDeliveryStatus = deliveryStatus
                self.completionCalled = true
            case .failure(_):
                XCTAssert(false)
            }
        }
        
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: IDPumpState())
        pump.idControlPoint.appendToRequestQueue(Data(IDControlPointOpcode.setTherapyControlState.rawValue), completion: setTherapyControlStateCompletions)
        var response = Data(IDControlPointOpcode.responseCode.rawValue)
        response.append(IDControlPointOpcode.setTherapyControlState.rawValue)
        response.append(IDControlPointResponseCode.success.rawValue)
        response.append(pump.idControlPoint.e2eCounter)
        response = response.appendingCRC()

        pump.manageInsulinDeliveryControlPointResponse(response)
        XCTAssertEqual(pump.deviceInformation?.reservoirLevel, pumpDeliveryStatus?.reservoirLevel)
        XCTAssertEqual(pump.deviceInformation?.therapyControlState, pumpDeliveryStatus?.therapyControlState)
        XCTAssertEqual(pump.deviceInformation?.pumpOperationalState, pumpDeliveryStatus?.pumpOperationalState)
        XCTAssertTrue(completionCalled)
    }

    func testControlPointProcedureFailedProcedureResultCompletion() {
        let writeBasalRateTemplateCompletions: ProcedureResultCompletion = { result in
            switch result {
            case .success():
                XCTAssert(false)
            case .failure(_):
                self.completionCalled = true
            }
        }
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: IDPumpState())
        pump.idControlPoint.appendToRequestQueue(Data(IDControlPointOpcode.writeBasalRateTemplate.rawValue), completion: writeBasalRateTemplateCompletions)

        let flags: WriteBasalRateFlags = .endTransaction
        let basalRateProfileNumber: UInt8 = 1
        let firstTimeBlockNumberIndex: UInt8 = 1
        var response = Data(IDControlPointOpcode.writeBasalRateTemplateResponse.rawValue)
        response.append(flags.rawValue)
        response.append(basalRateProfileNumber)
        response.append(firstTimeBlockNumberIndex)
        response.append(pump.idControlPoint.e2eCounter)
        response.append(0x0000)

        pump.manageInsulinDeliveryControlPointResponse(response)
        XCTAssertTrue(completionCalled)
        _ = pump.idControlPoint.getPendingProceduresAndReset()
    }

    func testControlPointProcedureFailedBolusDeliveryStatusCompletion() {
        let writeBasalRateTemplateCompletions: BolusDeliveryStatusCompletion = { result in
            switch result {
            case .success(_):
                XCTAssert(false)
            case .failure(_):
                self.completionCalled = true
            }
        }
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: IDPumpState())
        pump.idControlPoint.appendToRequestQueue(Data(IDControlPointOpcode.writeBasalRateTemplate.rawValue), completion: writeBasalRateTemplateCompletions)

        let flags: WriteBasalRateFlags = .endTransaction
        let basalRateProfileNumber: UInt8 = 1
        let firstTimeBlockNumberIndex: UInt8 = 1
        var response = Data(IDControlPointOpcode.writeBasalRateTemplateResponse.rawValue)
        response.append(flags.rawValue)
        response.append(basalRateProfileNumber)
        response.append(firstTimeBlockNumberIndex)
        response.append(pump.idControlPoint.e2eCounter)
        response.append(0x0000)

        pump.manageInsulinDeliveryControlPointResponse(response)
        XCTAssertTrue(completionCalled)
        _ = pump.idControlPoint.getPendingProceduresAndReset()
    }

    func testControlPointProcedureFailedPumpDeliveryStatusCompletion() {
        let writeBasalRateTemplateCompletion: PumpDeliveryStatusCompletion = { result in
            switch result {
            case .success(_):
                XCTAssert(false)
            case .failure(_):
                self.completionCalled = true
            }
        }
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: IDPumpState())
        pump.idControlPoint.appendToRequestQueue(Data(IDControlPointOpcode.writeBasalRateTemplate.rawValue), completion: writeBasalRateTemplateCompletion)

        let flags: WriteBasalRateFlags = .endTransaction
        let basalRateProfileNumber: UInt8 = 1
        let firstTimeBlockNumberIndex: UInt8 = 1
        var response = Data(IDControlPointOpcode.writeBasalRateTemplateResponse.rawValue)
        response.append(flags.rawValue)
        response.append(basalRateProfileNumber)
        response.append(firstTimeBlockNumberIndex)
        response.append(pump.idControlPoint.e2eCounter)
        response.append(0x0000)

        pump.manageInsulinDeliveryControlPointResponse(response)
        XCTAssertTrue(completionCalled)
        _ = pump.idControlPoint.getPendingProceduresAndReset()
    }

    func testPendingProcedureCompletionWriteBasalRateTemplate() {
        let writeBasalRateTemplateCompletion: ProcedureResultCompletion = { result in
            switch result {
            case .success():
                self.completionCalled = true
            case .failure(_):
                XCTAssert(false)
            }
        }
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: IDPumpState())
        pump.idControlPoint.appendToRequestQueue(Data(IDControlPointOpcode.writeBasalRateTemplate.rawValue), completion: writeBasalRateTemplateCompletion)
        
        let flags: WriteBasalRateFlags = .endTransaction
        let basalRateProfileNumber: UInt8 = 1
        let firstTimeBlockNumberIndex: UInt8 = 1
        var response = Data(IDControlPointOpcode.writeBasalRateTemplateResponse.rawValue)
        response.append(flags.rawValue)
        response.append(basalRateProfileNumber)
        response.append(firstTimeBlockNumberIndex)
        response.append(pump.idControlPoint.e2eCounter)
        response = response.appendingCRC()

        pump.manageInsulinDeliveryControlPointResponse(response)
        XCTAssertTrue(completionCalled)
    }

    func testPendingProcedureCompletionStartPriming() {
        let startPrimingCompletion: ProcedureResultCompletion = { result in
            switch result {
            case .success():
                self.completionCalled = true
            case .failure(_):
                XCTAssert(false)
            }
        }
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: IDPumpState())
        pump.idControlPoint.appendToRequestQueue(Data(IDControlPointOpcode.startPriming.rawValue), completion: startPrimingCompletion)
        
        var response = Data(IDControlPointOpcode.responseCode.rawValue)
        response.append(IDControlPointOpcode.startPriming.rawValue)
        response.append(IDControlPointResponseCode.success.rawValue)
        response.append(pump.idControlPoint.e2eCounter)
        response = response.appendingCRC()

        pump.manageInsulinDeliveryControlPointResponse(response)
        XCTAssertTrue(completionCalled)
    }

    func testPendingProcedureCompletionSetBolus() {
        let setBolusCompletion: ProcedureResultCompletion = { result in
            switch result {
            case .success():
                self.completionCalled = true
            case .failure(_):
                XCTAssert(false)
            }
        }
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: IDPumpState())
        pump.idControlPoint.appendToRequestQueue(Data(IDControlPointOpcode.setBolus.rawValue), completion: setBolusCompletion)
        
        var response = Data(IDControlPointOpcode.setBolusResponse.rawValue)
        response.append(UInt16(0x0001))
        response.append(pump.idControlPoint.e2eCounter)
        response = response.appendingCRC()

        pump.manageInsulinDeliveryControlPointResponse(response)
        XCTAssertTrue(completionCalled)
    }

    func testPendingProcedureCompletionCancelBolus() {
        var expectedBolusDeliveryStatus: BolusDeliveryStatus?
        let cancelBolusCompletion: BolusDeliveryStatusCompletion = { result in
            switch result {
            case .success(let bolusDeliveryStatus):
                expectedBolusDeliveryStatus = bolusDeliveryStatus
                self.completionCalled = true
            case .failure(_):
                XCTAssert(false)
            }
        }
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: IDPumpState(),
                                      pendingAnnunciationCompletions: [IDControlPointOpcode.cancelBolus.procedureID: cancelBolusCompletion])

        let flags = AnnunciationStatusFlag.init(arrayLiteral: [.presentAnnunciation, .presentAuxInfo1, .presentAuxInfo2, .presentAuxInfo3, .presentAuxInfo4])
        let annunciationID: UInt16 = 1
        let annunciationType = AnnunciationType.bolusCanceled
        let annunciationStatus = AnnunciationStatus.pending
        let e2eCounter: UInt8 = 1

        var cancelBolusAnnunication = Data(flags.rawValue)
        cancelBolusAnnunication.append(annunciationID)
        cancelBolusAnnunication.append(annunciationType.rawValue)
        cancelBolusAnnunication.append(annunciationStatus.rawValue)
        cancelBolusAnnunication.append(0x0001)
        cancelBolusAnnunication.append(BolusType.fast.rawValue)
        cancelBolusAnnunication.append(0x00)
        cancelBolusAnnunication.append(1.0.sfloat)
        cancelBolusAnnunication.append(0.5.sfloat)
        cancelBolusAnnunication.append(e2eCounter)
        cancelBolusAnnunication = cancelBolusAnnunication.appendingCRC()

        pump.manageInsulinDeliveryAnnunciationStatusData(cancelBolusAnnunication)
        XCTAssertNotNil(expectedBolusDeliveryStatus)
        XCTAssertTrue(completionCalled)
    }

    func testHandleBolusCanceledResponse() {
        let testExpectation = expectation(description: #function)
        var expectedBolusDeliveryStatus: BolusDeliveryStatus?
        let bolusID: BolusID = 10
        let activeBolus = BolusDeliveryStatus(id: bolusID, progressState: .inProgress, type: .fast, insulinProgrammed: 2, insulinDelivered: 0.5)
        bolusManager = BolusManager(activeBolusDeliveryStatus: activeBolus)
        let cancelBolusCompletion: BolusDeliveryStatusCompletion = { result in
            switch result {
            case .success(let bolusDeliveryStatus):
                expectedBolusDeliveryStatus = bolusDeliveryStatus
                testExpectation.fulfill()
            case .failure(_):
                XCTAssert(false)
            }
        }
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: IDPumpState())
        pump.idControlPoint.appendToRequestQueue(Data(IDControlPointOpcode.cancelBolus.rawValue), completion: cancelBolusCompletion)

        var response = Data(IDControlPointOpcode.cancelBolusResponse.rawValue)
        response.append(bolusID)
        response.append(pump.idControlPoint.e2eCounter)
        response = response.appendingCRC()

        pump.manageInsulinDeliveryControlPointResponse(response)

        wait(for: [testExpectation], timeout: 1)
        XCTAssertNotNil(expectedBolusDeliveryStatus)
        XCTAssertEqual(expectedBolusDeliveryStatus?.progressState, .canceled)
        XCTAssertEqual(expectedBolusDeliveryStatus?.id, bolusID)
        XCTAssertEqual(bolusManager.activeBolusDeliveryStatus.progressState, .canceled)
        XCTAssertEqual(bolusManager.activeBolusDeliveryStatus.id, bolusID)
    }

    func testPendingProcedureCompletionSetTempBasalAdjustment() {
        let setTempBasalAdjustmentCompletion: ProcedureResultCompletion = { result in
            switch result {
            case .success():
                self.completionCalled = true
            case .failure(_):
                XCTAssert(false)
            }
        }
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: IDPumpState())
        pump.idControlPoint.appendToRequestQueue(Data(IDControlPointOpcode.setTempBasalAdjustment.rawValue), completion: setTempBasalAdjustmentCompletion)

        var response = Data(IDControlPointOpcode.responseCode.rawValue)
        response.append(IDControlPointOpcode.setTempBasalAdjustment.rawValue)
        response.append(IDControlPointResponseCode.success.rawValue)
        response.append(pump.idControlPoint.e2eCounter)
        response = response.appendingCRC()

        pump.manageInsulinDeliveryControlPointResponse(response)
        XCTAssertTrue(completionCalled)
    }

    func testPendingProcedureCompletionCancelTempBasalAdjustment() {
        let cancelTempBasalAdjustmentCompletion: ProcedureResultCompletion = { result in
            switch result {
            case .success():
                self.completionCalled = true
            case .failure(_):
                XCTAssert(false)
            }
        }
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: IDPumpState())
        pump.idControlPoint.appendToRequestQueue(Data(IDControlPointOpcode.cancelTempBasalAdjustment.rawValue), completion: cancelTempBasalAdjustmentCompletion)
        
        var response = Data(IDControlPointOpcode.responseCode.rawValue)
        response.append(IDControlPointOpcode.cancelTempBasalAdjustment.rawValue)
        response.append(IDControlPointResponseCode.success.rawValue)
        response.append(pump.idControlPoint.e2eCounter)
        response = response.appendingCRC()

        pump.manageInsulinDeliveryControlPointResponse(response)
        XCTAssertTrue(completionCalled)
    }

    func testIsConnected() {
        let testExpectation = XCTestExpectation(description: #function)
        let pumpIsConnected = false
        var receivedError: DeviceCommError?
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: IDPumpState(),
                                      isConnectedHandler: { pumpIsConnected })
        pump.setBolus(2, activationType: .recommendedBolus, completion: { result in
            switch result {
            case .success(_):
                XCTAssert(false)
            case .failure(let error):
                receivedError = error
            }
            testExpectation.fulfill()
        })

        wait(for: [testExpectation], timeout: 1)
        XCTAssertEqual(receivedError, .disconnected)
    }

    func testHandleCBError() {
        var receivedError: DeviceCommError?
        var testExpectation = XCTestExpectation(description: #function)
        testExpectation.expectedFulfillmentCount = 3
        let procedureResultCompletion: ProcedureResultCompletion = { result in
            switch result {
            case .success():
                XCTAssert(false)
            case .failure(let error):
                receivedError = error
                testExpectation.fulfill()
            }
        }
        let bolusDeliveryStatusCompletion: BolusDeliveryStatusCompletion = { result in
            switch result {
            case .success(_):
                XCTAssert(false)
            case .failure(let error):
                receivedError = error
                testExpectation.fulfill()
            }
        }
        let pumpDeliveryStatusCompletion: PumpDeliveryStatusCompletion = { result in
            switch result {
            case .success(_):
                XCTAssert(false)
            case .failure(let error):
                receivedError = error
                testExpectation.fulfill()
            }
        }
        
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: IDPumpState())
        pump.idControlPoint.appendToRequestQueue(Data(IDControlPointOpcode.setTherapyControlState.rawValue), completion: procedureResultCompletion)
        pump.idControlPoint.appendToRequestQueue(Data(IDControlPointOpcode.startPriming.rawValue), completion: bolusDeliveryStatusCompletion)
        pump.idControlPoint.appendToRequestQueue(Data(IDControlPointOpcode.stopPriming.rawValue), completion: pumpDeliveryStatusCompletion)
        
        // timeout
        var cbError = CBError(.connectionTimeout)
        pump.handleCBError(cbError)
        wait(for: [testExpectation], timeout: 1)
        XCTAssertEqual(receivedError, .connectionTimeout)
        
        // disconnect
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: IDPumpState())
        _ = pump.idControlPoint.getPendingProceduresAndReset()
        pump.idControlPoint.appendToRequestQueue(Data(IDControlPointOpcode.setTherapyControlState.rawValue), completion: procedureResultCompletion)
        pump.idControlPoint.appendToRequestQueue(Data(IDControlPointOpcode.startPriming.rawValue), completion: bolusDeliveryStatusCompletion)
        pump.idControlPoint.appendToRequestQueue(Data(IDControlPointOpcode.stopPriming.rawValue), completion: pumpDeliveryStatusCompletion)
        
        receivedError = nil
        testExpectation = XCTestExpectation(description: #function)
        testExpectation.expectedFulfillmentCount = 3
        cbError = CBError(.peripheralDisconnected)
        pump.handleCBError(cbError)
        wait(for: [testExpectation], timeout: 1)
        XCTAssertEqual(receivedError, .disconnected)
        
        // connection failed
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: IDPumpState())
        _ = pump.idControlPoint.getPendingProceduresAndReset()
        pump.idControlPoint.appendToRequestQueue(Data(IDControlPointOpcode.setTherapyControlState.rawValue), completion: procedureResultCompletion)
        pump.idControlPoint.appendToRequestQueue(Data(IDControlPointOpcode.startPriming.rawValue), completion: bolusDeliveryStatusCompletion)
        pump.idControlPoint.appendToRequestQueue(Data(IDControlPointOpcode.stopPriming.rawValue), completion: pumpDeliveryStatusCompletion)
        
        receivedError = nil
        testExpectation = XCTestExpectation(description: #function)
        testExpectation.expectedFulfillmentCount = 3
        cbError = CBError(.connectionFailed)
        pump.handleCBError(cbError)
        wait(for: [testExpectation], timeout: 1)
        XCTAssertEqual(receivedError, .disconnected)
        
        // pump already paired
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: IDPumpState())
        _ = pump.idControlPoint.getPendingProceduresAndReset()
        pump.idControlPoint.appendToRequestQueue(Data(IDControlPointOpcode.setTherapyControlState.rawValue), completion: procedureResultCompletion)
        pump.idControlPoint.appendToRequestQueue(Data(IDControlPointOpcode.startPriming.rawValue), completion: bolusDeliveryStatusCompletion)
        pump.idControlPoint.appendToRequestQueue(Data(IDControlPointOpcode.stopPriming.rawValue), completion: pumpDeliveryStatusCompletion)
        
        receivedError = nil
        testExpectation = XCTestExpectation(description: #function)
        testExpectation.expectedFulfillmentCount = 3
        cbError = CBError(.uuidNotAllowed)
        pump.handleCBError(cbError)
        wait(for: [testExpectation], timeout: 1)
        XCTAssertEqual(receivedError, .deviceAlreadyPaired)
        
        // other error
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: IDPumpState())
        _ = pump.idControlPoint.getPendingProceduresAndReset()
        pump.idControlPoint.appendToRequestQueue(Data(IDControlPointOpcode.setTherapyControlState.rawValue), completion: procedureResultCompletion)
        pump.idControlPoint.appendToRequestQueue(Data(IDControlPointOpcode.startPriming.rawValue), completion: bolusDeliveryStatusCompletion)
        pump.idControlPoint.appendToRequestQueue(Data(IDControlPointOpcode.stopPriming.rawValue), completion: pumpDeliveryStatusCompletion)
        
        receivedError = nil
        testExpectation = XCTestExpectation(description: #function)
        testExpectation.isInverted = true
        cbError = CBError(.unknown)
        pump.handleCBError(cbError)
        XCTAssertEqual(receivedError, .commandFailed("\"The operation couldn’t be completed. (CBErrorDomain error 0.)\""))
    }

    func testTrackActiveBolusDelivery() {
        setUpGeneralPump()
        pump.delegate = self

        let bolusID: UInt16 = 1
        var expectedBolusDeliveryStatus: BolusDeliveryStatus = .noActiveBolus
        var receivedBolusDeliveryStatus: BolusDeliveryStatus = expectedBolusDeliveryStatus
        var updateHandlerCalled = false
        let updateHandler: (BolusDeliveryStatus) -> Void = { bolusDeliveryStatus in
            receivedBolusDeliveryStatus = bolusDeliveryStatus
            updateHandlerCalled = true
        }

        // no active bolus
        bolusManager.activeBolusDeliveryStatus = expectedBolusDeliveryStatus
        pump.updateActiveBolusDeliveryDetails(updateHandler: updateHandler)
        XCTAssertTrue(updateHandlerCalled)
        XCTAssertEqual(receivedBolusDeliveryStatus, expectedBolusDeliveryStatus)

        // estimating bolus progress
        let insulinProgrammed = 2.0
        var insulinDelivered = 0.5
        let startTime = Date().addingTimeInterval(-(insulinDelivered/estimatedBolusDeliveryRate))
        expectedBolusDeliveryStatus = BolusDeliveryStatus(id: bolusID, progressState: .estimatingProgress, type: .fast, insulinProgrammed: insulinProgrammed, insulinDelivered: insulinDelivered, startTime: startTime)
        bolusManager.activeBolusDeliveryStatus = expectedBolusDeliveryStatus
        pump.updateActiveBolusDeliveryDetails(updateHandler: updateHandler)
        XCTAssertTrue(updateHandlerCalled)
        XCTAssertEqual(receivedBolusDeliveryStatus, expectedBolusDeliveryStatus)

        // bolus in progress
        pump.state.uuidToHandleMap = [InsulinDeliveryCharacteristicUUID.statusReaderControlPoint.cbUUID: 1]
        insulinDelivered = 1.3
        updateHandlerCalled = false
        expectedBolusDeliveryStatus.progressState = .inProgress
        expectedBolusDeliveryStatus.insulinDelivered = insulinDelivered

        _ = bolusManager.createGetActiveBolusDeliveryRequest(bolusValueSelection: .delivered)
        bolusManager.sendingActiveBolusRequest(.delivered)
        var response = Data(IDStatusReaderOpcode.getActiveBolusDeliveryResponse.rawValue)
        response.append(UInt8(0x00)) // flags
        response.append(bolusID)
        response.append(BolusType.fast.rawValue)
        response.append(insulinDelivered.sfloat)
        response.append(0.sfloat) // extended bolus is 0 for fast
        response.append(pump.idStatusReader.e2eCounter)
        response = response.appendingCRC()

        pump.manageInsulinDeliveryStatusReaderResponse(response)
        XCTAssertTrue(updateHandlerCalled)
        XCTAssertEqual(receivedBolusDeliveryStatus, expectedBolusDeliveryStatus)

        // bolus canceled by therapy control state set to stop
        expectedBolusDeliveryStatus.progressState = .canceled

        let reservoirRemaining = 130.5
        let flags: IDStatusFlag = .reservoirAttached
        response = Data(InsulinTherapyControlState.stop.rawValue)
        response.append(PumpOperationalState.ready.rawValue)
        response.append(reservoirRemaining.sfloat)
        response.append(flags.rawValue)
        response.append(UInt8(1)) // e2eCounter
        response = response.appendingCRC()
        pump.manageInsulinDeliveryStatusData(response)
        
        XCTAssertEqual(receivedBolusDeliveryStatus, expectedBolusDeliveryStatus)
        XCTAssertNil(bolusManager.activeBolusDeliveryUpdateHandler)
    }

    func testPrimingCannula() {
        let testExpectation = XCTestExpectation(description: #function)
        var primingCommandSuccessful = false
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: IDPumpState(),
                                      isConnectedHandler: { true })
        pump.state.uuidToHandleMap = [InsulinDeliveryCharacteristicUUID.commandControlPoint.cbUUID: 1]

        pump.primeCannula(0.5) { result in
            switch result {
            case .success():
                primingCommandSuccessful = true
                testExpectation.fulfill()
            case .failure(_):
                XCTAssert(false)
            }
        }

        var response = Data(IDControlPointOpcode.responseCode.rawValue)
        response.append(IDControlPointOpcode.startPriming.rawValue)
        response.append(IDControlPointResponseCode.success.rawValue)
        response.append(pump.idControlPoint.e2eCounter)
        response = response.appendingCRC()

        pump.manageInsulinDeliveryControlPointResponse(response)
        wait(for: [testExpectation], timeout: 1)
        XCTAssertTrue(primingCommandSuccessful)
    }

    func testPrepareForInsulinDelivery() {
        let testExpectation = XCTestExpectation(description: #function)
        var activateBasalRateScheduleCommandSuccessful = false
        let basalSegments = [BasalSegment(index: 1, rate: 1, durationInMinutes: 1440)]
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: IDPumpState(),
                                      isConnectedHandler: { true })
        pump.state.uuidToHandleMap = [
            InsulinDeliveryCharacteristicUUID.commandControlPoint.cbUUID: 1,
            InsulinDeliveryCharacteristicUUID.statusReaderControlPoint.cbUUID: 2
        ]

        pump.prepareForInsulinDelivery(reservoirLevel: 140, basalSegments: basalSegments) { result in
            switch result {
            case .success():
                activateBasalRateScheduleCommandSuccessful = true
                testExpectation.fulfill()
            case .failure(_):
                XCTAssert(false)
            }
        }
        
        var response = Data(IDControlPointOpcode.responseCode.rawValue)
        response.append(IDControlPointOpcode.setInitialResevoirFillLevel.rawValue)
        response.append(IDControlPointResponseCode.success.rawValue)
        response.append(pump.idControlPoint.e2eCounter)
        response = response.appendingCRC()
        pump.manageInsulinDeliveryControlPointResponse(response)
        
        response = Data(IDControlPointOpcode.responseCode.rawValue)
        response.append(IDControlPointOpcode.resetResevoirInsulinOperationTime.rawValue)
        response.append(IDControlPointResponseCode.success.rawValue)
        response.append(pump.idControlPoint.e2eCounter)
        response = response.appendingCRC()
        pump.manageInsulinDeliveryControlPointResponse(response)

        response = Data(IDControlPointOpcode.responseCode.rawValue)
        response.append(IDControlPointOpcode.writeBasalRateTemplate.rawValue)
        response.append(IDControlPointResponseCode.success.rawValue)
        response.append(pump.idControlPoint.e2eCounter)
        response = response.appendingCRC()
        pump.manageInsulinDeliveryControlPointResponse(response)

        response = Data(IDControlPointOpcode.activateProfileTemplatesResponse.rawValue)
        response.append(UInt8(1))
        response.append(UInt8(1))
        response.append(pump.idControlPoint.e2eCounter)
        response = response.appendingCRC()

        pump.manageInsulinDeliveryControlPointResponse(response)
        wait(for: [testExpectation], timeout: 1)
        XCTAssertTrue(activateBasalRateScheduleCommandSuccessful)
    }

    func testGetInsulinDeliveryStatus() {
        var testExpectation = XCTestExpectation(description: #function)
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: pumpState,
                                      isConnectedHandler: { true })

        pump.getInsulinDeliveryStatus() { result in
            switch result {
            case .success():
                testExpectation.fulfill()
            case .failure(_):
                XCTAssert(false)
            }
        }

        var therapyControlState = InsulinTherapyControlState.stop
        var operationalControlState = PumpOperationalState.waiting
        let reservoirRemaining = 130.5
        let flags: IDStatusFlag = .reservoirAttached

        var response = Data(therapyControlState.rawValue)
        response.append(operationalControlState.rawValue)
        response.append(reservoirRemaining.sfloat)
        response.append(flags.rawValue)
        response.append(UInt8(1)) // e2eCounter
        response = response.appendingCRC()

        pump.manageInsulinDeliveryStatusData(response)
        wait(for: [testExpectation], timeout: 1)
        XCTAssertFalse(pump.state.setupCompleted)

        testExpectation = XCTestExpectation(description: #function)
        pump.getInsulinDeliveryStatus() { result in
            switch result {
            case .success():
                testExpectation.fulfill()
            case .failure(_):
                XCTAssert(false)
            }
        }

        therapyControlState = InsulinTherapyControlState.run
        operationalControlState = PumpOperationalState.ready

        response = Data(therapyControlState.rawValue)
        response.append(operationalControlState.rawValue)
        response.append(reservoirRemaining.sfloat)
        response.append(flags.rawValue)
        response.append(UInt8(1)) // e2eCounter
        response = response.appendingCRC()

        pump.manageInsulinDeliveryStatusData(response)
        wait(for: [testExpectation], timeout: 1)
        XCTAssertTrue(pump.state.setupCompleted)
    }

    func testInvalidBolusVolume() {
        let invalidBolusVolume = 0.001
        let invalidBolusVolume2 = 0.01
        let validBolusVolume = 1.0
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: IDPumpState(),
                                      isConnectedHandler: { true })
        pump.delegate = self
        
        XCTAssertFalse(pump.isValidBolusVolume(invalidBolusVolume))
        XCTAssertFalse(pump.isValidBolusVolume(invalidBolusVolume2))
        XCTAssertTrue(pump.isValidBolusVolume(validBolusVolume))
    }

    func testInvalidBasalRate() {
        let invalidBasalRate = 0.001
        let validBasalRate = 1.0
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: IDPumpState(),
                                      isConnectedHandler: { true })
        pump.delegate = self
        XCTAssertFalse(pump.isValidBasalRate(invalidBasalRate))
        XCTAssertTrue(pump.isValidBasalRate(validBasalRate))
    }

    func testAllowNestedCompletions() {
        let testExpectation = XCTestExpectation(description: #function)
        let nestedCompletion: ProcedureResultCompletion = { result in
            switch result {
            case .success:
                XCTAssert(false)
            case .failure(let error):
                self.completionCalled = true
                XCTAssertEqual(error, .procedureNotApplicable)
                testExpectation.fulfill()
            }
        }
        let pendingCompletion: ProcedureResultCompletion = { result in
            switch result {
            case .success:
                self.completionCalled = true
                self.pump.idControlPoint.appendToRequestQueue(Data(IDControlPointOpcode.stopPriming.rawValue), completion: nestedCompletion)
            case .failure(_):
                XCTAssert(false)
            }
        }
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: IDPumpState())
        pump.idControlPoint.appendToRequestQueue(Data(IDControlPointOpcode.stopPriming.rawValue), completion: pendingCompletion)
        
        var response = Data(IDControlPointOpcode.responseCode.rawValue)
        response.append(IDControlPointOpcode.stopPriming.rawValue)
        response.append(IDControlPointResponseCode.success.rawValue)
        response = pump.idControlPoint.appendingE2EProtection(response)

        pump.manageInsulinDeliveryControlPointResponse(response)
        XCTAssertTrue(completionCalled)
        self.completionCalled = false

        response = Data(IDControlPointOpcode.responseCode.rawValue)
        response.append(IDControlPointOpcode.stopPriming.rawValue)
        response.append(IDControlPointResponseCode.procedureNotApplicable.rawValue)
        response = pump.idControlPoint.appendingE2EProtection(response)
        pump.manageInsulinDeliveryControlPointResponse(response)
        wait(for: [testExpectation], timeout: 1)
        XCTAssertTrue(completionCalled)
    }

    func testGetMostCurrentReferenceTimeHistoryEvent() {
        let testExpectation = XCTestExpectation(description: #function)
        let pendingProcedureCompletion: ProcedureResultCompletion = { result in
            switch result {
            case .success:
                self.completionCalled = true
                testExpectation.fulfill()
            case .failure(_):
                XCTAssert(false)
            }
        }
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: pumpState,
                                      isConnectedHandler: { true })

        pump.getMostCurrentReferenceTimeHistoryEvent(completion: pendingProcedureCompletion)

        var response = Data(RACPOpcode.responseCode.rawValue)
        response.append(RACPOperator.nullOperator.rawValue)
        response.append(RACPOpcode.reportStoredRecords.rawValue)
        response.append(RACPResponseCode.success.rawValue)
        response = pump.recordAccessControlPoint.appendingE2EProtection(response)

        pump.manageRecordAccessControlPointResponse(response)
        wait(for: [testExpectation], timeout: 1)
        XCTAssertTrue(completionCalled)
    }

    func testDidDeliverBolus() {
        setUpGeneralPump()
        pump.delegate = self

        let now = Date()
        let duration = TimeInterval.minutes(1)
        let insulinProgrammed = 2.0
        let insulinDelivered = 1.75
        pump.pumpHistoryEventManagerDidDetectBolusDelivered(pumpHistoryEventManager, bolusID: 1, insulinProgrammed: insulinProgrammed, insulinDelivered: insulinDelivered, startTime: now, duration: duration)
        XCTAssertTrue(bolusDelivered)
        XCTAssertEqual(bolusProgrammedAmount, insulinProgrammed)
        XCTAssertEqual(bolusDeliveredAmount, insulinDelivered)
        XCTAssertEqual(bolusStartTime, now)
        XCTAssertEqual(bolusDuration, duration)
    }

    func testActiveBolusStatusChange() {
        pumpState.setupCompleted = true
        setUpGeneralPump(isAuthenticated: true)

        let statusChangedFlags = IDStatusChangedFlag([.activeBolusStatusChanged])

        var statusChangedData = Data(statusChangedFlags.rawValue)
        statusChangedData = TestE2EProtection().appendingE2EProtection(statusChangedData)

        // request to reset status changed flag
        pump.manageInsulinDeliveryStatusChangedData(statusChangedData)
        XCTAssertNotNil(pump.idStatusReader.requestQueue.first)
        XCTAssertEqual(pump.idStatusReader.currentProcedureOpcode(), IDStatusReaderOpcode.resetStatus)

        // response that reset was successful
        var response = Data(IDStatusReaderOpcode.responseCode.rawValue)
        response.append(IDStatusReaderOpcode.resetStatus.rawValue)
        response.append(IDStatusReaderResponseCode.success.rawValue)
        response.append(pump.idStatusReader.e2eCounter)
        response = response.appendingCRC()

        // request to get active bolus IDs
        pump.manageInsulinDeliveryStatusReaderResponse(response)
        XCTAssertNotNil(pump.idStatusReader.requestQueue.first)
        XCTAssertEqual(pump.idStatusReader.currentProcedureOpcode(), IDStatusReaderOpcode.getActiveBolusIDs)
    }

    func testHistoryEventStatusChange() {
        pumpState.setupCompleted = true
        setUpGeneralPump(isAuthenticated: true)

        let statusChangedFlags = IDStatusChangedFlag([.historyEventRecordedChanged])

        var statusChangedData = Data(statusChangedFlags.rawValue)
        statusChangedData = TestE2EProtection().appendingE2EProtection(statusChangedData)

        // request to reset status changed flag
        pump.manageInsulinDeliveryStatusChangedData(statusChangedData)
        XCTAssertNotNil(pump.idStatusReader.requestQueue.first)
        XCTAssertEqual(pump.idStatusReader.currentProcedureOpcode(), IDStatusReaderOpcode.resetStatus)

        // response that reset was successful
        var response = Data(IDStatusReaderOpcode.responseCode.rawValue)
        response.append(IDStatusReaderOpcode.resetStatus.rawValue)
        response.append(IDStatusReaderResponseCode.success.rawValue)
        response.append(pump.idStatusReader.e2eCounter)
        response = response.appendingCRC()

        // request to get stored records
        pump.manageInsulinDeliveryStatusReaderResponse(response)
        XCTAssertNotNil(pump.recordAccessControlPoint.requestQueue.first)
        XCTAssertEqual(pump.recordAccessControlPoint.currentProcedureOpcode(), RACPOpcode.reportStoredRecords)
    }

    func testAnnunciationStatusChange() {
        pumpState.setupCompleted = true
        setUpGeneralPump(isAuthenticated: true)

        let statusChangedFlags = IDStatusChangedFlag([.annunciationStatusChanged])

        var statusChangedData = Data(statusChangedFlags.rawValue)
        statusChangedData = TestE2EProtection().appendingE2EProtection(statusChangedData)

        // request to reset status changed flag
        pump.manageInsulinDeliveryStatusChangedData(statusChangedData)
        XCTAssertNotNil(pump.idStatusReader.requestQueue.first)
        XCTAssertEqual(pump.idStatusReader.currentProcedureOpcode(), IDStatusReaderOpcode.resetStatus)

        // response that reset was successful
        var response = Data(IDStatusReaderOpcode.responseCode.rawValue)
        response.append(IDStatusReaderOpcode.resetStatus.rawValue)
        response.append(IDStatusReaderResponseCode.success.rawValue)
        response.append(pump.idStatusReader.e2eCounter)
        response = response.appendingCRC()

        // request to get annunciation status
        pump.manageInsulinDeliveryStatusReaderResponse(response)
        XCTAssertNotNil(pump.lockedReadRequestQueue.value.first)
        if let procedureID = pump.lockedReadRequestQueue.value.first?.1 {
            XCTAssertEqual(procedureID, InsulinDeliveryCharacteristicUUID.annunciationStatus.procedureID)
        }
    }

    func testStatusChangeBeforeSetupComplete() {
        pumpState.setupCompleted = true
        setUpGeneralPump()
        let statusChangedFlags = IDStatusChangedFlag([.historyEventRecordedChanged])

        var statusChangedData = Data(statusChangedFlags.rawValue)
        statusChangedData = TestE2EProtection().appendingE2EProtection(statusChangedData)

        pump.manageInsulinDeliveryStatusChangedData(statusChangedData)
        
        // response that reset was successful
        var response = Data(IDStatusReaderOpcode.responseCode.rawValue)
        response.append(IDStatusReaderOpcode.resetStatus.rawValue)
        response.append(IDStatusReaderResponseCode.success.rawValue)
        response.append(pump.idStatusReader.e2eCounter)
        response = response.appendingCRC()
        pump.manageInsulinDeliveryStatusReaderResponse(response)
        
        XCTAssertNotNil(pump.recordAccessControlPoint.requestQueue.first)
        XCTAssertEqual(pump.recordAccessControlPoint.currentProcedureOpcode(), RACPOpcode.reportStoredRecords)
    }

    func testStatusChangeWhileReportingBolus() {
        pumpState.setupCompleted = true
        setUpGeneralPump()
        bolusManager.activeBolusDeliveryStatus = BolusDeliveryStatus(id: 1, progressState: .inProgress, type: .fast, insulinProgrammed: 2.0, insulinDelivered: 1.0, startTime: Date())
        bolusManager.activeBolusDeliveryUpdateHandler = { _ in }
        let statusChangedFlags = IDStatusChangedFlag([.activeBolusStatusChanged])

        var statusChangedData = Data(statusChangedFlags.rawValue)
        statusChangedData = TestE2EProtection().appendingE2EProtection(statusChangedData)

        pump.manageInsulinDeliveryStatusChangedData(statusChangedData)
        XCTAssertNil(pump.lockedReadRequestQueue.value.first)
        XCTAssertNil(pump.idStatusReader.requestQueue.first)
    }

    func testStatusChangeWithActiveBolus() {
        pumpState.setupCompleted = true
        setUpGeneralPump()
        bolusManager.activeBolusDeliveryStatus = BolusDeliveryStatus(id: 1, progressState: .inProgress, type: .fast, insulinProgrammed: 2.0, insulinDelivered: 1.0, startTime: Date())
        let statusChangedFlags = IDStatusChangedFlag([.activeBolusStatusChanged])

        var statusChangedData = Data(statusChangedFlags.rawValue)
        statusChangedData = TestE2EProtection().appendingE2EProtection(statusChangedData)

        pump.manageInsulinDeliveryStatusChangedData(statusChangedData)
        XCTAssertNotNil(pump.idStatusReader.requestQueue.first)
        XCTAssertEqual(pump.idStatusReader.currentProcedureOpcode(), IDStatusReaderOpcode.resetStatus)
    }

    func testUpdateStatus() {
        let testExpectation = XCTestExpectation(description: #function)
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: pumpState,
                                      isConnectedHandler: { true },
                                      isAuthenticatedHandler: { true })

        var pumpStatus: PumpDeliveryStatus?
        pump.updateStatus() { result in
            switch result {
            case .success(let status):
                pumpStatus = status
                testExpectation.fulfill()
            case .failure(_):
                XCTAssert(false)
            }
        }

        let therapyControlState = InsulinTherapyControlState.run
        let pumpOperationalState = PumpOperationalState.ready
        let reservoirLevel = 140.0
        let flags: IDStatusFlag = .reservoirAttached

        // insulin status response
        var response = Data(therapyControlState.rawValue)
        response.append(pumpOperationalState.rawValue)
        response.append(reservoirLevel.sfloat)
        response.append(flags.rawValue)
        response = TestE2EProtection().appendingE2EProtection(response)
        pump.manageInsulinDeliveryStatusData(response)

        // remaining lifetime response
        response = Data(IDStatusReaderOpcode.getCounterResponse.rawValue)
        response.append(CounterType.lifetime.rawValue)
        response.append(CounterValueSelection.remaining.rawValue)
        response.append(Int32(TimeInterval.days(120).minutes))
        response = TestE2EProtection().appendingE2EProtection(response)
        pump.manageInsulinDeliveryStatusReaderResponse(response)

        // status changes response
        let statusChangedFlags = IDStatusChangedFlag.allZeros
        var statusChangedData = Data(statusChangedFlags.rawValue)
        statusChangedData = TestE2EProtection().appendingE2EProtection(statusChangedData)
        pump.manageInsulinDeliveryStatusChangedData(statusChangedData)

        wait(for: [testExpectation], timeout: 1)
        XCTAssertEqual(pumpStatus?.therapyControlState, therapyControlState)
        XCTAssertEqual(pumpStatus?.pumpOperationalState, pumpOperationalState)
        XCTAssertEqual(pumpStatus?.reservoirLevel, reservoirLevel)
    }

    func testUpdateStatusDisconnected() {
        let testExpectation = XCTestExpectation(description: #function)
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: SecurityManager(),
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: IDPumpState())

        pump.updateStatus() { result in
            switch result {
            case .success(_):
                XCTAssert(false)
            case .failure(let error):
                XCTAssertEqual(error, .disconnected)
                testExpectation.fulfill()
            }
        }
        wait(for: [testExpectation], timeout: 1)
    }

    func testUpdateStatusNoAuthentication() {
        let testExpectation = XCTestExpectation(description: #function)
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: SecurityManager(),
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: IDPumpState(authorizationControlRequired: true),
                                      isConnectedHandler: { true })

        pump.updateStatus() { result in
            switch result {
            case .success(_):
                XCTAssert(false)
            case .failure(let error):
                XCTAssertEqual(error, .authenticationFailed)
                XCTAssertFalse(self.pump.isAuthenticated)
                testExpectation.fulfill()
            }
        }
        wait(for: [testExpectation], timeout: 1)
    }

    func testAuthenticationFailed() {
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: basalManager,
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: pumpState,
                                      isConnectedHandler: { self.isConnected })
        pump.delegate = self
        sharedKeyData = Data(hexadecimalString: "000102030405060708090a0b0c0d0e0f")!
        XCTAssertTrue(pump.isAuthenticated)
        var authenticationFailedResponse = Data(ACControlPointOpcode.responseCode.rawValue)
        authenticationFailedResponse.append(ACControlPointOpcode.keyExchangeECDHConfirmationCodeResponse.rawValue)
        authenticationFailedResponse.append(ACControlPointResponseCode.invalidKeyExchangeConfirmationCode.rawValue)

        pump.manageACControlPointResponse(nil, response: authenticationFailedResponse, isSegmented: false)
        XCTAssertFalse(pump.isAuthenticated)
    }

    func testPumpAlreadyPaired() {
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: basalManager,
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: pumpState,
                                      isConnectedHandler: { self.isConnected })
        pump.delegate = self
        sharedKeyData = Data(hexadecimalString: "000102030405060708090a0b0c0d0e0f")!
        XCTAssertTrue(pump.isAuthenticated)
        pump.handleCBError(CBError(.uuidNotAllowed))
        XCTAssertFalse(pump.isAuthenticated)
    }

    func testUpdateStatusNoDeviceInformation() {
        let testExpectation = XCTestExpectation(description: #function)
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: IDPumpState(),
                                      isConnectedHandler: { true })

        pump.updateStatus() { result in
            switch result {
            case .success(_):
                XCTAssert(false)
            case .failure(let error):
                XCTAssertEqual(error, .deviceNotReady)
                testExpectation.fulfill()
            }
        }
        wait(for: [testExpectation], timeout: 1)
    }

    func testHandleAnnunciationStatusData() {
        let testExpectation = XCTestExpectation(description: #function)
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: pumpState,
                                      isConnectedHandler: { true })
        let annunciationID: AnnunciationIdentifier = 123
        let annunciation = GeneralAnnunciation(type: .bolusCanceled, identifier: annunciationID)
        pump.confirmAnnunciation(annunciation) { result in
            switch result {
            case .success:
                self.completionCalled = true
                testExpectation.fulfill()
            case .failure(_):
                XCTAssert(false)
            }
        }

        var response = Data(IDControlPointOpcode.confirmAnnunciationResponse.rawValue)
        response.append(annunciationID)
        response.append(pump.idControlPoint.e2eCounter)
        response = response.appendingCRC()

        pump.manageInsulinDeliveryControlPointResponse(response)

        wait(for: [testExpectation], timeout: 1)
        XCTAssertTrue(completionCalled)
    }

    func testHandleAnnunciationStatusDataError() {
        let testExpectation = XCTestExpectation(description: #function)
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: pumpState,
                                      isConnectedHandler: { true })
        let annunciationID: AnnunciationIdentifier = 123
        let annunciation = GeneralAnnunciation(type: .bolusCanceled, identifier: annunciationID)
        var receivedError: DeviceCommError?
        pump.confirmAnnunciation(annunciation) { result in
            switch result {
            case .success:
                XCTAssert(false)
            case .failure(let error):
                receivedError = error
                self.completionCalled = true
                testExpectation.fulfill()
            }
        }

        var response = Data(IDControlPointOpcode.responseCode.rawValue)
        response.append(IDControlPointOpcode.confirmAnnunciation.rawValue)
        response.append(IDControlPointResponseCode.procedureNotCompleted.rawValue)
        response.append(pump.idControlPoint.e2eCounter)
        response = response.appendingCRC()

        pump.manageInsulinDeliveryControlPointResponse(response)

        wait(for: [testExpectation], timeout: 1)
        XCTAssertTrue(completionCalled)
        XCTAssertEqual(receivedError, .procedureNotCompleted)
    }

    func testManageACDataValuePartialResponse() {
        let testExpectation = expectation(description: #function)
        // since this is only a partial response, it waits for the complete response
        testExpectation.isInverted = true
        let pendingCompletion: ProcedureResultCompletion = { result in
            switch result {
            case .success:
                testExpectation.fulfill()
            case .failure(_):
                XCTAssert(false)
            }
        }
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: IDPumpState())
        pump.idControlPoint.appendToRequestQueue(Data(IDControlPointOpcode.setTherapyControlState.rawValue), completion: pendingCompletion)

        let segmentationHeader = SegmentationHeader(rawValue: 0b00010101)
        let response = Data(segmentationHeader.rawValue)
        pump.manageACDataValue(response)
        wait(for: [testExpectation], timeout: 1)
    }

    func testManageACDataValueSecurityManagerError() {
        let testExpectation = expectation(description: #function)
        let pendingCompletion: ProcedureResultCompletion = { result in
            switch result {
            case .success:
                XCTAssert(false)
            case .failure(let error):
                if case .securityManagerError(let securityManagerError) = error {
                    XCTAssertEqual(securityManagerError, .missingKey)
                    testExpectation.fulfill()
                } else {
                    XCTAssert(false)
                }
            }
        }
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: pumpState)
        pump.idControlPoint.appendToRequestQueue(Data(IDControlPointOpcode.setTherapyControlState.rawValue), completion: pendingCompletion)
        
        let segmentationHeader = SegmentationHeader(rawValue: 0b00010111)
        var response = Data(segmentationHeader.rawValue)
        response.append(0x01020304)
        pump.manageACDataValue(response)
        wait(for: [testExpectation], timeout: 1)
    }

    func testTempBasalStarted() {
        setUpGeneralPump()
        pump.delegate = self

        let duration = TimeInterval.minutes(15)
        let rate = 2.0
        let now = Date()
        pump.pumpHistoryEventManagerDidDetectTempBasalStarted(pumpHistoryEventManager, at: now, rate: rate, duration: duration)
        XCTAssertEqual(tempBasalStarted, true)
        XCTAssertEqual(tempBasalDuration, duration)
        XCTAssertEqual(tempBasalStartTime, now)
        XCTAssertEqual(tempBasalRate, rate)
    }

    func testTempBasalChanged() {
        setUpGeneralPump()
        pump.delegate = self

        let duration = TimeInterval.minutes(15)
        let elaspedDuration = TimeInterval.minutes(15)
        let rate = 2.0
        let now = Date()
        pump.pumpHistoryEventManagerDidDetectTempBasalChanged(pumpHistoryEventManager, at: now, rate: rate, programmedDuration: duration, elapsedDuration: elaspedDuration)
        XCTAssertEqual(tempBasalStarted, true)
        XCTAssertEqual(tempBasalDuration, duration)
        XCTAssertEqual(tempBasalStartTime, now)
        XCTAssertEqual(tempBasalRate, rate)
    }

    func testTempBasalEnded() {
        setUpGeneralPump()
        pump.delegate = self

        let duration = TimeInterval.minutes(15)
        pump.pumpHistoryEventManagerDidDetectTempBasalEnded(pumpHistoryEventManager, duration: duration, endReason: .errorAbort)
        XCTAssertEqual(tempBasalEnded, true)
        XCTAssertEqual(tempBasalDuration, duration)
    }

    func testInsulinDeliveryDidSuspend() {
        setUpGeneralPump()
        pump.delegate = self

        let expectedSuspendedAt = Date()
        pump.pumpHistoryEventManagerDidDetectInsulinDeliverySuspended(pumpHistoryEventManager, suspendedAt: expectedSuspendedAt)
        XCTAssertNotNil(suspendedAt)
        XCTAssertEqual(suspendedAt, expectedSuspendedAt)
    }

    func isReceivingHistoryEvents() {
        setUpGeneralPump()
        XCTAssertFalse(pump.isReceivingHistoryEvents)

        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: pumpHistoryEventManager,
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: IDPumpState())
        pump.recordAccessControlPoint.appendToRequestQueue(Data(RACPOpcode.reportStoredRecords.rawValue), completion: "test")
        XCTAssertTrue(pump.isReceivingHistoryEvents)
    }

    func testPumpDidSync() {
        pumpState.setupCompleted = true
        pump = InsulinDeliveryService(bluetoothManager: bluetoothManager,
                                      bolusManager: bolusManager,
                                      basalManager: BasalManager(),
                                      pumpHistoryEventManager: PumpHistoryEventManager(lastReceivedHistoryEventSequenceNumber: 9),
                                      securityManager: securityManager,
                                      acControlPoint: acControlPoint,
                                      acData: acData,
                                      state: pumpState,
                                      isConnectedHandler: { true })
        pump.delegate = self
        XCTAssertNil(pumpDidSync)

        // when all history records are received, the pump did sync
        var statusChangedFlags = IDStatusChangedFlag.historyEventRecordedChanged
        var statusChangedData = Data(statusChangedFlags.rawValue)
        statusChangedData = TestE2EProtection().appendingE2EProtection(statusChangedData)
        pump.manageInsulinDeliveryStatusChangedData(statusChangedData)

        var response = Data(IDStatusReaderOpcode.responseCode.rawValue)
        response.append(IDStatusReaderOpcode.resetStatus.rawValue)
        response.append(IDStatusReaderResponseCode.success.rawValue)
        response.append(pump.idStatusReader.e2eCounter)
        response = response.appendingCRC()
        pump.manageInsulinDeliveryStatusReaderResponse(response)

        response = Data(RACPOpcode.responseCode.rawValue)
        response.append(RACPOperator.nullOperator.rawValue)
        response.append(RACPOpcode.reportStoredRecords.rawValue)
        response.append(RACPResponseCode.success.rawValue)
        response = pump.recordAccessControlPoint.appendingE2EProtection(response)

        pump.manageRecordAccessControlPointResponse(response)
        XCTAssertEqual(pumpDidSync, true)

        pumpDidSync = nil

        // when there is no new history events, the pump did sync
        statusChangedFlags = IDStatusChangedFlag.allZeros
        statusChangedData = Data(statusChangedFlags.rawValue)
        statusChangedData = TestE2EProtection().appendingE2EProtection(statusChangedData)
        pump.manageInsulinDeliveryStatusChangedData(statusChangedData)
        XCTAssertEqual(pumpDidSync, true)
    }

    func testHistoricalAnnunciationDetected() {
        setUpGeneralPump()
        pump.delegate = self

        let now = Date()
        let expectedAnnunciation = GeneralAnnunciation(type: .automaticOff, identifier: 123)
        pump.pumpHistoryEventManagerDidDetectAnnunciation(pumpHistoryEventManager, annunciation: expectedAnnunciation, at: now)
        XCTAssertEqual(annunciation, expectedAnnunciation)
        XCTAssertEqual(annunciationDate, now)
    }

    func testUpdateMaxRequestSize() {
        setUpGeneralPump()
        XCTAssertEqual(acControlPoint.maxRequestSize, 19)
        XCTAssertEqual(acData.maxRequestSize, 19)

        let segmentationHeader: UInt8 = 0x03
        let attMTU = 256
        let newMaxRequestSize = attMTU - 1 // minus 1 for segmentation header
        var response = Data(segmentationHeader)
        response.append(ACControlPointOpcode.attMTUResponse.rawValue)
        response.append(UInt16(attMTU))

        let (result, _) = acControlPoint.handleSegmentedResponse(response)
        switch result {
        case .success:
            XCTAssertEqual(acControlPoint.maxRequestSize, newMaxRequestSize)
            XCTAssertEqual(acData.maxRequestSize, newMaxRequestSize)
        case .failure(_):
            XCTAssert(false)
        }
    }

    func testTherapyControlStateStopDuringBolus() {
        setUpGeneralPump()

        let bolusID: BolusID = 3
        pump.setBolus(2, activationType: .recommendedBolus) { _ in }
        var response = Data(IDControlPointOpcode.setBolusResponse.rawValue)
        response.append(bolusID)
        response.append(pump.idControlPoint.e2eCounter)
        response = response.appendingCRC()
        pump.manageInsulinDeliveryControlPointResponse(response)

        XCTAssertEqual(bolusManager.activeBolusDeliveryStatus.id, bolusID)
        XCTAssertEqual(bolusManager.activeBolusDeliveryStatus.progressState, .inProgress)

        let reservoirRemaining = 130.5
        let flags: IDStatusFlag = .reservoirAttached

        response = Data(InsulinTherapyControlState.stop.rawValue)
        response.append(PumpOperationalState.ready.rawValue)
        response.append(reservoirRemaining.sfloat)
        response.append(flags.rawValue)
        response.append(UInt8(1)) // e2eCounter
        response = response.appendingCRC()

        pump.manageInsulinDeliveryStatusData(response)
        XCTAssertEqual(bolusManager.activeBolusDeliveryStatus.progressState, .canceled)
    }
    
    func testBasalManagerDidUpdateStatus() {
        setUpGeneralPump()
        basalManager.delegate = self
        
        let progressState: TempBasalProgressState = .inProgress
        let tempBasalRate = 4.3
        let tempBasalDuration: UInt16 = 30
        let tempBasalDurationRemaining: UInt16 = 20
        
        _ = basalManager.createSetTempBasalAdjustmentRequest(unitsPerHour: tempBasalRate, durationInMinutes: tempBasalDuration, deliveryContext: .apController)
        
        // trigger active temp basal status update
        var response = Data(IDStatusReaderOpcode.getActiveBasalRateDeliveryResponse.rawValue)
        response.append(ActiveBasalRateFlag([.tbrPresent]).rawValue)
        response.append(UInt8(1))
        response.append(2.3.sfloat)
        response.append(TempBasalType.absolute.rawValue)
        response.append(tempBasalRate.sfloat)
        response.append(tempBasalDuration)
        response.append(tempBasalDurationRemaining)
        response.append(pump.idStatusReader.e2eCounter)
        response = response.appendingCRC()
        pump.manageInsulinDeliveryStatusReaderResponse(response)
        XCTAssertEqual(activeTempBasalDeliveryStatus.progressState, progressState)
        XCTAssertEqual(activeTempBasalDeliveryStatus.rate, tempBasalRate)
        XCTAssertEqual(activeTempBasalDeliveryStatus.duration, TimeInterval(minutes: Double(tempBasalDuration)))
        XCTAssertEqual(activeTempBasalDeliveryStatus.insulinDelivered, 0)
        
        // trigger total basal delivered update
        let bolusDelivered: UInt32 = 100
        let expectedTotalBasalDelivered: UInt32 = 200
        response = Data(IDStatusReaderOpcode.getDeliveredInsulinResponse.rawValue)
        response.append(bolusDelivered)
        response.append(expectedTotalBasalDelivered)
        response.append(pump.idStatusReader.e2eCounter)
        response = response.appendingCRC()
        pump.manageInsulinDeliveryStatusReaderResponse(response)
        
        XCTAssertEqual(Double(expectedTotalBasalDelivered), totalBasalDelivered)
    }
}

extension InsulinDeliveryServiceTests: IDPumpCommDelegate {
    var pumpDiscoverableName: String { "TestPump" }
    
    var supportedBasalRates: [Double] { Array((10...350).map { Double($0) / Double(10) }) }
    
    var supportedMaximumBasalRateAmount: Double { 30 }
    
    var supportedMaximumBasalSegmentCount: Int { 24 }
    
    var supportedMinimumBasalSegmentDuration: TimeInterval { .minutes(30) }
    
    var basalRateProfileTemplateNumber: UInt8 { 1 }
    
    var numberOfProfileTemplates: UInt8 { 1 }
    
    var supportedBolusVolumes: [Double]  { Array((1...35).map { Double($0) / Double(10) }) }
    
    var supportedMaximumBolusVolumes: [Double] { Array((1...35).map { Double($0) / Double(10) }) }
    
    var reservoirCapacity: Double { 100 }
    
    var reservoirAccuracyLimit: Double? { 50 }
    
    var reservoirFillSupportedVolumes: [Double] { Array((10...1000).map { Double($0) / Double(10) }) }
    
    var pulseSize: Double { 0.05 }
    
    var pulsesPerUnit: Double { 1/pulseSize }
    
    var expectedLifespan: TimeInterval { .days(10) }
    
    var maxAllowedPumpClockDrift: TimeInterval { .minutes(1) }
    
    var basalSegments: [BasalSegment] {
        [BasalSegment(index:1, rate: 1, durationInMinutes: 1440)]
    }
    
    var pumpTimeZone: TimeZone {
        .currentFixed
    }

    func pumpDidUpdateState(_ pump: IDPumpComms) {
        updatedState = pump.state
    }
        
    func pump(_ pump: IDPumpComms, didReceiveAnnunciation annunciation: Annunciation) {
        annunciationsIssued.append(annunciation)
    }
    
    func pump(_ pump: IDPumpComms, didDiscoverPumpWithName peripheralName: String?, identifier: UUID, serialNumber: String?) { }
    
    func pumpConnectionStatusChanged(_ pump: IDPumpComms) { }

    func pumpDidCompleteAuthentication(_ pump: IDPumpComms, error: DeviceCommError?) { }
    
    func pumpDidCompleteConfiguration(_ pump: IDPumpComms) {
        didCompleteConfigurationCalled = true
    }
    
    func pumpDidCompleteTherapyUpdate(_ pump: IDPumpComms) { }

    func pumpDidInitiateBolus(_ pump: IDPumpComms, bolusID: BolusID, insulinProgrammed: Double, startTime: Date) {
        bolusProgrammedAmount = insulinProgrammed
        bolusStartTime = startTime
    }

    func pumpDidDeliverBolus(_ pump: IDPumpComms, bolusID: BolusID, insulinProgrammed: Double, insulinDelivered: Double, startTime: Date, duration: TimeInterval) {
        bolusDelivered = true
        bolusProgrammedAmount = insulinProgrammed
        bolusDeliveredAmount = insulinDelivered
        bolusStartTime = startTime
        bolusDuration = duration
    }

    func pumpTempBasalStarted(_ pump: IDPumpComms, at startTime: Date, rate: Double, duration: TimeInterval) {
        tempBasalStarted = true
        tempBasalDuration = duration
        tempBasalStartTime = startTime
        tempBasalRate = rate
    }

    func pumpTempBasalEnded(_ pump: IDPumpComms, duration: TimeInterval) {
        tempBasalEnded = true
        tempBasalDuration = duration
    }

    func pumpDidSuspendInsulinDelivery(_ pump: IDPumpComms, suspendedAt: Date) {
        self.suspendedAt = suspendedAt
    }

    func pumpDidDetectHistoricalAnnunciation(_ pump: IDPumpComms, annunciation: Annunciation, at date: Date?) {
        self.annunciation = annunciation as? GeneralAnnunciation
        annunciationDate = date
    }

    func pumpDidSync(_ pump: IDPumpComms, pendingCommandCheckCompleted: Bool, at date: Date = Date()) {
        pumpDidSync = true
        pumpSyncDate = date
    }
}

extension InsulinDeliveryServiceTests: BasalManagerDelegate {
    func basalManagerDidUpdateStatus(_ basalManager: BasalManager) {
        activeTempBasalDeliveryStatus = basalManager.activeTempBasalDeliveryStatus
        totalBasalDelivered = basalManager.totalBasalDelivered
    }
    
    func isActiveBasalRate(_ activeBasalRate: Double) -> Bool {
        true
    }
}
