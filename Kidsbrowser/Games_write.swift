//
//  Games_write.swift
//  Kidsbrowser
//
//  Created by BriceM4 on 17/01/2026.
//

import SwiftUI
import AVFoundation

struct WriteGameView: View {
    var targetSuccess: Int = 5
    var onFinished: () -> Void
    
    // États du jeu
    @State private var challenges: [WriteContent] = []
    @State private var currentChallenge: WriteContent?
    @State private var userEntry = ""
    @State private var questionCount = 0
    @State private var isLoading = true
    
    // Statistiques
    @State private var mistakes = 0
    @State private var isError = false
    
    // Clavier ABC
    let row1 = "ABCDEFGHI".map { String($0) }
    let row2 = "JKLMNOPQ".map { String($0) }
    let row3 = "RSTUVWXYZ".map { String($0) }
    
    var body: some View {
        ZStack {
            Color.indigo.edgesIgnoringSafeArea(.all)
            
            if isLoading {
                ProgressView("Chargement des mots...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .foregroundColor(.white)
            } else {
                VStack(spacing: 20) {
                    
                    // --- EN-TÊTE ---
                    HStack {
                        Text("✍️ Le Correcteur")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Spacer()
                        
                        // Affichage dynamique du niveau
                        Text("Niveau \(questionCount + 1) / \(targetSuccess)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 40)
                    
                    Spacer()
                    
                    // --- LE DÉFI ---
                    VStack(spacing: 15) {
                        Text("Oups ! Corrige cette erreur :")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.9))
                        
                        if let challenge = currentChallenge {
                            Text(challenge.wrong.uppercased())
                                .font(.system(size: 60, weight: .heavy, design: .rounded))
                                .foregroundColor(Color.red.opacity(0.9))
                                .strikethrough(true, color: .red)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(15)
                                .shadow(radius: 5)
                        }
                    }
                    
                    // --- ZONE DE SAISIE ---
                    HStack {
                        Text(userEntry.isEmpty ? "..." : userEntry)
                            .font(.system(size: 50, weight: .bold, design: .monospaced))
                            .foregroundColor(isError ? .red : .green)
                            .frame(minWidth: 300, minHeight: 80)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(isError ? Color.red : Color.white, lineWidth: 4)
                            )
                            .offset(x: isError ? -10 : 0)
                        
                        Button(action: {
                            if !userEntry.isEmpty { userEntry.removeLast() }
                            isError = false
                        }) {
                            Image(systemName: "delete.left.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.red.opacity(0.8))
                                .clipShape(Circle())
                        }
                    }
                    
                    Spacer()
                    
                    // --- CLAVIER ---
                    VStack(spacing: 12) {
                        HStack(spacing: 10) { ForEach(row1, id: \.self) { letter in KeyButton(letter: letter) } }
                        HStack(spacing: 10) { ForEach(row2, id: \.self) { letter in KeyButton(letter: letter) } }
                        HStack(spacing: 10) { ForEach(row3, id: \.self) { letter in KeyButton(letter: letter) } }
                    }
                    .padding(.horizontal)
                    
                    // --- BOUTON VALIDER ---
                    Button(action: validateAnswer) {
                        Text("VALIDER")
                            .font(.system(size: 40, weight: .heavy))
                            .foregroundColor(.white)
                            .frame(width: 250, height: 80)
                            .background(userEntry.isEmpty ? Color.gray : Color.green)
                            .cornerRadius(40)
                            .shadow(radius: 5)
                    }
                    .disabled(userEntry.isEmpty)
                    .padding(.vertical, 30)
                }
            }
        }
        .onAppear {
            loadLibrary()
            forceAudio()
        }
    }
    
    // --- COMPOSANTS ---
    func KeyButton(letter: String) -> some View {
        Button(action: {
            userEntry += letter
            isError = false
        }) {
            Text(letter)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.indigo)
                .frame(width: 60, height: 60)
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: .black.opacity(0.2), radius: 2)
        }
    }
    
    // --- LOGIQUE SUPABASE ---
    func loadLibrary() {
        Task {
            do {
                let data = try await SupabaseManager.shared.fetchWriteContent()
                await MainActor.run {
                    if data.isEmpty {
                        // Fallback si la DB est vide
                        self.challenges = [
                            WriteContent(correct: "MYTHOLOGIE", wrong: "MITHOLOGIE"),
                            WriteContent(correct: "AVENTURE", wrong: "AVANTURE"),
                            WriteContent(correct: "ANTIQUE", wrong: "ANTIC")
                        ]
                    } else {
                        self.challenges = data.shuffled()
                    }
                    startNewRound()
                    self.isLoading = false
                }
            } catch {
                print("❌ Erreur chargement: \(error)")
                self.isLoading = false
            }
        }
    }
    
    func startNewRound() {
        currentChallenge = challenges.randomElement()
        userEntry = ""
        isError = false
    }
    
    func validateAnswer() {
        guard let challenge = currentChallenge else { return }
        
        if userEntry.uppercased() == challenge.correct.uppercased() {
            // ✅ SUCCÈS
            playSuccessSound()
            questionCount += 1
            
            if questionCount >= targetSuccess {
                finishGame()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    startNewRound()
                }
            }
        } else {
            // ❌ ERREUR
            playErrorSound()
            mistakes += 1
            withAnimation(.default) {
                isError = true
            }
            // On laisse l'enfant voir son erreur puis on efface
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                userEntry = ""
            }
        }
    }
    
    func finishGame() {
        // --- MODIFICATION ICI : On enregistre le mot correct pour les stats ---
        let correctWord = currentChallenge?.correct ?? ""
        let summary = "Copié : \(correctWord)"
        
        let details = HistoryDetails(
            text_read: nil,
            audio_url: nil,
            duration_seconds: nil,
            score: targetSuccess,
            total_questions: targetSuccess,
            mistakes: mistakes,
            exercise_summary: summary // Affiché dans StatisticsView
        )
        SupabaseManager.shared.saveHistory(type: "write", details: details)
        
        onFinished()
    }
    
    func forceAudio() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    func playSuccessSound() { AudioServicesPlaySystemSound(1057) }
    func playErrorSound() { AudioServicesPlaySystemSound(1053) }
}
