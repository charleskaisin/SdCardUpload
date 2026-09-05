import SwiftUI

@main
struct CarteClaireApp: App {
    @StateObject private var controller = CarteController()

    var body: some Scene {
        WindowGroup("Carte Claire") {
            ContentView(controller: controller)
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
