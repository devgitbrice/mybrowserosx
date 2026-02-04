import SwiftUI

struct NoteToolbar: View {
    // États pour le micro
    @Binding var isRecording: Bool
    @Binding var isTranscribing: Bool
    
    // Actions
    var onBold: () -> Void
    var onItalic: () -> Void
    var onColor: () -> Void
    var onHighlight: () -> Void
    var onDictate: () -> Void
    var onClearFormatting: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            
            // GRAS
            ToolButton(icon: "bold", help: "Gras", action: onBold)
            
            // ITALIQUE
            ToolButton(icon: "italic", help: "Italique", action: onItalic)
            
            // COULEUR ROUGE
            ToolButton(icon: "paintbrush.fill", color: .red, help: "Texte Rouge", action: onColor)
            
            // SURLIGNAGE JAUNE
            ToolButton(icon: "highlighter", color: .yellow, help: "Surligner", action: onHighlight)
            
            Divider()
                .frame(height: 20)
                .padding(.horizontal, 4)

            // MICROPHONE (DICTÉE)
            Button(action: onDictate) {
                ZStack {
                    if isTranscribing {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: isRecording ? "mic.fill" : "mic")
                            .font(.system(size: 14))
                            .foregroundColor(isRecording ? .white : .indigo)
                    }
                }
                .padding(6)
                .background(isRecording ? Color.red : (isTranscribing ? Color.indigo.opacity(0.1) : Color.clear))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                // Animation de pulsation si enregistrement
                .scaleEffect(isRecording ? 1.1 : 1.0)
                .animation(isRecording ? Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: isRecording)
            }
            .buttonStyle(.plain)
            .help("Maintenir pour dicter")

            // NETTOYER FORMATAGE
            ToolButton(icon: "eraser", help: "Effacer le formatage", action: onClearFormatting)
        }
        .padding(4)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// Petit composant réutilisable pour les boutons simples
struct ToolButton: View {
    var icon: String
    var color: Color = .primary
    var help: String
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color == .primary ? .gray : color)
                .padding(6)
                .background(Color.white.opacity(0.01)) // Zone cliquable
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
