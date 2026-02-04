import SwiftUI
import AppKit

struct BlocNotesView: View {
    @ObservedObject var notesManager: NotesManager
    @Binding var estVisible: Bool
    @Binding var estVerrouille: Bool

    @State private var showingAddCategory = false
    @State private var newCategoryName = ""
    
    var body: some View {
        VStack(spacing: 0) {
            
            // --- HEADER ---
            HStack {
                Image(systemName: "note.text").foregroundColor(.indigo)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("Bloc-Notes").font(.headline).foregroundColor(.white)
                    Text("\(notesManager.blocksAffiches.count) notes").font(.caption2).foregroundColor(.gray)
                }
                
                Menu {
                    Button("Tout afficher") { withAnimation { notesManager.filtreCategorie = nil } }
                    Divider()
                    ForEach(notesManager.categories, id: \.self) { cat in
                        Button(cat) { withAnimation { notesManager.filtreCategorie = cat } }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(notesManager.filtreCategorie ?? "Tout").font(.caption).lineLimit(1)
                    }
                    .padding(4).background(Color.white.opacity(0.1)).cornerRadius(8)
                }
                .menuStyle(.borderlessButton).padding(.leading, 8)
                
                Spacer()
                
                Button(action: { withAnimation { notesManager.isAutoCorrectActive.toggle() } }) {
                    HStack(spacing: 4) {
                        Image(systemName: "wand.and.stars")
                        if notesManager.isAutoCorrectActive { Text("ON").font(.caption2).bold() }
                    }
                    .foregroundColor(notesManager.isAutoCorrectActive ? .green : .gray)
                    .padding(6).background(notesManager.isAutoCorrectActive ? Color.green.opacity(0.2) : Color.clear).cornerRadius(8)
                }.buttonStyle(.plain).padding(.trailing, 8)

                Button(action: { notesManager.ajouterNote() }) {
                    Image(systemName: "plus").foregroundColor(.white).padding(6).background(Color.indigo).clipShape(Circle())
                }.buttonStyle(.plain)

                Button(action: { withAnimation { estVerrouille.toggle() } }) {
                    Image(systemName: estVerrouille ? "lock.fill" : "lock.open")
                        .font(.title3)
                        .foregroundColor(estVerrouille ? .orange : .gray)
                }
                .buttonStyle(.plain).padding(.leading, 8)
                .help(estVerrouille ? "Déverrouiller le panneau" : "Verrouiller le panneau ouvert")

                Button(action: { withAnimation { estVisible = false; estVerrouille = false } }) {
                    Image(systemName: "xmark.circle.fill").font(.title3).foregroundColor(.gray)
                }.buttonStyle(.plain).padding(.leading, 4)
            }
            .padding().background(Color(red: 0.1, green: 0.1, blue: 0.12))
            
            // --- ZONE AUTO PLAY ---
            if notesManager.blocks.count > 0 {
                HStack {
                    if notesManager.audioService.isAutoPlayActive {
                        Button(action: {
                            if notesManager.audioService.isPaused { notesManager.audioService.resumeAudio() }
                            else { notesManager.audioService.pauseAudio() }
                        }) {
                            HStack {
                                Image(systemName: notesManager.audioService.isPaused ? "play.fill" : "pause.fill")
                                Text(notesManager.audioService.isPaused ? "Reprendre" : "Pause")
                            }
                            .font(.caption).bold().padding(.vertical, 6).padding(.horizontal, 12)
                            .background(Color.orange).foregroundColor(.white).cornerRadius(20)
                        }.buttonStyle(.plain).keyboardShortcut(.space, modifiers: [])
                        
                        Button(action: { notesManager.audioService.stopAudio() }) {
                            HStack { Image(systemName: "stop.fill"); Text("Stop") }
                            .font(.caption).bold().padding(.vertical, 6).padding(.horizontal, 12)
                            .background(Color.red).foregroundColor(.white).cornerRadius(20)
                        }.buttonStyle(.plain)
                        
                        if !notesManager.audioService.isPaused {
                            Text("Lecture...").font(.caption).foregroundColor(.gray).opacity(0.8)
                        }
                    } else {
                        Button(action: { notesManager.audioService.toggleAutoPlay(playlist: notesManager.blocksAffiches) }) {
                            HStack { Image(systemName: "play.circle.fill"); Text("AUTO AUDIO (Tout lire)") }
                            .font(.caption).bold().padding(.vertical, 6).padding(.horizontal, 12)
                            .background(Color.blue).foregroundColor(.white).cornerRadius(20)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 8).frame(maxWidth: .infinity).background(Color(red: 0.1, green: 0.1, blue: 0.12))
            }
            
            // --- LISTE DES NOTES ---
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(notesManager.blocksAffiches) { block in
                        if let id = block.id,
                           let index = notesManager.blocks.firstIndex(where: { $0.id == id }) {
                            NoteRow(
                                note: $notesManager.blocks[index],
                                manager: notesManager,
                                activeMicId: $notesManager.audioService.playingBlockId,
                                onAddCategory: { showingAddCategory = true },
                                onExpand: {
                                    // Appel au gestionnaire sécurisé
                                    FullscreenWindowManager.shared.openNote(id: id, manager: notesManager)
                                }
                            )
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color.black.opacity(0.85))
        }
        #if os(macOS)
        .frame(width: 550, height: 750)
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
        .cornerRadius(16).shadow(radius: 20)
        .onAppear { notesManager.chargerNotes() }
        .onDisappear { notesManager.audioService.stopAudio() }
        
        .alert("Nouvelle Catégorie", isPresented: $showingAddCategory) {
            TextField("Nom", text: $newCategoryName)
            Button("Ajouter") { notesManager.creerCategorie(nom: newCategoryName); newCategoryName = "" }
            Button("Annuler", role: .cancel) { newCategoryName = "" }
        }
    }
}

// --- SOUS-VUE NOTE (Inchangée) ---
struct NoteRow: View {
    @Binding var note: NoteBlock
    @ObservedObject var manager: NotesManager
    @State private var localMicActive = false
    @Binding var activeMicId: UUID?
    
    var onAddCategory: () -> Void
    var onExpand: () -> Void
    
    @State private var rowHeight: CGFloat = 100
    @State private var correctionTask: Task<Void, Never>? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 12) {
                Button(action: { if let id = note.id { manager.toggleFavorite(id: id) } }) {
                    Image(systemName: note.is_favorite ? "heart.fill" : "heart").foregroundColor(note.is_favorite ? .red : .gray)
                }.buttonStyle(.plain)
                Button(action: { if let id = note.id { manager.deplacerEnHaut(id: id) } }) { Image(systemName: "arrow.up.to.line").foregroundColor(.gray) }.buttonStyle(.plain)
                Button(action: { if let id = note.id { manager.deplacerEnBas(id: id) } }) { Image(systemName: "arrow.down.to.line").foregroundColor(.gray) }.buttonStyle(.plain)
                Button(action: { if let id = note.id { manager.togglePin(id: id) } }) {
                    Image(systemName: note.is_pinned ? "pin.fill" : "pin").foregroundColor(note.is_pinned ? .indigo : .gray).rotationEffect(.degrees(45))
                }.buttonStyle(.plain)
            }.padding(.trailing, 8).padding(.top, 40)
            
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Menu {
                        ForEach(manager.categories, id: \.self) { cat in
                            Button(cat) { if let id = note.id { manager.changerCategorie(id: id, nouvelleCategorie: cat) } }
                        }
                        Divider(); Button(action: { onAddCategory() }) { Label("Ajouter...", systemImage: "plus") }
                    } label: {
                        Text(note.category.isEmpty ? "À catégoriser" : note.category)
                            .font(.caption2).fontWeight(.bold).padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.indigo.opacity(0.3)).cornerRadius(4).foregroundColor(.white)
                    }.menuStyle(.borderlessButton)
                    Spacer()
                    // Bouton Grand Écran
                    Button(action: { onExpand() }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption).foregroundColor(.white.opacity(0.7)).padding(6)
                            .background(Color.white.opacity(0.1)).clipShape(Circle())
                    }.buttonStyle(.plain).help("Voir en grand")
                }.padding(.top, 8).padding(.horizontal, 8)
                
                RichTextEditor(text: $note.content, dynamicHeight: $rowHeight)
                    .frame(height: max(100, rowHeight)).padding(4).background(Color.clear)
                    .onChange(of: note.content) { _, newValue in
                        if let id = note.id {
                            manager.sauvegarderContenu(id: id, content: newValue)
                            if manager.isAutoCorrectActive {
                                correctionTask?.cancel()
                                correctionTask = Task {
                                    try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
                                    if !Task.isCancelled { manager.declencherCorrectionAuto(pour: id, contenuActuel: newValue) }
                                }
                            }
                        }
                    }
            }.background(Color(red: 0.15, green: 0.15, blue: 0.18)).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(manager.audioService.playingBlockId == note.id ? Color.green : Color.clear, lineWidth: 2))
            
            VStack(spacing: 12) {
                Button(action: {
                    if let id = note.id {
                        if manager.audioService.playingBlockId == id { manager.audioService.stopAudio() }
                        else { manager.audioService.lireNote(note: note, dansPlaylist: manager.blocksAffiches) }
                    }
                }) {
                    Image(systemName: manager.audioService.playingBlockId == note.id ? "stop.circle.fill" : "speaker.wave.2.circle.fill")
                        .font(.title2).foregroundColor(manager.audioService.playingBlockId == note.id ? .red : .indigo)
                }.buttonStyle(.plain)
                
                Image(systemName: localMicActive ? "mic.fill" : "mic.circle").font(.title2).foregroundColor(localMicActive ? .red : .white)
                    .padding(4).background(localMicActive ? Color.white.opacity(0.1) : Color.clear).clipShape(Circle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { _ in if !localMicActive { localMicActive = true; manager.startRecording() } }
                    .onEnded { _ in if let id = note.id { manager.stopRecordingAndTranscribe(for: id) }; DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { localMicActive = false } })
                
                Spacer()
                Button(action: { if let id = note.id { manager.supprimerNote(id: id) } }) { Image(systemName: "trash").font(.caption).foregroundColor(.red.opacity(0.5)) }.buttonStyle(.plain)
            }.padding(.leading, 8).padding(.top, 40)
        }.padding(.horizontal)
    }
}

// --- SUBCLASS DE FENÊTRE POUR ACTIVER L'ÉDITION ---
class BorderlessKeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// --- GESTIONNAIRE DE FENÊTRE CORRIGÉ (ANTI-CRASH) ---
class FullscreenWindowManager: NSObject, NSWindowDelegate {
    
    @MainActor static let shared = FullscreenWindowManager()
    
    private var window: NSWindow?
    
    @MainActor
    func openNote(id: UUID, manager: NotesManager) {
        // 1. Si une fenêtre existe déjà, on la ferme proprement
        if let existing = window {
            existing.close()
            window = nil
        }
        
        // 2. Création de la nouvelle fenêtre AVEC LA CLASSE SPÉCIALE
        let newWindow = BorderlessKeyWindow(
            contentRect: NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // 3. IMPORTANT : Empêche le crash en gardant la fenêtre en mémoire
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        
        newWindow.level = .floating
        newWindow.isOpaque = true
        newWindow.backgroundColor = .black
        newWindow.hidesOnDeactivate = false
        
        // 4. Contenu
        let contentView = FullscreenNoteView(
            notesManager: manager,
            currentNoteId: id,
            onClose: { [weak self] in
                // Fermeture via le bouton X
                self?.closeWindow()
            }
        )
        
        newWindow.contentView = NSHostingView(rootView: contentView)
        newWindow.makeKeyAndOrderFront(nil)
        newWindow.makeFirstResponder(newWindow.contentView) // Force le focus
        
        // 5. Sauvegarde de la référence
        self.window = newWindow
    }
    
    @MainActor
    func closeWindow() {
        window?.close()
        window = nil
    }
    
    // Détecte si la fenêtre est fermée autrement (ex: Cmd+W) pour nettoyer
    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async {
            self.window = nil
        }
    }
}
