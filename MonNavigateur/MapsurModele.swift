import SwiftUI
import WebKit
import Combine

// On garde Int ici car la table 'favoris' est ancienne et utilise des IDs numériques.
struct Favori: Identifiable, Codable {
    var id: Int?
    var titre: String
    var url: String
}

// NOTE : Pas de struct ConfigSupabase ici, on utilise celle de Config.swift à la racine

class SupabaseManager {
    static func envoyerDonnees(table: String, donnees: [String: String]) {
        // Utilisation de Config.url
        guard let url = URL(string: "\(Config.url)/rest/v1/\(table)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Utilisation de Config.key
        request.addValue("Bearer \(Config.key)", forHTTPHeaderField: "Authorization")
        request.addValue(Config.key, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("return=minimal", forHTTPHeaderField: "Prefer")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: donnees, options: [])
        } catch { print("Erreur JSON: \(error)") }
        URLSession.shared.dataTask(with: request).resume()
    }

    static func recupererFavoris(completion: @escaping ([Favori]) -> Void) {
        guard let url = URL(string: "\(Config.url)/rest/v1/favoris?select=*&order=id.asc") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(Config.key)", forHTTPHeaderField: "Authorization")
        request.addValue(Config.key, forHTTPHeaderField: "apikey")
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data, let favoris = try? JSONDecoder().decode([Favori].self, from: data) {
                DispatchQueue.main.async { completion(favoris) }
            }
        }.resume()
    }
    
    static func mettreAJourFavori(id: Int, nouveauTitre: String) {
        guard let url = URL(string: "\(Config.url)/rest/v1/favoris?id=eq.\(id)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("Bearer \(Config.key)", forHTTPHeaderField: "Authorization")
        request.addValue(Config.key, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let donnees = ["titre": nouveauTitre]
        do { request.httpBody = try JSONSerialization.data(withJSONObject: donnees, options: []) } catch {}
        URLSession.shared.dataTask(with: request).resume()
    }

    static func supprimerFavori(id: Int) {
        guard let url = URL(string: "\(Config.url)/rest/v1/favoris?id=eq.\(id)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("Bearer \(Config.key)", forHTTPHeaderField: "Authorization")
        request.addValue(Config.key, forHTTPHeaderField: "apikey")
        URLSession.shared.dataTask(with: request).resume()
    }
}

class NavigateurModele: NSObject, ObservableObject {
    let webView: WKWebView = WKWebView()
    
    @Published var progression: Double = 0.0
    @Published var titrePage: String = "Nouvelle page"
    @Published var urlActuelle: String = ""
    @Published var listeFavoris: [Favori] = []
    
    private var observations: [NSKeyValueObservation] = []
    
    override init() {
        super.init()
        webView.navigationDelegate = self
        chargerLesFavoris()
        
        let obs1 = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            DispatchQueue.main.async { self?.progression = webView.estimatedProgress }
        }
        let obs2 = webView.observe(\.title, options: [.new]) { [weak self] webView, _ in
            DispatchQueue.main.async { self?.titrePage = webView.title ?? "Sans titre" }
        }
        let obs3 = webView.observe(\.url, options: [.new]) { [weak self] webView, _ in
            DispatchQueue.main.async { self?.urlActuelle = webView.url?.absoluteString ?? "" }
        }
        observations = [obs1, obs2, obs3]
    }
    
    func chargerLesFavoris() {
        SupabaseManager.recupererFavoris { [weak self] favorisRecus in
            self?.listeFavoris = favorisRecus
        }
    }
    
    func ajouterAuxFavoris() {
        var titreDirect = webView.title ?? ""
        let urlDirecte = webView.url?.absoluteString ?? ""
        
        titreDirect = titreDirect.trimmingCharacters(in: .whitespacesAndNewlines)
        if titreDirect.isEmpty { titreDirect = urlDirecte }
        if titreDirect.isEmpty { titreDirect = "Favori sans nom" }

        let donnees = ["titre": titreDirect, "url": urlDirecte]
        SupabaseManager.envoyerDonnees(table: "favoris", donnees: donnees)
        
        let nouveau = Favori(id: Int.random(in: 1000...9999), titre: titreDirect, url: urlDirecte)
        listeFavoris.append(nouveau)
    }
    
    func ajouterSection(titre: String) {
        let titreFinal = titre.uppercased()
        let donnees = ["titre": titreFinal, "url": ""]
        SupabaseManager.envoyerDonnees(table: "favoris", donnees: donnees)
        let nouveau = Favori(id: Int.random(in: 1000...9999), titre: titreFinal, url: "")
        listeFavoris.append(nouveau)
    }
    
    func renommerFavori(id: Int, nouveauTitre: String) {
        if let index = listeFavoris.firstIndex(where: { $0.id == id }) {
            listeFavoris[index].titre = nouveauTitre
        }
        SupabaseManager.mettreAJourFavori(id: id, nouveauTitre: nouveauTitre)
    }
    
    func supprimerFavori(id: Int) {
        if let index = listeFavoris.firstIndex(where: { $0.id == id }) {
            // Correction propre pour éviter le warning "Result of call to 'withAnimation' is unused"
            _ = withAnimation {
                listeFavoris.remove(at: index)
            }
        }
        SupabaseManager.supprimerFavori(id: id)
    }
    
    func allerSur(url: String) {
        if let link = URL(string: url) {
            webView.load(URLRequest(url: link))
        }
    }
    
    func deplacerFavori(item: Favori, versCible cible: Favori) {
        guard let fromIndex = listeFavoris.firstIndex(where: { $0.id == item.id }),
              let toIndex = listeFavoris.firstIndex(where: { $0.id == cible.id }) else { return }
        
        if fromIndex != toIndex {
            // Correction propre pour éviter le warning
            _ = withAnimation {
                let element = listeFavoris.remove(at: fromIndex)
                listeFavoris.insert(element, at: toIndex)
            }
        }
    }
}

extension NavigateurModele: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = webView.url?.absoluteString, !url.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let titre = webView.title ?? url
                let donnees = ["titre": titre, "url": url]
                SupabaseManager.envoyerDonnees(table: "historique", donnees: donnees)
            }
        }
    }
}
