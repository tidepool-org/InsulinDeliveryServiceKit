//
//  InsulinDeliveryServiceDelegate.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit

// MARK: - Procedure Completions
public typealias BolusDeliveryStatusCompletion = ProcedureCompletion<BolusDeliveryStatus>
public typealias PumpDeliveryStatusCompletion = ProcedureCompletion<PumpDeliveryStatus?>

// MARK: - Insulin delivery Pump Delegate
public protocol IDPumpDelegate: AnyObject {
    var supportedBasalRates: [Double] { get }
    var supportedBolusVolumes: [Double] { get }
    var supportedMaximumBolusVolumes: [Double] { get }
    var maximumBasalScheduleEntryCount: Int { get }
    var minimumBasalScheduleEntryDuration: TimeInterval { get }
    var pumpReservoirCapacity: Double { get }
    var supportedMaximumBasalRateAmount: Double { get }
    var basalRateProfileTemplateNumber: UInt8 { get }
    var numberOfProfileTemplates: UInt8 { get }
    var estimatedBolusDeliveryRate: Double { get }
    var reservoirAccuracyLimit: Double? { get }
    var supportedReservoirFillVolumes: [Int] { get }
    var pulseSize: Double { get }
    var pulsesPerUnit: Double { get }
    var expectedLifespan: TimeInterval { get }
    var maxAllowedPumpClockDrift: TimeInterval { get }
    var pumpTimeZone: TimeZone { get }
    var isInReplacementWorkflow: Bool { get }
    var basalProfile: [BasalSegment] { get }
    func pump(_ pump: IDPumpComms, didDiscoverPumpWithName peripheralName: String?, identifier: UUID, serialNumber: String?)
    func pump(_ pump: IDPumpComms, didReceiveAnnunciation annunciation: Annunciation)
    func pumpConnectionStatusChanged(_ pump: IDPumpComms)
    func pumpDidCompleteAuthentication(_ pump: IDPumpComms, error: DeviceCommError?)
    func pumpDidCompleteConfiguration(_ pump: IDPumpComms)
    func pumpDidCompleteTherapyUpdate(_ pump: IDPumpComms)
    func pumpDidUpdateState(_ pump: IDPumpComms)
    func pumpDidInitiateBolus(_ pump: IDPumpComms, bolusID: BolusID, insulinProgrammed: Double, startTime: Date)
    func pumpDidDeliverBolus(_ pump: IDPumpComms, bolusID: BolusID, insulinProgrammed: Double, insulinDelivered: Double, startTime: Date, duration: TimeInterval)
    func pumpTempBasalStarted(_ pump: IDPumpComms, at startTime: Date, rate: Double, duration: TimeInterval)
    func pumpTempBasalEnded(_ pump: IDPumpComms, duration: TimeInterval)
    func pumpDidSuspendInsulinDelivery(_ pump: IDPumpComms, suspendedAt: Date)
    func pumpDidDetectHistoricalAnnunciation(_ pump: IDPumpComms, annunciation: Annunciation, at date: Date?)
    func pumpDidSync(_ pump: IDPumpComms, pendingCommandCheckCompleted: Bool, at date: Date)
}

public extension IDPumpDelegate {
    func pumpDidCompleteAuthentication(_ pump: IDPumpComms) { pumpDidCompleteAuthentication(pump, error: nil) }
    func pumpDidSync(_ pump: IDPumpComms, pendingCommandCheckCompleted: Bool = true) { pumpDidSync(pump, pendingCommandCheckCompleted: pendingCommandCheckCompleted, at: Date()) }
}

// MARK: - Insulin Delivery Pump Communication Manager Protocol
public protocol IDPumpComms: AnyObject {
    /**
     The delegate used to asynchrounously notify the application of various pump communication events.
     */
    var delegate: IDPumpDelegate? { get set }

    /**
     Delegate responsible for logging communication events
     */
    var loggingDelegate: DeviceCommLoggingDelegate? { get set }


    // MARK: Parameters
    var state: IDPumpState { get set }

    var deviceInformation: DeviceInformation? { get }

    var isBolusActive: Bool { get }
    
    var activeBolusID: BolusID? { get }

    var isConnected: Bool { get }

    var isAuthenticated: Bool { get }

    var isAwaitingConfiguration: Bool { get }
    
    // MARK: Procedure Requests
    func updateStatus(completion: @escaping PumpDeliveryStatusCompletion)

    /**
     Requests the current battery level from the pump, which will be stored in the pump state deviceInformation and informs the delegate via pumpDidUpdateState()
     */
    func getBatteryLevel()

    /**
     Gets the current time of the pump based on the given time zone. Note that the time zone of the pump may differ from the time zone of the iOS device.
     */
    func getTime(using timeZone: TimeZone, completion: @escaping ProcedureTimeCompletion)

    /**
     Sets the current time of the pump in the given time zone. Note that the time zone of the pump may differ from the time zone of the iOS device.
     */
    func setTime(_ date: Date, using timeZone: TimeZone, completion: @escaping ProcedureResultCompletion)
    
    func setOOBString(_ oobString: String)

    func prepareForNewPump()

    func connectToPump(withIdentifier identifier: UUID, andSerialNumber serialNumber: String)

    func prepareForDeactivation(completion: @escaping ProcedureResultCompletion)

    func prepareForInsulinDelivery(reservoirLevel: Int, basalProfile: [BasalSegment], completion: @escaping ProcedureResultCompletion)

    /**
     Requests the start of priming the pump
     - completion:  result of the request. If success, priming has started. Otherwise the request has failed
     */
    func startPrimingReservoir(_ amount: Double, completion: @escaping ProcedureResultCompletion)

    func primeCannula(_ amount: Double, completion: @escaping ProcedureResultCompletion)

    func stopPriming(completion: @escaping ProcedureResultCompletion)

    /**
     Requests the start of insulin delivery
     - completion:  result of the request. If success, insulin delivery has started. Otherwise the request has failed
     */
    func startInsulinDelivery(completion: @escaping PumpDeliveryStatusCompletion)

    /**
     Requests the suspend of insulin delivery
     - completion:  result of the request. If success, insulin delivery has stopped. Otherwise the request has failed
     */
    func suspendInsulinDelivery(completion: @escaping PumpDeliveryStatusCompletion)

    func confirmAnnunciation(_ annunciation: Annunciation, completion: @escaping ProcedureResultCompletion)

    func getInsulinDeliveryStatus(completion: @escaping ProcedureResultCompletion)

    func setBasalProfile(_ basalProfile: [BasalSegment], completion: @escaping ProcedureResultCompletion)

    func isValidBasalRate(_ rate: Double) -> Bool

    func setBolus(_ amount: Double, activationType: IDBolusActivationType, completion: @escaping BolusDeliveryStatusCompletion)

    func isValidBolusVolume(_ amount: Double) -> Bool

    func cancelBolus(completion: @escaping BolusDeliveryStatusCompletion)

    func updateActiveBolusDeliveryDetails(updateHandler: @escaping (BolusDeliveryStatus) -> Void)
    
    func setTempBasal(unitsPerHour: Double,
                      durationInMinutes: UInt16,
                      replaceExisting: Bool,
                      deliveryContext: BasalDeliveryContext,
                      completion: @escaping ProcedureResultCompletion)

    func cancelTempBasal(completion: @escaping ProcedureResultCompletion)
}

public extension IDPumpComms {
    var maximumBasalScheduleEntryCount: Int {
        delegate?.maximumBasalScheduleEntryCount ?? 24
    }
    
    var minimumBasalScheduleEntryDuration: TimeInterval {
        delegate?.minimumBasalScheduleEntryDuration ?? .minutes(30)
    }
    
    func isValidBasalRate(_ rate: Double) -> Bool {
        delegate?.supportedBasalRates.contains(rate) ?? false
    }
    
    func isValidBolusVolume(_ amount: Double) -> Bool {
        delegate?.supportedBolusVolumes.contains(amount) ?? false
    }
    
    func roundToSupportedBolusVolume(units: Double) -> Double {
        delegate?.supportedBolusVolumes.filter({$0 <= units}).max() ?? 0
    }
    
    func setTempBasal(unitsPerHour: Double,
                             durationInMinutes: UInt16,
                             replaceExisting: Bool,
                             completion: @escaping ProcedureResultCompletion)
    {
        setTempBasal(unitsPerHour: unitsPerHour, durationInMinutes: durationInMinutes, replaceExisting: replaceExisting, deliveryContext: .aidController, completion: completion)
    }
}
