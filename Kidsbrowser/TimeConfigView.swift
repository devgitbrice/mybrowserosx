//
//  TimeConfigView.swift
//  Kidsbrowser
//
//  Created by BriceM4 on 18/01/2026.
//

import SwiftUI

struct TimeConfigView: View {
    @State private var cycles = 1
    @State private var initialDelay: Double = 20.0
    @State private var breakDelay: Double = 10.0
    @State private var isLoading = false
    
    // --- VARIABLES POUR LE POP-UP ---
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var isSuccess = true
    
    // Le profil pour lequel on modifie le temps
    let profile: String

    var body: some View {
        ZStack {
            // 1. LE FORMULAIRE
            Form {
                Section(header: Text("Minuteurs pour \(profile)")) {
                    
                    // --- TEMPS VIDÉO ---
                    VStack(alignment: .leading) {
                        Text("⏳ Durée Vidéo avant pause : \(Int(initialDelay)) min")
                        Slider(value: $initialDelay, in: 1...60, step: 1)
                    }
                    .padding(.vertical, 5)
                    
                    // --- TEMPS PAUSE ---
                    VStack(alignment: .leading) {
                        Text("⏸️ Durée de la Pause (Jeux) : \(Int(breakDelay)) min")
                        Slider(value: $breakDelay, in: 1...30, step: 1)
                    }
                    .padding(.vertical, 5)
                    
                    // --- CYCLES ---
                    Stepper("🔄 Nombre de cycles : \(cycles)", value: $cycles, in: 1...10)
                }
                
                Section {
                    Button(action: saveSettings) {
                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            HStack {
                                Spacer()
                                Text("Enregistrer les réglages")
                                    .fontWeight(.bold)
                                Spacer()
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
                
                Section(header: Text("Info")) {
                    Text("Ces réglages s'appliquent spécifiquement au profil \(profile).")
                        .font(.caption).foregroundColor(.gray)
                }
            }
            
            // 2. LE POP-UP (TOAST)
            if showToast {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.title2)
                        Text(toastMessage)
                            .fontWeight(.medium)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isSuccess ? Color.green : Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .shadow(radius: 5)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100) // S'assure qu'il est au-dessus de tout
            }
        }
        .navigationTitle("Gestion du temps ⏱️")
        .onAppear { loadSettings() }
    }
    
    // --- LOGIQUE ---
    
    func loadSettings() {
        // Sécurité : On dit au manager quel profil charger
        SupabaseManager.shared.currentProfile = profile
        
        Task {
            do {
                let settings = try await SupabaseManager.shared.fetchSettings()
                await MainActor.run {
                    self.cycles = settings.number_of_cycles
                    self.initialDelay = Double(settings.initial_delay)
                    self.breakDelay = Double(settings.break_delay)
                }
            } catch { print("Erreur chargement temps: \(error)") }
        }
    }
    
    func saveSettings() {
        isLoading = true
        
        // --- CORRECTION CRITIQUE ---
        // On force le manager à cibler le profil actuel avant de sauvegarder
        SupabaseManager.shared.currentProfile = profile
        
        Task {
            do {
                // 1. On récupère la config actuelle pour garder les jeux intacts
                // (Cela permet aussi de vérifier que le profil existe bien en base)
                let currentSettings = try await SupabaseManager.shared.fetchSettings()
                
                // 2. On sauvegarde
                try await SupabaseManager.shared.saveSettings(
                    cycles: cycles,
                    initialDelay: Int(initialDelay),
                    breakDelay: Int(breakDelay),
                    games: currentSettings.games_config
                )
                
                await MainActor.run {
                    isLoading = false
                    showToast(message: "Réglages de \(profile) enregistrés !", success: true)
                }
            } catch {
                print("Erreur sauvegarde: \(error)")
                await MainActor.run {
                    isLoading = false
                    showToast(message: "Erreur de sauvegarde", success: false)
                }
            }
        }
    }
    
    // Fonction pour afficher et cacher le pop-up
    func showToast(message: String, success: Bool) {
        withAnimation {
            self.toastMessage = message
            self.isSuccess = success
            self.showToast = true
        }
        
        // Disparait après 3 secondes
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                self.showToast = false
            }
        }
    }
}
