//
//  Games_math.swift
//  Kidsbrowser
//
//  Created by BriceM4 on 16/01/2026.
//

import SwiftUI
import AVFoundation

struct SuperMaths: View {
    
    // Paramètres reçus
    var targetScore: Int = 10
    var onFinished: () -> Void
    
    // États du jeu
    @State private var questionIndex = 0
    @State private var num1 = Int.random(in: 2...9)
    @State private var num2 = Int.random(in: 2...9)
    @State private var userAnswer = ""
    @State private var feedbackColor = Color.white
    
    // --- Pour les statistiques ---
    @State private var mistakes = 0
    
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        ZStack {
            Color.orange.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                Text("🔢 Défi Calcul")
                    .font(.largeTitle).fontWeight(.heavy).foregroundColor(.white)
                    .padding(.top, 40).shadow(radius: 2)
                
                // Compteur
                Text("Question \(questionIndex + 1) / \(targetScore)")
                    .font(.headline).foregroundColor(.white.opacity(0.8))
                
                // Affichage du calcul
                VStack(spacing: 15) {
                    Text("\(num1) x \(num2) = ?")
                        .font(.system(size: 60, weight: .bold)).foregroundColor(.black)
                    
                    Text(userAnswer.isEmpty ? "..." : userAnswer)
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.blue)
                        .frame(minWidth: 150, minHeight: 80)
                        .background(Color.white).cornerRadius(15)
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(feedbackColor, lineWidth: 4))
                }
                .padding().background(Color.white.opacity(0.9)).cornerRadius(20).shadow(radius: 10)
                
                Spacer()
                
                // Clavier Numérique
                LazyVGrid(columns: columns, spacing: 15) {
                    ForEach(1...9, id: \.self) { number in numButton(number: number) }
                    
                    Button(action: { userAnswer = "" }) {
                        Text("C").font(.title).fontWeight(.bold).frame(width: 80, height: 80).background(Color.red).foregroundColor(.white).clipShape(Circle())
                    }
                    
                    numButton(number: 0)
                    
                    Button(action: { checkAnswer() }) {
                        Image(systemName: "checkmark").font(.title).fontWeight(.bold).frame(width: 80, height: 80).background(Color.green).foregroundColor(.white).clipShape(Circle())
                    }
                }
                .padding(.horizontal, 50).padding(.bottom, 40)
            }
        }
        .onAppear { forceAudio() }
    }
    
    // --- COMPOSANTS UI ---
    
    func numButton(number: Int) -> some View {
        Button(action: { if userAnswer.count < 3 { userAnswer += "\(number)" } }) {
            Text("\(number)").font(.largeTitle).fontWeight(.bold).frame(width: 80, height: 80).background(Color.white).foregroundColor(.black).clipShape(Circle()).shadow(radius: 3)
        }
    }
    
    // --- LOGIQUE DU JEU ---
    
    func checkAnswer() {
        guard let answerInt = Int(userAnswer) else { return }
        
        if answerInt == num1 * num2 {
            // BONNE RÉPONSE
            playSuccessSound()
            feedbackColor = .green
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if questionIndex >= targetScore - 1 {
                    finishGame() // On finit si c'était le dernier
                } else {
                    nextQuestion()
                }
            }
        } else {
            // MAUVAISE RÉPONSE
            playErrorSound()
            feedbackColor = .red
            mistakes += 1
            withAnimation { userAnswer = "" }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { feedbackColor = .white }
        }
    }
    
    func nextQuestion() {
        userAnswer = ""
        feedbackColor = .white
        questionIndex += 1
        num1 = Int.random(in: 2...9)
        num2 = Int.random(in: 2...9)
    }
    
    func finishGame() {
        // --- MODIFICATION ICI : On enregistre le calcul réussi ---
        let lastCalculation = "\(num1) x \(num2) = \(num1 * num2)"
        
        let details = HistoryDetails(
            text_read: nil,
            audio_url: nil,
            duration_seconds: nil,
            score: targetScore,
            total_questions: targetScore,
            mistakes: mistakes,
            exercise_summary: lastCalculation // Sera visible dans la liste des stats
        )
        
        SupabaseManager.shared.saveHistory(type: "math", details: details)
        
        // On libère
        onFinished()
    }
    
    // --- SONS ---
    func forceAudio() { try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default); try? AVAudioSession.sharedInstance().setActive(true) }
    func playSuccessSound() { AudioServicesPlaySystemSound(1057) }
    func playErrorSound() { AudioServicesPlaySystemSound(1053) }
}
