import Foundation

enum LayoutSelectionRestorationPolicy {
    static func shouldRestore(
        caret: CFRange,
        temporarySelection: CFRange,
        currentSelection: CFRange?,
        currentText: String?,
        expectedText: String
    ) -> Bool {
        guard caret.location >= 0, caret.length == 0,
              temporarySelection.location >= 0, temporarySelection.length > 0,
              currentSelection?.location == temporarySelection.location,
              currentSelection?.length == temporarySelection.length,
              currentText == expectedText else { return false }
        return true
    }
}
