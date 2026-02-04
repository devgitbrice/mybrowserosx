import Foundation
import AVFoundation

// Note : AudioRecorder est géré dans DictationService, ici on gère le Player

class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    var player: AVAudioPlayer?
    var onFinish: (() -> Void)?
    
    func play(data: Data, onFinish: @escaping () -> Void) {
        // 1. On stocke l'action à faire à la fin
        self.onFinish = onFinish
        
        do {
            // 2. Configuration pour la lecture
            player = try AVAudioPlayer(data: data)
            player?.delegate = self // CRUCIAL : C'est ça qui permet de détecter la fin
            player?.prepareToPlay()
            
            // 3. Lancement
            let success = player?.play() ?? false
            
            // Si la lecture échoue immédiatement, on passe tout de suite à la suite
            if !success {
                print("⚠️ AudioPlayer: Impossible de lancer la lecture.")
                onFinish()
            }
        } catch {
            print("❌ AudioPlayer Erreur: \(error)")
            onFinish()
        }
    }
    
    func stop() {
        player?.stop()
        player = nil // On nettoie
    }
    
    // --- DÉTECTION DE LA FIN ---
    
    // Cette fonction est appelée automatiquement par iOS/macOS quand le son est fini
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("✅ AudioPlayer: Fin de lecture détectée.")
        // On revient sur le fil principal pour mettre à jour l'interface
        DispatchQueue.main.async {
            self.onFinish?()
        }
    }
    
    // En cas d'erreur de décodage
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌ AudioPlayer: Erreur décodage.")
        DispatchQueue.main.async {
            self.onFinish?()
        }
    }
}
