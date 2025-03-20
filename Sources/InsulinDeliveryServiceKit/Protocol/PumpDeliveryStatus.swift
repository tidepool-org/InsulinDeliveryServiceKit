//
//  PumpDeliveryStatus.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

public protocol PumpDeliveryStatus {
    var therapyControlState: InsulinTherapyControlState { get }
    var pumpOperationalState: PumpOperationalState { get }
    var reservoirLevel: Double? { get }
}
