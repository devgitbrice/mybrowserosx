import SwiftUI
import Combine

// MARK: - Modele de message
struct ChatMessage: Identifiable {
    let id = UUID()
    let contenu: String
    let estUtilisateur: Bool
    let date = Date()
}

// MARK: - Enum pour le choix du modele IA
enum ModeleIA: String, CaseIterable {
    case chatgpt = "ChatGPT 5.2"
    case gemini = "Gemini 3 Pro"
}

// MARK: - Service API
class ChatbotService: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var enChargement = false

    private let cleChatGPT = Config.openAIKey
    private let cleGemini = Config.geminiKey

    func envoyerMessage(_ texte: String, modele: ModeleIA) {
        let messageUtilisateur = ChatMessage(contenu: texte, estUtilisateur: true)
        messages.append(messageUtilisateur)
        enChargement = true

        switch modele {
        case .chatgpt:
            appelChatGPT(texte)
        case .gemini:
            appelGemini(texte)
        }
    }

    private func appelChatGPT(_ texte: String) {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(cleChatGPT)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        var messagesAPI: [[String: String]] = [
            ["role": "system", "content": "Tu es un assistant utile et amical. Reponds en francais."]
        ]
        for msg in messages {
            messagesAPI.append([
                "role": msg.estUtilisateur ? "user" : "assistant",
                "content": msg.contenu
            ])
        }

        let body: [String: Any] = [
            "model": "gpt-4.1",
            "messages": messagesAPI,
            "max_tokens": 2048
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            ajouterReponse("Erreur de serialisation: \(error.localizedDescription)")
            return
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.enChargement = false

                if let error = error {
                    self?.ajouterReponse("Erreur reseau: \(error.localizedDescription)")
                    return
                }

                guard let data = data else {
                    self?.ajouterReponse("Pas de donnees recues.")
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let choices = json["choices"] as? [[String: Any]],
                           let premier = choices.first,
                           let message = premier["message"] as? [String: Any],
                           let contenu = message["content"] as? String {
                            self?.ajouterReponse(contenu)
                        } else if let erreur = json["error"] as? [String: Any],
                                  let msg = erreur["message"] as? String {
                            self?.ajouterReponse("Erreur API: \(msg)")
                        } else {
                            self?.ajouterReponse("Reponse inattendue du serveur.")
                        }
                    }
                } catch {
                    self?.ajouterReponse("Erreur de decodage: \(error.localizedDescription)")
                }
            }
        }.resume()
    }

    private func appelGemini(_ texte: String) {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro-preview-05-06:generateContent?key=\(cleGemini)") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        var contenus: [[String: Any]] = []
        for msg in messages {
            contenus.append([
                "role": msg.estUtilisateur ? "user" : "model",
                "parts": [["text": msg.contenu]]
            ])
        }

        let body: [String: Any] = [
            "contents": contenus
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            ajouterReponse("Erreur de serialisation: \(error.localizedDescription)")
            return
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.enChargement = false

                if let error = error {
                    self?.ajouterReponse("Erreur reseau: \(error.localizedDescription)")
                    return
                }

                guard let data = data else {
                    self?.ajouterReponse("Pas de donnees recues.")
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let candidates = json["candidates"] as? [[String: Any]],
                           let premier = candidates.first,
                           let content = premier["content"] as? [String: Any],
                           let parts = content["parts"] as? [[String: Any]],
                           let texte = parts.first?["text"] as? String {
                            self?.ajouterReponse(texte)
                        } else if let erreur = json["error"] as? [String: Any],
                                  let msg = erreur["message"] as? String {
                            self?.ajouterReponse("Erreur API: \(msg)")
                        } else {
                            self?.ajouterReponse("Reponse inattendue du serveur.")
                        }
                    }
                } catch {
                    self?.ajouterReponse("Erreur de decodage: \(error.localizedDescription)")
                }
            }
        }.resume()
    }

    private func ajouterReponse(_ texte: String) {
        let reponse = ChatMessage(contenu: texte, estUtilisateur: false)
        messages.append(reponse)
    }

    func effacerConversation() {
        messages.removeAll()
    }
}

// MARK: - En-tete du chatbot
struct ChatbotEnTete: View {
    let onEffacer: () -> Void
    let onFermer: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "cpu")
                .font(.title2)
                .foregroundColor(.cyan)
            Text("ROBOT")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Button(action: onEffacer) {
                Image(systemName: "trash").foregroundColor(.gray)
            }
            .buttonStyle(.plain)
            .help("Effacer la conversation")
            Button(action: onFermer) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.3))
    }
}

// MARK: - Selecteur de modele
struct ChatbotSelecteurModele: View {
    @Binding var modeleChoisi: ModeleIA
    let onChangement: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ModeleIA.allCases, id: \.self) { modele in
                boutonModele(modele)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func boutonModele(_ modele: ModeleIA) -> some View {
        let estActif = modeleChoisi == modele
        let icone = modele == .chatgpt ? "brain" : "sparkles"
        let couleurActive: Color = modele == .chatgpt ? .green : .cyan
        let fondActif: Color = modele == .chatgpt ? Color.green.opacity(0.3) : Color.blue.opacity(0.3)
        let bordureActive: Color = modele == .chatgpt ? Color.green.opacity(0.5) : Color.cyan.opacity(0.5)

        return Button(action: {
            modeleChoisi = modele
            onChangement()
        }) {
            HStack(spacing: 6) {
                Image(systemName: icone).font(.caption)
                Text(modele.rawValue).font(.caption).fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(estActif ? fondActif : Color.white.opacity(0.05))
            .foregroundColor(estActif ? couleurActive : .gray)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(estActif ? bordureActive : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Zone de messages
struct ChatbotMessagesZone: View {
    let messages: [ChatMessage]
    let enChargement: Bool
    let modeleChoisi: ModeleIA

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if messages.isEmpty {
                        placeholderVide
                    }
                    ForEach(messages) { message in
                        BulleMessage(message: message, modele: modeleChoisi)
                            .id(message.id)
                    }
                    if enChargement {
                        indicateurChargement
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: messages.count) { _ in
                withAnimation {
                    if let dernier = messages.last {
                        proxy.scrollTo(dernier.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var placeholderVide: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.4))
            Text("Posez une question a \(modeleChoisi.rawValue)")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var indicateurChargement: some View {
        HStack(spacing: 6) {
            ProgressView()
                .scaleEffect(0.7)
                .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
            Text("\(modeleChoisi.rawValue) reflechit...")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .id("chargement")
    }
}

// MARK: - Zone de saisie
struct ChatbotSaisie: View {
    @Binding var texteInput: String
    let enChargement: Bool
    let onEnvoyer: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField("Ecrivez votre message...", text: $texteInput)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
                .foregroundColor(.white)
                .onSubmit { onEnvoyer() }

            Button(action: onEnvoyer) {
                Image(systemName: "paperplane.fill")
                    .font(.title3)
                    .foregroundColor(texteInput.isEmpty ? .gray : .cyan)
                    .rotationEffect(.degrees(45))
            }
            .buttonStyle(.plain)
            .disabled(texteInput.isEmpty || enChargement)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Vue Chatbot principale
struct ChatbotView: View {
    @StateObject private var service = ChatbotService()
    @State private var texteInput = ""
    @State private var modeleChoisi: ModeleIA = .chatgpt
    @Binding var estVisible: Bool

    var body: some View {
        VStack(spacing: 0) {
            ChatbotEnTete(
                onEffacer: { service.effacerConversation() },
                onFermer: { withAnimation(.spring()) { estVisible = false } }
            )

            ChatbotSelecteurModele(
                modeleChoisi: $modeleChoisi,
                onChangement: { service.effacerConversation() }
            )

            Divider().background(Color.gray.opacity(0.3))

            ChatbotMessagesZone(
                messages: service.messages,
                enChargement: service.enChargement,
                modeleChoisi: modeleChoisi
            )

            Divider().background(Color.gray.opacity(0.3))

            ChatbotSaisie(
                texteInput: $texteInput,
                enChargement: service.enChargement,
                onEnvoyer: envoyerMessage
            )
        }
        #if os(macOS)
        .background(
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .overlay(Color.black.opacity(0.3))
        )
        #else
        .background(Color(white: 0.12))
        #endif
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
    }

    private func envoyerMessage() {
        let texte = texteInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !texte.isEmpty else { return }
        texteInput = ""
        service.envoyerMessage(texte, modele: modeleChoisi)
    }
}

// MARK: - Bulle de message
struct BulleMessage: View {
    let message: ChatMessage
    let modele: ModeleIA

    var body: some View {
        HStack {
            if message.estUtilisateur { Spacer(minLength: 40) }
            contenuBulle
            if !message.estUtilisateur { Spacer(minLength: 40) }
        }
    }

    private var contenuBulle: some View {
        let alignement: HorizontalAlignment = message.estUtilisateur ? .trailing : .leading
        return VStack(alignment: alignement, spacing: 4) {
            if !message.estUtilisateur {
                labelModele
            }
            texteBulle
        }
    }

    private var labelModele: some View {
        HStack(spacing: 4) {
            Image(systemName: modele == .chatgpt ? "brain" : "sparkles")
                .font(.caption2)
            Text(modele.rawValue)
                .font(.caption2)
        }
        .foregroundColor(.gray)
    }

    private var texteBulle: some View {
        let couleurFond: Color = message.estUtilisateur ? Color.cyan.opacity(0.25) : Color.white.opacity(0.08)
        return Text(message.contenu)
            .font(.body)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(couleurFond)
            .cornerRadius(14)
            .textSelection(.enabled)
    }
}
