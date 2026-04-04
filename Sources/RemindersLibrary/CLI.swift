import ArgumentParser
import Foundation

private let reminders = Reminders()

private struct ShowLists: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print the name of lists to pass to other commands")
    @Option(
        name: .shortAndLong,
        help: "format, either of 'plain' or 'json'")
    var format: OutputFormat = .plain

    func run() {
        let lists = reminders.getLists()
        switch format {
        case .json:
            print(encodeToJson(data: lists.map { $0.title }))
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

    func run() {
        let savedReminder = reminders.addReminder(
            string: self.reminder.joined(separator: " "),
            notes: self.notes,
            toListNamed: self.listName,
            dueDateComponents: self.dueDate,
            priority: priority)

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

    @Argument(
        parsing: .remaining,
        help: "The new reminder contents")
    var reminder: [String] = []

    func validate() throws {
        let hasTitle = !self.reminder.isEmpty
        if !hasTitle && self.notes == nil && self.dueDate == nil && self.priority == nil && self.list == nil && self.url == nil {
            throw ValidationError("Must specify at least one option to edit (title, --notes, --due-date, --priority, --list, --url)")
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
            newURL: self.url
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

    func run() {
        let newList = reminders.newList(with: self.listName, source: self.source)
        print("Created new list '\(newList.title)'!")
    }
}

public struct CLI: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "reminders",
        abstract: "Interact with macOS Reminders from the command line",
        subcommands: [
            Add.self,
            Complete.self,
            Uncomplete.self,
            Delete.self,
            Edit.self,
            Show.self,
            ShowLists.self,
            NewList.self,
            ShowAll.self,
        ]
    )

    public init() {}
}
