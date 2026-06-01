import ArgumentParser
import Foundation

private let reminders = Reminders()

private struct ListAccessEntry: Encodable {
    let title: String
    let allowed: Bool
}

private struct ShowLists: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print the name of lists to pass to other commands")

    @Flag(help: "Show all lists, including those not granted by your config")
    var all = false

    @Option(
        name: .shortAndLong,
        help: "format, either of 'plain' or 'json'")
    var format: OutputFormat = .plain

    func run() {
        if all {
            let report = reminders.listAccessReport()
            switch format {
            case .json:
                print(encodeToJson(data: report.map { ListAccessEntry(title: $0.name, allowed: $0.allowed) }))
            case .plain:
                for entry in report {
                    print(entry.allowed ? "\(entry.name) [allowed]" : entry.name)
                }
            }
            return
        }

        let lists = reminders.getLists()
        switch format {
        case .json:
            print(encodeToJson(data: lists))
        case .plain:
            for list in lists {
                print(list.title)
            }
        }
    }
}

private struct ShowAll: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print all reminders")

    @Flag(help: "Show completed items only")
    var onlyCompleted = false

    @Flag(help: "Include completed items in output")
    var includeCompleted = false

    @Flag(help: "When using --due-date, also include items due before the due date")
    var includeOverdue = false

    @Option(
        name: .shortAndLong,
        help: "Show only reminders due on this date")
    var dueDate: DateComponents?

    @Option(
        name: .shortAndLong,
        help: "format, either of 'plain' or 'json'")
    var format: OutputFormat = .plain

    func validate() throws {
        if self.onlyCompleted && self.includeCompleted {
            throw ValidationError(
                "Cannot specify both --show-completed and --only-completed")
        }
    }

    func run() {
        var displayOptions = DisplayOptions.incomplete
        if self.onlyCompleted {
            displayOptions = .complete
        } else if self.includeCompleted {
            displayOptions = .all
        }

        let items = reminders.getAllReminders(
            dueOn: self.dueDate, includeOverdue: self.includeOverdue,
            displayOptions: displayOptions)

        switch format {
        case .json:
            print(encodeToJson(data: items))
        case .plain:
            for (i, reminder) in items.enumerated() {
                let listName = reminder.calendar.title
                print(RemindersLibrary.format(reminder, at: i, listName: listName))
            }
        }
    }
}

private struct Show: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print the items on the given list")

    @Argument(
        help: "The list to print items from, see 'show-lists' for names",
        completion: .custom(listNameCompletion))
    var listName: String

    @Flag(help: "Show completed items only")
    var onlyCompleted = false

    @Flag(help: "Include completed items in output")
    var includeCompleted = false

    @Flag(help: "When using --due-date, also include items due before the due date")
    var includeOverdue = false

    @Option(
        name: .shortAndLong,
        help: "Show the reminders in a specific order, one of: \(Sort.commaSeparatedCases)")
    var sort: Sort = .none

    @Option(
        name: [.customShort("o"), .long],
        help: "How the sort order should be applied, one of: ascending, descending")
    var sortOrder: SortOrder = .forward

    @Option(
        name: .shortAndLong,
        help: "Show only reminders due on this date")
    var dueDate: DateComponents?

    @Option(
        name: .shortAndLong,
        help: "format, either of 'plain' or 'json'")
    var format: OutputFormat = .plain

    func validate() throws {
        if self.onlyCompleted && self.includeCompleted {
            throw ValidationError(
                "Cannot specify both --show-completed and --only-completed")
        }
    }

    func run() {
        var displayOptions = DisplayOptions.incomplete
        if self.onlyCompleted {
            displayOptions = .complete
        } else if self.includeCompleted {
            displayOptions = .all
        }

        let items = reminders.getListItems(
            withName: self.listName, dueOn: self.dueDate, includeOverdue: self.includeOverdue,
            displayOptions: displayOptions, sort: sort, sortOrder: sortOrder)

        switch format {
        case .json:
            print(encodeToJson(data: items))
        case .plain:
            for (i, reminder) in items.enumerated() {
                let index = sort == .none ? i : nil
                print(RemindersLibrary.format(reminder, at: index))
            }
        }
    }
}

private struct Add: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Add a reminder to a list")

    @Argument(
        help: "The list to add to, see 'show-lists' for names",
        completion: .custom(listNameCompletion))
    var listName: String

    @Argument(
        parsing: .remaining,
        help: "The reminder contents")
    var reminder: [String]

    @Option(
        name: .shortAndLong,
        help: "The date the reminder is due")
    var dueDate: DateComponents?

    @Option(
        name: .shortAndLong,
        help: "The priority of the reminder")
    var priority: Priority = .none

    @Option(
        name: .shortAndLong,
        help: "format, either of 'plain' or 'json'")
    var format: OutputFormat = .plain

    @Option(
        name: .shortAndLong,
        help: "The notes to add to the reminder")
    var notes: String?

    @Option(
        help: "Recurrence frequency: daily, weekly, monthly, yearly, none")
    var `repeat`: String?

    @Option(
        help: "Recurrence interval (default 1)")
    var repeatInterval: Int?

    @Option(
        help: "End date for recurrence")
    var repeatEnd: DateComponents?

    @Option(
        parsing: .singleValue,
        help: "Alarm spec: date string for absolute, or -Nm/-Nh/-Nd for relative offset (repeatable)")
    var alarm: [String] = []

    @Option(
        help: "Location title for a location-based reminder")
    var location: String?

    @Option(
        help: "Latitude for location-based reminder")
    var latitude: Double?

    @Option(
        help: "Longitude for location-based reminder")
    var longitude: Double?

    @Option(
        help: "Geofence radius in meters (default 100)")
    var radius: Double?

    @Option(
        help: "Trigger on 'enter' or 'leave' (default 'enter')")
    var proximity: String?

    func run() {
        let savedReminder = reminders.addReminder(
            string: self.reminder.joined(separator: " "),
            notes: self.notes,
            toListNamed: self.listName,
            dueDateComponents: self.dueDate,
            priority: priority,
            repeatFrequency: self.repeat,
            repeatInterval: self.repeatInterval,
            repeatEnd: self.repeatEnd,
            alarmSpecs: self.alarm,
            locationTitle: self.location,
            latitude: self.latitude,
            longitude: self.longitude,
            radius: self.radius,
            proximity: self.proximity)

        switch format {
        case .json:
            print(encodeToJson(data: savedReminder))
        case .plain:
            print("Added '\(savedReminder.title!)' to '\(savedReminder.calendar.title)'")
        }
    }
}

private struct Complete: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Complete a reminder")

    @Argument(
        help: "The list to complete a reminder on, see 'show-lists' for names",
        completion: .custom(listNameCompletion))
    var listName: String

    @Argument(
        help: "The index or id of the reminder to delete, see 'show' for indexes")
    var index: String

    @Option(
        name: .shortAndLong,
        help: "format, either of 'plain' or 'json'")
    var format: OutputFormat = .plain

    func run() {
        let reminder = reminders.setComplete(true, itemAtIndex: self.index, onListNamed: self.listName)
        switch format {
        case .json:
            print(encodeToJson(data: reminder))
        case .plain:
            print("Completed '\(reminder.title!)'")
        }
    }
}

private struct Uncomplete: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Uncomplete a reminder")

    @Argument(
        help: "The list to uncomplete a reminder on, see 'show-lists' for names",
        completion: .custom(listNameCompletion))
    var listName: String

    @Argument(
        help: "The index or id of the reminder to delete, see 'show' for indexes")
    var index: String

    @Option(
        name: .shortAndLong,
        help: "format, either of 'plain' or 'json'")
    var format: OutputFormat = .plain

    func run() {
        let reminder = reminders.setComplete(false, itemAtIndex: self.index, onListNamed: self.listName)
        switch format {
        case .json:
            print(encodeToJson(data: reminder))
        case .plain:
            print("Uncompleted '\(reminder.title!)'")
        }
    }
}

private struct Delete: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Delete a reminder")

    @Argument(
        help: "The list to delete a reminder on, see 'show-lists' for names",
        completion: .custom(listNameCompletion))
    var listName: String

    @Argument(
        help: "The index or id of the reminder to delete, see 'show' for indexes")
    var index: String

    @Option(
        name: .shortAndLong,
        help: "format, either of 'plain' or 'json'")
    var format: OutputFormat = .plain

    func run() {
        let result = reminders.delete(itemAtIndex: self.index, onListNamed: self.listName)
        switch format {
        case .json:
            let jsonResult: [String: String] = [
                "id": result.id,
                "externalId": result.externalId,
                "title": result.title,
                "status": "deleted"
            ]
            print(encodeToJson(data: jsonResult))
        case .plain:
            print("Deleted '\(result.title)'")
        }
    }
}

func listNameCompletion(_ arguments: [String]) -> [String] {
    // NOTE: A list name with ':' was separated in zsh completion, there might be more of these or
    // this might break other shells
    return reminders.getListNames().map { $0.replacingOccurrences(of: ":", with: "\\:") }
}

private struct Edit: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Edit the text of a reminder")

    @Argument(
        help: "The list to edit a reminder on, see 'show-lists' for names",
        completion: .custom(listNameCompletion))
    var listName: String

    @Argument(
        help: "The index or id of the reminder to delete, see 'show' for indexes")
    var index: String

    @Option(
        name: .shortAndLong,
        help: "The notes to set on the reminder, overwriting previous notes")
    var notes: String?

    @Option(
        name: .shortAndLong,
        help: "The date the reminder is due")
    var dueDate: DateComponents?

    @Option(
        name: .shortAndLong,
        help: "The priority of the reminder")
    var priority: Priority?

    @Option(
        name: .shortAndLong,
        help: "Move the reminder to a different list")
    var list: String?

    @Option(
        name: .shortAndLong,
        help: "Set/change the URL of the reminder")
    var url: String?

    @Option(
        help: "Recurrence frequency: daily, weekly, monthly, yearly, none")
    var `repeat`: String?

    @Option(
        help: "Recurrence interval (default 1)")
    var repeatInterval: Int?

    @Option(
        help: "End date for recurrence")
    var repeatEnd: DateComponents?

    @Option(
        parsing: .singleValue,
        help: "Alarm spec: date string for absolute, or -Nm/-Nh/-Nd for relative offset (repeatable, replaces existing alarms)")
    var alarm: [String] = []

    @Flag(
        help: "Remove all alarms from the reminder")
    var clearAlarms = false

    @Option(
        help: "Location title for a location-based reminder")
    var location: String?

    @Option(
        help: "Latitude for location-based reminder")
    var latitude: Double?

    @Option(
        help: "Longitude for location-based reminder")
    var longitude: Double?

    @Option(
        help: "Geofence radius in meters (default 100)")
    var radius: Double?

    @Option(
        help: "Trigger on 'enter' or 'leave' (default 'enter')")
    var proximity: String?

    @Flag(
        help: "Remove the location-based alarm from the reminder")
    var clearLocation = false

    @Argument(
        parsing: .remaining,
        help: "The new reminder contents")
    var reminder: [String] = []

    func validate() throws {
        let hasTitle = !self.reminder.isEmpty
        if !hasTitle && self.notes == nil && self.dueDate == nil && self.priority == nil && self.list == nil && self.url == nil && self.repeat == nil && self.alarm.isEmpty && !self.clearAlarms && self.location == nil && !self.clearLocation {
            throw ValidationError("Must specify at least one option to edit (title, --notes, --due-date, --priority, --list, --url, --repeat, --alarm, --clear-alarms, --location, --clear-location)")
        }
    }

    @Option(
        name: .shortAndLong,
        help: "format, either of 'plain' or 'json'")
    var format: OutputFormat = .plain

    func run() {
        let newText = self.reminder.joined(separator: " ")
        let updatedReminder = reminders.edit(
            itemAtIndex: self.index,
            onListNamed: self.listName,
            newText: newText.isEmpty ? nil : newText,
            newNotes: self.notes,
            newDueDate: self.dueDate,
            newPriority: self.priority,
            newListName: self.list,
            newURL: self.url,
            repeatFrequency: self.repeat,
            repeatInterval: self.repeatInterval,
            repeatEnd: self.repeatEnd,
            alarmSpecs: self.alarm,
            clearAlarms: self.clearAlarms,
            locationTitle: self.location,
            latitude: self.latitude,
            longitude: self.longitude,
            radius: self.radius,
            proximity: self.proximity,
            clearLocation: self.clearLocation
        )

        switch format {
        case .json:
            print(encodeToJson(data: updatedReminder))
        case .plain:
            print("Updated reminder '\(updatedReminder.title!)'")
        }
    }
}


private struct NewList: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Create a new list")

    @Argument(
        help: "The name of the new list")
    var listName: String

    @Option(
        name: .shortAndLong,
        help: "The name of the source of the list, if all your lists use the same source it will default to that")
    var source: String?

    @Option(
        name: .shortAndLong,
        help: "format, either of 'plain' or 'json'")
    var format: OutputFormat = .plain

    func run() {
        let newList = reminders.newList(with: self.listName, source: self.source)
        switch format {
        case .json:
            print(encodeToJson(data: newList))
        case .plain:
            print("Created new list '\(newList.title)'!")
        }
    }
}

private struct DeleteList: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Delete a list")

    @Argument(
        help: "The name of the list to delete",
        completion: .custom(listNameCompletion))
    var listName: String

    @Flag(
        help: "Confirm deletion (required for safety)")
    var confirm = false

    @Option(
        name: .shortAndLong,
        help: "format, either of 'plain' or 'json'")
    var format: OutputFormat = .plain

    func validate() throws {
        if !self.confirm {
            throw ValidationError("Must pass --confirm to delete a list")
        }
    }

    func run() {
        let title = reminders.deleteList(named: self.listName)
        switch format {
        case .json:
            let jsonResult: [String: String] = [
                "title": title,
                "status": "deleted"
            ]
            print(encodeToJson(data: jsonResult))
        case .plain:
            print("Deleted list '\(title)'")
        }
    }
}

private struct RenameList: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Rename a list")

    @Argument(
        help: "The current name of the list",
        completion: .custom(listNameCompletion))
    var listName: String

    @Argument(
        help: "The new name for the list")
    var newName: String

    @Option(
        name: .shortAndLong,
        help: "format, either of 'plain' or 'json'")
    var format: OutputFormat = .plain

    func run() {
        let calendar = reminders.renameList(named: self.listName, newName: self.newName)
        switch format {
        case .json:
            let jsonResult: [String: String] = [
                "title": calendar.title,
                "status": "renamed"
            ]
            print(encodeToJson(data: jsonResult))
        case .plain:
            print("Renamed list to '\(calendar.title)'")
        }
    }
}

private struct InitConfig: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init-config",
        abstract: "Create a starter access-control config at ~/.config/reminders-cli.yml")

    @Flag(help: "Overwrite an existing config file")
    var force = false

    func run() throws {
        let url = configURL()
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path) && !self.force {
            print("Config already exists at \(url.path) (use --force to overwrite)")
            throw ExitCode.failure
        }

        let template = configTemplate(listNames: reminders.enumerateAllListNames())
        do {
            try fileManager.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try template.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to write config: \(error.localizedDescription)")
            throw ExitCode.failure
        }

        print("Wrote \(url.path)")
        print("Edit it to allow the lists you want, then re-run your command.")
    }
}

public struct CLI: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "reminders",
        abstract: "Interact with macOS Reminders from the command line",
        version: remindersVersion,
        subcommands: [
            Add.self,
            Complete.self,
            Uncomplete.self,
            Delete.self,
            DeleteList.self,
            Edit.self,
            RenameList.self,
            Show.self,
            ShowLists.self,
            NewList.self,
            ShowAll.self,
            InitConfig.self,
        ]
    )

    public init() {}
}
