import SwiftUI
import AVFoundation
import Combine

class NotesAudioService: ObservableObject {
    // --- ÉTATS ---
    @Published var playingBlockId: UUID? = nil
    @Published var isAutoPlayActive = false
    @Published var isPaused = false
    
    // --- INTERNE ---
    var audioPlayer = AudioPlayer()
    private var currentPlaylist: [NoteBlock] = []
    
    // --- LECTURE ---
    func lireNote(note: NoteBlock, dansPlaylist playlist: [NoteBlock]) {
        // Gestion Play/Pause sur la même note
        if isPaused && playingBlockId == note.id {
            resumeAudio()
            return
        }
        
        // Changement de note
        if playingBlockId != nil && playingBlockId != note.id {
            stopAudio(garderAutoPlay: true)
        }
        
        playingBlockId = note.id
        isPaused = false
        self.currentPlaylist = playlist
        
        let textToRead = cleanHTML(note.content)
        
        guard let url = URL(string: "https://api.openai.com/v1/audio/speech") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(Config.openAIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["model": "tts-1", "input": textToRead, "voice": "alloy"]
        
        do { request.httpBody = try JSONSerialization.data(withJSONObject: body) } catch { return }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else {
                DispatchQueue.main.async { self?.stopAudio() }
                return
            }
            
            DispatchQueue.main.async {
                self.audioPlayer.play(data: data) {
                    // Callback quand l'audio est fini
                    self.gestionFinDeNote(noteIdFinie: note.id)
                }
            }
        }.resume()
    }
    
    // --- AUTO PLAY SUIVANT ---
    private func gestionFinDeNote(noteIdFinie: UUID?) {
        if !isAutoPlayActive || isPaused {
            if !isPaused { playingBlockId = nil }
            return
        }
        
        guard let idFinie = noteIdFinie,
              let index = currentPlaylist.firstIndex(where: { $0.id == idFinie }),
              index + 1 < currentPlaylist.count else {
            stopAudio() // Fin de liste
            return
        }
        
        let noteSuivante = currentPlaylist[index + 1]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.isAutoPlayActive && !self.isPaused {
                self.lireNote(note: noteSuivante, dansPlaylist: self.currentPlaylist)
            }
        }
    }
    
    // --- CONTRÔLES ---
    func pauseAudio() {
        audioPlayer.player?.pause()
        isPaused = true
    }
    
    func resumeAudio() {
        audioPlayer.player?.play()
        isPaused = false
    }
    
    func stopAudio(garderAutoPlay: Bool = false) {
        audioPlayer.stop()
        playingBlockId = nil
        isPaused = false
        if !garderAutoPlay { isAutoPlayActive = false }
    }
    
    func toggleAutoPlay(playlist: [NoteBlock]) {
        if isAutoPlayActive {
            stopAudio()
        } else {
            isAutoPlayActive = true
            if let premier = playlist.first {
                lireNote(note: premier, dansPlaylist: playlist)
            } else {
                isAutoPlayActive = false
            }
        }
    }
    
    // --- NETTOYAGE ---
    private func cleanHTML(_ html: String) -> String {
        let noMarkdown = html
            .replacingOccurrences(of: "```html", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = noMarkdown.data(using: .utf8) else { return noMarkdown }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        if let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attributedString.string
        }
        return noMarkdown
    }
}
