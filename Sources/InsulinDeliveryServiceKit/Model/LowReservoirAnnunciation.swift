//
//  LowReservoirAnnunciation.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-18.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

public struct LowReservoirAnnunciation: Annunciation {
    public let type: AnnunciationType = .reservoirLow
    
    public let identifier: UInt16

    public let currentReservoirLevel: Double

    public var annunciationMessageCauseArgs: [CVarArg] {
        return ["\(currentReservoirLevel)"]
    }
}
