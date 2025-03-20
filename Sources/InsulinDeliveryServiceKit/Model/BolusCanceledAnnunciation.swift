//
//  BolusCanceledAnnunciation.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import HealthKit
import BluetoothCommonKit

public struct BolusCanceledAnnunciation: Annunciation {
    nonisolated(unsafe) static let type: AnnunciationType = .bolusCanceled
    public let type: AnnunciationType = type

    public let identifier: AnnunciationIdentifier

    public let bolusDeliveryStatus: BolusDeliveryStatus

    public var annunciationMessageCauseArgs: [CVarArg] {
        let quantityFormatter = NumberFormatter()
        quantityFormatter.numberStyle = .decimal
        quantityFormatter.minimumFractionDigits = 0
        quantityFormatter.maximumFractionDigits = 3
        let partialAmountString = quantityFormatter.string(from: NSNumber(value: bolusDeliveryStatus.insulinDelivered)) ?? "?"
        let programmedAmountString = quantityFormatter.string(from: NSNumber(value: bolusDeliveryStatus.insulinProgrammed)) ?? "?"
        return [partialAmountString, programmedAmountString]
    }
    
    init(identifier: AnnunciationIdentifier,
         auxiliaryData: Data)
    {
        self.identifier = identifier
        
        var index = 0
        let bolusID = auxiliaryData[auxiliaryData.startIndex.advanced(by: index)...].to(BolusID.self)
        index += 2
        
        let bolusType = BolusType(rawValue: auxiliaryData[auxiliaryData.startIndex.advanced(by: index)...].to(UInt8.self)) ?? .undetermined
        index += 2
        
        let insulinProgrammed = Data(auxiliaryData[auxiliaryData.startIndex.advanced(by: index)...].to(SFLOAT.self)).sfloatToDouble()
        index += 2
        
        let insulinDelivered = Data(auxiliaryData[auxiliaryData.startIndex.advanced(by: index)...].to(SFLOAT.self)).sfloatToDouble()

        bolusDeliveryStatus = BolusDeliveryStatus(id: bolusID,
                                                  progressState: .canceled,
                                                  type: bolusType,
                                                  insulinProgrammed: insulinProgrammed,
                                                  insulinDelivered: insulinDelivered)
    }

    init(identifier: AnnunciationIdentifier, bolusDeliveryStatus: BolusDeliveryStatus) {
        self.identifier = identifier
        self.bolusDeliveryStatus = bolusDeliveryStatus
    }
}
