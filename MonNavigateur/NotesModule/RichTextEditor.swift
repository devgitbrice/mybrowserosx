import SwiftUI
import AppKit

struct RichTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var dynamicHeight: CGFloat
    
    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        
        // --- CONFIGURATION VISUELLE ---
        textView.isRichText = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.backgroundColor = .clear
        
        // Curseur et Texte en BLANC pour le fond sombre
        textView.textColor = .white
        textView.insertionPointColor = .white // <--- IMPORTANT : Curseur blanc
        textView.font = .systemFont(ofSize: 16)
        
        // --- CONFIGURATION LAYOUT ---
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 5, height: 10)
        
        if let container = textView.textContainer {
            container.widthTracksTextView = true
        }
        
        textView.delegate = context.coordinator
        return textView
    }
    
    func updateNSView(_ nsView: NSTextView, context: Context) {
        // Nettoyage préalable des artefacts de l'IA
        let cleanedText = cleanHTML(text)
        
        // On ne met à jour que si le texte a VRAIMENT changé depuis l'extérieur
        // (pour éviter la boucle infinie quand c'est toi qui tapes)
        if cleanedText != context.coordinator.lastText {
            
            // 1. SAUVEGARDE DU CURSEUR (La position actuelle)
            let selectedRanges = nsView.selectedRanges
            
            // 2. MISE À JOUR DU TEXTE
            if let data = cleanedText.data(using: .utf8) {
                if let attributedString = try? NSAttributedString(
                    data: data,
                    options: [
                        .documentType: NSAttributedString.DocumentType.html,
                        .characterEncoding: String.Encoding.utf8.rawValue
                    ],
                    documentAttributes: nil
                ) {
                    let mutableString = NSMutableAttributedString(attributedString: attributedString)
                    let fullRange = NSRange(location: 0, length: mutableString.length)
                    
                    // On force le style blanc
                    mutableString.addAttributes([
                        .foregroundColor: NSColor.white,
                        .font: NSFont.systemFont(ofSize: 16)
                    ], range: fullRange)
                    
                    nsView.textStorage?.setAttributedString(mutableString)
                }
            } else {
                nsView.string = cleanedText
            }
            
            // 3. RESTAURATION DU CURSEUR
            // On vérifie que le curseur n'est pas hors limites (si le texte a raccourci)
            if let firstRange = selectedRanges.first as? NSRange {
                let length = nsView.string.count
                if firstRange.location <= length {
                    nsView.selectedRanges = selectedRanges
                } else {
                    // Si hors limite, on met à la fin
                    nsView.setSelectedRange(NSRange(location: length, length: 0))
                }
            }
            
            context.coordinator.lastText = cleanedText
            context.coordinator.recalculateHeight(for: nsView)
        }
    }
    
    // Fonction de nettoyage des balises parasites
    private func cleanHTML(_ raw: String) -> String {
        return raw
            .replacingOccurrences(of: "```html", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditor
        var lastText: String = ""
        
        init(_ parent: RichTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // Conversion en HTML pour la sauvegarde
            if let attrString = textView.textStorage {
                do {
                    let htmlData = try attrString.data(
                        from: NSRange(location: 0, length: attrString.length),
                        documentAttributes: [.documentType: NSAttributedString.DocumentType.html]
                    )
                    
                    if let htmlString = String(data: htmlData, encoding: .utf8) {
                        // On évite de renvoyer si c'est identique (optimisation)
                        if self.lastText != htmlString {
                            self.lastText = htmlString
                            // Mise à jour du Binding SwiftUI
                            self.parent.text = htmlString
                        }
                    }
                } catch {
                    print("Erreur export HTML: \(error)")
                }
            }
            
            recalculateHeight(for: textView)
        }
        
        func recalculateHeight(for textView: NSTextView) {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }
            
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            let newHeight = usedRect.height + 40
            
            if abs(parent.dynamicHeight - newHeight) > 2 {
                DispatchQueue.main.async {
                    self.parent.dynamicHeight = newHeight
                }
            }
        }
    }
}
