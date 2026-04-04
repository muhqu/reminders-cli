import EventKit

extension EKCalendar: @retroactive Encodable {
    private enum CodingKeys: String, CodingKey {
        case title, id, color, source, sourceType, allowsModification, isImmutable
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.title, forKey: .title)
        try container.encode(self.calendarIdentifier, forKey: .id)
        // Convert CGColor to hex string
        if let components = self.cgColor.components, components.count >= 3 {
            let r = Int(components[0] * 255)
            let g = Int(components[1] * 255)
            let b = Int(components[2] * 255)
            try container.encode(String(format: "#%02X%02X%02X", r, g, b), forKey: .color)
        }
        try container.encodeIfPresent(self.source?.title, forKey: .source)
        // sourceType as string
        if let source = self.source {
            let sourceTypeString: String
            switch source.sourceType {
            case .local: sourceTypeString = "local"
            case .exchange: sourceTypeString = "exchange"
            case .calDAV: sourceTypeString = "calDAV"
            case .mobileMe: sourceTypeString = "mobileMe"
            case .subscribed: sourceTypeString = "subscribed"
            case .birthdays: sourceTypeString = "birthdays"
            @unknown default: sourceTypeString = "unknown"
            }
            try container.encode(sourceTypeString, forKey: .sourceType)
        }
        try container.encode(self.allowsContentModifications, forKey: .allowsModification)
        try container.encode(self.isImmutable, forKey: .isImmutable)
    }
}
