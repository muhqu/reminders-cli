import ArgumentParser
import EventKit

public enum Sort: String, Decodable, ExpressibleByArgument, CaseIterable {
    case none
    case creationDate = "creation-date"
    case dueDate = "due-date"

    public static let commaSeparatedCases = Self.allCases.map { $0.rawValue }.joined(separator: ", ")

    func sortFunction(order: SortOrder) -> (EKReminder, EKReminder) -> Bool {
        let ascending = order == .forward
        switch self {
            case .none: return { _, _ in fatalError() }
            case .creationDate: return {
                ascending ? $0.creationDate! < $1.creationDate! : $0.creationDate! > $1.creationDate!
            }
            case .dueDate: return {
                switch ($0.dueDateComponents, $1.dueDateComponents) {
                    case (.none, .none): return false
                    case (.none, .some): return false
                    case (.some, .none): return true
                    case (.some, .some):
                        let d0 = $0.dueDateComponents!.date!
                        let d1 = $1.dueDateComponents!.date!
                        return ascending ? d0 < d1 : d0 > d1
                }
            }
        }
    }
}

extension SortOrder: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        switch argument.lowercased() {
        case "ascending": self = .forward
        case "descending": self = .reverse
        default: return nil
        }
    }
}
