//
//  InsulinDeliveryService.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2020-03-23.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import CoreBluetooth
import BluetoothCommonKit
import os.log

open class InsulinDeliveryService: IDPumpComms {
    public weak var delegate: IDPumpCommDelegate?

    public weak var loggingDelegate: DeviceCommLoggingDelegate?
    
    private let log = OSLog(category: "InsulinDeliveryService")
    
    public let bluetoothManager: BluetoothManager
    
    public let bolusManager: BolusManager
    
    public let basalManager: BasalManager

    public let pumpHistoryEventManager: PumpHistoryEventManager
    
    public let securityManager: SecurityManager
    
    public let acControlPoint: ACControlPoint
    
    public let acData: ACData

    public let idControlPoint: IDControlPoint

    public let idStatusReader: IDStatusReader

    public let recordAccessControlPoint: RecordAccessControlPoint
    
    public let dtControlPoint: DTControlPoint
    
    public let deviceTime: DeviceTime

    private var lockedPendingAnnunciationCompletions:  Locked<[ProcedureID: Any]> = Locked([:])
    private func appendPendingAnnunciationCompletion(procedureID: ProcedureID, completion: Any) {
        lockedPendingAnnunciationCompletions.mutate { pendingCompletions in
            pendingCompletions[procedureID] = completion
        }
    }
    private func removePendingAnnunciationCompletion(forProcedureID procedureID: ProcedureID) {
        lockedPendingAnnunciationCompletions.mutate { pendingCompletions in
            pendingCompletions[procedureID] = nil
        }
    }
    private func getPendingAnnunciationCompletionsAndReset() -> [(procedureID: ProcedureID, completion: Any)] {
        var pendingProcedures: [(procedureID: ProcedureID, completion: Any)] = []
        lockedPendingAnnunciationCompletions.mutate { pendingCompletions in
            pendingProcedures = pendingCompletions.map { return ($0.key, $0.value) }
            pendingCompletions.removeAll()
        }
        return pendingProcedures
    }

    var lockedReadRequestQueue: Locked<[(cbUUID: CBUUID, procedureID: ProcedureID, completion: Any?)]> = Locked([])
    private func getReadRequestQueuePendingProceduresAndReset() -> [(procedureID: ProcedureID, completion: Any?)] {
        var pendingProcedures: [(procedureID: ProcedureID, completion: Any?)] = []
        lockedReadRequestQueue.mutate { requestQueue in
            pendingProcedures = requestQueue.map { return ($0.procedureID, $0.completion) }
            requestQueue.removeAll()
        }
        return pendingProcedures
    }
    func appendToReadRequestQueue(cbUUID: CBUUID, procedureID: ProcedureID, completion: Any?) {
        lockedReadRequestQueue.mutate { requestQueue in
            requestQueue.append((cbUUID, procedureID, completion))
        }
    }
    private var readRequestInProgress = false

    private var shouldSendBeepRequest = false
    
    open func setOOBString(_ oobString: String) {
        if let oobData = oobString.data(using: .utf8) {
            securityManager.configuration.oobRandomNumber = oobData
        }
    }

    public var deviceInformation: DeviceInformation? {
        get {
            return state.deviceInformation
        }
        set {
            if state.deviceInformation != newValue {
                state.deviceInformation = newValue
            }
        }
    }
    
    public var rawState: IDPumpState.RawValue {
        return state.rawValue
    }

    public var state: IDPumpState {
        didSet {
            if self.state != oldValue {
                delegate?.pumpDidUpdateState(self)
            }
        }
    }
    
    private var isE2EProtectionRequired: Bool {
        state.features.contains(.supportedE2EProtection)
    }
    
    private var isAuthorizationControlRequired: Bool {
        state.isAuthorizationControlRequired
    }
    
    public var isBolusActive: Bool { bolusManager.isBolusActive }
    
    public var activeBolusID: BolusID? { bolusManager.activeBolusDeliveryStatus.id }

    public var peripheralManager: PeripheralManager? { bluetoothManager.peripheralManager }
    
    // used for unit tests
    private var isConnectedHandler: (() -> Bool)?

    public var isConnected: Bool {
        if let isConnectedHandler = isConnectedHandler {
            return isConnectedHandler()
        }

        return peripheralManager?.peripheral?.state == .connected
    }
    
    public var isAuthenticated: Bool {
        guard isAuthorizationControlRequired else { return true }
        
        if let isAuthenticatedHandler = isAuthenticatedHandler {
            return isAuthenticatedHandler()
        }

        return sharedKeyData != nil
    }

    var lastReceivedHistoryEventSequenceNumber: HistoryEventSequenceNumber? {
        pumpHistoryEventManager.lastReceivedHistoryEventSequenceNumber
    }

    // used for unit tests
    private var isAuthenticatedHandler: (() -> Bool)?

    public var isAwaitingConfiguration: Bool {
        deviceInformation?.pumpOperationalState == .waiting
    }

    convenience public init(state: IDPumpState = IDPumpState(),
                            maxRequestSize: Int = 255) {
        let bluetoothManager = BluetoothManager(
            peripheralIdentifier: state.deviceInformation?.identifier,
            peripheralConfiguration: PeripheralManager.Configuration.insulinDeliveryServiceConfiguration,
            servicesToDiscover: [InsulinDeliveryCharacteristicUUID.service.cbUUID]
        )
        let bolusManager = BolusManager(activeBolusDeliveryStatus: state.activeBolusDeliveryStatus)
        let basalManager = BasalManager(activeTempBasalDeliveryStatus: state.activeTempBasalDeliveryStatus, totalBasalDelivered: state.totalBasalDelivered, lastTempBasalRate: state.lastTempBasalRate)
        let pumpHistoryEventManager = PumpHistoryEventManager(configuration: state.pumpHistoryEventManagerConfiguration)
        let securityManager = SecurityManager(configuration: state.securityManagerConfiguration)
        let acControlPoint = ACControlPoint(securityManager: securityManager, maxRequestSize: maxRequestSize)
        let acData = ACData(securityManager: securityManager, maxRequestSize: maxRequestSize)
        self.init(bluetoothManager: bluetoothManager,
                  bolusManager: bolusManager,
                  basalManager: basalManager,
                  pumpHistoryEventManager: pumpHistoryEventManager,
                  securityManager: securityManager,
                  acControlPoint: acControlPoint,
                  acData: acData,
                  state: state)
    }
    
    public init(bluetoothManager: BluetoothManager,
                bolusManager: BolusManager,
                basalManager: BasalManager,
                pumpHistoryEventManager: PumpHistoryEventManager,
                securityManager: SecurityManager,
                acControlPoint: ACControlPoint,
                acData: ACData,
                state: IDPumpState,
                pendingAnnunciationCompletions: [ProcedureID : Any] = [:],
                isConnectedHandler: (() -> Bool)? = nil,
                isAuthenticatedHandler: (() -> Bool)? = nil) {
        self.bluetoothManager = bluetoothManager
        self.pumpHistoryEventManager = pumpHistoryEventManager
        self.bolusManager = bolusManager
        self.basalManager = basalManager
        self.securityManager = securityManager
        self.acControlPoint = acControlPoint
        self.acData = acData
        self.state = state
        self.lockedPendingAnnunciationCompletions.mutate { pendingCompletions in
            pendingCompletions = pendingAnnunciationCompletions
        }
        self.isConnectedHandler = isConnectedHandler
        self.isAuthenticatedHandler = isAuthenticatedHandler
        
        self.idControlPoint = IDControlPoint(bolusManager: bolusManager, basalManager: basalManager, e2eCounter: state.idControlPointNextE2ECounter)
        self.idStatusReader = IDStatusReader(bolusManager: bolusManager, basalManager: basalManager, e2eCounter: state.idStatusReaderNextE2ECounter)
        self.recordAccessControlPoint = RecordAccessControlPoint(e2eCounter: state.recordAccessControlPointNextE2ECounter)
        self.deviceTime = DeviceTime()
        self.dtControlPoint = DTControlPoint()
        
        self.bolusManager.delegate = self
        self.basalManager.delegate = self
        self.pumpHistoryEventManager.delegate = self
        self.bluetoothManager.delegate = self
        self.securityManager.delegate = self
        self.acData.delegate = self
        self.idStatusReader.lifetimeRemainingHandler = { [weak self] in
            self?.deviceInformation?.updateExpirationDate(remainingLifetime: $0)
        }
        
        self.acControlPoint.maxRequestSizeUpdatedHandler = { [weak self] newValue in
            self?.updateMaxRequestSize(newValue)
        }

        // TODO this handler needs to do alot, specifically getting certificates
//        self.acControlPoint.certificateNonceHandler = { [weak self] certificateNonce in
//            guard let self = self,
//                  let serialNumber = self.deviceInformation?.serialNumber
//            else { return }
//            
//            // TODO this should also get the certificate using the information provided
//            self.securityManager.setConstrainedCertificatePumpIdentifier(serialNumber: serialNumber, certificateNonce: certificateNonce)
//        }
        
        self.acControlPoint.continueAuthenticationHandler = { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let certificateData):
                guard isAuthenticated else {
                    // complete key exchange
                    acControlPoint.queueStartKeyExchangeRequest()
                    acControlPoint.queueECDHPublicKeyRequest(certificateData: certificateData)
                    acControlPoint.queueKeyExchangeKDFRequest()
                    
                    guard let peripheralManager = self.peripheralManager else { return }
                    
                    peripheralManager.perform { [weak self] peripheralManager in
                        guard let self = self else { return }
                        self.acControlPoint.sendNextRequest(peripheralManager, timeout: 1)
                    }
                    
                    return
                }
            case .failure(let error):
                self.loggingDelegate?.logErrorEvent("error during authentication \(String(describing: error.localizedDescription.debugDescription))")
                self.delegate?.pumpDidCompleteAuthentication(self, error: error)
            }
        }
    }
    
    private func updateMaxRequestSize(_ newValue: Int) {
        acData.updateMaxRequestSize(newValue)
        acControlPoint.updateMaxRequestSize(newValue)
    }
    
    public func connectToPump(withIdentifier identifier: UUID, andSerialNumber serialNumber: String) {
        guard let delegate else {
            fatalError("Cannot connect to pump with delegate assigned")
        }
        loggingDelegate?.logConnectionEvent("identifier: \(identifier), serial number \(serialNumber)")
        
        // only try to connect to the pump if it is new or disconnected
        guard serialNumber == deviceInformation?.serialNumber,
              isConnected,
              let peripheralManager = peripheralManager
        else {
            deviceInformation = DeviceInformation(identifier: identifier, serialNumber: serialNumber, reportedRemainingLifetime: delegate.expectedLifespan)
            bluetoothManager.connectToPeripheral(withIdentifier: identifier)
            return
        }
        
        loggingDelegate?.logConnectionEvent("pump has matching serial number and is already connected. report ready")
        bluetoothManager(bluetoothManager, peripheralManager: peripheralManager, isReadyWithError: nil)
    }
    
    open func prepareForDeactivation(completion: @escaping ProcedureResultCompletion) {
        loggingDelegate?.logConnectionEvent()
        bluetoothManager.prepareForDeactivation()
        idStatusReader.lifetimeRemainingHandler = nil
        reset()
        completion(.success)
    }

    public func prepareForNewPump() {
        loggingDelegate?.logConnectionEvent()
        reset()
        state.activeTempBasalDeliveryStatus = .noActiveTempBasal
        state.activeBolusDeliveryStatus = .noActiveBolus
        state.totalBasalDelivered = 0
        bluetoothManager.prepareForNewPeripheral()
    }

    open func reset() {
        log.debug("%{public}@", #function)
        reportErrorToAllPendingProcedureCompletions(.disconnected) // happens first to report to all pending completions
        bluetoothManager.reset()
        deviceInformation = nil
        bolusManager.reset()
        basalManager.reset()
        pumpHistoryEventManager.reset()
        state.uuidToHandleMap = [:]
        state.setupCompleted = false
        resetCounters()
        shouldSendBeepRequest = false
    }

    private func disconnect() {
        loggingDelegate?.logConnectionEvent()
        bolusManager.startEstimatingBolusProgress()
        resetCounters()
        delegate?.pumpConnectionStatusChanged(self)
    }
    
    public func resetCounters() {
        log.debug("%{public}@", #function)
        // E2E counters reset with every connection
        idControlPoint.resetE2ECounter()
        state.idControlPointNextE2ECounter = idControlPoint.e2eCounter
        idStatusReader.resetE2ECounter()
        state.idStatusReaderNextE2ECounter = idStatusReader.e2eCounter
        recordAccessControlPoint.resetE2ECounter()
        state.recordAccessControlPointNextE2ECounter = recordAccessControlPoint.e2eCounter
    }
    
    //MARK: Procedure handling

    open func reportErrorToAllPendingProcedureCompletions(_ error: DeviceCommError) {
        loggingDelegate?.logErrorEvent("error: \(String(describing: error))")
        
        // copy & reset
        let idControlPointPendingProcedures = idControlPoint.getPendingProceduresAndReset()
        let idStatusReaderPendingProcedures = idStatusReader.getPendingProceduresAndReset()
        let recordAccessControlPointPendingProcedures = recordAccessControlPoint.getPendingProceduresAndReset()
        let deviceTimePendingProcedures = dtControlPoint.getPendingProceduresAndReset()
        let readRequestPendingProcedures = getReadRequestQueuePendingProceduresAndReset()
        let pendingAnnunciationCompletions = getPendingAnnunciationCompletionsAndReset()
        
        // report
        // control point
        for (procedureID, completion) in idControlPointPendingProcedures {
            reportErrorToPendingCompletion(error, forProcedureID: procedureID, completion)
        }
        
        // status reader
        for (procedureID, completion) in idStatusReaderPendingProcedures {
            reportErrorToPendingCompletion(error, forProcedureID: procedureID, completion)
        }
        
        // RACP
        for (procedureID, completion) in recordAccessControlPointPendingProcedures {
            reportErrorToPendingCompletion(error, forProcedureID: procedureID, completion)
        }
                
        // device time
        for (procedureID, completion) in deviceTimePendingProcedures {
            reportErrorToPendingCompletion(error, forProcedureID: procedureID, completion)
        }
        
        // read queue
        for (procedureID, completion) in readRequestPendingProcedures {
            reportErrorToPendingCompletion(error, forProcedureID: procedureID, completion)
        }
        
        // pending annunciation completions
        for (procedureID, completion) in pendingAnnunciationCompletions {
            reportErrorToPendingCompletion(error, forProcedureID: procedureID, completion)
        }
    }

    public func reportErrorToPendingCompletion(_ error: DeviceCommError, forProcedureID procedureID: ProcedureID?, _ completion: Any?) {
        guard let procedureID = procedureID,
              let completion = completion
        else { return }

        loggingDelegate?.logErrorEvent("procedure \(procedureID) encountered error \(error)")
        
        switch completion {
        case let completion as ProcedureResultCompletion:
            completion(.failure(error))
        case let completion as BolusDeliveryStatusCompletion:
            completion(.failure(error))
        case let completion as PumpDeliveryStatusCompletion:
            completion(.failure(error))
        case let completion as ProcedureTimeCompletion:
            completion(.failure(error))
        default:
            assertionFailure("Pending completion type is unknown \(completion)")
        }
    }

    public func reportSuccessToPendingCompletionForProcedureID(_ procedureID: ProcedureID?, _ completion: Any?) {
        guard let procedureID = procedureID,
              let completion = completion
        else { return }

        loggingDelegate?.logReceiveEvent("Procedure \(String(describing: procedureID)) was successful")
        
        switch completion {
        case let completion as ProcedureResultCompletion:
            completion(.success)
        case let completion as BolusDeliveryStatusCompletion:
            completion(.success(bolusManager.activeBolusDeliveryStatus))
        case let completion as PumpDeliveryStatusCompletion:
            completion(.success(deviceInformation))
        default:
            assertionFailure("Pending completion type is unknown \(completion)")
        }
    }
    
    public func reportResultToReadRequestProcedure(_ procedureID: ProcedureID?, result: DeviceCommResult<Void>) {
        guard !lockedReadRequestQueue.value.isEmpty else { return }
        
        var queuedProcedures: [(cbUUID: CBUUID, procedureID: ProcedureID, completion: Any?)] = []
        lockedReadRequestQueue.mutate { readRequestQueue in
            queuedProcedures = readRequestQueue.filter { $0.procedureID == procedureID }
            guard !queuedProcedures.isEmpty else { return }
            
            readRequestQueue = readRequestQueue.filter { $0.procedureID != procedureID }
        }

        for (_ , queuedProcedureID, queuedCompletion) in queuedProcedures {
            switch result {
            case .success:
                reportSuccessToPendingCompletionForProcedureID(queuedProcedureID, queuedCompletion)
            case .failure(let error):
                if error != .procedureInProgress {
                    // if a procedure is in progress, this request is queue and will be sent later
                    reportErrorToPendingCompletion(error, forProcedureID: queuedProcedureID, queuedCompletion)
                }
            }
        }
    }

    //MARK: - Requests
    open func sendNextReadRequest() {
        guard let (cbUUID, procedureID, _) = lockedReadRequestQueue.value.first else { return }
        
        guard isAuthorizationControlRequired else {
            // TODO send a read request
            return
        }
        
        readRequestInProgress = sendSecureRead(to: getResourceHandle(for: cbUUID)) { [weak self] result in
            guard let self else { return }
            self.reportResultToReadRequestProcedure(procedureID, result: result)
            self.readRequestInProgress = false
            self.sendNextPendingSecureRequest()
        }
    }

    func sendSecureRead(to resourceHandle: ResourceHandle?, completion: @escaping ProcedureResultCompletion) -> Bool {
        sendSecureRequest(nil, to: resourceHandle, completion: completion)
    }

    func sendSecureRequest(_ request: Data?, to resourceHandle: ResourceHandle?, completion: @escaping ProcedureResultCompletion) -> Bool {
        guard let peripheralManager = peripheralManager else {
            loggingDelegate?.logErrorEvent("Cannot make a request to resource: \(String(describing: resourceHandle)). No peripheral manager")
            let error = DeviceCommError.deviceNotReady
            reportErrorToAllPendingProcedureCompletions(error)
            completion(.failure(error))
            return false
        }

        guard let resourceHandle = resourceHandle else {
            loggingDelegate?.logErrorEvent("Cannot make a request to resource: \(String(describing: resourceHandle)). No resource handle")
            let error = DeviceCommError.deviceNotReady
            reportErrorToAllPendingProcedureCompletions(error)
            completion(.failure(error))
            return false
        }

        guard !procedureInProgress else {
            loggingDelegate?.logErrorEvent("procedure already in progress")
            completion(.failure(.procedureInProgress))
            return false
        }

        peripheralManager.perform { [weak self] peripheralManager in
            guard let self = self else { return }
            
            self.loggingDelegate?.logSendEvent("sending secure request \(self.getResourceProcedureID(for: resourceHandle)), raw request: \(String(describing: request?.toHexString()))")
            let result = self.acData.sendRequest(request, resourceHandle: resourceHandle, peripherialManager: peripheralManager, timeout: 10)
            completion(result)
        }
        return true
    }

    open var procedureInProgress: Bool {
        return acControlPoint.procedureRunning ||
        idControlPoint.procedureRunning ||
        idStatusReader.procedureRunning ||
        recordAccessControlPoint.procedureRunning
    }

    func sendNextPendingSecureRequest() {
        guard !procedureInProgress else { return }

        // ordered by priority of request
        if shouldSendBeepRequest {
            sendBeepRequest()
        } else if idControlPoint.hasRequestToSend {
            sendNextRequestToInsulinDeliveryControlPoint()
        } else if idStatusReader.hasRequestToSend {
            sendNextRequestToInsulinDeliveryStatusReader()
        } else if dtControlPoint.hasRequestToSend {
            sendNextRequestToDeviceTimeControlPoint()
        } else if !lockedReadRequestQueue.value.isEmpty {
            sendNextReadRequest()
        } else if recordAccessControlPoint.hasRequestToSend {
            sendNextRequestToRecordAccessControlPoint()
        }
    }
    
    func getResourceHandle(for uuid: CBUUID) -> UInt16? {
        state.uuidToHandleMap[uuid]
    }

    func getCBUUID(for resourceHandle: ResourceHandle) -> CBUUID? {
        state.uuidToHandleMap.first(where: { $1 == resourceHandle })?.key
    }

    open func getResourceProcedureID(for resourceHandle: ResourceHandle?) -> ProcedureID {
        guard let resourceHandle = resourceHandle,
              let uuidString = state.uuidToHandleMap.first(where: { $1 == resourceHandle })?.key.uuidString.lowercased()
        else {
            return "unknown procedure ID"
        }

        if let characteristic = ImmediateAlertCharacteristicUUID(rawValue: uuidString) {
            return characteristic.procedureID
        } else if let characteristic = InsulinDeliveryCharacteristicUUID(rawValue: uuidString) {
            return characteristic.procedureID
        } else if let characteristic = BatteryCharacteristicUUID(rawValue: uuidString) {
            return characteristic.procedureID
        } else if let characteristic = ACCharacteristicUUID(rawValue: uuidString) {
            return characteristic.procedureID
        } else if let characteristic = DeviceInfoCharacteristicUUID(rawValue: uuidString) {
            return characteristic.procedureID
        } else if let characteristic = DeviceTimeCharacteristicUUID(rawValue: uuidString) {
            return characteristic.procedureID
        } else {
            return "unknown procedure ID"
        }
    }
    
    //MARK: Immediate Alert Service Requests
    func sendBeepRequest() {
        loggingDelegate?.logSendEvent()
        shouldSendBeepRequest = !sendSecureRequest(ImmediateAlertService.createBeepRequest(), to: getResourceHandle(for: ImmediateAlertCharacteristicUUID.alertLevel.cbUUID)) { _ in }
    }

    //MARK: Authorization Control Service Requests
    func sendNextSecureRequestToACControlPoint() {
        guard let (request, completion) = acControlPoint.nextRequestToSend() else { return }

        let procedureID = acControlPoint.procedureIDForRequest(request)
        loggingDelegate?.logSendEvent("Procedure \(procedureID), raw request: \(request.toHexString())")
        acControlPoint.procedureRunning = sendSecureRequest(request, to: getResourceHandle(for: ACCharacteristicUUID.controlPoint.cbUUID)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                self.acControlPoint.procedureRunning = error == .procedureInProgress
                if error != .procedureInProgress {
                    // if there is a procedure in progress, this procedure is queued and will be requested later
                    self.reportErrorToPendingCompletion(error, forProcedureID: procedureID, completion)
                }
            default:
                break
            }
        }
    }

    public func invalidateKey(completion: @escaping ProcedureResultCompletion) {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            completion(.failure(.disconnected))
            return
        }

        loggingDelegate?.logSendEvent()
        acControlPoint.queueInvalidateKeyRequest(completion: completion)
        sendNextPendingSecureRequest()
    }

    //MARK: Device Time Service Requests
    func sendNextRequestToDeviceTimeControlPoint() {
        guard let (request, completion) = dtControlPoint.nextRequestToSend() else { return }
        
        guard isAuthorizationControlRequired else {
            // TODO send basic request
            return
        }
        
        let procedureID = dtControlPoint.procedureIDForRequest(request)
        loggingDelegate?.logSendEvent("Procedure \(procedureID), raw request: \(request.toHexString())")
        dtControlPoint.procedureRunning = sendSecureRequest(request, to: getResourceHandle(for: DeviceTimeCharacteristicUUID.controlPoint.cbUUID)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                break
            case .failure(let error):
                self.dtControlPoint.procedureRunning = error == .procedureInProgress
                if error != .procedureInProgress {
                    // if there is a procedure in progress, this procedure is queued and will be requested later
                    self.reportErrorToPendingCompletion(error, forProcedureID: procedureID, completion)
                }
            }
        }
    }

    public func getTime(using timeZone: TimeZone, completion: @escaping ProcedureTimeCompletion) {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            completion(.failure(.disconnected))
            return
        }

        loggingDelegate?.logSendEvent("Getting pump time for time zone: \(timeZone)")

        let procedureID = DeviceTimeCharacteristicUUID.deviceTime.procedureID
        appendToReadRequestQueue(cbUUID: DeviceTimeCharacteristicUUID.deviceTime.cbUUID, procedureID: procedureID, completion: nil)
        deviceTime.queueGetDateTimeRequest(completion: completion)
        sendNextPendingSecureRequest()
    }

    public func setTime(_ date: Date, using timeZone: TimeZone, completion: @escaping ProcedureResultCompletion) {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            completion(.failure(.disconnected))
            return
        }

        loggingDelegate?.logSendEvent("Setting time of pump: \(date) time zone: \(timeZone)")

        dtControlPoint.queueProposeTimeUpdateRequest(date, using: timeZone, completion: completion)
        sendNextPendingSecureRequest()
    }

    //MARK: Insulin Delivery Service Requests
    func sendNextRequestToInsulinDeliveryStatusReader() {
        guard var (request, _) = idStatusReader.nextRequestToSend() else { return }

        // add the E2E protection before sending
        if isE2EProtectionRequired {
            request = idStatusReader.appendingE2EProtection(request)
        }
        
        guard isAuthorizationControlRequired else {
            // TODO send basic request
            return
        }
        
        loggingDelegate?.logSendEvent("Procedure \(idStatusReader.procedureIDForRequest(request)), raw request: \(request.toHexString())")
        idStatusReader.procedureRunning = sendSecureRequest(request, to: getResourceHandle(for: InsulinDeliveryCharacteristicUUID.statusReaderControlPoint.cbUUID)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.idStatusReader.incrementE2ECounter()
                self.state.idStatusReaderNextE2ECounter = self.idStatusReader.e2eCounter
            case .failure(let error):
                self.idStatusReader.procedureRunning = error == .procedureInProgress
                if error != .procedureInProgress { // if there is a procedure in progress, this procedure is queued and will be requested later
                    for (procedureID, completion) in self.idStatusReader.getPendingProceduresAndReset() {
                        self.reportErrorToPendingCompletion(error, forProcedureID: procedureID, completion)
                    }
                }
            }
        }
    }
    
    func sendNextRequestToInsulinDeliveryControlPoint() {
        guard var (request, _) = idControlPoint.nextRequestToSend() else { return }

        if isE2EProtectionRequired {
            request = idControlPoint.appendingE2EProtection(request)
        }
        
        guard isAuthorizationControlRequired else {
            // TODO just send a basic command
            return
        }

        loggingDelegate?.logSendEvent("Procedure \(idControlPoint.procedureIDForRequest(request)), raw request: \(request.toHexString())")
        idControlPoint.procedureRunning = sendSecureRequest(request, to: getResourceHandle(for: InsulinDeliveryCharacteristicUUID.commandControlPoint.cbUUID)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.idControlPoint.incrementE2ECounter()
                self.state.idControlPointNextE2ECounter = self.idControlPoint.e2eCounter
            case .failure(let error):
                self.idControlPoint.procedureRunning = error == .procedureInProgress
                if error != .procedureInProgress {
                    // if there is a procedure in progress, this procedure is queued and will be requested later
                    for (procedureID, completion) in self.idControlPoint.getPendingProceduresAndReset() {
                        reportErrorToPendingCompletion(error, forProcedureID: procedureID, completion)
                    }
                }
            }
        }
    }

    func sendNextRequestToRecordAccessControlPoint() {
        guard var (request, _) = recordAccessControlPoint.nextRequestToSend() else { return }

        // add the E2E protection before sending
        if isE2EProtectionRequired {
            request = recordAccessControlPoint.appendingE2EProtection(request)
            
        }

        guard isAuthorizationControlRequired else {
            // TODO send basic request
            return
        }
        
        loggingDelegate?.logSendEvent("Procedure \(recordAccessControlPoint.procedureIDForRequest(request)), raw request: \(request.toHexString())")
        recordAccessControlPoint.procedureRunning = sendSecureRequest(request, to: getResourceHandle(for: InsulinDeliveryCharacteristicUUID.recordAccessControlPoint.cbUUID)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.recordAccessControlPoint.incrementE2ECounter()
                self.state.recordAccessControlPointNextE2ECounter = self.recordAccessControlPoint.e2eCounter
            case .failure(let error):
                self.recordAccessControlPoint.procedureRunning = error == .procedureInProgress
                if error != .procedureInProgress {
                    // if there is a procedure in progress, this procedure is queued and will be requested later
                    for (procedureID, completion) in self.recordAccessControlPoint.getPendingProceduresAndReset() {
                        reportErrorToPendingCompletion(error, forProcedureID: procedureID, completion)
                    }
                }
            }
        }
    }
    
    public func prepareForInsulinDelivery(reservoirLevel: Int, basalSegments: [BasalSegment], completion: @escaping ProcedureResultCompletion) {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            completion(.failure(.disconnected))
            return
        }

        state.initialReservoirLevel = reservoirLevel
        loggingDelegate?.logSendEvent("Setting reservoirLevel \(reservoirLevel), basalSegments: \(String(describing: basalSegments))")
        let activateBasalRateScheduleCompletion: ProcedureResultCompletion = { [weak self] result in
            guard let self = self else {
                completion(result)
                return
            }
            switch result {
            case .success():
                self.loggingDelegate?.logReceiveEvent("Did set reservoirLevel \(reservoirLevel), basalSegments: \(String(describing: basalSegments))")
                self.delegate?.pumpDidCompleteTherapyUpdate(self)
            default:
                break
            }
            completion(result)
        }
        idControlPoint.queueInsulinSetupRequests(fillValue: reservoirLevel, basalSegments: basalSegments, completion: activateBasalRateScheduleCompletion)
        sendNextPendingSecureRequest()
    }
    
    public func startPrimingReservoir(_ amount: Double, completion: @escaping ProcedureResultCompletion) {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            completion(.failure(.disconnected))
            return
        }

        loggingDelegate?.logSendEvent()
        idControlPoint.queueStartPrimingRequest(amount, completion: completion)
        sendNextPendingSecureRequest()
    }
    
    public func primeCannula(_ amount: Double, completion: @escaping ProcedureResultCompletion) {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            completion(.failure(.disconnected))
            return
        }
        
        loggingDelegate?.logSendEvent()
        idControlPoint.queuePrimeCannulaRequest(amount, completion: completion)
        sendNextPendingSecureRequest()
    }
    
    public func stopPriming(completion: @escaping ProcedureResultCompletion) {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            completion(.failure(.disconnected))
            return
        }

        loggingDelegate?.logSendEvent()
        idControlPoint.queueStopPrimingRequest(completion: completion)
        sendNextPendingSecureRequest()
    }
    
    public func startInsulinDelivery(completion: @escaping PumpDeliveryStatusCompletion) {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            completion(.failure(.disconnected))
            return
        }

        loggingDelegate?.logSendEvent()
        idControlPoint.queueStartInsulinTherapyRequest(completion: completion)
        sendNextPendingSecureRequest()
    }
    
    public func suspendInsulinDelivery(completion: @escaping PumpDeliveryStatusCompletion) {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            completion(.failure(.disconnected))
            return
        }

        let suspendInsulinDeliveryHanlder: (_ completion: @escaping PumpDeliveryStatusCompletion) -> Void = { [weak self] completion in
            guard let self = self else { return  }
            self.loggingDelegate?.logSendEvent("suspending insulin delivery")
            self.idControlPoint.queueStopInsulinTherapyRequest(completion: completion)
            self.sendNextPendingSecureRequest()
        }
        
        guard state.activeTempBasalDeliveryStatus.isTempBasalActive else {
            suspendInsulinDeliveryHanlder(completion)
            return
        }
            
        // get the delivered insulin for the active temp basal that will be cancelled
        getDeliveredInsulin() { [weak self] result in
            switch result {
            case .success:
                suspendInsulinDeliveryHanlder(completion)
            case .failure(let error):
                self?.loggingDelegate?.logErrorEvent("Failed to suspend insulin delivery. Could not get delivered insulin")
                completion(.failure(error))
            }
        }
    }

    public func getAnnunciationStatus(completion: @escaping ProcedureResultCompletion = { _ in }) {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            completion(.failure(.disconnected))
            return
        }

        loggingDelegate?.logSendEvent()
        let procedureID = InsulinDeliveryCharacteristicUUID.annunciationStatus.procedureID
        appendToReadRequestQueue(cbUUID: InsulinDeliveryCharacteristicUUID.annunciationStatus.cbUUID, procedureID: procedureID, completion: completion)
        sendNextPendingSecureRequest()
    }
    
    public func confirmAnnunciation(_ annunciation: Annunciation, completion: @escaping ProcedureResultCompletion) {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            completion(.failure(.disconnected))
            return
        }

        loggingDelegate?.logSendEvent("Confirming annunciation: \(String(describing: annunciation))")
        idControlPoint.queueConfirmAnnunciationRequest(for: annunciation.identifier, completion: completion)
        sendNextPendingSecureRequest()
    }
    
    public func getInsulinDeliveryStatus(completion: @escaping ProcedureResultCompletion = { _ in }) {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            completion(.failure(.disconnected))
            return
        }

        loggingDelegate?.logSendEvent()
        let procedureID = InsulinDeliveryCharacteristicUUID.status.procedureID
        appendToReadRequestQueue(cbUUID: InsulinDeliveryCharacteristicUUID.status.cbUUID, procedureID: procedureID, completion: completion)
        sendNextPendingSecureRequest()
    }
    
    private func getInsulinDeliveryFeatures(completion: @escaping ProcedureResultCompletion = { _ in }) {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            completion(.failure(.disconnected))
            return
        }

        loggingDelegate?.logSendEvent()
        let procedureID = InsulinDeliveryCharacteristicUUID.features.procedureID
        appendToReadRequestQueue(cbUUID: InsulinDeliveryCharacteristicUUID.features.cbUUID, procedureID: procedureID, completion: completion)
        sendNextPendingSecureRequest()
    }
    
    public func setBasalRateSchedule(_ basalSegments: [BasalSegment], completion: @escaping ProcedureResultCompletion) {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            completion(.failure(.disconnected))
            return
        }

        loggingDelegate?.logSendEvent("Request set basal rate schedule: \(String(describing: basalSegments))")
        idControlPoint.queueWriteBasalRateRequests(for: basalSegments, completion: completion)
        sendNextPendingSecureRequest()
    }

    public func setBolus(_ amount: Double, activationType: IDBolusActivationType, completion: @escaping BolusDeliveryStatusCompletion) {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            completion(.failure(.disconnected))
            return
        }

        loggingDelegate?.logSendEvent("Requesting bolus of amount: \(amount), activation type: \(activationType)")
        idControlPoint.queueSetBolusRequest(for: amount, activationType: activationType, completion: completion)
        sendNextPendingSecureRequest()
    }

    public func cancelBolus(completion: @escaping BolusDeliveryStatusCompletion) {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            completion(.failure(.disconnected))
            return
        }

        if idControlPoint.didQueueCancelCurrentBolusRequest() {
            loggingDelegate?.logSendEvent("Canceling bolus with ID: \(String(describing: bolusManager.activeBolusDeliveryStatus.id))")
            appendPendingAnnunciationCompletion(procedureID: IDControlPointOpcode.cancelBolus.procedureID, completion: completion)
            sendNextPendingSecureRequest()
        } else {
            loggingDelegate?.logErrorEvent("Could not create cancel bolus request")
            completion(.failure(.procedureNotApplicable))
        }
    }

    public func updateActiveBolusDeliveryDetails(updateHandler: @escaping (BolusDeliveryStatus) -> Void) {
        guard isBolusActive else {
            updateHandler(.noActiveBolus)
            return
        }

        // assign the active bolus update handler even if the pump is not connected
        bolusManager.activeBolusDeliveryUpdateHandler = { [weak self] bolusDeliveryStatus in
            guard let self = self else { return }
            self.loggingDelegate?.logReceiveEvent("Received updated bolus details \(bolusDeliveryStatus)")
            updateHandler(bolusDeliveryStatus)

            switch bolusDeliveryStatus.progressState {
            case .canceled, .completed, .noActiveBolus:
                self.loggingDelegate?.logReceiveEvent("Bolus with ID \(String(describing: self.bolusManager.activeBolusDeliveryStatus.id)) reported as \(bolusDeliveryStatus.progressState)")

                // no longer a need to get updates for this bolus
                self.bolusManager.resetActiveBolus()

                if bolusDeliveryStatus.progressState == .canceled {
                    self.getAnnunciationStatus()
                }
                
                // Now that this bolus is finished, get history events to finalize the bolus and then reset active bolus status changed
                self.getPumpHistoryEvents() { _ in
                    self.resetStatusChanged([.activeBolusStatusChanged, .historyEventRecordedChanged]) { _ in }
                }
            default:
                break
            }
        }

        guard bolusManager.activeBolusDeliveryStatus.progressState != .estimatingProgress else {
            loggingDelegate?.logConnectionEvent("Pump not ready. Estimating bolus progress")
            // report the updated the bolus progress estimation
            bolusManager.updateEstimatedBolusDeliveryStatus()
            return
        }

        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            // start bolus progress estimation
            bolusManager.startEstimatingBolusProgress()
            return
        }

        getActiveBolusDeliveredDetails()
    }
    
    public func getRemainingLifetime(completion: @escaping ProcedureResultCompletion) {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            completion(.failure(.disconnected))
            return
        }

        loggingDelegate?.logSendEvent("Get remaining lifetime of pump")
        idStatusReader.queueGetRemainingLifetimeRequest(completion: completion)
        sendNextPendingSecureRequest()
    }
    
    func getDeliveredInsulin(completion: @escaping ProcedureResultCompletion) {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            completion(.failure(.disconnected))
            return
        }

        loggingDelegate?.logSendEvent("Get delivered insulin")
        idStatusReader.queueGetDeliveredInsulinRequest(completion: completion)
        sendNextPendingSecureRequest()
    }
    
    func getActiveBasalRateDelivery(completion: @escaping ProcedureResultCompletion) {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            completion(.failure(.disconnected))
            return
        }
        
        loggingDelegate?.logSendEvent("Get active basal rate delivery")
        idStatusReader.queueGetActiveBasalRateDelivery(completion: completion)
        sendNextPendingSecureRequest()
    }

    func getInsulinDeliveryStatusChanged(completion: @escaping ProcedureResultCompletion) {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            completion(.failure(.disconnected))
            return
        }

        loggingDelegate?.logSendEvent("Get insulin delivery status changed flags")
        let procedureID = InsulinDeliveryCharacteristicUUID.statusChanged.procedureID
        appendToReadRequestQueue(cbUUID: InsulinDeliveryCharacteristicUUID.statusChanged.cbUUID, procedureID: procedureID, completion: completion)
        sendNextPendingSecureRequest()
    }

    func resetStatusChanged(_ statusToReset: IDStatusChangedFlag, completion: @escaping ProcedureResultCompletion) {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            completion(.failure(.disconnected))
            return
        }
        
        loggingDelegate?.logSendEvent("Resetting status changed for \(statusToReset)")
        idStatusReader.queueResetStatusChangedRequest(statusToReset, completion: completion)
        sendNextPendingSecureRequest()
    }

    func getActiveBolusDetails() {
        self.getActiveBolusIDs() { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success():
                if self.isBolusActive {
                    self.getActiveBolusProgrammedDetails() { [weak self] result in
                        guard let self = self else { return }
                        switch result {
                        case .success():
                            guard let bolusID = self.bolusManager.activeBolusDeliveryStatus.id else { return }
                            // this may be a bolus programmed directly on the pump, since it was unknown. report of such
                            self.delegate?.pumpDidInitiateBolus(self, bolusID: bolusID, insulinProgrammed: self.bolusManager.activeBolusDeliveryStatus.insulinProgrammed, startTime: Date())
                        case .failure(let error):
                            self.loggingDelegate?.logErrorEvent("Failed to get the active bolus delivered details: \(String(describing: error.errorDescription))")
                        }
                    }
                }
            case .failure(let error):
                self.loggingDelegate?.logErrorEvent("Failed to get the active bolus IDs: \(String(describing: error.errorDescription))")
            }
        }
    }

    func getActiveBolusIDs(completion: @escaping ProcedureResultCompletion) {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            completion(.failure(.disconnected))
            return
        }

        loggingDelegate?.logSendEvent()
        idStatusReader.queueGetActiveBolusIDs(completion: completion)
        sendNextPendingSecureRequest()
    }

    func getActiveBolusDeliveredDetails(completion: ProcedureResultCompletion? = nil) {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            completion?(.failure(.disconnected))
            return
        }

        loggingDelegate?.logSendEvent("Requesting active bolus delivered details for bolus with ID \(String(describing: bolusManager.activeBolusDeliveryStatus.id))")

        guard idStatusReader.didQueueGetActiveBolusDeliveredDetailsRequest(completion: completion) else {
            completion?(.failure(.procedureNotApplicable))
            return
        }
        sendNextPendingSecureRequest()
    }

    func getActiveBolusProgrammedDetails(completion: ProcedureResultCompletion? = nil) {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            completion?(.failure(.disconnected))
            return
        }

        loggingDelegate?.logSendEvent("Requesting active bolus programmed details for bolus with ID \(String(describing: bolusManager.activeBolusDeliveryStatus.id))")

        guard idStatusReader.didQueueGetActiveBolusProgrammedDetailsRequest(completion: completion) else { return }
        sendNextPendingSecureRequest()
    }
    
    public func setTempBasal(unitsPerHour: Double,
                             durationInMinutes: UInt16,
                             replaceExisting: Bool,
                             deliveryContext: TempBasalDeliveryContext,
                             completion: @escaping ProcedureResultCompletion)
    {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            completion(.failure(.disconnected))
            return
        }
        
        let setTempBasalHandler: (_ unitsPerHour: Double, _ durationInMinutes: UInt16, _ replaceExisting: Bool, _ deliveryContext: TempBasalDeliveryContext, _ completion: @escaping ProcedureResultCompletion) -> Void = { [weak self] unitsPerHour, durationInMinutes, replaceExisting, deliveryContext, completion in
            guard let self = self else {
                completion(.failure(.unknown))
                return
            }
            self.loggingDelegate?.logSendEvent("Requesting temp basal with rate: \(unitsPerHour), duration: \(durationInMinutes), deliveryContext: \(deliveryContext), replace existing: \(replaceExisting.description)")
            self.idControlPoint.queueSetTempBasalRequest(unitsPerHour: unitsPerHour, durationInMinutes: durationInMinutes, deliveryContext: deliveryContext, replaceExisting: replaceExisting, completion: completion)
            self.sendNextPendingSecureRequest()
        }
        
        guard replaceExisting else {
            setTempBasalHandler(unitsPerHour, durationInMinutes, replaceExisting, deliveryContext, completion)
            return
        }

        // get the delivered amount for the temp basal that is being replaced
        getDeliveredInsulin() { [weak self] result in
            switch result {
            case .success:
                setTempBasalHandler(unitsPerHour, durationInMinutes, replaceExisting, deliveryContext, completion)
            case .failure(let error):
                self?.loggingDelegate?.logErrorEvent("Failed to set temp basal. Could not get delivered insulin")
                completion(.failure(error))
            }
        }
    }
    
    public func cancelTempBasal(completion: @escaping ProcedureResultCompletion) {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            completion(.failure(.disconnected))
            return
        }

        // get the delivered insulin for the temp basal being cancelled
        getDeliveredInsulin() { [weak self] result in
            switch result {
            case .success:
                self?.loggingDelegate?.logSendEvent("Canceling temp basal.")
                self?.idControlPoint.queueCancelTempBasalRequest(completion: completion)
                self?.sendNextPendingSecureRequest()
            case .failure(let error):
                self?.loggingDelegate?.logErrorEvent("Failed to cancel temp basal. Could not get delivered insulin")
                completion(.failure(error))
            }
        }
    }

    func getMostCurrentReferenceTimeHistoryEvent(completion: @escaping ProcedureResultCompletion) {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            completion(.failure(.disconnected))
            return
        }

        loggingDelegate?.logSendEvent()
        recordAccessControlPoint.queueGetMostCurrentStoredReferenceTimeRecordRequest(completion: completion)
        sendNextPendingSecureRequest()
    }

    func getOldestHistoryEvent(completion: @escaping ProcedureResultCompletion) {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            completion(.failure(.disconnected))
            return
        }

        loggingDelegate?.logSendEvent()
        recordAccessControlPoint.queueOldestStoredRecordRequest(completion: completion)
        sendNextPendingSecureRequest()
    }

    var isReceivingHistoryEvents: Bool {
        recordAccessControlPoint.isReceivingHistoryEvents
    }

    func getPumpHistoryEvents(completion: @escaping ProcedureResultCompletion) {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            completion(.failure(.disconnected))
            return
        }

        if let lastReceivedHistoryEventSequenceNumber = self.lastReceivedHistoryEventSequenceNumber {
            loggingDelegate?.logSendEvent("Getting all history events since sequence number \(lastReceivedHistoryEventSequenceNumber)")
            recordAccessControlPoint.queueGetAllStoredRecordsRequest(startingAtSequenceNumber: lastReceivedHistoryEventSequenceNumber+1, completion: completion)
            sendNextPendingSecureRequest()
        } else {
            // No history events received for this pump. Since the pump is new, get the most recent reference time event and start collecting history since then
            loggingDelegate?.logSendEvent("No history events received for this pump.")
            getMostCurrentReferenceTimeHistoryEvent() { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success:
                    self.getPumpHistoryEvents(completion: completion)
                case .failure(let error):
                    self.loggingDelegate?.logErrorEvent("Could not get most current reference time event: \(String(describing: error.errorDescription))")
                    completion(result)
                }
            }
        }
    }
    
    //MARK: Device Information Service Requests
    private func getFirmwareRevision() {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            return
        }

        loggingDelegate?.logSendEvent()
        appendToReadRequestQueue(cbUUID: DeviceInfoCharacteristicUUID.firmwareRevisionString.cbUUID, procedureID: DeviceInfoCharacteristicUUID.firmwareRevisionString.procedureID, completion: nil)
        sendNextPendingSecureRequest()
    }
    
    private func getHardwareRevision() {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            return
        }

        loggingDelegate?.logSendEvent()
        appendToReadRequestQueue(cbUUID: DeviceInfoCharacteristicUUID.hardwareRevisionString.cbUUID, procedureID: DeviceInfoCharacteristicUUID.hardwareRevisionString.procedureID, completion: nil)
        sendNextPendingSecureRequest()
    }
    
    //MARK: Battery Service Requests
    public func getBatteryLevel() {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            return
        }

        loggingDelegate?.logSendEvent()
        appendToReadRequestQueue(cbUUID: BatteryCharacteristicUUID.batteryLevel.cbUUID, procedureID: BatteryCharacteristicUUID.batteryLevel.procedureID, completion: nil)
        sendNextPendingSecureRequest()
    }

    //MARK: Pump status
    public func updateStatus(completion: @escaping PumpDeliveryStatusCompletion) {
        guard isConnected else {
            loggingDelegate?.logConnectionEvent("Pump not currently connected")
            completion(.failure(.disconnected))
            return
        }


        guard isAuthenticated else {
            loggingDelegate?.logConnectionEvent("Pump authentication failed")
            completion(.failure(.authenticationFailed))
            return
        }

        guard deviceInformation != nil else {
            loggingDelegate?.logErrorEvent("Pump not configured correctly")
            completion(.failure(.deviceNotReady))
            return
        }

        // get current status
        self.loggingDelegate?.logSendEvent("Getting insulin delivery status.")
        getInsulinDeliveryStatus() { [weak self] result in
            switch result {
            case .success:
                self?.updatePumpDetails(completion: completion)
            case .failure(let error):
                guard error == .procedureInProgress else {
                    completion(.failure(error))
                    return
                }
                // if another procedure is in progress, the cached insulin delivery status is current
                self?.updatePumpDetails(completion: completion)
            }
        }
    }

    private func updatePumpDetails(completion: @escaping PumpDeliveryStatusCompletion) {
        loggingDelegate?.logSendEvent("Getting remaining lifetime.")
        getRemainingLifetime() { [weak self] result in
            switch result {
            case .success:
                // check is there are any changes to sync with
                self?.loggingDelegate?.logSendEvent("Checking for status changes to sync.")
                self?.getInsulinDeliveryStatusChanged() { [weak self] result in
                    switch result {
                    case .success:
                        completion(.success(self?.deviceInformation))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    open func serialNumber(fromAdvertisementData advertisementData: [String: Any]?) -> String? {
        return nil
    }
    
    open func bluetoothManager(_ manager: BluetoothManager,
                                 peripheralManager: PeripheralManager,
                                 isReadyWithError error: Error?)
    {
        loggingDelegate?.logConnectionEvent("peripheral: \(peripheralManager), error: \(String(describing: error))")
        if isConnected {
            peripheralManager.perform { [weak self] peripheralManager in
                guard let self = self else { return }
                
                if self.securityManager.applicationSecurityEstablished {
                    self.getInsulinDeliveryStatus() { [weak self] result in
                        guard let self = self else { return }
                        switch result {
                        case .success():
                            if self.bolusManager.isBolusActive {
                                self.getActiveBolusDeliveredDetails() { _ in }
                            }

                            // REMOVE: reconnected. make the pump beep as a sanity check
                            self.sendBeepRequest()

                            if self.state.setupCompleted {
                                self.loggingDelegate?.logSendEvent("Setup is completed. Checking for status changes to sync.")
                                // check remaining lifetime of the pump
                                self.getRemainingLifetime() { result in
                                    switch result {
                                    case .success:
                                        // trigger reading pump status changes (e.g., new history, new bolus) with each connection if the pump is setup
                                        self.getInsulinDeliveryStatusChanged() { _ in }
                                    default:
                                        break
                                    }
                                }
                            }

                            // report after it is known that authentication works, otherwise a disconnect occurs
                            self.delegate?.pumpConnectionStatusChanged(self)
                            self.delegate?.pumpDidCompleteAuthentication(self)
                        default:
                            break
                        }
                    }
                } else if !self.acControlPoint.hasRequestToSend {
                    self.startAuthentication(with: peripheralManager)
                }
            }
        } else if let nsError = error as NSError? {
            handleCBError(CBError(_nsError: nsError))
        }
    }
    
    open func bluetoothManager(_ manager: BluetoothManager, peripheralManager: PeripheralManager, didReceiveValue value: Data, fromCharactistic uuid: CBUUID) {
        state.lastCommsDate = Date()
        
        switch uuid {
        case ACCharacteristicUUID.status.cbUUID:
            manageACStatusData(value)
        case ACCharacteristicUUID.controlPoint.cbUUID:
            manageACControlPointResponse(peripheralManager, response: value)
        case ACCharacteristicUUID.dataOutNotify.cbUUID,  ACCharacteristicUUID.dataOutIndicate.cbUUID:
            manageACDataValue(value)
        default:
            loggingDelegate?.logErrorEvent("Unprotected value for characteristic UUID \(uuid) received: \(value)")
        }
        
        delegate?.pumpDidSync(self, pendingCommandCheckCompleted: false)
    }
    
    open func manageInsulinDeliveryStatusChangedData(_ data: Data) {
        let result = IDStatusChanged.handleData(data)
        loggingDelegate?.logReceiveEvent("Received insulin delivery status changed. results: \(result), data: \(data.toHexString())")
        switch result {
        case .success(let statusChangedFlags):
            loggingDelegate?.logReceiveEvent("Received insulin delivery status changed for: \(String(describing: statusChangedFlags))")

            // ignore status changes until setup is complete, while a bolus is being delivered, and while in a replacement workflow
            if state.setupCompleted,
               !bolusManager.isReportingBolus,
               !(delegate?.isInReplacementWorkflow ?? false)
            {
                if statusChangedFlags.contains(.activeBolusStatusChanged) {
                    resetStatusChanged(.activeBolusStatusChanged) { [weak self] result in
                        guard let self = self else { return }
                        switch result {
                        case .success:
                            self.loggingDelegate?.logReceiveEvent("Successfully reset the active bolus status changed")
                            self.getActiveBolusDetails()
                        case .failure(let error):
                            self.loggingDelegate?.logErrorEvent("Failed to reset the active bolus status changed: \(String(describing: error.errorDescription))")
                        }
                    }
                } else if statusChangedFlags.contains(.annunciationStatusChanged) {
                    resetStatusChanged(.annunciationStatusChanged) { [weak self] result in
                        guard let self = self else { return }
                        switch result {
                        case .success:
                            self.loggingDelegate?.logReceiveEvent("Successfully reset the annunciation status changed")
                            self.getAnnunciationStatus() { [weak self] result in
                                guard let self = self else { return }
                                switch result {
                                case .success:
                                    self.loggingDelegate?.logReceiveEvent("Successfully received annunciation status")
                                case .failure(let error):
                                    self.loggingDelegate?.logErrorEvent("Failed to get annunciation status: \(String(describing: error.errorDescription))")
                                }
                            }
                        case .failure(let error):
                            self.loggingDelegate?.logErrorEvent("Failed to reset the annunciation status changed: \(String(describing: error.errorDescription))")
                        }
                    }
                } else if statusChangedFlags.contains(.activeBasalRateStatusChanged) {
                    resetStatusChanged(.activeBasalRateStatusChanged) { [weak self] result in
                        guard let self = self else { return }
                        switch result {
                        case .success:
                            self.loggingDelegate?.logReceiveEvent("Successfully reset the active basal rate status changed")
                            self.getDeliveredInsulin() { [weak self] result in
                                guard let self = self else { return }
                                switch result {
                                case .success:
                                    self.loggingDelegate?.logReceiveEvent("Successfully got delivered insulin")
                                    self.getActiveBasalRateDelivery() { [weak self] result in
                                        guard let self = self else { return }
                                        switch result {
                                        case .success:
                                            self.loggingDelegate?.logReceiveEvent("Successfully got active basal rate delivery")
                                        case .failure(let error):
                                            self.loggingDelegate?.logErrorEvent("Failed to get active basal rate delivery: \(String(describing: error.errorDescription))")
                                        }
                                    }
                                case .failure(let error):
                                    self.loggingDelegate?.logErrorEvent("Failed to get delivered insulin: \(String(describing: error.errorDescription))")
                                }
                            }
                        case .failure(let error):
                            self.loggingDelegate?.logErrorEvent("Failed to reset the active basal rate status changed: \(String(describing: error.errorDescription))")
                        }
                    }
                } else if statusChangedFlags.contains(.historyEventRecordedChanged) {
                    resetStatusChanged(.historyEventRecordedChanged) { [weak self] result in
                        guard let self = self else { return }
                        switch result {
                        case .success:
                            self.loggingDelegate?.logReceiveEvent("Successfully reset the history event recorded status changed")
                            self.getPumpHistoryEvents() { [weak self] result in
                                guard let self = self else { return }
                                switch result {
                                case .success:
                                    self.loggingDelegate?.logReceiveEvent("Successfully received history events")
                                    self.delegate?.pumpDidSync(self)
                                case .failure(let error):
                                    self.loggingDelegate?.logErrorEvent("Failed to get history events: \(String(describing: error.errorDescription))")
                                    if case .noRecordsFound = error {
                                        self.delegate?.pumpDidSync(self)
                                    }
                                }
                            }
                        case .failure(let error):
                            self.loggingDelegate?.logErrorEvent("Failed to reset the history event recorded status changed: \(String(describing: error.errorDescription))")
                        }
                    }
                } else if !isReceivingHistoryEvents {
                    self.delegate?.pumpDidSync(self)
                }
            }
            reportResultToReadRequestProcedure(InsulinDeliveryCharacteristicUUID.statusChanged.procedureID, result: .success)
        case .failure(let error):
            reportResultToReadRequestProcedure(InsulinDeliveryCharacteristicUUID.statusChanged.procedureID, result: .failure(error))
        }
    }
    
    open func manageInsulinDeliveryAnnunciationStatusData(_ data: Data) {
        let result = IDAnnunciationStatus.handleData(data)
        loggingDelegate?.logReceiveEvent("Received annunication status: result: \(result), data: \(data.toHexString())")

        switch result {
        case .success(let annunciation):
            defer {
                reportResultToReadRequestProcedure(InsulinDeliveryCharacteristicUUID.annunciationStatus.procedureID, result: .success)
            }

            guard let annunciation = annunciation else {
                loggingDelegate?.logReceiveEvent("No current annunciation")
                return
            }

            loggingDelegate?.logReceiveEvent("Annunciation of type \(annunciation.type) with id: \(annunciation.identifier), status \(annunciation.status), and aux data: \(annunciation.auxiliaryData.toHexString())")

            if annunciation.status == .pending {
                var annunciationToDeliver: Annunciation = GeneralAnnunciation(type: annunciation.type, identifier: annunciation.identifier)
                // pending and snoozed annunciations are considered active and need user confirmation
                switch annunciation.type {
                case .bolusCanceled:
                    let bolusCanceledAnnunciation = BolusCanceledAnnunciation(identifier: annunciation.identifier, auxiliaryData: annunciation.auxiliaryData)
                    let bolusDeliveryStatus = bolusCanceledAnnunciation.bolusDeliveryStatus
                    bolusManager.activeBolusDeliveryCanceled(canceledBolusDeliveryStatus: bolusDeliveryStatus)
                    if let completion = lockedPendingAnnunciationCompletions.value[IDControlPointOpcode.cancelBolus.procedureID] as? BolusDeliveryStatusCompletion {
                        completion(.success(bolusDeliveryStatus))
                    }
                    removePendingAnnunciationCompletion(forProcedureID: IDControlPointOpcode.cancelBolus.procedureID)
                    annunciationToDeliver = bolusCanceledAnnunciation
                case .reservoirLow:
                    guard let currentReservoirWarningLevel = state.deviceInformation?.reservoirLevelWarningThresholdInUnits else {
                        break
                    }
                    
                    annunciationToDeliver = LowReservoirAnnunciation(identifier: annunciation.identifier, currentReservoirLevel: state.deviceInformation?.reservoirLevel ?? Double(currentReservoirWarningLevel))
                case .batteryLow:
                    deviceInformation?.batteryLevel = DeviceInformation.BatteryLevelIndicator.low.threshold
                case .batteryEmpty:
                    deviceInformation?.batteryLevel = DeviceInformation.BatteryLevelIndicator.empty.threshold
                default:
                    break
                }
                delegate?.pump(self, didReceiveAnnunciation: annunciationToDeliver)
            }
        case .failure(let error):
            reportResultToReadRequestProcedure(InsulinDeliveryCharacteristicUUID.annunciationStatus.procedureID, result: .failure(error))
        }
    }
}

//MARK: - Bluetooth Manager Delegation
extension InsulinDeliveryService: BluetoothManagerDelegate {
    public func bluetoothManager(_ manager: BluetoothManager, shouldConnectPeripheral peripheral: CBPeripheral, advertisementData: [String: Any]?) -> Bool {
        loggingDelegate?.logConnectionEvent("peripheral: \(peripheral), advertisementData: \(String(describing: advertisementData?.debugDescription)), stored identifier: \(String(describing: deviceInformation?.identifier))")

        guard let storedIdentifier = deviceInformation?.identifier else {
            loggingDelegate?.logConnectionEvent("No pump identifier stored \(peripheral.identifier). Do not auto-connect")
            return false
        }

        let matchingIdentifiers = storedIdentifier == peripheral.identifier
        guard matchingIdentifiers else {
            // check if the serial number is the same, since switching services also switches the peripheral identifier
            if let storedSerialNumber = deviceInformation?.serialNumber {
                let matchingSerialNumbers = storedSerialNumber == serialNumber(fromAdvertisementData: advertisementData)
                if matchingSerialNumbers {
                    // store the new identifier
                    deviceInformation?.identifier = peripheral.identifier
                }
                loggingDelegate?.logConnectionEvent("Should connect to peripheral with identifier \(peripheral.identifier): \(matchingSerialNumbers)")
                return matchingSerialNumbers
            }

            loggingDelegate?.logConnectionEvent("No pump serial number stored \(peripheral.identifier). Do not auto-connect")
            return false
        }

        loggingDelegate?.logConnectionEvent("Should connect to peripheral with identifier \(peripheral.identifier): \(matchingIdentifiers)")
        return matchingIdentifiers
    }
    
    public func bluetoothManager(_ manager: BluetoothManager,
                                 didDiscoverPeripheralWithName peripheralName: String?,
                                 identifier: UUID,
                                 advertisementData: [String: Any],
                                 signalStrength: NSNumber) {
        let manufacturerData = advertisementData["kCBAdvDataManufacturerData"] as? Data
        
        loggingDelegate?.logConnectionEvent("Did discover peripheral: \(String(describing: peripheralName)) with manufacturer data \(String(describing: manufacturerData?.hexadecimalString))")
        delegate?.pump(self,
                       didDiscoverPumpWithName: peripheralName,
                       identifier: identifier,
                       serialNumber: serialNumber(fromAdvertisementData: advertisementData))
    }

    private func startAuthentication(with peripheralManager: PeripheralManager) {
        loggingDelegate?.logSendEvent("Preparing for pump authentication.")
        delegate?.pumpConnectionStatusChanged(self)
        acControlPoint.queueConfigurationRequests()
        loggingDelegate?.logSendEvent("Starting pump authentication.")
        loggingDelegate?.logSendEvent("Procedure \(String(describing: acControlPoint.procedureIDForNextRequest()))")
        acControlPoint.sendNextRequest(peripheralManager, timeout: 1)
    }

    public func bluetoothManager(_ manager: BluetoothManager, peripheralManager: PeripheralManager, didEncounterError error: Error) {
        guard let nsError = error as NSError? else {
            reportErrorToAllPendingProcedureCompletions(.commandFailed(error.localizedDescription.debugDescription))
            return
        }
        handleCBError(CBError(_nsError: nsError))
    }

    func handleCBError(_ cbError: CBError) {
        guard cbError.code == .peripheralDisconnected ||
                cbError.code == .connectionTimeout ||
                cbError.code == .connectionFailed ||
                cbError.code == .uuidNotAllowed ||
                cbError.code == .peerRemovedPairingInformation ||
                cbError.code == .encryptionTimedOut
        else {
            reportErrorToAllPendingProcedureCompletions(.commandFailed(cbError.localizedDescription.debugDescription))
            return
        }

        let message: String
        let error: DeviceCommError
        switch cbError.code {
        case .connectionTimeout:
            error = .connectionTimeout
            message = "Pump connection timed out."
            disconnect()
        case .uuidNotAllowed:
            error = .deviceAlreadyPaired
            message = "Pump was already paired."
            deleteStoredKey()
            delegate?.pumpDidCompleteAuthentication(self, error: error)
        case .encryptionTimedOut:
            guard !state.setupCompleted else { return }

            error = .authenticationCancelled
            message = "User did not accept iOS pairing request."
            delegate?.pumpDidCompleteAuthentication(self, error: error)
        case .peerRemovedPairingInformation:
            error  = .authenticationFailed
            message = "Peer removed the pairing information"
            delegate?.pumpDidCompleteAuthentication(self, error: error)
        default:
            error  = .disconnected
            message = "Pump disconnected."
            disconnect()
        }

        loggingDelegate?.logConnectionEvent(message)
        reportErrorToAllPendingProcedureCompletions(error)
    }
    
    func manageACStatusData(_ data: Data) {
        loggingDelegate?.logReceiveEvent("data: \(data.toHexString())")
        guard let results = ACStatus.handleData(data) else {
            return
        }
        loggingDelegate?.logReceiveEvent("AC status \(String(describing: results.status))")
    }
    
    func manageACControlPointResponse(_ peripheralManager: PeripheralManager? = nil, response: Data, isSegmented: Bool = true) {
        loggingDelegate?.logReceiveEvent("response: \(response.toHexString())")
        let result: DeviceCommResult<Void>
        let completion: Any?
        if isSegmented {
            (result, completion) = acControlPoint.handleSegmentedResponse(response)
        } else {
            (result, completion) = acControlPoint.handleCompleteResponse(response)
        }
        loggingDelegate?.logReceiveEvent("Authorization Control Control Point result: \(String(describing: result))")
        switch result {
        case .success():
            loggingDelegate?.logReceiveEvent("Authorization Control procedure completed successfully.")
            if !acControlPoint.procedureRunning {
                let procedureID = acControlPoint.procedureIDForResponse(response)
                reportSuccessToPendingCompletionForProcedureID(procedureID, completion)

                if acControlPoint.hasRequestToSend {
                    loggingDelegate?.logSendEvent("Procedure \(String(describing: acControlPoint.procedureIDForNextRequest()))")
                    peripheralManager?.perform { [weak self] (peripheralManager) in
                        self?.acControlPoint.sendNextRequest(peripheralManager, timeout: 10)
                    }
                } else {
                    sendNextPendingSecureRequest()
                }
            }
        case .failure(let error):
            if error != .partialResponse {
                loggingDelegate?.logReceiveEvent("Authorization Control procedure failed.")
                delegate?.pumpDidCompleteAuthentication(self, error: .authenticationFailed)
                for (procedureID, completion) in self.acControlPoint.getPendingProceduresAndReset() {
                    reportErrorToPendingCompletion(error, forProcedureID: procedureID, completion)
                }
                deleteStoredKey()
                reportErrorToAllPendingProcedureCompletions(error)
            }
        }
    }
    
    func manageACDataValue(_ value: Data) {
        let segmentationHeader = SegmentationHeader(rawValue: value[value.startIndex...].to(SegmentationHeader.RawValue.self))
        loggingDelegate?.logReceiveEvent("Received secure data. Segmentation header \(String(describing: segmentationHeader)). raw data \(value.toHexString())")
        let result = acData.handleSecureResponse(value)
        loggingDelegate?.logReceiveEvent("Authorization Control Data result: \(String(describing: result))")
        switch result {
        case .success(let resourceResponse):
            let resourceHandle = resourceResponse.resourceHandle
            let response = resourceResponse.response
            loggingDelegate?.logReceiveEvent("Authorization Control Data response was handled successfully. \(getResourceProcedureID(for: resourceHandle)), response: \(response.toHexString())")

            switch resourceHandle {
            case getResourceHandle(for: ACCharacteristicUUID.controlPoint.cbUUID):
                manageACControlPointResponse(response: response, isSegmented: false)
            case getResourceHandle(for: InsulinDeliveryCharacteristicUUID.features.cbUUID):
                manageInsulinDeliveryFeatureData(response)
            case getResourceHandle(for: InsulinDeliveryCharacteristicUUID.commandControlPoint.cbUUID):
                manageInsulinDeliveryControlPointResponse(response)
            case getResourceHandle(for: InsulinDeliveryCharacteristicUUID.statusReaderControlPoint.cbUUID):
                manageInsulinDeliveryStatusReaderResponse(response)
            case getResourceHandle(for: InsulinDeliveryCharacteristicUUID.recordAccessControlPoint.cbUUID):
                manageRecordAccessControlPointResponse(response)
            case getResourceHandle(for: InsulinDeliveryCharacteristicUUID.historyData.cbUUID):
                manageInsulinDeliveryHistoryData(response)
            case getResourceHandle(for: InsulinDeliveryCharacteristicUUID.status.cbUUID):
                manageInsulinDeliveryStatusData(response)
            case getResourceHandle(for: InsulinDeliveryCharacteristicUUID.statusChanged.cbUUID):
                manageInsulinDeliveryStatusChangedData(response)
            case getResourceHandle(for: InsulinDeliveryCharacteristicUUID.annunciationStatus.cbUUID):
                manageInsulinDeliveryAnnunciationStatusData(response)
            case getResourceHandle(for: DeviceInfoCharacteristicUUID.firmwareRevisionString.cbUUID):
                guard let firmwareRevisionString = DeviceInfoCharacteristicUUID.firmwareRevisionString.toString(response) else {
                    break
                }
                loggingDelegate?.logReceiveEvent("Firmware revision: \(firmwareRevisionString)")
                deviceInformation?.firmwareRevision = firmwareRevisionString
                // TODO get the hardware revision once it is available
            case getResourceHandle(for: BatteryCharacteristicUUID.batteryLevel.cbUUID):
                let batteryLevel = BatteryCharacteristicUUID.batteryLevel.toPercent(response)
                loggingDelegate?.logReceiveEvent("Pump battery level: \(batteryLevel)")
                deviceInformation?.batteryLevel = batteryLevel
            case getResourceHandle(for: DeviceTimeCharacteristicUUID.controlPoint.cbUUID):
                managerDeviceTimeControlPointResponse(response)
            case getResourceHandle(for: DeviceTimeCharacteristicUUID.deviceTime.cbUUID):
                managerDeviceTimeData(response)
            default:
                break
            }

            sendNextPendingSecureRequest()
        case .failure(let error):
            if error != DeviceCommError.partialResponse {
                loggingDelegate?.logErrorEvent("Authorization Control Data response could not be handled")
                reportErrorToAllPendingProcedureCompletions(error)
            }
        }
    }

    func managerDeviceTimeData(_ data: Data) {
        loggingDelegate?.logReceiveEvent("data: \(data.toHexString())")
        let procedureID = DeviceTimeCharacteristicUUID.deviceTime.procedureID
        let (result, completion) = deviceTime.handleData(data)
        switch result {
        case .success(let pumpTime):
            if let completion = completion as? ProcedureTimeCompletion {
                guard let pumpTime = pumpTime else {
                    let error = DeviceCommError.invalidFormat
                    loggingDelegate?.logErrorEvent("Error getting pump time \(error)")
                    completion(.failure(error))
                    return
                }

                loggingDelegate?.logReceiveEvent("Got pump time \(pumpTime)")
                completion(.success(pumpTime))
            }
        case .failure(let error):
            loggingDelegate?.logErrorEvent("Error handling pump time \(error)")
            reportErrorToPendingCompletion(error, forProcedureID: procedureID, completion)
            deviceTime.reset()
        }
    }

    func managerDeviceTimeControlPointResponse(_ response: Data) {
        let responseOpcode: DTControlPointOpcode? = dtControlPoint.responseOpcode(response)
        let procedureID = dtControlPoint.procedureIDForResponse(response)
        loggingDelegate?.logReceiveEvent("Device Time Control Point response \(responseOpcode.debugDescription) to procedure \(String(describing: procedureID)): \(response.toHexString())")

        let (result, completion) = dtControlPoint.handleResponse(response)
        switch result {
        case .success:
            reportSuccessToPendingCompletionForProcedureID(procedureID, completion)
        case .failure(let error):
            reportErrorToPendingCompletion(error, forProcedureID: procedureID, completion)
            for (procedureID, completion) in dtControlPoint.getPendingProceduresAndReset() {
                reportErrorToPendingCompletion(error, forProcedureID: procedureID, completion)
            }
        }
    }
    
    func manageInsulinDeliveryControlPointResponse(_ response: Data) {
        let responseOpcode: IDControlPointOpcode? = idControlPoint.responseOpcode(response)
        let procedureID = idControlPoint.procedureIDForResponse(response)
        loggingDelegate?.logReceiveEvent("Insulin Delivery Control Point response \(responseOpcode.debugDescription) to procedure \(String(describing: procedureID)): \(response.toHexString())")
        
        let (result, completion) = idControlPoint.handleResponse(response)
        switch result {
        case .success():
            reportSuccessToPendingCompletionForProcedureID(procedureID, completion)
        case .failure(let error):
            guard error != .partialResponse else {
                // write basal rate may take multiple requests
                if procedureID == IDControlPointOpcode.writeBasalRateTemplate.procedureID {
                    sendNextRequestToInsulinDeliveryControlPoint()
                }
                return
            }

            // report error to all pending procedures first
            reportErrorToPendingCompletion(error, forProcedureID: procedureID, completion)
            for (procedureID, completion) in idControlPoint.getPendingProceduresAndReset() {
                reportErrorToPendingCompletion(error, forProcedureID: procedureID, completion)
            }
        }
    }
    
    func manageInsulinDeliveryStatusReaderResponse(_ response: Data) {
        let responseOpcode: IDStatusReaderOpcode? = idStatusReader.responseOpcode(response)
        let procedureID = idStatusReader.procedureIDForResponse(response)
        loggingDelegate?.logReceiveEvent("Insulin Delivery Status Reader response \(responseOpcode.debugDescription) to procedure \(String(describing: procedureID)): \(response.toHexString())")

        let (result, completion) = idStatusReader.handleResponse(response)
        switch result {
        case .success():
            reportSuccessToPendingCompletionForProcedureID(procedureID, completion)
        case .failure(let error):
            reportErrorToPendingCompletion(error, forProcedureID: procedureID, completion)
            for (procedureID, completion) in idStatusReader.getPendingProceduresAndReset() {
                reportErrorToPendingCompletion(error, forProcedureID: procedureID, completion)
            }
        }
    }

    func manageRecordAccessControlPointResponse(_ response: Data) {
        let responseOpcode: RACPOpcode? = recordAccessControlPoint.responseOpcode(response)
        let procedureID = recordAccessControlPoint.procedureIDForResponse(response)
        loggingDelegate?.logReceiveEvent("Record Access Control Point response \(responseOpcode.debugDescription) to procedure \(String(describing: procedureID)): \(response.toHexString())")

        let (result, completion) = recordAccessControlPoint.handleResponse(response)
        switch result {
        case .success():
            reportSuccessToPendingCompletionForProcedureID(procedureID, completion)
        case .failure(let error):
            reportErrorToPendingCompletion(error, forProcedureID: procedureID, completion)
            for (procedureID, completion) in recordAccessControlPoint.getPendingProceduresAndReset() {
                reportErrorToPendingCompletion(error, forProcedureID: procedureID, completion)
            }
        }
    }

    func manageInsulinDeliveryHistoryData(_ data: Data) {
        loggingDelegate?.logReceiveEvent("data: \(data.toHexString())")
        let result = IDHistoryData.handleData(data)

        switch result {
        case .success(let pumpHistoryEvent):
            loggingDelegate?.logReceiveEvent("Received insulin delivery pump history event: \(String(describing: pumpHistoryEvent))")
            pumpHistoryEventManager.processPumpHistoryEvent(pumpHistoryEvent)
        case .failure(let error):
            loggingDelegate?.logErrorEvent("Failed to process pump history event: \(String(describing: error.errorDescription))")
        }
    }
    
    func manageInsulinDeliveryFeatureData(_ data: Data) {
        loggingDelegate?.logReceiveEvent("data: \(data.toHexString())")
        let result = IDFeature.handleData(data)
        switch result {
        case .success((_, let features)):
            state.features = features
        case .failure(let error):
            reportResultToReadRequestProcedure(InsulinDeliveryCharacteristicUUID.features.procedureID, result: .failure(error))
        }
    }
    
    func manageInsulinDeliveryStatusData(_ data: Data) {
        loggingDelegate?.logReceiveEvent("data: \(data.toHexString())")
        let result = IDStatus.handleData(data)

        switch result {
        case .success((let therapyControlState, let operationalState, let remainingReservoir, _)):
            loggingDelegate?.logReceiveEvent("Received insulin delivery status: therapy state: \(therapyControlState), operational state: \(operationalState), reservoir level: \(remainingReservoir)")
            if var deviceInformation = deviceInformation {
                // store all information together to only trigger 1 update to state
                deviceInformation.therapyControlState = therapyControlState
                deviceInformation.pumpOperationalState = operationalState
                deviceInformation.reservoirLevel = remainingReservoir
                self.deviceInformation = deviceInformation
                if delegate?.isInReplacementWorkflow == false, self.deviceInformation?.isComplete == false {
                    getInsulinDeliveryFeatures()
                    getFirmwareRevision()
                    getBatteryLevel()
                }

                // setup is considered complete the first time insulin is being delivered for a new pump
                if !state.setupCompleted,
                   state.isDeliveringInsulin
                {
                    state.setupCompleted = true
                }

                bolusManager.handleTherapyControlState(therapyControlState)
            }
            
            reportResultToReadRequestProcedure(InsulinDeliveryCharacteristicUUID.status.procedureID, result: .success)
        case .failure(let error):
            reportResultToReadRequestProcedure(InsulinDeliveryCharacteristicUUID.status.procedureID, result: .failure(error))
        }
    }
}

//MARK: - Security Manager Delegation
extension InsulinDeliveryService: SecurityManagerDelegate {
    public var sharedKeyData: Data? {
        get {
            delegate?.sharedKeyData
        }
        set {
            delegate?.sharedKeyData = newValue
        }
    }
    
    func deleteStoredKey() {
        delegate?.sharedKeyData = nil
        securityManager.configuration.resetSequenceNumber()
    }
    
    public func securityManagerDidEstablishedSecurity(_ securityManager: SecurityManager) {
        state.uuidToHandleMap = acControlPoint.uuidToHandleMap
        delegate?.pumpDidCompleteAuthentication(self)
    }
    
    public func securityManagerDidUpdateConfiguration(_ securityManager: SecurityManager) {
        state.securityManagerConfiguration = securityManager.configuration
    }
}

//MARK: - Pump History Event Manager Delegation
extension InsulinDeliveryService: PumpHistoryEventManagerDelegate {
    func pumpHistoryEventManagerDidUpdateConfiguration(_ pumpHistoryEventManager: PumpHistoryEventManager) {
        state.pumpHistoryEventManagerConfiguration = pumpHistoryEventManager.configuration
    }

    func pumpHistoryEventManagerDidDetectBolusProgrammed(_ pumpHistoryEventManager: PumpHistoryEventManager, bolusID: BolusID, insulinProgrammed: Double, at date: Date) {
        delegate?.pumpDidInitiateBolus(self, bolusID: bolusID, insulinProgrammed: insulinProgrammed, startTime: date)
    }

    func pumpHistoryEventManagerDidDetectBolusDelivered(_ pumpHistoryEventManager: PumpHistoryEventManager, bolusID: BolusID, insulinProgrammed: Double, insulinDelivered: Double, startTime: Date, duration: TimeInterval) {
        delegate?.pumpDidDeliverBolus(self, bolusID: bolusID, insulinProgrammed: insulinProgrammed, insulinDelivered: insulinDelivered, startTime: startTime, duration: duration)
        bolusManager.completeBolus(for: bolusID, insulinProgrammed: insulinProgrammed, insulinDelivered: insulinDelivered, startTime: startTime, duration: duration)
    }

    func pumpHistoryEventManagerDidDetectTempBasalStarted(_ pumpHistoryEventManager: PumpHistoryEventManager, at startTime: Date, rate: Double, duration: TimeInterval) {
        delegate?.pumpTempBasalStarted(self, at: startTime, rate: rate, duration: duration)
    }

    func pumpHistoryEventManagerDidDetectTempBasalChanged(_ pumpHistoryEventManager: PumpHistoryEventManager, at startTime: Date, rate: Double, programmedDuration: TimeInterval, elapsedDuration: TimeInterval) {
        delegate?.pumpTempBasalStarted(self, at: startTime, rate: rate, duration: programmedDuration)
    }

    func pumpHistoryEventManagerDidDetectTempBasalEnded(_ pumpHistoryEventManager: PumpHistoryEventManager, duration: TimeInterval, endReason: TempBasalEndReason) {
        delegate?.pumpTempBasalEnded(self, duration: duration)
    }

    func pumpHistoryEventManagerDidDetectInsulinDeliverySuspended(_ pumpHistoryEventManager: PumpHistoryEventManager, suspendedAt: Date) {
        delegate?.pumpDidSuspendInsulinDelivery(self, suspendedAt: suspendedAt)
    }

    func pumpHistoryEventManagerDidDetectAnnunciation(_ pumpHistoryEventManager: PumpHistoryEventManager, annunciation: Annunciation, at date: Date?) {
        delegate?.pumpDidDetectHistoricalAnnunciation(self, annunciation: annunciation, at: date)
    }
}

//MARK: - AC Data Delegate
extension InsulinDeliveryService: ACDataDelegate {
    public func didEncounterE2ECounterError() {
        loggingDelegate?.logErrorEvent("Encountered E2E counter error.")
        triggerReconnectToResolveCounterError()
    }

    public func didEncounterSegmentCounterError() {
        loggingDelegate?.logErrorEvent("Encountered segment counter error.")
        triggerReconnectToResolveCounterError()
    }

    private func triggerReconnectToResolveCounterError() {
        loggingDelegate?.logConnectionEvent("Triggering reconnect to resolve counter error.")
        reportErrorToAllPendingProcedureCompletions(.disconnected)
        bluetoothManager.disconnect()
        disconnect()
    }
}

//MARK: - Bolus Manager Delegate
extension InsulinDeliveryService: BolusManagerDelegate {
    func bolusManagerDidUpdateActiveBolusDeliveryStatus(_ bolusManager: BolusManager) {
        state.activeBolusDeliveryStatus = bolusManager.activeBolusDeliveryStatus
    }
    
    func estimatedBolusDelivery(for elapsedTime: TimeInterval) -> Double? {
        guard let estimatedBolusDeliveryRate = delegate?.estimatedBolusDeliveryRate else {
            return delegate?.supportedBolusVolumes.first
        }
        
        let estimatedBolusDelivered = estimatedBolusDeliveryRate * elapsedTime
        return roundToSupportedBolusVolume(units: estimatedBolusDelivered)
    }
}

//MARK: - Basal Manager Delegate
extension InsulinDeliveryService: BasalManagerDelegate {
    func basalManagerDidUpdateStatus(_ basalManager: BasalManager) {
        state.activeTempBasalDeliveryStatus = basalManager.activeTempBasalDeliveryStatus
        state.totalBasalDelivered = basalManager.totalBasalDelivered
    }
    
    func isActiveBasalRate(_ activeBasalRate: Double) -> Bool {
        isActiveBasalRate(activeBasalRate, now: Date())
    }
    
    internal func isActiveBasalRate(_ activeBasalRate: Double, now: Date) -> Bool {
        // need to check now and +/- maxAllowedPumpClockDrift seconds to account for drift
        guard let basalSegments = delegate?.basalSegments,
              let maxAllowedPumpClockDrift = delegate?.maxAllowedPumpClockDrift,
              let activeBasalRateNow = basalSegments.rate(at: now),
              let activeBasalRate10Minus = basalSegments.rate(at: now.addingTimeInterval(-maxAllowedPumpClockDrift)),
              let activeBasalRate10Plus = basalSegments.rate(at: now.addingTimeInterval(maxAllowedPumpClockDrift))
        else {
            loggingDelegate?.logErrorEvent("could not get the basal rate schedule to compare the active basal rate")
            return false
        }
        
        guard activeBasalRate == activeBasalRateNow ||
                activeBasalRate == activeBasalRate10Minus ||
                activeBasalRate == activeBasalRate10Plus
        else {
            loggingDelegate?.logErrorEvent("active basal rate does not match an expected basal rate. activeBasalRate: \(activeBasalRate), expected: [now: \(activeBasalRateNow), -10: \(activeBasalRate10Minus), +10: \(activeBasalRate10Plus)]")
            return false
        }

        return true
    }
}
