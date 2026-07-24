import XCTest

final class ScreenshotAllTabs: XCTestCase {
    let dir = "/tmp/vita-screenshots"

    override func setUpWithError() throws {
        continueAfterFailure = true
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    }

    func testScreenshotAllTabs() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--vita-e2e-demo"]
        app.launch()
        assertHomeLoaded(app)

        // HOME
        save("01-home")
        app.swipeUp(); sleep(1)
        save("01-home-scroll")
        app.swipeDown(); sleep(1)

        // ESTUDOS
        tap(app, "tab_estudos"); sleep(2)
        save("02-estudos")
        app.swipeUp(); sleep(1)
        save("02-estudos-scroll")

        // FACULDADE
        tap(app, "tab_faculdade"); sleep(2)
        save("03-faculdade")
        app.swipeUp(); sleep(1)
        save("03-faculdade-scroll")

        // PROGRESSO
        tap(app, "tab_progresso"); sleep(2)
        save("04-progresso")
        app.swipeUp(); sleep(1)
        save("04-progresso-scroll")

        tap(app, "tab_home"); sleep(2)
        app.buttons["tool_flashcards"].tap()
        sleep(2)
        save("05-flashcards")

        relaunchToHome(app)
        app.buttons["tool_simulados"].tap()
        sleep(2)
        save("06-simulados")

        relaunchToHome(app)
        app.buttons["tool_transcricao"].tap()
        sleep(2)
        save("07-transcricao")
    }

    func testCaptureAtlasRoutes() throws {
        continueAfterFailure = true
        let routes = [
            "notebook-list", "notebook-editor", "mind-map-list", "mind-map-editor",
            "pdf-viewer", "deck-home", "community-decks", "flashcard-topics",
            "card-browser", "flashcard-session", "flashcard-settings", "flashcard-stats",
            "desempenho", "simulado-builder", "simulado-config", "simulado-session",
            "simulado-result", "simulado-review", "simulado-diagnostics", "canvas-connect",
            "unsupported-connector", "insights", "trabalhos", "trabalho-detail", "about",
            "agenda", "appearance", "skin-appearance", "notifications", "connections",
            "paywall", "atlas-3d", "osce", "activity-feed", "leaderboard", "course-detail",
            "achievements", "tool-manager", "profile", "configuracoes", "privacy-documents",
            "privacy-settings", "export-data", "feedback", "focus-session", "referral",
            "disciplinas-config", "qbank", "qbank-session", "transcricao", "flashcard-builder",
            "discipline-detail", "faculdade-disciplinas", "faculdade-materias",
            "faculdade-documentos", "faculdade-provas", "faculdade-professores",
            "material-folder-detail",
        ]
        let routeDir = ProcessInfo.processInfo.environment["VITA_CAPTURE_DIR"]
            ?? "/tmp/vita-atlas-routes"
        try FileManager.default.createDirectory(atPath: routeDir, withIntermediateDirectories: true)

        for route in routes {
            let app = XCUIApplication()
            app.launchArguments = ["--vita-capture-route", route]
            app.launch()

            let marker = "screen_ready_vita_\(route.replacingOccurrences(of: "-", with: "_"))"
            let ready = app.descendants(matching: .any)[marker]
            guard ready.waitForExistence(timeout: 8) else {
                XCTFail("Capture route did not become ready: \(route)")
                save("failed-\(route)", from: app, in: routeDir)
                app.terminate()
                continue
            }

            XCTAssertEqual(app.state, .runningForeground, "App left foreground on \(route)")
            save(route, from: app, in: routeDir)
            app.terminate()
        }
    }

    private func tap(_ app: XCUIApplication, _ id: String) {
        let btn = app.buttons[id]
        if btn.waitForExistence(timeout: 3) { btn.tap() }
    }

    private func assertHomeLoaded(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["tool_questoes"].waitForExistence(timeout: 15), "Dashboard should load tools in demo mode")
    }

    private func relaunchToHome(_ app: XCUIApplication) {
        app.terminate()
        app.launch()
        assertHomeLoaded(app)
    }

    private func save(_ name: String) {
        let s = XCUIScreen.main.screenshot()
        FileManager.default.createFile(atPath: "\(dir)/\(name).png", contents: s.pngRepresentation)
    }

    private func save(_ name: String, from app: XCUIApplication, in directory: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let path = "\(directory)/\(name).png"
        FileManager.default.createFile(atPath: path, contents: screenshot.pngRepresentation)
    }
}
