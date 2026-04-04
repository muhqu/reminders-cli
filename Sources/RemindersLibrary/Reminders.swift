import ArgumentParser
import CoreLocation
import EventKit
import Foundation

private let Store = EKEventStore()
private let dateFormatter = RelativeDateTimeFormatter()
private func formattedDueDate(from reminder: EKReminder) -> String? {
    return reminder.dueDateComponents?.date.map {
        dateFormatter.localizedString(for: $0, relativeTo: Date())
    }
}

private extension EKReminder {
    var mappedPriority: EKReminderPriority {
        UInt(exactly: self.priority).flatMap(EKReminderPriority.init) ?? EKReminderPriority.none
    }
}

func format(_ reminder: EKReminder, at index: Int?, listName: String? = nil) -> String {
    let dateString = formattedDueDate(from: reminder).map { " (\($0))" } ?? ""
    let priorityString = Priority(reminder.mappedPriority).map { " (priority: \($0))" } ?? ""
    let listString = listName.map { "\($0): " } ?? ""
    let notesString = reminder.notes.map { " (\($0))" } ?? ""
    let indexString = index.map { "\($0): " } ?? ""
    return "\(listString)\(indexString)\(reminder.title ?? "<unknown>")\(notesString)\(dateString)\(priorityString)"
}

public enum OutputFormat: String, ExpressibleByArgument {
    case json, plain
}

public enum DisplayOptions: String, Decodable {
    case all
    case incomplete
    case complete
}

public enum Priority: String, ExpressibleByArgument {
    case none
    case low
    case medium
    case high

    var value: EKReminderPriority {
        switch self {
            case .none: return .none
            case .low: return .low
            case .medium: return .medium
            case .high: return .high
        }
    }

    init?(_ priority: EKReminderPriority) {
        switch priority {
            case .none: return nil
            case .low: self = .low
            case .medium: self = .medium
            case .high: self = .high
        @unknown default:
            return nil
        }
    }
}

public final class Reminders {
    public static func requestAccess() -> (Bool, Error?) {
        let semaphore = DispatchSemaphore(value: 0)
        var grantedAccess = false
        var returnError: Error? = nil
        Store.requestFullAccessToReminders { granted, error in
            grantedAccess = granted
            returnError = error
            semaphore.signal()
        }

        semaphore.wait()
        return (grantedAccess, returnError)
    }

    func getListNames() -> [String] {
        return self.getCalendars().map { $0.title }
    }

    func getLists() -> [EKCalendar] {
        return self.getCalendars()
    }

    func getAllReminders(dueOn dueDate: DateComponents?, includeOverdue: Bool,
        displayOptions: DisplayOptions) -> [EKReminder]
    {
        let semaphore = DispatchSemaphore(value: 0)
        let calendar = Calendar.current
        var result: [EKReminder] = []

        self.reminders(on: self.getCalendars(), displayOptions: displayOptions) { reminders in
            for reminder in reminders {
                guard let dueDate = dueDate?.date else {
                    result.append(reminder)
                    continue
                }

                guard let reminderDueDate = reminder.dueDateComponents?.date else {
                    continue
                }

                let sameDay = calendar.compare(
                    reminderDueDate, to: dueDate, toGranularity: .day) == .orderedSame
                let earlierDay = calendar.compare(
                    reminderDueDate, to: dueDate, toGranularity: .day) == .orderedAscending

                if sameDay || (includeOverdue && earlierDay) {
                    result.append(reminder)
                }
            }

            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    func getListItems(withName name: String, dueOn dueDate: DateComponents?, includeOverdue: Bool,
        displayOptions: DisplayOptions, sort: Sort, sortOrder: SortOrder) -> [EKReminder]
    {
        let semaphore = DispatchSemaphore(value: 0)
        let calendar = Calendar.current
        var result: [EKReminder] = []

        self.reminders(on: [self.calendar(withName: name)], displayOptions: displayOptions) { reminders in
            let reminders = sort == .none ? reminders : reminders.sorted(by: sort.sortFunction(order: sortOrder))
            for reminder in reminders {
                guard let dueDate = dueDate?.date else {
                    result.append(reminder)
                    continue
                }

                guard let reminderDueDate = reminder.dueDateComponents?.date else {
                    continue
                }

                let sameDay = calendar.compare(
                    reminderDueDate, to: dueDate, toGranularity: .day) == .orderedSame
                let earlierDay = calendar.compare(
                    reminderDueDate, to: dueDate, toGranularity: .day) == .orderedAscending

                if sameDay || (includeOverdue && earlierDay) {
                    result.append(reminder)
                }
            }

            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    func newList(with name: String, source requestedSourceName: String?) -> EKCalendar {
        let store = EKEventStore()
        let sources = store.sources
        guard var source = sources.first else {
            print("No existing list sources were found, please create a list in Reminders.app")
            exit(1)
        }

        if let requestedSourceName = requestedSourceName {
            guard let requestedSource = sources.first(where: { $0.title == requestedSourceName }) else
            {
                print("No source named '\(requestedSourceName)'")
                exit(1)
            }

            source = requestedSource
        } else {
            let uniqueSources = Set(sources.map { $0.title })
            if uniqueSources.count > 1 {
                print("Multiple sources were found, please specify one with --source:")
                for source in uniqueSources {
                    print("  \(source)")
                }

                exit(1)
            }
        }

        let newList = EKCalendar(for: .reminder, eventStore: store)
        newList.title = name
        newList.source = source

        do {
            try store.saveCalendar(newList, commit: true)
            return newList
        } catch let error {
            print("Failed create new list with error: \(error)")
            exit(1)
        }
    }

    func edit(
        itemAtIndex index: String,
        onListNamed name: String,
        newText: String?,
        newNotes: String?,
        newDueDate: DateComponents? = nil,
        newPriority: Priority? = nil,
        newListName: String? = nil,
        newURL: String? = nil,
        repeatFrequency: String? = nil,
        repeatInterval: Int? = nil,
        repeatEnd: DateComponents? = nil,
        alarmSpecs: [String] = [],
        clearAlarms: Bool = false,
        locationTitle: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        radius: Double? = nil,
        proximity: String? = nil,
        clearLocation: Bool = false
    ) -> EKReminder {
        let calendar = self.calendar(withName: name)
        let semaphore = DispatchSemaphore(value: 0)
        var result: EKReminder!

        self.reminders(on: [calendar], displayOptions: .incomplete) { reminders in
            guard let reminder = self.getReminder(from: reminders, at: index) else {
                print("No reminder at index \(index) on \(name)")
                exit(1)
            }

            do {
                if let newText = newText {
                    reminder.title = newText
                }
                if let newNotes = newNotes {
                    reminder.notes = newNotes
                }
                if let newDueDate = newDueDate {
                    reminder.dueDateComponents = newDueDate
                }
                if let newPriority = newPriority {
                    reminder.priority = Int(newPriority.value.rawValue)
                }
                if let newListName = newListName {
                    reminder.calendar = self.calendar(withName: newListName)
                }
                if let newURL = newURL {
                    reminder.url = URL(string: newURL)
                }
                if let repeatFrequency = repeatFrequency {
                    // Remove existing recurrence rules
                    for rule in reminder.recurrenceRules ?? [] {
                        reminder.removeRecurrenceRule(rule)
                    }
                    // Add new rule unless "none"
                    if repeatFrequency != "none" {
                        if let rule = Self.makeRecurrenceRule(frequency: repeatFrequency, interval: repeatInterval ?? 1, endDate: repeatEnd) {
                            reminder.addRecurrenceRule(rule)
                        }
                    }
                }
                if clearAlarms || !alarmSpecs.isEmpty {
                    // Remove existing alarms
                    for alarm in reminder.alarms ?? [] {
                        reminder.removeAlarm(alarm)
                    }
                    // Add new alarms if specs provided
                    for spec in alarmSpecs {
                        if let alarm = Self.parseAlarmSpec(spec) {
                            reminder.addAlarm(alarm)
                        }
                    }
                }
                if clearLocation {
                    // Remove location-based alarms
                    for alarm in reminder.alarms ?? [] {
                        if alarm.structuredLocation != nil {
                            reminder.removeAlarm(alarm)
                        }
                    }
                } else if let locationTitle = locationTitle, let lat = latitude, let lon = longitude {
                    // Remove existing location alarms first
                    for alarm in reminder.alarms ?? [] {
                        if alarm.structuredLocation != nil {
                            reminder.removeAlarm(alarm)
                        }
                    }
                    let alarm = Self.makeLocationAlarm(
                        title: locationTitle, latitude: lat, longitude: lon,
                        radius: radius ?? 100, proximity: proximity ?? "enter")
                    reminder.addAlarm(alarm)
                }
                try Store.save(reminder, commit: true)
                result = reminder
            } catch let error {
                print("Failed to update reminder with error: \(error)")
                exit(1)
            }

            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    func setComplete(_ complete: Bool, itemAtIndex index: String, onListNamed name: String) -> EKReminder {
        let calendar = self.calendar(withName: name)
        let semaphore = DispatchSemaphore(value: 0)
        let displayOptions = complete ? DisplayOptions.incomplete : .complete
        var result: EKReminder!

        self.reminders(on: [calendar], displayOptions: displayOptions) { reminders in
            guard let reminder = self.getReminder(from: reminders, at: index) else {
                print("No reminder at index \(index) on \(name)")
                exit(1)
            }

            do {
                reminder.isCompleted = complete
                try Store.save(reminder, commit: true)
                result = reminder
            } catch let error {
                print("Failed to save reminder with error: \(error)")
                exit(1)
            }

            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    func delete(itemAtIndex index: String, onListNamed name: String) -> (id: String, externalId: String, title: String) {
        let calendar = self.calendar(withName: name)
        let semaphore = DispatchSemaphore(value: 0)
        var result: (id: String, externalId: String, title: String)!

        self.reminders(on: [calendar], displayOptions: .incomplete) { reminders in
            guard let reminder = self.getReminder(from: reminders, at: index) else {
                print("No reminder at index \(index) on \(name)")
                exit(1)
            }

            let title = reminder.title ?? "<unknown>"
            let externalId = reminder.calendarItemExternalIdentifier ?? ""
            let id = reminder.calendarItemIdentifier

            do {
                try Store.remove(reminder, commit: true)
                result = (id: id, externalId: externalId, title: title)
            } catch let error {
                print("Failed to delete reminder with error: \(error)")
                exit(1)
            }

            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    func addReminder(
        string: String,
        notes: String?,
        toListNamed name: String,
        dueDateComponents: DateComponents?,
        priority: Priority,
        repeatFrequency: String? = nil,
        repeatInterval: Int? = nil,
        repeatEnd: DateComponents? = nil,
        alarmSpecs: [String] = [],
        locationTitle: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        radius: Double? = nil,
        proximity: String? = nil) -> EKReminder
    {
        let calendar = self.calendar(withName: name)
        let reminder = EKReminder(eventStore: Store)
        reminder.calendar = calendar
        reminder.title = string
        reminder.notes = notes
        reminder.dueDateComponents = dueDateComponents
        reminder.priority = Int(priority.value.rawValue)

        if !alarmSpecs.isEmpty {
            for spec in alarmSpecs {
                if let alarm = Self.parseAlarmSpec(spec) {
                    reminder.addAlarm(alarm)
                }
            }
        } else if let dueDate = dueDateComponents?.date, dueDateComponents?.hour != nil {
            reminder.addAlarm(EKAlarm(absoluteDate: dueDate))
        }

        if let repeatFrequency = repeatFrequency, repeatFrequency != "none" {
            if let rule = Self.makeRecurrenceRule(frequency: repeatFrequency, interval: repeatInterval ?? 1, endDate: repeatEnd) {
                reminder.addRecurrenceRule(rule)
            }
        }

        if let locationTitle = locationTitle, let lat = latitude, let lon = longitude {
            let alarm = Self.makeLocationAlarm(
                title: locationTitle, latitude: lat, longitude: lon,
                radius: radius ?? 100, proximity: proximity ?? "enter")
            reminder.addAlarm(alarm)
        }

        do {
            try Store.save(reminder, commit: true)
            return reminder
        } catch let error {
            print("Failed to save reminder with error: \(error)")
            exit(1)
        }
    }

    func deleteList(named name: String) -> String {
        let calendar = self.calendar(withName: name)
        let title = calendar.title
        do {
            try Store.removeCalendar(calendar, commit: true)
            return title
        } catch let error {
            print("Failed to delete list with error: \(error)")
            exit(1)
        }
    }

    func renameList(named name: String, newName: String) -> EKCalendar {
        let calendar = self.calendar(withName: name)
        calendar.title = newName
        do {
            try Store.saveCalendar(calendar, commit: true)
            return calendar
        } catch let error {
            print("Failed to rename list with error: \(error)")
            exit(1)
        }
    }

    // MARK: - Alarm helpers

    static func parseAlarmSpec(_ spec: String) -> EKAlarm? {
        // Check for relative offset: -Nm, -Nh, -Nd
        let pattern = #"^-(\d+)([mhd])$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: spec, range: NSRange(spec.startIndex..., in: spec)) {
            let numberRange = Range(match.range(at: 1), in: spec)!
            let unitRange = Range(match.range(at: 2), in: spec)!
            let number = Double(spec[numberRange])!
            let unit = spec[unitRange]
            let seconds: Double
            switch unit {
            case "m": seconds = -number * 60
            case "h": seconds = -number * 3600
            case "d": seconds = -number * 86400
            default: return nil
            }
            return EKAlarm(relativeOffset: seconds)
        }

        // Try parsing as a date string
        if let dateComponents = DateComponents(argument: spec), let date = dateComponents.date {
            return EKAlarm(absoluteDate: date)
        }

        print("Warning: could not parse alarm spec '\(spec)'")
        return nil
    }

    // MARK: - Location helpers

    private static func makeLocationAlarm(title: String, latitude: Double, longitude: Double, radius: Double, proximity: String) -> EKAlarm {
        let structuredLocation = EKStructuredLocation(title: title)
        structuredLocation.geoLocation = CLLocation(latitude: latitude, longitude: longitude)
        structuredLocation.radius = radius
        let alarm = EKAlarm()
        alarm.structuredLocation = structuredLocation
        alarm.proximity = proximity == "leave" ? .leave : .enter
        return alarm
    }

    // MARK: - Recurrence helpers

    private static func parseFrequency(_ string: String) -> EKRecurrenceFrequency? {
        switch string.lowercased() {
        case "daily": return .daily
        case "weekly": return .weekly
        case "monthly": return .monthly
        case "yearly": return .yearly
        default: return nil
        }
    }

    private static func makeRecurrenceRule(frequency: String, interval: Int, endDate: DateComponents?) -> EKRecurrenceRule? {
        guard let freq = parseFrequency(frequency) else {
            print("Unknown recurrence frequency '\(frequency)'. Use: daily, weekly, monthly, yearly, none")
            return nil
        }
        let end: EKRecurrenceEnd? = endDate?.date.map { EKRecurrenceEnd(end: $0) }
        return EKRecurrenceRule(recurrenceWith: freq, interval: interval, end: end)
    }

    // MARK: - Private functions

    private func reminders(
        on calendars: [EKCalendar],
        displayOptions: DisplayOptions,
        completion: @escaping (_ reminders: [EKReminder]) -> Void)
    {
        let predicate = Store.predicateForReminders(in: calendars)
        Store.fetchReminders(matching: predicate) { reminders in
            let reminders = reminders?
                .filter { self.shouldDisplay(reminder: $0, displayOptions: displayOptions) }
            completion(reminders ?? [])
        }
    }

    private func shouldDisplay(reminder: EKReminder, displayOptions: DisplayOptions) -> Bool {
        switch displayOptions {
        case .all:
            return true
        case .incomplete:
            return !reminder.isCompleted
        case .complete:
            return reminder.isCompleted
        }
    }

    private func calendar(withName name: String) -> EKCalendar {
        if let calendar = self.getCalendars().find(where: { $0.title.lowercased() == name.lowercased() }) {
            return calendar
        } else {
            print("No reminders list matching \(name)")
            exit(1)
        }
    }

    private func getCalendars() -> [EKCalendar] {
        return Store.calendars(for: .reminder)
                    .filter { $0.allowsContentModifications }
    }

    private func getReminder(from reminders: [EKReminder], at index: String) -> EKReminder? {
        precondition(!index.isEmpty, "Index cannot be empty, argument parser must be misconfigured")
        if let index = Int(index) {
            return reminders[safe: index]
        } else {
            return reminders.first { $0.calendarItemExternalIdentifier == index }
        }
    }

}

func encodeToJson(data: Encodable) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let encoded = try! encoder.encode(data)
    return String(data: encoded, encoding: .utf8) ?? ""
}
