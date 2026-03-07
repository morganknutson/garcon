import Foundation

enum StatusItemToggleAction: Equatable {
    case openPanel
    case closePanel
}

enum StatusItemTogglePolicy {
    static func action(panelIsVisible: Bool) -> StatusItemToggleAction {
        panelIsVisible ? .closePanel : .openPanel
    }
}
