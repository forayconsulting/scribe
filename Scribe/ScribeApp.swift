import SwiftUI

@main
struct ScribeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup(for: RecordingSession.self) { $session in
            ContentView(session: session ?? RecordingSession())
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Recording Window") {
                    openWindow(value: RecordingSession())
                }
                .keyboardShortcut("N", modifiers: [.command, .shift])
            }
            CommandGroup(after: .windowList) {
                Button("Microphone Test") {
                    openWindow(id: "mic-test")
                }
                .keyboardShortcut("M", modifiers: [.command, .shift])
            }
        }

        WindowGroup("Microphone Test", id: "mic-test") {
            MicTestView()
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
