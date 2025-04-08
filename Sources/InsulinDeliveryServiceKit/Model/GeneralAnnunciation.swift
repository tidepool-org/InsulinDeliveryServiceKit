//
//  GeneralAnnunciation.swift
//  InsulinDeliveryServiceKit
//
//  Created by Nathaniel Hamming on 2025-03-14.
//  Copyright © 2025 Tidepool Project. All rights reserved.
//

import Foundation

public struct GeneralAnnunciation: Annunciation, Equatable, Hashable {
    public let type: AnnunciationType
    
    public let identifier: AnnunciationIdentifier

    public var status: AnnunciationStatus
    
    public var auxiliaryData: Data?
    
    public init(type: AnnunciationType, identifier: AnnunciationIdentifier, status: AnnunciationStatus, auxiliaryData: Data?) {
        self.type = type
        self.identifier = identifier
        self.status = status
        self.auxiliaryData = auxiliaryData
    }
    
    public init(from annunication: Annunciation) {
        self.type = annunication.type
        self.identifier = annunication.identifier
        self.status = annunication.status
        self.auxiliaryData = annunication.auxiliaryData
    }
}

extension GeneralAnnunciation: RawRepresentable {
    public typealias RawValue = [String: Any]

    private enum GeneralAnnunciationKey: String {
        case auxiliaryData
        case identifier
        case status
        case type
    }

    public var rawValue: RawValue {
        var rawValue: [String: Any] = [
            GeneralAnnunciationKey.type.rawValue: type.rawValue,
            GeneralAnnunciationKey.identifier.rawValue: identifier,
            GeneralAnnunciationKey.status.rawValue: status.rawValue
        ]
        
        rawValue[GeneralAnnunciationKey.auxiliaryData.rawValue] = auxiliaryData
        
        return rawValue
    }

    public init?(rawValue: [String : Any]) {
        guard let rawType = rawValue[GeneralAnnunciationKey.type.rawValue] as? AnnunciationType.RawValue,
              let identifier = rawValue[GeneralAnnunciationKey.identifier.rawValue] as? AnnunciationIdentifier,
              let rawStatus = rawValue[GeneralAnnunciationKey.status.rawValue] as? AnnunciationStatus.RawValue
        else { return nil }

        self.type = AnnunciationType(rawValue: rawType)
        self.identifier = identifier
        self.status = AnnunciationStatus(rawValue: rawStatus) ?? .undetermined
        self.auxiliaryData = rawValue[GeneralAnnunciationKey.auxiliaryData.rawValue] as? Data
    }
}
