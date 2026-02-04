//
//  SupabaseManager.swift
//  Kidsbrowser
//
//  Created by BriceM4 on 17/01/2026.
//

import Foundation
import Supabase

// --- 1. MODÈLES DE CONFIGURATION ---
enum GameType: String, Codable, CaseIterable {
    case quiz = "Orthographe"
    case write = "Écriture"
    case math = "Mathématiques"
    case lecture = "Lecture"
}

struct GameConfig: Identifiable, Codable, Equatable {
    var id: String { type.rawValue }
    var type: GameType
    var isEnabled: Bool
    var questionCount: Int
    enum CodingKeys: String, CodingKey { case type, isEnabled, questionCount }
}

struct AppSettings: Codable, Identifiable {
    var id: Int?
    var number_of_cycles: Int
    var initial_delay: Int
    var break_delay: Int
    var games_config: [GameConfig]
    
    // Ajout de profile_name pour correspondre à la colonne SQL
    var profile_name: String?
    
    enum CodingKeys: String, CodingKey {
        case id, number_of_cycles, initial_delay, break_delay, games_config, profile_name
    }
}

// --- 2. MODÈLES DE CONTENU (EXERCICES) ---
struct MathContent: Codable { let num1: Int; let num2: Int }
struct QuizContent: Codable { let text: String; let correctAnswer: String; let wrongAnswers: [String] }
struct WriteContent: Codable { let correct: String; let wrong: String }
struct LectureContent: Codable { let text: String }

struct ExerciseRow<T: Codable>: Codable { let content: T }

// --- 3. MODÈLES ADMIN ---
struct AdminContent: Codable {
    var num1: Int?
    var num2: Int?
    var text: String?
    var correct: String?
    var wrong: String?
    var correctAnswer: String?
    var wrongAnswers: [String]?
}

struct AdminExercise: Identifiable, Codable {
    let id: Int
    let type: String
    let destinataire: String
    let content: AdminContent
}

// --- 4. STRUCTURE D'INSERTION (ADMIN) ---
struct InsertPayload<T: Encodable>: Encodable {
    let type: String
    let destinataire: String
    let content: T
}

// --- 5. MODÈLES HISTORIQUE & STATISTIQUES ---
struct HistoryDetails: Codable {
    var text_read: String?
    var audio_url: String?
    var duration_seconds: Int?
    var score: Int?
    var total_questions: Int?
    var mistakes: Int?
    var exercise_summary: String?
}

struct HistoryItem: Identifiable, Codable {
    var id: Int
    var created_at: String
    var game_type: String
    var details: HistoryDetails
}

struct HistoryInsertPayload: Encodable {
    let game_type: String
    let child_name: String
    let details: HistoryDetails
}

// ==========================================
// MARK: - MANAGER PRINCIPAL
// ==========================================

class SupabaseManager {
    static let shared = SupabaseManager()
    let client: SupabaseClient
    
    // Profil Actif (Par défaut Arthur, mais modifiable via ProfileSelectionView)
    var currentProfile: String = "Arthur"
    
    private init() {
        let url = URL(string: "https://lomgelwpxlzynuogxsri.supabase.co")!
        let key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxvbWdlbHdweGx6eW51b2d4c3JpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjYyMTQ2MDgsImV4cCI6MjA4MTc5MDYwOH0.aUty5KjHdr0dJVH1ubEKqYz9D1M4u1w1LYhys7dr0Cg"
        self.client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    }
    
    // --- GESTION DES RÉGLAGES (MULTI-PROFILS) ---
    
    func fetchSettings() async throws -> AppSettings {
        // On filtre par profile_name pour charger la config du profil actif
        let response = try await client
            .from("game_app_settings")
            .select()
            .eq("profile_name", value: self.currentProfile)
            .limit(1)
            .execute()
        
        let settings = try JSONDecoder().decode([AppSettings].self, from: response.data)
        
        // Si aucune config, on renvoie un défaut
        return settings.first ?? AppSettings(
            number_of_cycles: 1,
            initial_delay: 20,
            break_delay: 10,
            games_config: [],
            profile_name: self.currentProfile
        )
    }
    
    func saveSettings(cycles: Int, initialDelay: Int, breakDelay: Int, games: [GameConfig]) async throws {
        // On inclut le profile_name dans l'objet à sauvegarder
        let updateData = AppSettings(
            id: nil,
            number_of_cycles: cycles,
            initial_delay: initialDelay,
            break_delay: breakDelay,
            games_config: games,
            profile_name: self.currentProfile
        )
        
        // On met à jour la ligne spécifique du profil actif
        try await client
            .from("game_app_settings")
            .update(updateData)
            .eq("profile_name", value: self.currentProfile)
            .execute()
    }
    
    // --- GESTION DU CONTENU (JEUX) ---
    
    func fetchMathContent() async throws -> [MathContent] {
        let response = try await client.from("game_exercise_library")
            .select("content")
            .eq("type", value: "math")
            .eq("destinataire", value: self.currentProfile)
            .execute()
        return try JSONDecoder().decode([ExerciseRow<MathContent>].self, from: response.data).map { $0.content }
    }
    
    func fetchQuizContent() async throws -> [QuizContent] {
        let response = try await client.from("game_exercise_library")
            .select("content")
            .eq("type", value: "quiz")
            .eq("destinataire", value: self.currentProfile)
            .execute()
        return try JSONDecoder().decode([ExerciseRow<QuizContent>].self, from: response.data).map { $0.content }
    }
    
    func fetchWriteContent() async throws -> [WriteContent] {
        let response = try await client.from("game_exercise_library")
            .select("content")
            .eq("type", value: "write")
            .eq("destinataire", value: self.currentProfile)
            .execute()
        return try JSONDecoder().decode([ExerciseRow<WriteContent>].self, from: response.data).map { $0.content }
    }
    
    func fetchLectureContent() async throws -> [LectureContent] {
        let response = try await client.from("game_exercise_library")
            .select("content")
            .eq("type", value: "lecture")
            .eq("destinataire", value: self.currentProfile)
            .execute()
        return try JSONDecoder().decode([ExerciseRow<LectureContent>].self, from: response.data).map { $0.content }
    }
    
    // --- GESTION ADMINISTRATION (PARENTS) ---
    
    func fetchAllAdminExercises() async throws -> [AdminExercise] {
        let response = try await client
            .from("game_exercise_library")
            .select()
            .eq("destinataire", value: self.currentProfile)
            .order("created_at", ascending: false)
            .execute()
        
        return try JSONDecoder().decode([AdminExercise].self, from: response.data)
    }
    
    func addExercise<T: Encodable>(type: String, content: T) async throws {
        let payload = InsertPayload(type: type, destinataire: self.currentProfile, content: content)
        try await client.from("game_exercise_library").insert(payload).execute()
    }
    
    func deleteExercise(id: Int) async throws {
        try await client.from("game_exercise_library").delete().eq("id", value: id).execute()
    }
    
    // --- GESTION HISTORIQUE (STATS) ---
    
    func saveHistory(type: String, details: HistoryDetails) {
        let payload = HistoryInsertPayload(game_type: type, child_name: self.currentProfile, details: details)
        
        Task {
            do {
                try await client.from("game_exercise_history").insert(payload).execute()
                print("✅ SUCCÈS : Historique sauvegardé pour \(self.currentProfile) (\(type))")
            } catch {
                print("❌ ERREUR CRITIQUE SAUVEGARDE HISTORIQUE : \(error)")
            }
        }
    }
    
    func fetchHistory() async throws -> [HistoryItem] {
        // --- CORRECTION : On filtre par le nom de l'enfant connecté ---
        let response = try await client
            .from("game_exercise_history")
            .select()
            .eq("child_name", value: self.currentProfile) // <--- ICI : Le filtre essentiel
            .order("created_at", ascending: false)
            .execute()
        
        return try JSONDecoder().decode([HistoryItem].self, from: response.data)
    }
    
    // --- GESTION EMAIL / MAKE ---
    func sendSessionReport() {
        guard let url = URL(string: "https://hook.eu1.make.com/votre_code_bizarre_ici") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let task = URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                print("❌ Erreur appel Make: \(error)")
            } else {
                print("📧 Signal envoyé à Make pour le rapport !")
            }
        }
        task.resume()
    }
}
