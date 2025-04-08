//
//  ProfileTemplateActivatedHistoryEvent.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

public struct ProfileTemplateActivatedHistoryEvent: PumpHistoryEvent {
    public let type: IDHistoryEventType = .profileTemplateActivated

    public let recordNumber: RecordNumber

    public let relativeOffset: TimeInterval

    public let eventData: Data
    
    public init(recordNumber: RecordNumber, relativeOffset: TimeInterval, eventData: Data) {
        self.recordNumber = recordNumber
        self.relativeOffset = relativeOffset
        self.eventData = eventData
    }

    var templateType: ProfileTemplateType {
        ProfileTemplateType(rawValue: eventData[eventData.startIndex...].to(ProfileTemplateType.RawValue.self)) ?? .undetermined
    }

    var oldTemplateNumber: Int {
        Int(eventData[eventData.startIndex.advanced(by: 1)...].to(UInt8.self))
    }

    var newTemplateNumber: Int {
        Int(eventData[eventData.startIndex.advanced(by: 2)...].to(UInt8.self))
    }
}

extension ProfileTemplateActivatedHistoryEvent {
    public var description: String {
        "ProfileTemplateActivatedHistoryEvent oldTemplateNumber: \(oldTemplateNumber), newTemplateNumber: \(newTemplateNumber), templateType: \(templateType), recordNumber: \(recordNumber), relativeOffset: \(relativeOffset), eventData: \(eventData.hexadecimalString)"
    }
}

//MARK: - Enumerations

enum ProfileTemplateType: UInt8, CustomStringConvertible {
    case undetermined = 0x0f
    case basalRate = 0x33
    case isf = 0x3c
    case i2choRatio = 0x55
    case targetGlucoseRange = 0x5a
    
    var description: String {
        switch self {
        case .undetermined: return "undetermined"
        case .basalRate: return "basalRate"
        case .isf: return "isf"
        case .i2choRatio: return "i2choRatio"
        case .targetGlucoseRange: return "targetGlucoseRange"
        }
    }
}

