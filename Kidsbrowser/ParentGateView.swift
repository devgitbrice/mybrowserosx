//
//  ParentGateView.swift
//  Kidsbrowser
//
//  Created by BriceM4 on 18/01/2026.
//

import SwiftUI
import LocalAuthentication

struct ParentGateView: View {
    // État du verrouillage
    @State private var isUnlocked = false
    @State private var authError: String? = nil
    
    // Variables pour le calcul mental de secours
    @State private var answer = ""
    @State private var num1 = 0
    @State private var num2 = 0
    
    // Permet de fermer la vue si on clique sur Annuler
    @Environment(\.dismiss) var dismiss
    
    // --- NOUVEAU : LIEN POUR L'ALERTE "VENEZ ICI" ---
    @Binding var triggerAlert: Bool
    
    var body: some View {
        Group {
            if isUnlocked {
                // ✅ 1. SI DÉVERROUILLÉ -> ON AFFICHE LES RÉGLAGES
                // On passe la binding triggerAlert à SettingsView
                SettingsView(triggerAlert: $triggerAlert)
                    .navigationBarBackButtonHidden(true)
                    .transition(.opacity)
            } else {
                // 🔒 2. SI VERROUILLÉ -> ON AFFICHE LE CADENAS
                lockScreenContent
                    .transition(.opacity)
            }
        }
        .animation(.default, value: isUnlocked)
    }
    
    // --- L'ÉCRAN DE VERROUILLAGE (DESIGN) ---
    var lockScreenContent: some View {
        ScrollView {
            VStack(spacing: 30) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .padding(.top, 50)
                
                Text("Accès Parents")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Veuillez vous authentifier pour accéder au tableau de bord.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .foregroundColor(.gray)
                
                // BOUTON FACE ID / TOUCH ID
                Button(action: authenticate) {
                    HStack {
                        Image(systemName: "faceid")
                            .font(.title)
                        Text("Déverrouiller")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 280)
                    .background(Color.blue)
                    .cornerRadius(15)
                    .shadow(radius: 5)
                }
                .padding(.vertical)
                
                Divider().padding(.horizontal, 40)
                
                // CALCUL MENTAL (Secours)
                VStack(spacing: 15) {
                    Text("Ou résolvez ce calcul :")
                        .font(.caption).foregroundColor(.gray)
                    
                    if num1 > 0 {
                        Text("\(num1) x \(num2) = ?")
                            .font(.title).fontWeight(.heavy)
                    }
                    
                    HStack {
                        TextField("Réponse", text: $answer)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 120)
                            .multilineTextAlignment(.center)
                        
                        Button("Valider") { checkMath() }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(answer.isEmpty ? Color.gray : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .disabled(answer.isEmpty)
                    }
                }
                
                if let error = authError {
                    Text(error).foregroundColor(.red).font(.caption).padding(.top)
                }
                
                // BOUTON ANNULER (Revient à l'accueil)
                Button("Annuler / Retour") {
                    dismiss()
                }
                .foregroundColor(.gray)
                .padding(.top, 30)
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            generateMathProblem()
            authenticate() // Tente FaceID dès l'ouverture
        }
        .navigationBarBackButtonHidden(true)
    }
    
    // --- LOGIQUE ---
    
    func generateMathProblem() {
        if num1 == 0 {
            num1 = Int.random(in: 12...19)
            num2 = Int.random(in: 3...9)
        }
    }
    
    func authenticate() {
        let context = LAContext()
        var error: NSError?
        
        // On vérifie si la biométrie est disponible
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Accès aux réglages parents") { success, _ in
                DispatchQueue.main.async {
                    if success {
                        withAnimation { self.isUnlocked = true }
                    } else {
                        self.authError = "Authentification échouée."
                    }
                }
            }
        } else {
            // Sur simulateur ou si non configuré, on affiche l'erreur (ou on débloque pour dev)
            self.authError = "Authentification biométrique indisponible."
            // self.isUnlocked = true // Décommentez pour tester sans FaceID
        }
    }
    
    func checkMath() {
        let cleanAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        if let res = Int(cleanAnswer), res == (num1 * num2) {
            withAnimation { self.isUnlocked = true }
        } else {
            authError = "Mauvaise réponse."
            answer = ""
        }
    }
}

#Preview {
    // Pour la preview, on passe un binding constant
    ParentGateView(triggerAlert: .constant(false))
}
