import SwiftUI
import AppKit

/// A SwiftPM executable launches as a plain command-line process: no Dock
/// icon, no menu bar, and the window opens behind whatever you ran it from.
/// Promoting it to `.regular` and activating gives a normal app.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct GitVisualizerMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = RepositoryViewModel()

    var body: some Scene {
        WindowGroup("Git Visualizer") {
            ContentView(model: model)
                .frame(minWidth: 900, minHeight: 560)
                .task { model.loadIfNeeded() }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Repository…") { model.chooseRepository() }
                    .keyboardShortcut("o", modifiers: .command)

                Button("Reload") { model.load() }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
