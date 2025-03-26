//
//  BolusDeliveryStatus.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-13.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation
import BluetoothCommonKit

public enum BolusProgressState: String, Codable, Equatable {
    case canceled
    case completed
    case estimatingProgress
    case inProgress
    case noActiveBolus
    
    public var isOngoing: Bool {
        switch self {
        case .inProgress, .estimatingProgress: return true
        default: return false
        }
    }
}

public struct BolusDeliveryStatus: Equatable, RawRepresentable, Codable {

    public typealias RawValue = [String: Any]

    private enum BolusDeliveryStatusKey: String {
        case bolusID
        case progressState
        case type
        case insulinProgrammed
        case insulinDelivered
        case startTime
        case endTime
    }

    public var id: BolusID?
    public var progressState: BolusProgressState
    public let type: BolusType
    public var insulinProgrammed: Double
    public var insulinDelivered: Double
    public var startTime: Date?
    public var endTime: Date?

    public init(id: BolusID?,
                progressState: BolusProgressState,
                type: BolusType,
                insulinProgrammed: Double,
                insulinDelivered: Double,
                startTime: Date? = nil,
                endTime: Date? = nil)
    {
        self.id = id
        self.progressState = progressState
        self.type = type
        self.insulinProgrammed = insulinProgrammed
        self.insulinDelivered = insulinDelivered
        self.startTime = startTime
        self.endTime = endTime
    }

    public init?(rawValue: RawValue) {
        guard let rawProgressState = rawValue[BolusDeliveryStatusKey.progressState.rawValue] as? BolusProgressState.RawValue,
              let progressState = BolusProgressState(rawValue: rawProgressState),
              let rawType = rawValue[BolusDeliveryStatusKey.type.rawValue] as? BolusType.RawValue,
              let type = BolusType(rawValue: rawType),
              let insulinProgrammed = rawValue[BolusDeliveryStatusKey.insulinProgrammed.rawValue] as? Double,
              let insulinDelivered = rawValue[BolusDeliveryStatusKey.insulinDelivered.rawValue] as? Double
        else {
            return nil
        }

        self.progressState = progressState
        self.type = type
        self.insulinProgrammed = insulinProgrammed
        self.insulinDelivered = insulinDelivered
        self.id = rawValue[BolusDeliveryStatusKey.bolusID.rawValue] as? BolusID
        self.endTime = rawValue[BolusDeliveryStatusKey.endTime.rawValue] as? Date
        self.startTime = rawValue[BolusDeliveryStatusKey.startTime.rawValue] as? Date
    }

    public var rawValue: RawValue {
        var rawValue: RawValue = [
            BolusDeliveryStatusKey.progressState.rawValue: progressState.rawValue,
            BolusDeliveryStatusKey.type.rawValue: type.rawValue,
            BolusDeliveryStatusKey.insulinProgrammed.rawValue: insulinProgrammed,
            BolusDeliveryStatusKey.insulinDelivered.rawValue: insulinDelivered,
        ]
        rawValue[BolusDeliveryStatusKey.bolusID.rawValue] = id
        rawValue[BolusDeliveryStatusKey.endTime.rawValue] = endTime
        rawValue[BolusDeliveryStatusKey.startTime.rawValue] = startTime

        return rawValue
    }

    public static var noActiveBolus: BolusDeliveryStatus {
        BolusDeliveryStatus(id: nil,
                            progressState: .noActiveBolus,
                            type: .undetermined,
                            insulinProgrammed: 0,
                            insulinDelivered: 0,
                            startTime: nil,
                            endTime: nil)
    }
}

extension BolusDeliveryStatus {
    func unfinalizedBolus(at now: Date = Date(), estimatedBolusDeliveryRate: Double) -> UnfinalizedDose? {
        guard self.progressState != .noActiveBolus else { return nil }
        
        let startTime = self.startTime ?? now.addingTimeInterval(-self.insulinDelivered/estimatedBolusDeliveryRate)
        var unfinalizedBolus = UnfinalizedDose(bolusAmount: self.insulinProgrammed,
                                               startTime: startTime,
                                               scheduledCertainty: progressState == .estimatingProgress ? .uncertain : .certain,
                                               estimatedBolusDeliveryRate: estimatedBolusDeliveryRate
        )
        // calculate the end time
        switch progressState {
        case .noActiveBolus: return nil
        case .canceled:
            unfinalizedBolus.cancel(at: endTime ?? now, insulinDelivered: insulinDelivered)
        case .completed:
            unfinalizedBolus.endTime = startTime.addingTimeInterval(insulinProgrammed / estimatedBolusDeliveryRate)
            unfinalizedBolus.programmedUnits = insulinProgrammed
            unfinalizedBolus.units = insulinProgrammed
        case .estimatingProgress:
            // use the expected delivery rate to calculate the endTime
            unfinalizedBolus.endTime = startTime.addingTimeInterval(insulinProgrammed / estimatedBolusDeliveryRate)
        case .inProgress:
            // the bolus may be delivered slowly. As such recalculate the endTime
            unfinalizedBolus.endTime = endTime ?? now.addingTimeInterval((insulinProgrammed - insulinDelivered) / estimatedBolusDeliveryRate)
        }
        
        return unfinalizedBolus
    }
}
    
public extension BolusDeliveryStatus {
    static func canceledBolusStatus(auxiliaryData: Data, at now: Date = Date()) -> BolusDeliveryStatus {
        var index = 0
        let bolusID = auxiliaryData[auxiliaryData.startIndex.advanced(by: index)...].to(BolusID.self)
        index += 2
        
        let bolusType = BolusType(rawValue: auxiliaryData[auxiliaryData.startIndex.advanced(by: index)...].to(UInt8.self)) ?? .undetermined
        index += 2
        
        let insulinProgrammed = Data(auxiliaryData[auxiliaryData.startIndex.advanced(by: index)...].to(SFLOAT.self)).sfloatToDouble()
        index += 2
        
        let insulinDelivered = Data(auxiliaryData[auxiliaryData.startIndex.advanced(by: index)...].to(SFLOAT.self)).sfloatToDouble()

        return BolusDeliveryStatus(id: bolusID,
                                   progressState: .canceled,
                                   type: bolusType,
                                   insulinProgrammed: insulinProgrammed,
                                   insulinDelivered: insulinDelivered,
                                   endTime: now)
    }
}
