//
//  Games_quizz.swift
//  Kidsbrowser
//
//  Created by BriceM4 on 17/01/2026.
//

import SwiftUI
import AVFoundation

// 1. Structure de la donnée (Locale pour le fallback ou preview)
struct QuizQuestion {
    let text: String
    let correctAnswer: String
    let wrongAnswers: [String]
    
    var allAnswers: [String] {
        return (wrongAnswers + [correctAnswer]).shuffled()
    }
}

let sourceQuestions = [
    QuizQuestion(text: "Trouve la bonne orthographe :", correctAnswer: "Mythologie", wrongAnswers: ["Mithologie", "Mytologie", "Mythollogie"]),
    QuizQuestion(text: "Trouve la bonne orthographe :", correctAnswer: "Aventure", wrongAnswers: ["Avanture", "Aventurre", "Avanturre"]),
    QuizQuestion(text: "Trouve la bonne orthographe :", correctAnswer: "Antique", wrongAnswers: ["Antic", "Antike", "Antyque"])
]

struct GameView: View {
    var targetSuccess: Int = 3
    var onUnlock: () -> Void
    
    @State private var questions: [QuizContent] = []
    @State private var currentQuestionIndex = 0
    @State private var currentAnswers: [String] = []
    @State private var score = 0
    @State private var isLoading = true
    
    // --- STATISTIQUES ---
    @State private var mistakes = 0
    
    // UI États
    @State private var showResult = false
    @State private var resultMessage = ""
    @State private var resultColor = Color.clear
    
    var body: some View {
        ZStack {
            Color.purple.edgesIgnoringSafeArea(.all)
            
            if isLoading {
                ProgressView("Chargement du Quiz...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .foregroundColor(.white)
            } else if !questions.isEmpty {
                VStack(spacing: 30) {
                    Text("✍️ Défi Orthographe")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                        .foregroundColor(.white)
                        .padding(.top, 40)
                    
                    Text("Objectif : \(score) / \(targetSuccess)")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(10)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(10)
                    
                    // Question
                    Text(questions[currentQuestionIndex].text)
                        .font(.title2)
                        .bold()
                        .foregroundColor(.black)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(15)
                        .padding(.horizontal)
                    
                    // Réponses
                    VStack(spacing: 15) {
                        ForEach(currentAnswers, id: \.self) { answer in
                            Button(action: { checkAnswer(answer) }) {
                                Text(answer)
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.yellow)
                                    .cornerRadius(12)
                                    .shadow(radius: 3)
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    if showResult {
                        Text(resultMessage)
                            .font(.title)
                            .fontWeight(.heavy)
                            .foregroundColor(resultColor)
                            .padding()
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(15)
                            .transition(.scale)
                    }
                    
                    Spacer()
                }
            } else {
                Text("Aucune question disponible.").foregroundColor(.white)
            }
        }
        .onAppear {
            loadQuestions()
            forceAudio()
        }
    }
    
    // --- LOGIQUE ---
    
    func loadQuestions() {
        Task {
            do {
                let fetched = try await SupabaseManager.shared.fetchQuizContent()
                
                await MainActor.run {
                    if fetched.isEmpty {
                        self.questions = sourceQuestions.map { QuizContent(text: $0.text, correctAnswer: $0.correctAnswer, wrongAnswers: $0.wrongAnswers) }
                    } else {
                        self.questions = fetched.shuffled()
                    }
                    setupQuestion()
                    self.isLoading = false
                }
            } catch {
                print("Erreur Quiz: \(error)")
                await MainActor.run { self.isLoading = false }
            }
        }
    }
    
    func setupQuestion() {
        let currentQ = questions[currentQuestionIndex]
        currentAnswers = (currentQ.wrongAnswers + [currentQ.correctAnswer]).shuffled()
    }
    
    func checkAnswer(_ answer: String) {
        let correct = questions[currentQuestionIndex].correctAnswer
        
        if answer == correct {
            score += 1
            playSuccessSound()
            resultMessage = "BRAVO ! 🎉"
            resultColor = .green
            withAnimation { showResult = true }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if score >= targetSuccess {
                    finishGame()
                } else {
                    nextQuestion()
                }
            }
        } else {
            mistakes += 1
            playErrorSound()
            resultMessage = "Oups ! Recommence"
            resultColor = .red
            withAnimation { showResult = true }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation {
                    showResult = false
                    currentAnswers = currentAnswers.shuffled()
                }
            }
        }
    }
    
    func nextQuestion() {
        showResult = false
        currentQuestionIndex = (currentQuestionIndex + 1) % questions.count
        setupQuestion()
    }
    
    func finishGame() {
        // --- MODIFICATION ICI : On enregistre le mot correct ---
        let correctWord = questions[currentQuestionIndex].correctAnswer
        let summary = "Mot : \(correctWord)"
        
        let details = HistoryDetails(
            text_read: nil,
            audio_url: nil,
            duration_seconds: nil,
            score: score,
            total_questions: targetSuccess,
            mistakes: mistakes,
            exercise_summary: summary // Affichage dans la liste des stats
        )
        
        SupabaseManager.shared.saveHistory(type: "quiz", details: details)
        
        onUnlock()
    }
    
    func forceAudio() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    func playSuccessSound() { AudioServicesPlaySystemSound(1057) }
    func playErrorSound() { AudioServicesPlaySystemSound(1053) }
}
