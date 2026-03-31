import XCTest

final class OnboardingE2ETest: XCTestCase {
    let dir = "/tmp/vita-onboarding-e2e"
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        app = XCUIApplication()
    }

    func testOnboardingFlow() throws {
        app.launchArguments = ["--vita-e2e-demo", "--reset-onboarding"]
        app.launch()
        sleep(3)

        // ── Step 0: Sleep ──
        save("00-sleep")
        let acordar = app.buttons["Acordar Vita"]
        XCTAssertTrue(acordar.waitForExistence(timeout: 5), "Acordar Vita button should exist")
        acordar.tap()
        sleep(5) // Wake animation + typewriter text

        // ── Step 1: Welcome ──
        save("01-welcome")
        dismissKeyboard()

        // No uni available with demo token — use skip
        let skip = app.buttons["Pular, configuro depois"]
        if skip.waitForExistence(timeout: 3) {
            skip.tap()
            sleep(4) // Wait for transition + typewriter
        }

        // ── Step 2: Connect ──
        save("02-connect")
        dismissKeyboard()
        sleep(1)

        // Skip connect
        let skip2 = app.buttons["Pular, configuro depois"]
        if skip2.waitForExistence(timeout: 3) {
            skip2.tap()
            sleep(3)
        }

        // ── Step 3: Syncing (auto-advances after ~4s) ──
        save("03-syncing")
        sleep(7) // Wait for sync + auto-advance

        // ── Step 4: Subjects ──
        save("04-subjects")
        dismissKeyboard()
        sleep(1)

        // Skip subjects
        let skip3 = app.buttons["Pular, configuro depois"]
        if skip3.waitForExistence(timeout: 3) {
            skip3.tap()
            sleep(3)
        } else {
            // Try Continuar
            let cont = app.buttons["Continuar"]
            if cont.waitForExistence(timeout: 2) {
                cont.tap()
                sleep(3)
            }
        }

        // ── Step 5: Notifications ──
        save("05-notifications")
        sleep(2)

        // The button text matches exactly what's in the code
        let notifBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'notifica'")).firstMatch
        if notifBtn.waitForExistence(timeout: 5) {
            notifBtn.tap()
            sleep(2)
        } else {
            // Fallback: tap Continuar
            let cont = app.buttons["Continuar"]
            if cont.waitForExistence(timeout: 2) {
                cont.tap()
                sleep(2)
            }
        }

        // Handle system notification permission dialog
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowBtn = springboard.buttons["Allow"]
        if allowBtn.waitForExistence(timeout: 3) {
            allowBtn.tap()
            sleep(1)
        }

        // ── Step 6: Trial ──
        save("06-trial")
        sleep(2)

        let trialBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'gratis' OR label CONTAINS 'dias'")).firstMatch
        if trialBtn.waitForExistence(timeout: 5) {
            trialBtn.tap()
            sleep(3)
        } else {
            let cont = app.buttons["Continuar"]
            if cont.waitForExistence(timeout: 2) {
                cont.tap()
                sleep(3)
            }
        }

        // ── Step 7: Done ──
        save("07-done")
        sleep(2)

        let boraBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'estudar' OR label CONTAINS 'Bora'")).firstMatch
        if boraBtn.waitForExistence(timeout: 5) {
            boraBtn.tap()
            sleep(3)
        }

        // ── Should be on Dashboard now ──
        XCTAssertTrue(app.buttons["tab_home"].waitForExistence(timeout: 10), "Home tab should be visible after onboarding")
        XCTAssertTrue(app.buttons["tool_questoes"].waitForExistence(timeout: 10), "Dashboard tools should render in demo mode")
        save("08-dashboard")
        print("[E2E] Onboarding flow complete. Screenshots at \(dir)/")
    }

    // MARK: - Helpers

    private func save(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let path = "\(dir)/\(name).png"
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: path))
        print("[E2E] Screenshot: \(name)")
    }

    private func dismissKeyboard() {
        let coord = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
        coord.tap()
    }
}
