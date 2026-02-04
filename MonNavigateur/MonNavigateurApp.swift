import SwiftUI

@main
struct MonNavigateurApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // C'est ici qu'on ajoute les menus
        .commands {
            CommandMenu("Mon Navigateur Perso") {
                
                Button("Afficher un message test") {
                    print("Bouton menu cliqué !")
                }
                
                Divider() // Une petite ligne de séparation
                
                Button("Quitter proprement") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q") // Raccourci Cmd+Q
            }
        }
    }
}
