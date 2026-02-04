import SwiftUI
import UniformTypeIdentifiers

struct SideBar: View {
    @ObservedObject var modele: NavigateurModele
    @Binding var estVisible: Bool
    
    @State private var favoriCible: Favori? = nil
    @State private var favoriDeplace: Favori? = nil
    @State private var afficherAjoutSection = false
    @State private var nomNouvelleSection = ""
    @State private var idEnEdition: Int? = nil
    @State private var texteTemporaire: String = ""
    
    // --- NOUVEAU : Pour savoir quelle ligne est survolée par la souris ---
    @State private var idSurvole: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // --- EN-TÊTE ---
            HStack {
                Text("Favoris")
                    .font(.headline).foregroundColor(.white)
                Spacer()
                Button(action: { withAnimation { afficherAjoutSection.toggle() } }) {
                    Image(systemName: "plus.circle.fill").foregroundColor(.white).font(.title3)
                }
                .buttonStyle(.plain).padding(.trailing, 5)
                Button(action: { withAnimation { estVisible = false } }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding().background(Color.black.opacity(0.2))
            
            if afficherAjoutSection {
                HStack {
                    TextField("NOM SECTION", text: $nomNouvelleSection).textFieldStyle(.roundedBorder)
                    Button("OK") {
                        if !nomNouvelleSection.isEmpty {
                            modele.ajouterSection(titre: nomNouvelleSection)
                            nomNouvelleSection = ""
                            withAnimation { afficherAjoutSection = false }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(10).background(Color.black.opacity(0.3))
            }

            // --- LISTE ---
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(modele.listeFavoris) { favori in
                        if favoriCible?.id == favori.id && favoriDeplace?.id != favori.id {
                            Rectangle().fill(Color.orange).frame(height: 2).cornerRadius(1).padding(.horizontal, 10)
                        }

                        HStack {
                            if idEnEdition == favori.id {
                                Image(systemName: "pencil").foregroundColor(.yellow)
                                TextField("Titre", text: $texteTemporaire)
                                    .textFieldStyle(.roundedBorder)
                                    .onSubmit {
                                        if let id = favori.id { modele.renommerFavori(id: id, nouveauTitre: texteTemporaire) }
                                        idEnEdition = nil
                                    }
                            } else {
                                if favori.url.isEmpty {
                                    // SECTION
                                    Text(favori.titre).font(.headline).fontWeight(.bold).foregroundColor(.orange).padding(.vertical, 4)
                                        .onTapGesture(count: 2) { texteTemporaire = favori.titre; idEnEdition = favori.id }
                                    Spacer()
                                } else {
                                    // LIEN
                                    Image(systemName: "globe").foregroundColor(.blue)
                                    Text(favori.titre.isEmpty ? (favori.url.isEmpty ? "Lien sans titre" : favori.url) : favori.titre)
                                        .lineLimit(1).foregroundColor(.white)
                                        .onTapGesture(count: 2) { texteTemporaire = favori.titre; idEnEdition = favori.id }
                                    
                                    Spacer()
                                    
                                    // Poignée Drag & Drop (toujours visible)
                                    Image(systemName: "line.3.horizontal").foregroundColor(.gray.opacity(0.5)).font(.caption)
                                }
                                
                                // --- BOUTON SUPPRIMER (CROIX ROUGE) ---
                                // Apparaît seulement au survol
                                if idSurvole == favori.id {
                                    Button(action: {
                                        if let id = favori.id {
                                            modele.supprimerFavori(id: id)
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .font(.caption)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.leading, 5)
                                    .transition(.opacity)
                                }
                            }
                        }
                        .padding(.vertical, 8).padding(.horizontal, 10)
                        .background(favoriCible?.id == favori.id ? Color.white.opacity(0.1) : Color.clear)
                        .cornerRadius(6).contentShape(Rectangle())
                        
                        // --- DÉTECTION DU SURVOL ---
                        .onHover { isHovering in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if isHovering {
                                    idSurvole = favori.id
                                } else if idSurvole == favori.id {
                                    idSurvole = nil
                                }
                            }
                        }
                        // --------------------------
                        
                        .onTapGesture {
                            if idEnEdition == nil && !favori.url.isEmpty { modele.allerSur(url: favori.url) }
                        }
                        .onDrag {
                            self.favoriDeplace = favori
                            return NSItemProvider(object: String(favori.id ?? 0) as NSString)
                        }
                        .onDrop(of: [.text], delegate: FavoriDropDelegate(item: favori, favoriDeplace: $favoriDeplace, favoriCible: $favoriCible, modele: modele))
                    }
                }
                .padding(10)
            }
        }
        .frame(maxWidth: 250).background(VisualEffectBlur())
    }
}

// Utilitaires inchangés
struct FavoriDropDelegate: DropDelegate {
    let item: Favori; @Binding var favoriDeplace: Favori?; @Binding var favoriCible: Favori?; var modele: NavigateurModele
    func dropEntered(info: DropInfo) { withAnimation(.easeInOut(duration: 0.1)) { favoriCible = item } }
    func dropExited(info: DropInfo) { if favoriCible?.id == item.id { withAnimation { favoriCible = nil } } }
    func performDrop(info: DropInfo) -> Bool {
        guard let source = favoriDeplace else { return false }
        modele.deplacerFavori(item: source, versCible: item)
        favoriDeplace = nil; favoriCible = nil
        return true
    }
    func dropUpdated(info: DropInfo) -> DropProposal? { return DropProposal(operation: .move) }
}
struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView(); view.material = .sidebar; view.blendingMode = .behindWindow; return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
