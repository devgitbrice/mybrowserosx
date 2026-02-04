//
//  SettingsView.swift
//  Kidsbrowser
//
//  Created by BriceM4 on 17/01/2026.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    // 1. On récupère le nom du profil actuellement connecté
    let currentProfile = SupabaseManager.shared.currentProfile
    
    // --- NOUVEAU : LIEN POUR DÉCLENCHER L'ALERTE ---
    @Binding var triggerAlert: Bool
    
    var body: some View {
        NavigationStack {
            List {
                // --- SECTION ALERTE PARENTALE ---
                Section {
                    Button(action: triggerComeHereAction) {
                        HStack {
                            Spacer()
                            Image(systemName: "megaphone.fill")
                                .font(.title2)
                            Text("VENEZ ICI !")
                                .font(.headline)
                                .fontWeight(.black)
                            Spacer()
                        }
                        .padding(.vertical, 10)
                    }
                    .listRowBackground(Color.red)
                    .foregroundColor(.white)
                }
                
                // 2. Style (Couleur/Icône) selon le profil actif
                let style = getProfileStyle(for: currentProfile)
                
                // 3. Section du profil en cours
                ProfileSection(
                    name: currentProfile,
                    color: style.color,
                    icon: style.icon
                )
            }
            .navigationTitle("Réglages : \(currentProfile)")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
    }
    
    // --- LOGIQUE DU BOUTON "VENEZ ICI" ---
    func triggerComeHereAction() {
        // 1. On ferme d'abord les réglages
        dismiss()
        
        // 2. On attend un court instant (le temps que le modal disparaisse)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            // 3. On affiche l'écran noir
            triggerAlert = true
            
            // 4. On le retire automatiquement après 5 secondes
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.4) {
                triggerAlert = false
            }
        }
    }
    
    func getProfileStyle(for name: String) -> (color: Color, icon: String) {
        switch name {
        case "Arthur": return (.blue, "person.fill")
        case "Capucine": return (.pink, "heart.fill")
        case "Papa": return (.gray, "mustache.fill")
        default: return (.blue, "person.circle")
        }
    }
}

// --- COMPOSANT DE SECTION ---
struct ProfileSection: View {
    let name: String
    let color: Color
    let icon: String
    
    var body: some View {
        Section(header: Label("Profil \(name)", systemImage: icon).foregroundColor(color).font(.headline)) {
            
            NavigationLink(destination: SessionConfigView()) {
                SettingsRow(icon: "arrow.triangle.2.circlepath", text: "Configurer ordre et cycle", color: .orange)
            }
            .simultaneousGesture(TapGesture().onEnded {
                SupabaseManager.shared.currentProfile = name
            })
            
            NavigationLink(destination: ExerciseManagerView()) {
                SettingsRow(icon: "books.vertical.fill", text: "Gérer la bibliothèque", color: .purple)
            }
            
            NavigationLink(destination: StatisticsView()) {
                SettingsRow(icon: "chart.bar.xaxis", text: "Voir les statistiques", color: .green)
            }
            
            NavigationLink(destination: TimeConfigView(profile: name)) {
                SettingsRow(icon: "clock.fill", text: "Gestion du temps", color: .blue)
            }
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(color)
                .cornerRadius(8)
            Text(text)
        }
    }
}

#Preview {
    // Preview avec un binding constant
    SettingsView(triggerAlert: .constant(false))
}
