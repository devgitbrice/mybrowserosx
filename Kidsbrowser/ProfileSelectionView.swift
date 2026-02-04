//
//  ProfileSelectionView.swift
//  Kidsbrowser
//
//  Created by BriceM4 on 18/01/2026.
//

import SwiftUI

struct ProfileSelectionView: View {
    @State private var selectedProfile: String? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all) // Fond style Netflix
                
                VStack(spacing: 50) {
                    Text("Qui veut jouer ?")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 50)
                    
                    HStack(spacing: 40) {
                        // --- PROFIL ARTHUR ---
                        ProfileButton(name: "Arthur", color: .blue, icon: "person.fill") {
                            selectProfile("Arthur")
                        }
                        
                        // --- PROFIL CAPUCINE ---
                        ProfileButton(name: "Capucine", color: .pink, icon: "heart.fill") {
                            selectProfile("Capucine")
                        }
                        
                        // --- PROFIL PAPA ---
                        ProfileButton(name: "Papa", color: .gray, icon: "mustache.fill") {
                            selectProfile("Papa")
                        }
                    }
                    
                    Spacer()
                }
            }
            // --- CORRECTION COMPATIBILITÉ iOS 16 ---
            // On utilise 'isPresented' avec un Binding manuel au lieu de 'item' (iOS 17+)
            .navigationDestination(isPresented: Binding(
                get: { selectedProfile != nil },
                set: { if !$0 { selectedProfile = nil } }
            )) {
                ContentView()
                    .navigationBarBackButtonHidden(true)
            }
        }
    }
    
    func selectProfile(_ name: String) {
        // 1. On configure le manager
        SupabaseManager.shared.currentProfile = name
        print("👤 Profil sélectionné : \(name)")
        
        // 2. On déclenche la navigation
        selectedProfile = name
    }
}

// Composant bouton (inchangé)
struct ProfileButton: View {
    let name: String
    let color: Color
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 150, height: 150)
                    
                    Image(systemName: icon)
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }
                .shadow(radius: 10)
                
                Text(name)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.top, 10)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ProfileSelectionView()
}
