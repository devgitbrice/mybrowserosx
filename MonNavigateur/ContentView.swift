import SwiftUI
import WebKit
import Combine

struct ContentView: View {
    // 1. LE CERVEAU CENTRAL
    @StateObject var notesManager = NotesManager()
    
    @StateObject private var modele = NavigateurModele()
    @State private var texteRecherche: String = "https://www.google.fr"
    @State private var alerteFavori = false
    
    // Variables UI
    @State private var estBloque = false
    @State private var jeuEstActif = true
    @State private var sidebarVisible = false
    @State private var afficherBlocNotes = false
    @State private var blocNotesVerrouille = false
    
    let minuteur = Timer.publish(every: 20, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .leading) {
            
            // --- COUCHE 1 : CONTENU PRINCIPAL ---
            VStack(spacing: 0) {
                // BARRE D'OUTILS
                HStack(spacing: 12) {
                    // Navigation
                    Group {
                        Button(action: { modele.webView.goBack() }) { Image(systemName: "chevron.left") }.disabled(!modele.webView.canGoBack)
                        Button(action: { modele.webView.goForward() }) { Image(systemName: "chevron.right") }.disabled(!modele.webView.canGoForward)
                        Button(action: { chargerPage() }) { Image(systemName: "arrow.clockwise") }
                    }

                    // Champ Recherche
                    TextField("Recherche...", text: $texteRecherche)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { chargerPage() }
                    
                    // --- 1. BOUTON FAVORIS (Étoile) ---
                    Button(action: {
                        modele.ajouterAuxFavoris()
                        alerteFavori = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { alerteFavori = false }
                    }) {
                        Image(systemName: "star.fill").foregroundColor(.yellow)
                    }
                    .help("Ajouter aux favoris")
                    
                    // --- 2. NOUVEAU BOUTON : RÉSUMÉ IA (Document Bleu) ---
                    Button(action: {
                        // Action du clic gauche direct !
                        if let url = URL(string: texteRecherche) {
                            withAnimation { afficherBlocNotes = true } // Ouvre le panneau
                            notesManager.ajouterNoteDepuisLien(url: url) // Lance l'IA
                        }
                    }) {
                        Image(systemName: "doc.text.fill") // Icône Document
                            .font(.title3)
                            .foregroundColor(.blue) // Couleur Bleue
                    }
                    .help("Analyser cette page et créer un résumé")
                    .buttonStyle(.plain) // Style simple sans bordure moche
                    
                    // --- 3. BOUTON OUVRIR/FERMER BLOC-NOTES ---
                    Button(action: { withAnimation { afficherBlocNotes.toggle() } }) {
                        HStack {
                            Image(systemName: "square.and.pencil")
                            Text("Notes")
                        }
                        .foregroundColor(afficherBlocNotes ? .white : .indigo)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(afficherBlocNotes ? .indigo : .gray.opacity(0.2))
                    .help("Ouvrir le Bloc-Notes")
                }
                .padding(10)
                #if os(macOS)
                .background(Color(nsColor: .windowBackgroundColor))
                #else
                .background(Color(uiColor: .systemBackground))
                #endif
                
                // Alertes & Progression
                if alerteFavori {
                    Text("Sauvegardé !").font(.caption).foregroundColor(.green).padding(.bottom, 5)
                }
                if modele.progression < 1.0 && modele.progression > 0.0 {
                    ProgressView(value: modele.progression, total: 1.0).frame(height: 2).foregroundColor(.blue)
                }
                
                // Le Navigateur Web
                WebView(webView: modele.webView)
            }
            .disabled(estBloque)
            
            // --- COUCHE 2 : RIDEAU ---
            if sidebarVisible {
                Color.black.opacity(0.001)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture { withAnimation { sidebarVisible = false } }
                    .zIndex(2)
            }
            
            // --- COUCHE 3 : DÉTECTEUR SIDEBAR ---
            if !sidebarVisible {
                Rectangle().fill(Color.clear).frame(width: 1).contentShape(Rectangle())
                    .onHover { isHovering in if isHovering { withAnimation(.spring()) { sidebarVisible = true } } }
                    .zIndex(2)
            }
            
            // --- COUCHE 4 : SIDEBAR ---
            if sidebarVisible {
                SideBar(modele: modele, estVisible: $sidebarVisible)
                    .transition(.move(edge: .leading))
                    .zIndex(3)
            }

            // --- COUCHE 5 : MATHS ---
            if estBloque {
                LearnView(onUnlock: { estBloque = false }).zIndex(4)
            }
            
            // --- COUCHE 6 : DÉTECTEUR BORD DROIT (BLOC-NOTES) ---
            if !afficherBlocNotes {
                HStack {
                    Spacer()
                    Rectangle().fill(Color.clear).frame(width: 6)
                        .contentShape(Rectangle())
                        .onHover { isHovering in
                            if isHovering {
                                withAnimation(.spring()) { afficherBlocNotes = true }
                            }
                        }
                }
                .zIndex(5)
            }

            // --- COUCHE 7 : BLOC-NOTES ---
            if afficherBlocNotes {
                BlocNotesView(notesManager: notesManager, estVisible: $afficherBlocNotes, estVerrouille: $blocNotesVerrouille)
                    .padding(20)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(100)
                    #if os(macOS)
                    .frame(width: 500)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .onHover { isHovering in
                        if !isHovering && !blocNotesVerrouille {
                            withAnimation(.spring()) { afficherBlocNotes = false }
                        }
                    }
                    #else
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.5))
                    #endif
            }
            
            Button("") { estBloque = false; jeuEstActif = false; print("🛑 KILL") }
                .keyboardShortcut("s", modifiers: .command)
                .frame(width: 0, height: 0)
        }
        #if os(macOS)
        .frame(minWidth: 800, minHeight: 600)
        #endif
        .onAppear { chargerPage() }
        .onChange(of: modele.urlActuelle) { nouvelleUrl in if !nouvelleUrl.isEmpty { texteRecherche = nouvelleUrl } }
        .onReceive(minuteur) { _ in if !estBloque && jeuEstActif { estBloque = true } }
    }
    
    func chargerPage() {
        let texteBrut = texteRecherche.trimmingCharacters(in: .whitespacesAndNewlines)
        if texteBrut.contains(" ") || !texteBrut.contains(".") {
            if let rechercheEncodee = texteBrut.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                let urlGoogle = URL(string: "https://www.google.com/search?q=\(rechercheEncodee)")!
                modele.webView.load(URLRequest(url: urlGoogle))
            }
        } else {
            var adresse = texteBrut
            if !adresse.lowercased().hasPrefix("http") { adresse = "https://" + adresse }
            if let url = URL(string: adresse) {
                modele.webView.load(URLRequest(url: url))
            }
        }
    }
}

#Preview("APP - Mac") { ContentView().frame(width: 1200, height: 800) }
#Preview("APP - iPad") { ContentView().previewDevice(PreviewDevice(rawValue: "iPad Pro (13-inch) (M4)")) }
