//
//  TimeManager.swift
//  Kidsbrowser
//
//  Created by BriceM4 on 16/01/2026.
//

import SwiftUI

struct TimeManager<Content: View>: View {
    @Binding var isMonitoring: Bool
    let content: Content
    
    // --- ÉTATS SYNCHRONISÉS AVEC SUPABASE ---
    @State private var timeAllowed: Int = 20 * 60 // Sera écrasé par la DB
    @State private var timeElapsed = 0
    @State private var isBlocked = false
    @State private var timer: Timer? = nil
    
    // Sécurité pour vérifier si des jeux sont configurés
    @State private var hasActiveGames: Bool = false
    
    init(isMonitoring: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._isMonitoring = isMonitoring
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            // L'application (YouTube / Netflix)
            content
                .disabled(isBlocked)
                .blur(radius: isBlocked ? 10 : 0)
            
            // L'écran de pause
            if isBlocked {
                Color.black.opacity(0.9).edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 25) {
                    Image(systemName: "hourglass.badge.plus")
                        .font(.system(size: 80))
                        .foregroundColor(.orange)
                    
                    Text("⏳ Pause pour \(SupabaseManager.shared.currentProfile) !")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Tu as bien profité de ton temps vidéo.")
                        .foregroundColor(.gray)
                    
                    Text("Réussis un exercice pour débloquer !")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green.opacity(0.8))
                        .cornerRadius(12)
                }
                .transition(.scale)
            }
        }
        // COMPATIBILITÉ iOS 16
        .onChange(of: isMonitoring) { newValue in
            if newValue {
                // Dès que l'enfant ouvre YouTube, on va chercher ses réglages
                loadProfileSettingsAndStart()
            } else {
                stopTimer()
            }
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    // --- LOGIQUE DE CONNEXION SUPABASE ---
    
    func loadProfileSettingsAndStart() {
        Task {
            do {
                // On récupère les réglages spécifiques (ex: Capucine)
                let settings = try await SupabaseManager.shared.fetchSettings()
                
                await MainActor.run {
                    // Conversion des minutes de la DB en secondes
                    self.timeAllowed = settings.initial_delay * 60
                    
                    // On vérifie si au moins un jeu est activé dans son cycle
                    self.hasActiveGames = settings.games_config.contains(where: { $0.isEnabled })
                    
                    print("⏱️ Config chargée pour \(SupabaseManager.shared.currentProfile): \(settings.initial_delay) min")
                    
                    if hasActiveGames && timeAllowed > 0 {
                        startTimer()
                    } else {
                        print("⚠️ Alerte: Aucun jeu activé ou temps à 0 pour ce profil.")
                        // Optionnel: on peut bloquer direct si 0 min est configuré
                        if settings.initial_delay == 0 { isBlocked = true }
                    }
                }
            } catch {
                print("❌ Erreur chargement TimeManager: \(error)")
            }
        }
    }
    
    func startTimer() {
        stopTimer()
        timeElapsed = 0 // On repart de zéro à chaque nouvelle session vidéo
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if isMonitoring && !isBlocked {
                timeElapsed += 1
                
                // Si on dépasse le temps autorisé par les parents
                if timeElapsed >= timeAllowed {
                    withAnimation {
                        isBlocked = true
                    }
                    stopTimer()
                    print("🛑 BLOCAGE : Temps écoulé pour \(SupabaseManager.shared.currentProfile)")
                }
            }
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func resetTimer() {
        timeElapsed = 0
        isBlocked = false
    }
}
