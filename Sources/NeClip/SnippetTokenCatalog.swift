import Foundation

enum SnippetTokenCatalog {
    enum Token: String, CaseIterable, Hashable, Identifiable, Sendable {
        case date = "{date}"
        case time = "{time}"
        case clipboard = "{clipboard}"
        case isoDate = "{date:iso}"
        case isoTime = "{time:iso}"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .date: "Дата"
            case .time: "Время"
            case .clipboard: "Текущий буфер"
            case .isoDate: "Дата ISO"
            case .isoTime: "Время ISO"
            }
        }

        var example: String {
            switch self {
            case .date: "12.09.2026"
            case .time: "19:30"
            case .clipboard: "текст из буфера"
            case .isoDate: "2026-09-12"
            case .isoTime: "19:30:00"
            }
        }
    }
}
