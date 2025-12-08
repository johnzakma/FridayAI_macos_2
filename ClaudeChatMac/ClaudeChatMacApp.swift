import SwiftUI

@main
struct ClaudeChatMacApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
        .frame(minWidth: 1000, minHeight: 700)
    }
    .windowStyle(.hiddenTitleBar)
    .windowResizability(.contentSize)
  }
}