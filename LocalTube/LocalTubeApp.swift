import AppKit
import SwiftUI

@main
struct LocalTubeApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        Window("LocalTube", id: "main") {
            RootView()
                .environment(PlayerModel.shared)
        }
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…") { PlayerModel.shared.showOpenPanel() }
                    .keyboardShortcut("o")
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // One monitor for the whole window, so the Up next list never eats the arrow keys.
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let handled = MainActor.assumeIsolated {
                let model = PlayerModel.shared
                guard NSApp.keyWindow === model.window,
                      let action = ShortcutAction.from(keyCode: event.keyCode, characters: event.characters,
                                                       modifiers: event.modifierFlags)
                else { return false }
                return model.perform(action)
            }
            return handled ? nil : event
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if let url = urls.first { PlayerModel.shared.open(url) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        PlayerModel.shared.saveProgress()
    }
}
