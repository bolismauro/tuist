import Basic
import Foundation
import TuistSupport
import XCTest
@testable import TuistGenerator

final class ProjectLinterTests: XCTestCase {
    var targetLinter: MockTargetLinter!
    var schemeLinter: MockSchemeLinter!
    var settingsLinter: MockSettingsLinter!

    var subject: ProjectLinter!

    override func setUp() {
        super.setUp()
        targetLinter = MockTargetLinter()
        schemeLinter = MockSchemeLinter()
        settingsLinter = MockSettingsLinter()
        subject = ProjectLinter(targetLinter: targetLinter,
                                settingsLinter: settingsLinter,
                                schemeLinter: schemeLinter)
    }

    func test_validate_when_there_are_duplicated_targets() throws {
        let target = Target.test(name: "A")
        let project = Project.test(targets: [target, target])
        let got = subject.lint(project)
        XCTAssertTrue(got.contains(LintingIssue(reason: "Targets A from project at \(project.path.pathString) have duplicates.", severity: .error)))
    }

    func test_lint_valid_watchTargetBundleIdentifiers() throws {
        // Given
        let app = Target.test(name: "App", product: .app, bundleId: "app")
        let watchApp = Target.test(name: "WatchApp", product: .watch2App, bundleId: "app.watchapp")
        let watchExtension = Target.test(name: "WatchExtension", product: .watch2Extension, bundleId: "app.watchapp.watchextension")
        let project = Project.test(targets: [app, watchApp, watchExtension])

        // When
        let got = subject.lint(project)

        // Then
        XCTAssertTrue(got.isEmpty)
    }
}
