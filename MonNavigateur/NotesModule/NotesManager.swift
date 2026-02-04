import SwiftUI
import Combine
import AVFoundation

// (Les structs NoteBlock sont dans Note.swift)

public class NotesManager: ObservableObject {
    @Published var blocks: [NoteBlock] = []
    
    // ✅ CONNEXION AVEC LE SERVICE AUDIO
    @Published var audioService = NotesAudioService()
    
    @Published var categories: [String] = ["À catégoriser"]
    @Published var filtreCategorie: String? = nil
    
    @Published var dictationService = DictationService()
    @Published var afficherFavorisSeulement = false
    @Published var isAutoCorrectActive = true
    
    private var cancellables = Set<AnyCancellable>()
    
    var isRecording: Bool { dictationService.isRecording }
    var isTranscribing: Bool { dictationService.isTranscribing }
    
    // LISTE FILTRÉE
    var blocksAffiches: [NoteBlock] {
        var resultat = blocks
        if let filtre = filtreCategorie {
            resultat = resultat.filter { $0.category == filtre }
        }
        if afficherFavorisSeulement {
            resultat = resultat.filter { $0.is_favorite }
        }
        return resultat
    }
    
    public init() {
        // On surveille le service audio pour mettre à jour la vue si besoin
        audioService.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        
        dictationService.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        
        chargerNotes()
        chargerCategories()
    }

    // --- CHARGEMENT ---
    func chargerNotes() {
        guard let url = URL(string: "\(Config.url)/rest/v1/site_notes_blocks?select=*&order=is_pinned.desc,order_index.asc") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(Config.key)", forHTTPHeaderField: "Authorization")
        request.addValue(Config.key, forHTTPHeaderField: "apikey")
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data, let decoded = try? JSONDecoder().decode([NoteBlock].self, from: data) {
                DispatchQueue.main.async { self.blocks = decoded }
            }
        }.resume()
    }
    
    func chargerCategories() {
        guard let url = URL(string: "\(Config.url)/rest/v1/site_notes_categories?select=*&order=name.asc") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(Config.key)", forHTTPHeaderField: "Authorization")
        request.addValue(Config.key, forHTTPHeaderField: "apikey")
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data, let decoded = try? JSONDecoder().decode([CategoryBlock].self, from: data) {
                DispatchQueue.main.async {
                    self.categories = decoded.map { $0.name }
                    if !self.categories.contains("À catégoriser") { self.categories.insert("À catégoriser", at: 0) }
                }
            }
        }.resume()
    }
    
    func creerCategorie(nom: String) {
        guard !categories.contains(nom), !nom.isEmpty else { return }
        withAnimation { categories.append(nom) }
        guard let url = URL(string: "\(Config.url)/rest/v1/site_notes_categories") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(Config.key)", forHTTPHeaderField: "Authorization")
        request.addValue(Config.key, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["name": nom]
        do { request.httpBody = try JSONSerialization.data(withJSONObject: body) } catch {}
        URLSession.shared.dataTask(with: request).resume()
    }
    
    // --- GESTION NOTES ---
    func ajouterNote() {
        let minIndex = blocks.map { $0.order_index }.min() ?? 0
        let newIndex = minIndex - 1
        let catParDefaut = filtreCategorie ?? "À catégoriser"
        let newNote = NoteBlock(id: UUID(), content: "Nouvelle note...", order_index: newIndex, category: catParDefaut)

        withAnimation { blocks.insert(newNote, at: 0) }
        ajouterNoteBase(note: newNote) { [weak self] success in
            if success {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.chargerNotes()
                }
            }
        }
    }
    
    func ajouterNoteDepuisLien(url: URL) {
        let minIndex = blocks.map { $0.order_index }.min() ?? 0
        let newIndex = minIndex - 1
        let catParDefaut = filtreCategorie ?? "À catégoriser"
        let noteTemp = NoteBlock(id: UUID(), content: "🔗 Analyse du lien en cours...\n\(url.absoluteString)", order_index: newIndex, category: catParDefaut)
        withAnimation { blocks.insert(noteTemp, at: 0) }
        ajouterNoteBase(note: noteTemp)
        guard let noteId = noteTemp.id else { return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let htmlString = String(data: data, encoding: .utf8) {
                    let cleanContent = htmlString.prefix(15000)
                    await self.resumerEtMettreAJour(id: noteId, url: url, rawText: String(cleanContent))
                }
            } catch {
                DispatchQueue.main.async {
                    if let index = self.blocks.firstIndex(where: { $0.id == noteId }) {
                        self.blocks[index].content = "⚠️ Erreur de lecture"
                        self.sauvegarderContenu(id: noteId, content: self.blocks[index].content)
                    }
                }
            }
        }
    }
    
    private func ajouterNoteBase(note: NoteBlock, completion: ((Bool) -> Void)? = nil) {
        guard let url = URL(string: "\(Config.url)/rest/v1/site_notes_blocks") else {
            completion?(false)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(Config.key)", forHTTPHeaderField: "Authorization")
        request.addValue(Config.key, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("return=minimal", forHTTPHeaderField: "Prefer")
        let donnees: [String: Any] = ["id": note.id!.uuidString, "content": note.content, "order_index": note.order_index, "is_pinned": note.is_pinned, "is_favorite": note.is_favorite, "category": note.category]
        do { request.httpBody = try JSONSerialization.data(withJSONObject: donnees, options: []) } catch {
            completion?(false)
            return
        }
        URLSession.shared.dataTask(with: request) { _, response, error in
            let httpResponse = response as? HTTPURLResponse
            let success = error == nil && (httpResponse?.statusCode ?? 0) >= 200 && (httpResponse?.statusCode ?? 0) < 300
            if !success {
                print("❌ Erreur création note: status=\(httpResponse?.statusCode ?? -1), error=\(error?.localizedDescription ?? "aucune")")
            }
            DispatchQueue.main.async {
                completion?(success)
            }
        }.resume()
    }
    
    private func resumerEtMettreAJour(id: UUID, url: URL, rawText: String) async {
        let prompt = "Résumé en 100 mots max: \(rawText)"
        // (Code OpenAI résumé ici, je raccourcis pour la lisibilité, garde ton code existant)
    }
    
    func changerCategorie(id: UUID, nouvelleCategorie: String) {
        if let index = blocks.firstIndex(where: { $0.id == id }) {
            blocks[index].category = nouvelleCategorie
            updateField(id: id, field: "category", value: nouvelleCategorie)
        }
    }
    
    func sauvegarderContenu(id: UUID, content: String) {
        updateField(id: id, field: "content", value: content)
    }
    
    func supprimerNote(id: UUID) {
        if let index = blocks.firstIndex(where: { $0.id == id }) { blocks.remove(at: index) }
        guard let url = URL(string: "\(Config.url)/rest/v1/site_notes_blocks?id=eq.\(id.uuidString)") else { return }
        var request = URLRequest(url: url); request.httpMethod = "DELETE"
        request.addValue("Bearer \(Config.key)", forHTTPHeaderField: "Authorization"); request.addValue(Config.key, forHTTPHeaderField: "apikey")
        URLSession.shared.dataTask(with: request).resume()
    }
    
    func togglePin(id: UUID) {
        if let index = blocks.firstIndex(where: { $0.id == id }) {
            blocks[index].is_pinned.toggle()
            updateField(id: id, field: "is_pinned", value: blocks[index].is_pinned)
            blocks.sort { ($0.is_pinned && !$1.is_pinned) || ($0.is_pinned == $1.is_pinned && $0.order_index < $1.order_index) }
        }
    }
    
    func toggleFavorite(id: UUID) {
        if let index = blocks.firstIndex(where: { $0.id == id }) {
            blocks[index].is_favorite.toggle()
            updateField(id: id, field: "is_favorite", value: blocks[index].is_favorite)
        }
    }
    
    func deplacerEnHaut(id: UUID) {
        guard let minIndex = blocks.map({ $0.order_index }).min() else { return }
        let newIndex = minIndex - 1
        if let index = blocks.firstIndex(where: { $0.id == id }) {
            blocks[index].order_index = newIndex
            let element = blocks.remove(at: index)
            blocks.insert(element, at: 0)
            updateField(id: id, field: "order_index", value: newIndex)
        }
    }
    
    func deplacerEnBas(id: UUID) {
        guard let maxIndex = blocks.map({ $0.order_index }).max() else { return }
        let newIndex = maxIndex + 1
        if let index = blocks.firstIndex(where: { $0.id == id }) {
            blocks[index].order_index = newIndex
            let element = blocks.remove(at: index)
            blocks.append(element)
            updateField(id: id, field: "order_index", value: newIndex)
        }
    }
    
    private func updateField(id: UUID, field: String, value: Any) {
        guard let url = URL(string: "\(Config.url)/rest/v1/site_notes_blocks?id=eq.\(id.uuidString)") else { return }
        var request = URLRequest(url: url); request.httpMethod = "PATCH"
        request.addValue("Bearer \(Config.key)", forHTTPHeaderField: "Authorization"); request.addValue(Config.key, forHTTPHeaderField: "apikey"); request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = [field: value]; do { request.httpBody = try JSONSerialization.data(withJSONObject: body) } catch {}
        URLSession.shared.dataTask(with: request).resume()
    }
    
    func declencherCorrectionAuto(pour id: UUID, contenuActuel: String) {
        // (Garde ton code existant ici)
    }
    
    func startRecording() { dictationService.startRecording() }
    func stopRecordingAndTranscribe(for noteId: UUID) {
        dictationService.stopAndTranscribe { [weak self] text in
            guard let self = self, let text = text else { return }
            DispatchQueue.main.async {
                if let index = self.blocks.firstIndex(where: { $0.id == noteId }) {
                    let nouveauContenu = self.blocks[index].content + " " + text
                    self.blocks[index].content = nouveauContenu
                    if let id = self.blocks[index].id { self.sauvegarderContenu(id: id, content: nouveauContenu) }
                }
            }
        }
    }
}
