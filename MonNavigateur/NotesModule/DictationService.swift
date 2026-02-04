import SwiftUI
import Combine
import AVFoundation

class DictationService: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    
    @Published var isRecording = false
    @Published var isTranscribing = false
    
    // --- 1. GESTION MICROPHONE (NON BLOQUANTE) ---
    
    func startRecording() {
        print("🎤 Demande d'enregistrement...")
        
        // On passe immédiatement en tâche de fond pour ne pas geler l'UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Vérification Permission
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                self.setupAndRecord()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    if granted {
                        self.setupAndRecord()
                    } else {
                        print("❌ Permission refusée par l'utilisateur.")
                    }
                }
            case .denied, .restricted:
                print("❌ Accès micro bloqué par le système.")
            @unknown default:
                return
            }
        }
    }
    
    private func setupAndRecord() {
        let fileName = "dictation.wav"
        guard let docPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let path = docPath.appendingPathComponent(fileName)
        recordingURL = path
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]
        
        do {
            print("🎤 Initialisation du recorder...")
            let newRecorder = try AVAudioRecorder(url: path, settings: settings)
            newRecorder.prepareToRecord()
            
            if newRecorder.record() {
                self.audioRecorder = newRecorder
                print("✅ Enregistrement DÉMARRÉ avec succès.")
                // Mise à jour de l'UI sur le fil principal
                DispatchQueue.main.async {
                    self.isRecording = true
                }
            } else {
                print("❌ Échec : record() a renvoyé false.")
            }
        } catch {
            print("❌ Crash setup micro : \(error)")
        }
    }
    
    // --- 2. ARRÊT & TRANSCRIPTION ---
    
    func stopAndTranscribe(completion: @escaping (String?) -> Void) {
        print("🎤 Arrêt demandé...")
        audioRecorder?.stop()
        
        // Mise à jour UI immédiate
        DispatchQueue.main.async { self.isRecording = false }
        
        guard let url = recordingURL else { completion(nil); return }
        
        // Transcription en tâche de fond
        DispatchQueue.global(qos: .userInitiated).async {
            // Petite pause pour laisser le fichier s'écrire sur le disque
            Thread.sleep(forTimeInterval: 0.2)
            
            DispatchQueue.main.async { self.isTranscribing = true }
            
            let boundary = "Boundary-\(UUID().uuidString)"
            var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
            request.httpMethod = "POST"
            request.addValue("Bearer \(Config.openAIKey)", forHTTPHeaderField: "Authorization")
            request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            var data = Data()
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
            data.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
            
            if let audioData = try? Data(contentsOf: url) {
                data.append(audioData)
            } else {
                print("❌ Impossible de lire le fichier audio sur le disque.")
                DispatchQueue.main.async {
                    self.isTranscribing = false
                    completion(nil)
                }
                return
            }
            
            data.append("\r\n".data(using: .utf8)!)
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
            data.append("whisper-1\r\n".data(using: .utf8)!)
            data.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            request.httpBody = data
            
            print("🚀 Envoi à OpenAI...")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    self.isTranscribing = false
                    
                    if let error = error {
                        print("❌ Erreur Réseau : \(error.localizedDescription)")
                        completion(nil)
                        return
                    }
                    
                    guard let data = data else { completion(nil); return }
                    
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let text = json["text"] as? String {
                            print("✅ Transcription reçue : \(text)")
                            completion(text)
                        } else {
                            print("⚠️ Erreur API : \(json)")
                            completion(nil)
                        }
                    }
                }
            }.resume()
        }
    }
}
