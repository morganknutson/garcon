import XCTest
@testable import Garcon

final class ProcessClassifierTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: ProcessClassifier.customHintsDefaultsKey)
        super.tearDown()
    }

    func testShellExecutableIsTrusted() {
        XCTAssertTrue(ProcessClassifier.isTrustedAncestorCommand("/bin/zsh"))
        XCTAssertTrue(ProcessClassifier.isTrustedAncestorCommand("/opt/homebrew/bin/bash"))
    }

    func testTerminalAndEditorCommandsAreTrusted() {
        XCTAssertTrue(ProcessClassifier.isTrustedAncestorCommand("/Applications/iTerm.app/Contents/MacOS/iTerm2"))
        XCTAssertTrue(ProcessClassifier.isTrustedAncestorCommand("/Applications/Cursor.app/Contents/MacOS/Cursor"))
        XCTAssertTrue(ProcessClassifier.isTrustedAncestorCommand("/Applications/Visual Studio Code.app/Contents/MacOS/Electron"))
    }

    func testPopularAgentCommandsAreTrusted() {
        XCTAssertTrue(ProcessClassifier.isTrustedAncestorCommand("/usr/local/bin/codex --model gpt-5"))
        XCTAssertTrue(ProcessClassifier.isTrustedAncestorCommand("/usr/local/bin/claude code"))
        XCTAssertTrue(ProcessClassifier.isTrustedAncestorCommand("/usr/local/bin/aider --model sonnet"))
        XCTAssertTrue(ProcessClassifier.isTrustedAncestorCommand("/usr/local/bin/cline agent"))
        XCTAssertTrue(ProcessClassifier.isTrustedAncestorCommand("/usr/local/bin/opencode"))
    }

    func testBackgroundServicesAreNotTrusted() {
        XCTAssertFalse(ProcessClassifier.isTrustedAncestorCommand("/Applications/Dropbox.app/Contents/MacOS/Dropbox"))
        XCTAssertFalse(ProcessClassifier.isTrustedAncestorCommand("/Applications/Adobe Creative Cloud/ACC/Creative Cloud.app"))
        XCTAssertFalse(ProcessClassifier.isTrustedAncestorCommand("/Library/Application Support/Universal Audio/UADMixerEngine"))
    }

    func testCustomTrustedHintsAreApplied() {
        UserDefaults.standard.set(["my-agent-launcher"], forKey: ProcessClassifier.customHintsDefaultsKey)
        XCTAssertTrue(ProcessClassifier.isTrustedAncestorCommand("/opt/tools/my-agent-launcher --serve"))
    }
}
