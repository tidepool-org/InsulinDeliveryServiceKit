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

    init(type: AnnunciationType, identifier: AnnunciationIdentifier) {
        self.type = type
        self.identifier = identifier
    }
}

extension GeneralAnnunciation: RawRepresentable {
    public typealias RawValue = [String: Any]

    private enum GeneralAnnunciationKey: String {
        case type
        case identifier
    }

    public var rawValue: RawValue {
        return [
            GeneralAnnunciationKey.type.rawValue: type.rawValue,
            GeneralAnnunciationKey.identifier.rawValue: identifier
        ]
    }

    public init?(rawValue: [String : Any]) {
        guard let rawType = rawValue[GeneralAnnunciationKey.type.rawValue] as? AnnunciationType.RawValue,
              let type = AnnunciationType(rawValue: rawType),
              let identifier = rawValue[GeneralAnnunciationKey.identifier.rawValue] as? AnnunciationIdentifier
        else { return nil }

        self.type = type
        self.identifier = identifier
    }
}
