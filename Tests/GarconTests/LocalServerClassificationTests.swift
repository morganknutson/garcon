import XCTest
@testable import Garcon

final class LocalServerClassificationTests: XCTestCase {
    func testCursorHelperPluginIsClassifiedAsSystemSection() {
        let server = LocalServer(
            pid: 1234,
            processName: "Cursor Helper (Plugin)",
            port: 59380,
            scheme: "http",
            pageTitle: nil,
            executablePath: "/Applications/Cursor.app/Contents/Frameworks/Cursor Helper (Plugin).app/Contents/MacOS/Cursor Helper (Plugin)",
            isUserLaunched: true
        )

        XCTAssertTrue(server.isLikelyAppHelperProcess)
        XCTAssertFalse(server.appearsInPrimaryList)
    }

    func testCursorExtensionHostWithoutAppPathIsClassifiedAsSystemSection() {
        let server = LocalServer(
            pid: 4321,
            processName: "Cursor Helper (Plugin)",
            port: 59381,
            scheme: "http",
            pageTitle: "Cursor Helper (Plugin)",
            executablePath: "Cursor Helper (Plugin): extension-host (user) [2-1]",
            isUserLaunched: true
        )

        XCTAssertTrue(server.isLikelyAppHelperProcess)
        XCTAssertFalse(server.appearsInPrimaryList)
    }

    func testTerminalLaunchedDeveloperServerRemainsPrimary() {
        let server = LocalServer(
            pid: 5678,
            processName: "node",
            port: 3000,
            scheme: "http",
            pageTitle: nil,
            executablePath: "/Users/me/.nvm/versions/node/v22.0.0/bin/node",
            isUserLaunched: true
        )

        XCTAssertFalse(server.isLikelyAppHelperProcess)
        XCTAssertTrue(server.appearsInPrimaryList)
    }

    func testHelperDisplayTitleForcesSystemSection() {
        let server = LocalServer(
            pid: 2468,
            processName: "Cursor",
            port: 6000,
            scheme: "http",
            pageTitle: "Cursor Helper (Plugin)",
            executablePath: nil,
            isUserLaunched: true
        )

        XCTAssertFalse(server.appearsInPrimaryList)
    }
}
