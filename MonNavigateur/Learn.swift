import SwiftUI

struct LearnView: View {
    // Cette action permet de dire à la vue parent "C'est bon, débloque !"
    var onUnlock: () -> Void
    
    // Deux chiffres aléatoires entre 2 et 9
    @State private var chiffre1 = Int.random(in: 2...9)
    @State private var chiffre2 = Int.random(in: 2...9)
    
    @State private var reponseUtilisateur: String = ""
    @State private var estFaux: Bool = false
    
    var body: some View {
        ZStack {
            // 1. Fond noir total
            Color.black.edgesIgnoringSafeArea(.all)
            
            // 2. Le contenu de la question
            VStack(spacing: 30) {
                Text("🔒 Pause Éducative")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
                
                Text("Pour débloquer ton navigateur, réponds :")
                    .foregroundColor(.white)
                
                Text("\(chiffre1) x \(chiffre2) = ?")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.white)
                
                HStack {
                    TextField("Ta réponse", text: $reponseUtilisateur)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .onSubmit { verifierReponse() } // Valide avec la touche Entrée
                    
                    Button("Valider") {
                        verifierReponse()
                    }
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                if estFaux {
                    Text("Faux ! Essaie encore.")
                        .foregroundColor(.red)
                        .font(.title2)
                }
            }
        }
    }
    
    func verifierReponse() {
        // On calcule la vraie réponse
        let resultatCorrect = chiffre1 * chiffre2
        
        // On vérifie ce que l'utilisateur a tapé
        if Int(reponseUtilisateur) == resultatCorrect {
            // Si c'est bon, on appelle l'action de déblocage
            onUnlock()
        } else {
            // Sinon, on affiche l'erreur et on vide le champ
            estFaux = true
            reponseUtilisateur = ""
        }
    }
}
