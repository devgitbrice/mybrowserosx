import SwiftUI
import WebKit

// Ce fichier gère uniquement l'affichage technique du navigateur
struct WebView: NSViewRepresentable {
    let webView: WKWebView
    
    func makeNSView(context: Context) -> WKWebView {
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Rien à mettre à jour ici dynamiquement
    }
}
