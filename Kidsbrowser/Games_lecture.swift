//
//  Games_lecture.swift
//  Kidsbrowser
//
//  Created by BriceM4 on 16/01/2026.
//

import SwiftUI
import AVFoundation
import Combine
import Supabase

// --- CONFIGURATION ---
let supabaseUrl = URL(string: "https://lomgelwpxlzynuogxsri.supabase.co")!
let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxvbWdlbHdweGx6eW51b2d4c3JpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjYyMTQ2MDgsImV4cCI6MjA4MTc5MDYwOH0.aUty5KjHdr0dJVH1ubEKqYz9D1M4u1w1LYhys7dr0Cg"
let supabase = SupabaseClient(supabaseURL: supabaseUrl, supabaseKey: supabaseKey)
let storageUrl = "https://lomgelwpxlzynuogxsri.supabase.co/storage/v1/object/public/lectures/"

// --- CLASSE AUDIO (Doit être en dehors de la View) ---
class AudioRecorder: NSObject, ObservableObject {
    var audioRecorder: AVAudioRecorder?
    @Published var isRecording = false
    @Published var isUploading = false
    @Published var audioLevel: Float = 0.0
    private var timer: Timer?
    var audioFileURL: URL?
    
    func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            let fileName = "temp_lecture.m4a"
            audioFileURL = getDocumentsDirectory().appendingPathComponent(fileName)
            guard let url = audioFileURL else { return }
            let settings: [String: Any] = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 12000, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            isRecording = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                self.audioRecorder?.updateMeters()
                let level = self.audioRecorder?.averagePower(forChannel: 0) ?? -160
                let normalizedLevel =  max(0.2, CGFloat(level + 160) / 160)
                withAnimation { self.audioLevel = Float(normalizedLevel) }
            }
        } catch { print("❌ Échec enregistrement : \(error)") }
    }
    
    func stopRecordingAndUpload(completion: @escaping (String?) -> Void) {
        audioRecorder?.stop()
        isRecording = false
        timer?.invalidate()
        guard let fileUrl = audioFileURL else { completion(nil); return }
        
        DispatchQueue.main.async { self.isUploading = true }
        Task {
            do {
                let audioData = try Data(contentsOf: fileUrl)
                let uniqueID = UUID().uuidString
                let cloudFileName = "lecture_\(uniqueID).m4a"
                try await supabase.storage.from("lectures").upload(cloudFileName, data: audioData, options: FileOptions(contentType: "audio/m4a"))
                DispatchQueue.main.async { self.isUploading = false; completion(cloudFileName) }
            } catch {
                print("❌ Erreur Supabase : \(error)")
                DispatchQueue.main.async { self.isUploading = false; completion(nil) }
            }
        }
    }
    private func getDocumentsDirectory() -> URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }
}

// --- VUE PRINCIPALE ---
struct LectureGameView: View {
    var targetSuccess: Int = 1
    var isTrainingMode: Bool = false
    var onFinished: () -> Void
    
    @StateObject private var recorder = AudioRecorder()
    @State private var sessionTexts: [String] = []
    @State private var rawDbContents: [String] = []
    @State private var currentIndex = 0
    @State private var currentText = "Chargement..."
    @State private var isLoading = true
    @State private var showMenu = false
    @State private var dbCount = 0
    @State private var startTime: Date?
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .top, endPoint: .bottom).edgesIgnoringSafeArea(.all)
            
            if isLoading {
                ProgressView("Connexion...").scaleEffect(1.5).foregroundColor(.white)
            } else if showMenu {
                VStack(spacing: 40) {
                    Text("📚 Lecture").font(.largeTitle).foregroundColor(.white)
                    Button("Lire dans l'ordre") { startSession(shuffle: false) }.padding().background(Color.white).cornerRadius(10)
                    Button("Aléatoire") { startSession(shuffle: true) }.padding().background(Color.white).cornerRadius(10)
                    Button("Retour") { onFinished() }.foregroundColor(.white).padding(.top)
                }
            } else {
                VStack {
                    HStack {
                        Image(systemName: "mic.fill").foregroundColor(.white).padding().background(recorder.isRecording ? Color.red : Color.gray).clipShape(Circle())
                        Spacer()
                        Text("Texte \(currentIndex + 1) / \(sessionTexts.count)").foregroundColor(.white)
                    }
                    .padding(40)
                    
                    ScrollView {
                        Text(currentText).font(.system(size: 32)).foregroundColor(.white).padding()
                    }
                    .background(Color.black.opacity(0.4)).cornerRadius(20).padding()
                    
                    Button(action: { finishCurrentText() }) {
                        HStack {
                            if recorder.isUploading { Text("Envoi...") }
                            else { Image(systemName: "checkmark.circle.fill"); Text("Terminé") }
                        }
                        .font(.title2).bold().padding().background(recorder.isUploading ? Color.gray : Color.green).foregroundColor(.white).cornerRadius(15)
                    }
                    .disabled(recorder.isUploading).padding(.bottom, 50)
                }
            }
        }
        .onAppear { initialLoad(); forceAudio() }
    }
    
    func initialLoad() {
        Task {
            do {
                let contents = try await SupabaseManager.shared.fetchLectureContent()
                await MainActor.run {
                    self.rawDbContents = contents.map { $0.text }
                    self.dbCount = rawDbContents.count
                    self.isLoading = false
                    if rawDbContents.isEmpty { self.currentText = "Aucun texte."; return }
                    if isTrainingMode { self.showMenu = true }
                    else { startSession(shuffle: true, limit: targetSuccess) }
                }
            } catch { await MainActor.run { self.isLoading = false; self.currentText = "Erreur connexion." } }
        }
    }
    
    func startSession(shuffle: Bool, limit: Int? = nil) {
        var playlist = shuffle ? rawDbContents.shuffled() : rawDbContents
        if let max = limit {
            var temp: [String] = []
            while temp.count < max { temp.append(contentsOf: shuffle ? rawDbContents.shuffled() : rawDbContents) }
            playlist = Array(temp.prefix(max))
        }
        self.sessionTexts = playlist
        self.currentIndex = 0
        if !sessionTexts.isEmpty { self.currentText = sessionTexts[0]; startMic(); self.startTime = Date() }
        self.showMenu = false
    }
    
    func finishCurrentText() {
        let duration = Int(Date().timeIntervalSince(startTime ?? Date()))
        recorder.stopRecordingAndUpload { fileName in
            if let name = fileName {
                let details = HistoryDetails(text_read: currentText, audio_url: storageUrl + name, duration_seconds: duration, score: nil, total_questions: nil, mistakes: nil, exercise_summary: nil)
                SupabaseManager.shared.saveHistory(type: "lecture", details: details)
            }
            if currentIndex < sessionTexts.count - 1 {
                currentIndex += 1
                currentText = sessionTexts[currentIndex]
                startTime = Date()
                startMic()
            } else { onFinished() }
        }
    }
    
    func startMic() {
        if #available(iOS 17.0, *) { AVAudioApplication.requestRecordPermission { if $0 { DispatchQueue.main.async { recorder.startRecording() } } } }
        else { AVAudioSession.sharedInstance().requestRecordPermission { if $0 { DispatchQueue.main.async { recorder.startRecording() } } } }
    }
    func forceAudio() { try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default); try? AVAudioSession.sharedInstance().setActive(true) }
}
