import SwiftUI
import AppKit

struct FullscreenNoteView: View {
    @ObservedObject var notesManager: NotesManager
    
    @State var currentNoteId: UUID
    var onClose: () -> Void
    
    // --- ÉTATS ---
    @State private var isAutoAudioEnabled = false
    @State private var isFullAutoEnabled = false
    @State private var rowHeight: CGFloat = 600
    
    // États pour le survol (Hover)
    @State private var isHoveringTop = false
    @State private var isHoveringBottom = false
    
    // Gestion du Swipe Trackpad
    @State private var lastSwipeTime: Date = Date()
    @State private var eventMonitor: Any?
    
    // --- LE SECRET POUR AGRANDIR LE TEXTE SANS CASSER L'ÉDITION ---
    // Ce binding "emballe" le texte dans du CSS pour forcer la taille
    private var styledContentBinding: Binding<String>? {
        guard let index = notesManager.blocks.firstIndex(where: { $0.id == currentNoteId }) else { return nil }
        
        return Binding<String>(
            get: {
                // On récupère le contenu brut
                let content = notesManager.blocks[index].content
                // S'il est vide ou ne contient pas notre balise de style, on l'ajoute pour l'affichage
                // On force : Taille 28px, Couleur Blanche, Police lisible
                let stylePrefix = "<div style=\"font-size: 28px; line-height: 1.5; color: white; font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;\">"
                
                // Petite sécurité pour ne pas doubler les balises si elles sont déjà là (rudimentaire)
                if content.contains("font-size: 28px") {
                    return content
                }
                return stylePrefix + content + "</div>"
            },
            set: { newContent in
                // Quand on édite, on sauvegarde le tout.
                // L'éditeur va gérer le HTML. On sauvegarde directement dans le manager.
                notesManager.blocks[index].content = newContent
            }
        )
    }
    
    var body: some View {
        ZStack {
            // 1. FOND NOIR
            Color.black.edgesIgnoringSafeArea(.all)
            
            // 2. CONTENU PRINCIPAL (ÉDITEUR)
            VStack {
                if let binding = styledContentBinding {
                    // RichTextEditor
                    RichTextEditor(text: binding, dynamicHeight: $rowHeight)
                        // Note: On a retiré .scaleEffect car il casse la position de la souris
                        // Le grossissement est maintenant géré par le Binding CSS ci-dessus
                        
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        // ✅ POSITIONNEMENT
                        .padding(.top, 120)      // Descend le texte
                        .padding(.leading, 100)  // Décale vers la droite
                        .padding(.trailing, 40)  // Marge droite standard
                        .padding(.bottom, 100)   // Marge bas
                        
                        // Style du conteneur (le texte est blanc grâce au CSS injecté)
                        .background(Color.black)
                        .cornerRadius(10)
                        
                        // On force la sauvegarde explicite au changement
                        .onChange(of: binding.wrappedValue) { _, newValue in
                            if let index = notesManager.blocks.firstIndex(where: { $0.id == currentNoteId }) {
                                notesManager.sauvegarderContenu(id: currentNoteId, content: newValue)
                            }
                        }
                } else {
                    Text("Note introuvable").font(.title).foregroundColor(.red)
                }
            }
            
            // 3. INTERFACE (Barres flottantes)
            VStack {
                // --- BARRE DU HAUT ---
                HStack {
                    // Navigation
                    HStack(spacing: 20) {
                        Button(action: showPreviousNote) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                        }.buttonStyle(.plain)
                        
                        Button(action: showNextNote) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                        }.buttonStyle(.plain)
                    }
                    
                    Spacer()
                    
                    // Compteur
                    if let index = notesManager.blocksAffiches.firstIndex(where: { $0.id == currentNoteId }) {
                        Text("\(index + 1) / \(notesManager.blocksAffiches.count)")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    // Fermer
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .clipShape(Circle())
                    }.buttonStyle(.plain)
                }
                .padding(.top, 40).padding(.horizontal, 40)
                .opacity(isHoveringTop ? 1.0 : 0.2)
                .onHover { h in withAnimation { isHoveringTop = h } }
                
                Spacer()
                
                // --- BARRE DU BAS ---
                HStack(spacing: 40) {
                    // On utilise une référence directe à la note pour les favoris (pas le binding modifié)
                    if let index = notesManager.blocks.firstIndex(where: { $0.id == currentNoteId }) {
                        let note = notesManager.blocks[index]
                        
                        // FAVORIS
                        Button(action: { notesManager.toggleFavorite(id: currentNoteId) }) {
                            VStack {
                                Image(systemName: note.is_favorite ? "heart.fill" : "heart")
                                    .font(.system(size: 24))
                                    .foregroundColor(note.is_favorite ? .red : .white)
                                Text("Favori").font(.caption).foregroundColor(.gray)
                            }
                        }.buttonStyle(.plain)
                        
                        Divider().frame(height: 30).background(Color.gray)
                        
                        // LECTURE
                        Button(action: togglePlayCurrent) {
                            VStack {
                                Image(systemName: isPlayingCurrent ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 34))
                                    .foregroundColor(isPlayingCurrent ? .red : .white)
                                Text(isPlayingCurrent ? "Stop" : "Lire").font(.caption).foregroundColor(.gray)
                            }
                        }.buttonStyle(.plain)
                        
                        // AUTO AUDIO
                        Button(action: { isAutoAudioEnabled.toggle() }) {
                            VStack {
                                Image(systemName: "bolt.horizontal.circle")
                                    .font(.system(size: 24))
                                    .foregroundColor(isAutoAudioEnabled ? .yellow : .gray)
                                Text("Auto Audio").font(.caption).foregroundColor(isAutoAudioEnabled ? .yellow : .gray)
                            }
                        }.buttonStyle(.plain)
                        
                        // FULL AUTO
                        Button(action: toggleFullAuto) {
                            VStack {
                                Image(systemName: "infinity.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(isFullAutoEnabled ? .green : .gray)
                                Text("Full Auto").font(.caption).foregroundColor(isFullAutoEnabled ? .green : .gray)
                            }
                        }.buttonStyle(.plain)
                    }
                }
                .padding(20)
                .background(Color.black.opacity(0.8))
                .cornerRadius(30)
                .padding(.bottom, 40)
                .opacity(isHoveringBottom ? 1.0 : 0.2)
                .onHover { h in withAnimation { isHoveringBottom = h } }
            }
        }
        // --- GESTION SWIPE ---
        .onAppear { setupSwipeMonitor() }
        .onDisappear {
            if let monitor = eventMonitor { NSEvent.removeMonitor(monitor); eventMonitor = nil }
        }
        .focusable()
        .onMoveCommand { direction in
            if direction == .right { showNextNote() }
            if direction == .left { showPreviousNote() }
        }
        .onReceive(notesManager.audioService.$playingBlockId) { playingId in
            if isFullAutoEnabled, let id = playingId, id != currentNoteId { withAnimation { currentNoteId = id } }
        }
        .onChange(of: currentNoteId) { _, _ in
            if isAutoAudioEnabled && !isFullAutoEnabled { playCurrentNote() }
        }
    }
    
    // --- HELPERS ---
    private func setupSwipeMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            guard Date().timeIntervalSince(lastSwipeTime) > 0.5 else { return event }
            if abs(event.scrollingDeltaX) > 20 && abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) {
                // Swipe Naturel : Delta positif = aller vers la gauche (précédent visuel) = élément suivant
                if event.scrollingDeltaX > 0 { showPreviousNote(); lastSwipeTime = Date() }
                else { showNextNote(); lastSwipeTime = Date() }
            }
            return event
        }
    }
    
    private var isPlayingCurrent: Bool { notesManager.audioService.playingBlockId == currentNoteId }
    private func showNextNote() {
        guard let index = notesManager.blocksAffiches.firstIndex(where: { $0.id == currentNoteId }), index + 1 < notesManager.blocksAffiches.count else { return }
        withAnimation { currentNoteId = notesManager.blocksAffiches[index + 1].id! }
    }
    private func showPreviousNote() {
        guard let index = notesManager.blocksAffiches.firstIndex(where: { $0.id == currentNoteId }), index > 0 else { return }
        withAnimation { currentNoteId = notesManager.blocksAffiches[index - 1].id! }
    }
    private func togglePlayCurrent() {
        if isPlayingCurrent { notesManager.audioService.stopAudio(); isFullAutoEnabled = false } else { playCurrentNote() }
    }
    private func playCurrentNote() {
        if let index = notesManager.blocksAffiches.firstIndex(where: { $0.id == currentNoteId }) {
            notesManager.audioService.lireNote(note: notesManager.blocksAffiches[index], dansPlaylist: notesManager.blocksAffiches)
        }
    }
    private func toggleFullAuto() {
        isFullAutoEnabled.toggle()
        if isFullAutoEnabled {
            notesManager.audioService.toggleAutoPlay(playlist: notesManager.blocksAffiches)
            if !isPlayingCurrent { playCurrentNote() }
        } else { notesManager.audioService.stopAudio() }
    }
}
