//
//  SessionConfigView.swift
//  Kidsbrowser
//
//  Created by BriceM4 on 17/01/2026.
//

import SwiftUI

struct SessionConfigView: View {
    @State private var settings: AppSettings?
    @State private var isLoading = true
    
    // Pour gérer l'ordre et les jeux localement avant sauvegarde
    @State private var localGames: [GameConfig] = []
    @State private var numberOfCycles: Int = 1
    
    // Pour savoir quel profil on modifie
    let currentProfile = SupabaseManager.shared.currentProfile
    
    // --- FEEDBACK VISUEL ---
    @State private var feedbackMessage: String? = nil
    @State private var isSuccess: Bool = true
    
    var body: some View {
        ZStack {
            // 1. LE CONTENU
            if isLoading {
                ProgressView("Chargement de la configuration...")
            } else {
                Form {
                    // INFO PROFIL
                    Section {
                        HStack {
                            Text("Profil actif :")
                            Spacer()
                            Text(currentProfile)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // SECTION 1 : CYCLES
                    Section(header: Text("🔄 Cycles")) {
                        Stepper("Nombre de cycles : \(numberOfCycles)", value: $numberOfCycles, in: 1...10)
                        Text("Cela répétera la liste des jeux \(numberOfCycles) fois avant de débloquer l'iPad.")
                            .font(.caption).foregroundColor(.gray)
                    }
                    
                    // SECTION 2 : ORDRE ET CONTENU
                    Section(header: Text("🎮 Ordre des Jeux")) {
                        if localGames.isEmpty {
                            Text("Aucun jeu. Cliquez sur Réinitialiser.")
                                .foregroundColor(.gray)
                        } else {
                            Text("Maintenez et glissez ≡ pour changer l'ordre.")
                                .font(.caption).foregroundColor(.gray)
                                .listRowBackground(Color.clear)
                            
                            List {
                                ForEach($localGames) { $game in
                                    HStack {
                                        // Icône selon le type
                                        Image(systemName: iconForType(game.type))
                                            .foregroundColor(colorForType(game.type))
                                            .font(.title2)
                                            .frame(width: 30)
                                        
                                        VStack(alignment: .leading) {
                                            Text(game.type.rawValue)
                                                .font(.headline)
                                            
                                            // Réglage du nombre de questions
                                            if game.isEnabled {
                                                HStack {
                                                    Text("Objectif :")
                                                        .font(.caption).foregroundColor(.gray)
                                                    Stepper("\(game.questionCount)", value: $game.questionCount, in: 1...50)
                                                        .font(.subheadline)
                                                }
                                            } else {
                                                Text("Désactivé").font(.caption).foregroundColor(.red)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        // Toggle Activé/Désactivé
                                        Toggle("", isOn: $game.isEnabled)
                                            .labelsHidden()
                                    }
                                }
                                .onMove(perform: moveGame)
                            }
                        }
                    }
                    
                    // SECTION 3 : ACTIONS
                    Section {
                        Button(action: saveConfiguration) {
                            HStack {
                                Spacer()
                                Text("Enregistrer l'organisation")
                                    .fontWeight(.bold)
                                Spacer()
                            }
                        }
                        .foregroundColor(.white)
                        .listRowBackground(Color.blue)
                        
                        Button("Réinitialiser par défaut") {
                            resetDefaults()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            
            // 2. LE POP-UP DE CONFIRMATION
            if let message = feedbackMessage {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        Text(message).fontWeight(.bold)
                    }
                    .padding()
                    .background(isSuccess ? Color.green : Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(15)
                    .shadow(radius: 10)
                    .padding(.bottom, 50)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .navigationTitle("Configuration Session")
        .toolbar { EditButton() } // Ajoute le bouton "Modifier" pour faciliter le déplacement
        .onAppear { loadData() }
    }
    
    // --- LOGIQUE ---
    
    func loadData() {
        isLoading = true
        Task {
            do {
                let fetchedSettings = try await SupabaseManager.shared.fetchSettings()
                await MainActor.run {
                    self.settings = fetchedSettings
                    self.numberOfCycles = fetchedSettings.number_of_cycles
                    
                    // Si la liste est vide (nouveau profil), on met des défauts
                    if fetchedSettings.games_config.isEmpty {
                        self.resetDefaults()
                    } else {
                        self.localGames = fetchedSettings.games_config
                    }
                    
                    self.isLoading = false
                }
            } catch {
                print("Erreur : \(error)")
                await MainActor.run { isLoading = false }
            }
        }
    }
    
    func resetDefaults() {
        self.localGames = [
            GameConfig(type: .quiz, isEnabled: true, questionCount: 5),
            GameConfig(type: .math, isEnabled: true, questionCount: 5),
            GameConfig(type: .write, isEnabled: true, questionCount: 3),
            GameConfig(type: .lecture, isEnabled: true, questionCount: 1)
        ]
    }
    
    func saveConfiguration() {
        guard let current = settings else { return }
        
        Task {
            do {
                // IMPORTANT : On conserve les délais existants (current.initial_delay),
                // on ne met à jour que les cycles et la liste des jeux.
                try await SupabaseManager.shared.saveSettings(
                    cycles: numberOfCycles,
                    initialDelay: current.initial_delay,
                    breakDelay: current.break_delay,
                    games: localGames
                )
                
                await MainActor.run {
                    showFeedback(message: "Configuration sauvegardée pour \(currentProfile) !", success: true)
                }
            } catch {
                print("Erreur save : \(error)")
                await MainActor.run {
                    showFeedback(message: "Erreur de sauvegarde", success: false)
                }
            }
        }
    }
    
    func moveGame(from source: IndexSet, to destination: Int) {
        localGames.move(fromOffsets: source, toOffset: destination)
    }
    
    // --- FEEDBACK VISUEL ---
    func showFeedback(message: String, success: Bool) {
        withAnimation {
            self.feedbackMessage = message
            self.isSuccess = success
        }
        
        // Disparition auto après 3 secondes
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                self.feedbackMessage = nil
            }
        }
    }
    
    // --- HELPERS VISUELS ---
    func iconForType(_ type: GameType) -> String {
        switch type {
        case .quiz: return "pencil.and.scribble"
        case .write: return "keyboard"
        case .math: return "number.circle.fill"
        case .lecture: return "mic.fill"
        }
    }
    
    func colorForType(_ type: GameType) -> Color {
        switch type {
        case .quiz: return .purple
        case .write: return .indigo
        case .math: return .orange
        case .lecture: return .blue
        }
    }
}

#Preview {
    NavigationView {
        SessionConfigView()
    }
}
