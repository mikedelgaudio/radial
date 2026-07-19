import XCTest
@testable import ControlRingKit

final class ActionRunnerTests: XCTestCase {
    private func runner(appURL: URL? = URL(fileURLWithPath: "/Applications/Safari.app"))
        -> ActionRunner {
        ActionRunner(resolveAppURL: { _ in appURL })
    }
    private func pres() -> Presentation { Presentation(icon: .appIcon, color: .named("blue")) }

    func test_application_plan_uses_resolved_url_and_arguments() {
        let a = Action(title: "Safari", type: .application, bundleID: "com.apple.Safari",
                       arguments: ["--flag"], presentation: pres())
        XCTAssertEqual(runner().plan(for: a),
            .application(appURL: URL(fileURLWithPath: "/Applications/Safari.app"),
                         arguments: ["--flag"]))
    }

    func test_application_plan_fails_when_unresolved() {
        let a = Action(title: "Ghost", type: .application, bundleID: "no.such.app",
                       presentation: pres())
        if case .failure = runner(appURL: nil).plan(for: a) {} else { XCTFail() }
    }

    func test_script_plan_wraps_in_sh_lc() {
        let a = Action(title: "Sleep", type: .script, scriptCommand: "pmset sleepnow",
                       presentation: pres())
        XCTAssertEqual(runner().plan(for: a),
            .script(executable: "/bin/sh", arguments: ["-lc", "pmset sleepnow"]))
    }

    func test_script_plan_fails_on_empty_command() {
        let a = Action(title: "X", type: .script, scriptCommand: "  ", presentation: pres())
        if case .failure = runner().plan(for: a) {} else { XCTFail() }
    }

    func test_url_plan() {
        let a = Action(title: "GH", type: .url, url: "https://github.com", presentation: pres())
        XCTAssertEqual(runner().plan(for: a), .openURL(URL(string: "https://github.com")!))
    }

    func test_folder_plan() {
        let a = Action(title: "Home", type: .folder, folderPath: "/Users/me", presentation: pres())
        XCTAssertEqual(runner().plan(for: a), .openFolder(URL(fileURLWithPath: "/Users/me")))
    }
}
