import XCTest
@testable import Garcon

final class StatusItemTogglePolicyTests: XCTestCase {
    func testWhenPanelIsVisibleActionIsClosePanel() {
        XCTAssertEqual(
            StatusItemTogglePolicy.action(panelIsVisible: true),
            .closePanel
        )
    }

    func testWhenPanelIsHiddenActionIsOpenPanel() {
        XCTAssertEqual(
            StatusItemTogglePolicy.action(panelIsVisible: false),
            .openPanel
        )
    }
}
