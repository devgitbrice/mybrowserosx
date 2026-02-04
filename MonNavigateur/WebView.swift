import SwiftUI
import WebKit

// Ce fichier gère l'affichage du navigateur + swipe trackpad + raccourcis clavier
struct WebView: NSViewRepresentable {
    let webView: WKWebView

    func makeCoordinator() -> Coordinator {
        Coordinator(webView: webView)
    }

    func makeNSView(context: Context) -> WKWebView {
        // Active le swipe gauche/droite natif du trackpad pour naviguer
        webView.allowsBackForwardNavigationGestures = true
        context.coordinator.setupKeyboardMonitor()
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Rien à mettre à jour ici dynamiquement
    }

    class Coordinator {
        let webView: WKWebView
        var eventMonitor: Any?

        init(webView: WKWebView) {
            self.webView = webView
        }

        /// Vérifie si le WKWebView (ou une de ses sous-vues) est le premier répondeur
        private func isWebViewFocused() -> Bool {
            guard let firstResponder = webView.window?.firstResponder as? NSView else { return false }
            return firstResponder == webView || firstResponder.isDescendant(of: webView)
        }

        func setupKeyboardMonitor() {
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self,
                      event.modifierFlags.contains(.command),
                      self.isWebViewFocused() else { return event }

                switch event.charactersIgnoringModifiers?.lowercased() {
                case "r":
                    // Cmd+R → Rafraîchir la page
                    self.webView.reload()
                    return nil
                case "z":
                    // Cmd+Z → Annuler
                    NSApp.sendAction(Selector("undo:"), to: nil, from: nil)
                    return nil
                case "a":
                    // Cmd+A → Tout sélectionner
                    NSApp.sendAction(#selector(NSResponder.selectAll(_:)), to: nil, from: nil)
                    return nil
                case "c":
                    // Cmd+C → Copier
                    NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
                    return nil
                case "v":
                    // Cmd+V → Coller
                    NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
                    return nil
                default:
                    break
                }
                return event
            }
        }

        deinit {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}
