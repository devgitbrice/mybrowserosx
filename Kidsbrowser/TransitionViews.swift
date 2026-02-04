//
//  TransitionViews.swift
//  Kidsbrowser
//
//  Created by BriceM4 on 17/01/2026.
//

import SwiftUI
import AVFoundation

// --- ÉCRAN D'INTRODUCTION (DÉBUT DU CYCLE) ---
struct GlobalIntroView: View {
    var onFinished: () -> Void
    
    var body: some View {
        ZStack {
            Color.blue.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Text("🚀")
                    .font(.system(size: 100))
                    .scaleEffect(1.2)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: true)
                
                Text("C'est parti Arthur !")
                    .font(.system(size: 50, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Text("Petit entraînement avant de jouer...")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .onAppear {
            forceAudio() // On active le son
            AudioServicesPlaySystemSound(1022) // Son "Calypso" (Intro)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                onFinished()
            }
        }
    }
    
    func forceAudio() {
        // Force le son même si le bouton silencieux est activé
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}

// --- ÉCRAN DE SUCCÈS (FIN DU CYCLE) ---
struct GlobalSuccessView: View {
    var onUnlock: () -> Void
    
    var body: some View {
        ZStack {
            Color.green.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 40) {
                Text("🏆")
                    .font(.system(size: 100))
                    .rotationEffect(.degrees(15))
                    .animation(.spring(response: 0.5, dampingFraction: 0.3, blendDuration: 0).repeatForever(autoreverses: true), value: true)
                
                VStack(spacing: 10) {
                    Text("Bravo Arthur !")
                        .font(.system(size: 60, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Tu as bien travaillé.")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Text("Tu as le droit de continuer à t'amuser !")
                    .font(.title2)
                    .italic()
                    .foregroundColor(.yellow)
                    .padding(.top, 10)
                
                // Bouton pour débloquer
                Button(action: onUnlock) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Retour à la vidéo")
                    }
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                    .padding(.vertical, 20)
                    .padding(.horizontal, 40)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(radius: 10)
                }
                .padding(.top, 30)
            }
        }
        .onAppear {
            forceAudio() // On active le son
            AudioServicesPlaySystemSound(1025) // Son "Fanfare" (Victoire)
        }
    }
    
    func forceAudio() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}
