//
//  HomeView.swift
//  Kidsbrowser
//
//  Created by BriceM4 on 16/01/2026.
//

import SwiftUI

struct HomeView: View {
    let webItems: [MenuItem]
    let gameItems: [MenuItem]
    let onSelect: (MenuItem) -> Void
    
    // Action pour ouvrir les réglages
    let onSettings: () -> Void
    
    let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                
                Text("👋 Bonjour !")
                    .font(.system(size: 50, weight: .heavy))
                    .foregroundColor(.blue)
                    .padding(.top, 40)
                
                // SECTION VIDÉOS
                VStack(alignment: .leading, spacing: 20) {
                    Label("Vidéos (Chronométré ⏱️)", systemImage: "play.tv.fill")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.leading)
                    
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(webItems) { item in
                            BigButton(item: item) { onSelect(item) }
                        }
                    }
                }
                
                // SECTION JEUX
                VStack(alignment: .leading, spacing: 20) {
                    Label("Entraînement (Libre 🎓)", systemImage: "brain.head.profile")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.leading)
                    
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(gameItems) { item in
                            BigButton(item: item) { onSelect(item) }
                        }
                    }
                }
                
                Spacer(minLength: 50)
                
                // --- LE LIEN ACCÈS PARENTS ---
                Button(action: onSettings) {
                    HStack {
                        Image(systemName: "lock.shield")
                        Text("Accès Parents / Réglages")
                    }
                    .font(.headline)
                    .foregroundColor(.gray)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(radius: 2)
                }
                .padding(.bottom, 30)
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

// Le bouton standard pour les grilles
struct BigButton: View {
    let item: MenuItem
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: item.icon)
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
                
                Text(item.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading) // Au cas où le texte est long
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(20)
            .frame(height: 100)
            .background(item.color)
            .cornerRadius(20)
            .shadow(color: item.color.opacity(0.4), radius: 10, x: 0, y: 5)
        }
    }
}
