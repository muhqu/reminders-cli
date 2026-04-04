import EventKit

extension EKReminder: @retroactive Encodable {
    private enum EncodingKeys: String, CodingKey {
        case id
        case externalId
        case lastModified
        case creationDate
        case title
        case notes
        case url
        case completionDate
        case isCompleted
        case priority
        case startDate
        case dueDate
        case list
        case recurrence
        case alarms
    }

    private enum RecurrenceCodingKeys: String, CodingKey {
        case frequency
        case interval
        case end
        case count
        case daysOfWeek
    }

    private enum AlarmCodingKeys: String, CodingKey {
        case type
        case date
        case offset
        case locationTitle
        case latitude
        case longitude
        case proximity
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: EncodingKeys.self)
        try container.encode(self.calendarItemIdentifier, forKey: .id)
        try container.encode(self.calendarItemExternalIdentifier, forKey: .externalId)
        try container.encode(self.title, forKey: .title)
        try container.encode(self.isCompleted, forKey: .isCompleted)
        try container.encode(self.priority, forKey: .priority)
        try container.encode(self.calendar.title, forKey: .list)
        try container.encodeIfPresent(self.notes, forKey: .notes)

        // url field is nil
        // https://developer.apple.com/forums/thread/128140
        try container.encodeIfPresent(self.url, forKey: .url)
        try container.encodeIfPresent(format(self.completionDate), forKey: .completionDate)

        if let alarms = self.alarms, !alarms.isEmpty {
            var alarmsArray = container.nestedUnkeyedContainer(forKey: .alarms)
            for alarm in alarms {
                var alarmContainer = alarmsArray.nestedContainer(keyedBy: AlarmCodingKeys.self)
                if let absoluteDate = alarm.absoluteDate {
                    try alarmContainer.encode("absolute", forKey: .type)
                    try alarmContainer.encode(format(absoluteDate), forKey: .date)
                } else if alarm.relativeOffset != 0 {
                    try alarmContainer.encode("relative", forKey: .type)
                    try alarmContainer.encode(alarm.relativeOffset, forKey: .offset)
                }
                if let location = alarm.structuredLocation {
                    try alarmContainer.encode("location", forKey: .type)
                    try alarmContainer.encodeIfPresent(location.title, forKey: .locationTitle)
                    if let geo = location.geoLocation {
                        try alarmContainer.encode(geo.coordinate.latitude, forKey: .latitude)
                        try alarmContainer.encode(geo.coordinate.longitude, forKey: .longitude)
                    }
                    let proximityString: String
                    switch alarm.proximity {
                    case .enter: proximityString = "enter"
                    case .leave: proximityString = "leave"
                    case .none: proximityString = "none"
                    @unknown default: proximityString = "unknown"
                    }
                    try alarmContainer.encode(proximityString, forKey: .proximity)
                }
            }
        }

        if let startDateComponents = self.startDateComponents {
            try container.encodeIfPresent(format(startDateComponents.date), forKey: .startDate)
        }

        if let dueDateComponents = self.dueDateComponents {
            try container.encodeIfPresent(format(dueDateComponents.date), forKey: .dueDate)
        }

        if let lastModifiedDate = self.lastModifiedDate {
            try container.encode(format(lastModifiedDate), forKey: .lastModified)
        }

        if let creationDate = self.creationDate {
            try container.encode(format(creationDate), forKey: .creationDate)
        }

        if let rule = self.recurrenceRules?.first {
            var recurrenceContainer = container.nestedContainer(keyedBy: RecurrenceCodingKeys.self, forKey: .recurrence)
            let frequencyString: String
            switch rule.frequency {
            case .daily: frequencyString = "daily"
            case .weekly: frequencyString = "weekly"
            case .monthly: frequencyString = "monthly"
            case .yearly: frequencyString = "yearly"
            @unknown default: frequencyString = "unknown"
            }
            try recurrenceContainer.encode(frequencyString, forKey: .frequency)
            try recurrenceContainer.encode(rule.interval, forKey: .interval)
            if let endDate = rule.recurrenceEnd?.endDate {
                try recurrenceContainer.encodeIfPresent(format(endDate), forKey: .end)
            }
            if let count = rule.recurrenceEnd?.occurrenceCount, count > 0 {
                try recurrenceContainer.encode(count, forKey: .count)
            }
            if let daysOfWeek = rule.daysOfTheWeek {
                let dayNames = daysOfWeek.map { dayName(for: $0.dayOfTheWeek) }
                try recurrenceContainer.encode(dayNames, forKey: .daysOfWeek)
            }
        }
    }

    private func format(_ date: Date?) -> String? {
        return date?.ISO8601Format()
    }

    private func dayName(for day: EKWeekday) -> String {
        switch day {
        case .monday: return "monday"
        case .tuesday: return "tuesday"
        case .wednesday: return "wednesday"
        case .thursday: return "thursday"
        case .friday: return "friday"
        case .saturday: return "saturday"
        case .sunday: return "sunday"
        @unknown default: return "unknown"
        }
    }
}
