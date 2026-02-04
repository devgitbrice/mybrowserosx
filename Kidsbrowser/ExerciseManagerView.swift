//
//  ExerciseManagerView.swift
//  Kidsbrowser
//
//  Created by BriceM4 on 17/01/2026.
//

import SwiftUI

struct ExerciseManagerView: View {
    @State private var exercises: [AdminExercise] = []
    @State private var isLoading = true
    @State private var showAddSheet = false
    
    // Pour afficher le nom de l'enfant dans le titre
    let currentProfileName = SupabaseManager.shared.currentProfile
    
    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Chargement de la bibliothèque...")
                    Spacer()
                }
            } else {
                // Section MATHS
                exerciseSection(title: "Mathématiques", type: "math", icon: "number.circle.fill", color: .orange)
                
                // Section ORTHOGRAPHE
                exerciseSection(title: "Orthographe (Quiz)", type: "quiz", icon: "pencil", color: .purple)
                
                // Section ÉCRITURE
                exerciseSection(title: "Écriture (Le Correcteur)", type: "write", icon: "keyboard", color: .indigo)
                
                // Section LECTURE
                exerciseSection(title: "Lecture", type: "lecture", icon: "book.fill", color: .blue)
            }
        }
        .navigationTitle("Bibliothèque \(currentProfileName) 📚") // Titre dynamique
        .toolbar {
            Button(action: { showAddSheet = true }) {
                Image(systemName: "plus.circle.fill")
                Text("Ajouter")
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddExerciseView {
                // Quand on ferme la fenêtre d'ajout, on recharge la liste
                loadData()
            }
        }
        .onAppear { loadData() }
    }
    
    // Une section générique pour éviter de répéter le code
    func exerciseSection(title: String, type: String, icon: String, color: Color) -> some View {
        let filtered = exercises.filter { $0.type == type }
        
        return Section(header: Label(title, systemImage: icon).foregroundColor(color)) {
            if filtered.isEmpty {
                Text("Aucun exercice").font(.caption).foregroundColor(.gray)
            } else {
                ForEach(filtered) { exo in
                    HStack {
                        // Affichage intelligent selon le type
                        if type == "math", let n1 = exo.content.num1, let n2 = exo.content.num2 {
                            Text("\(n1) x \(n2) = \(n1*n2)")
                                .font(.system(.body, design: .monospaced))
                        }
                        else if type == "write", let wrong = exo.content.wrong, let correct = exo.content.correct {
                            VStack(alignment: .leading) {
                                Text(wrong).strikethrough().foregroundColor(.red)
                                Text(correct).foregroundColor(.green).bold()
                            }
                        }
                        else if type == "quiz", let text = exo.content.text {
                            VStack(alignment: .leading) {
                                Text(text).lineLimit(1)
                                if let wrongs = exo.content.wrongAnswers {
                                    Text("\(wrongs.count) leurres").font(.caption).foregroundColor(.gray)
                                }
                            }
                        }
                        else if type == "lecture", let text = exo.content.text {
                            Text(text).lineLimit(2).font(.caption)
                        }
                        else {
                            Text("Contenu inconnu")
                        }
                        
                        Spacer()
                    }
                }
                .onDelete { indexSet in
                    deleteItems(at: indexSet, in: filtered)
                }
            }
        }
    }
    
    // --- LOGIQUE ---
    
    func loadData() {
        isLoading = true
        Task {
            do {
                let items = try await SupabaseManager.shared.fetchAllAdminExercises()
                await MainActor.run {
                    self.exercises = items
                    self.isLoading = false
                }
            } catch {
                print("Erreur chargement: \(error)")
                await MainActor.run { isLoading = false }
            }
        }
    }
    
    func deleteItems(at offsets: IndexSet, in filteredList: [AdminExercise]) {
        offsets.forEach { index in
            let itemToDelete = filteredList[index]
            
            // Suppression Optimiste (on l'enlève de la vue tout de suite)
            if let mainIndex = exercises.firstIndex(where: { $0.id == itemToDelete.id }) {
                exercises.remove(at: mainIndex)
            }
            
            // Appel Cloud
            Task {
                try? await SupabaseManager.shared.deleteExercise(id: itemToDelete.id)
            }
        }
    }
}

// --- VUE D'AJOUT D'EXERCICE ---
struct AddExerciseView: View {
    var onSave: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedType = "math"
    @State private var isSaving = false
    
    // Champs pour les Maths
    @State private var num1 = 2
    @State private var num2 = 2
    
    // Champs pour Quiz
    @State private var quizQuestion = ""
    @State private var quizCorrect = ""
    @State private var quizWrong1 = ""
    @State private var quizWrong2 = ""
    @State private var quizWrong3 = "" // <--- NOUVEAU
    
    // Champs pour Write
    @State private var writeCorrect = ""
    @State private var writeWrong = ""
    
    // Champs pour Lecture
    @State private var lectureText = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Type d'exercice", selection: $selectedType) {
                        Text("Mathématiques").tag("math")
                        Text("Orthographe (Quiz)").tag("quiz")
                        Text("Écriture").tag("write")
                        Text("Lecture").tag("lecture")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // FORMULAIRE DYNAMIQUE
                if selectedType == "math" {
                    Section(header: Text("Table de multiplication")) {
                        Stepper("Nombre 1 : \(num1)", value: $num1, in: 2...20)
                        Stepper("Nombre 2 : \(num2)", value: $num2, in: 2...20)
                        Text("Résultat : \(num1 * num2)").foregroundColor(.gray)
                    }
                }
                else if selectedType == "quiz" {
                    Section(header: Text("Question QCM")) {
                        TextField("Question (ex: Capitale de...)", text: $quizQuestion)
                        TextField("✅ Bonne réponse", text: $quizCorrect)
                            .foregroundColor(.green)
                        TextField("❌ Mauvaise réponse 1", text: $quizWrong1)
                            .foregroundColor(.red)
                        TextField("❌ Mauvaise réponse 2", text: $quizWrong2)
                            .foregroundColor(.red)
                        TextField("❌ Mauvaise réponse 3", text: $quizWrong3) // <--- NOUVEAU CHAMP
                            .foregroundColor(.red)
                    }
                }
                else if selectedType == "write" {
                    Section(header: Text("Correction de mot")) {
                        TextField("Mot CORRECT (ex: MAISON)", text: $writeCorrect)
                        TextField("Mot FAUX (ex: MAIZON)", text: $writeWrong)
                    }
                }
                else if selectedType == "lecture" {
                    Section(header: Text("Texte à lire")) {
                        Text("Vous pouvez faire des sauts de ligne :")
                            .font(.caption).foregroundColor(.gray)
                        
                        TextEditor(text: $lectureText)
                            .frame(height: 200)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                    }
                }
                
                Section {
                    Button(action: saveExercise) {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Ajouter à la bibliothèque")
                                    .fontWeight(.bold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isSaving)
                    .listRowBackground(Color.blue)
                    .foregroundColor(.white)
                }
            }
            .navigationTitle("Nouvel Exercice")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }
    
    func saveExercise() {
        isSaving = true
        Task {
            do {
                if selectedType == "math" {
                    let content = MathContent(num1: num1, num2: num2)
                    try await SupabaseManager.shared.addExercise(type: "math", content: content)
                }
                else if selectedType == "quiz" {
                    let content = QuizContent(
                        text: quizQuestion,
                        correctAnswer: quizCorrect,
                        // ON ENVOIE LES 3 MAUVAISES RÉPONSES ICI
                        wrongAnswers: [quizWrong1, quizWrong2, quizWrong3].filter { !$0.isEmpty }
                    )
                    try await SupabaseManager.shared.addExercise(type: "quiz", content: content)
                }
                else if selectedType == "write" {
                    let content = WriteContent(correct: writeCorrect, wrong: writeWrong)
                    try await SupabaseManager.shared.addExercise(type: "write", content: content)
                }
                else if selectedType == "lecture" {
                    let content = LectureContent(text: lectureText)
                    try await SupabaseManager.shared.addExercise(type: "lecture", content: content)
                }
                
                await MainActor.run {
                    isSaving = false
                    onSave() // Rafraîchir la liste parente
                    dismiss() // Fermer la fenêtre
                }
            } catch {
                print("Erreur ajout: \(error)")
                await MainActor.run { isSaving = false }
            }
        }
    }
}
