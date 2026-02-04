//
//  ContentView.swift
//  Kidsbrowser
//
//  Created by BriceM4 on 16/01/2026.
//

import SwiftUI
import WebKit
import UserNotifications

// --- 1. HELPER WEBVIEW UNIVERSEL ---
#if os(macOS)
import AppKit
typealias ViewRepresentable = NSViewRepresentable
#else
import UIKit
typealias ViewRepresentable = UIViewRepresentable
#endif

struct WebView: ViewRepresentable {
    let url: URL
    func makeWebView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        #if os(iOS)
        webView.scrollView.bounces = false
        #endif
        return webView
    }
    func updateWebView(_ webView: WKWebView, context: Context) {
        if let currentURL = webView.url, currentURL == url { return }
        let request = URLRequest(url: url)
        webView.load(request)
    }
    #if os(iOS)
    func makeUIView(context: Context) -> WKWebView { return makeWebView(context: context) }
    func updateUIView(_ uiView: WKWebView, context: Context) { updateWebView(uiView, context: context) }
    #endif
    #if os(macOS)
    func makeNSView(context: Context) -> WKWebView { return makeWebView(context: context) }
    func updateNSView(_ nsView: WKWebView, context: Context) { updateWebView(nsView, context: context) }
    #endif
}

// --- 2. TYPES ---
enum MenuDestination: Hashable {
    case web(url: String)
    case quiz
    case write
    case math
    case lecture
}

struct MenuItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let type: MenuDestination
    let color: Color
    let icon: String
}

// --- 3. VUE PRINCIPALE ---
struct ContentView: View {
    @Environment(\.dismiss) var dismiss
    
    let webItems = [
        MenuItem(name: "YouTube", type: .web(url: "https://www.youtube.com"), color: .red, icon: "play.rectangle.fill"),
        MenuItem(name: "Netflix", type: .web(url: "https://www.netflix.com"), color: .black, icon: "tv.fill")
    ]
    
    let gameItems = [
        MenuItem(name: "Orthographe (Quiz)", type: .quiz, color: .purple, icon: "pencil.and.scribble"),
        MenuItem(name: "Écriture (Clavier)", type: .write, color: .indigo, icon: "keyboard"),
        MenuItem(name: "Mathématiques", type: .math, color: .orange, icon: "number.circle.fill"),
        MenuItem(name: "Lecture", type: .lecture, color: .blue, icon: "mic.fill")
    ]
    
    @State private var navigationPath = NavigationPath()
    @State private var isMonitoringActive = false
    @State private var showSettingsModal = false
    
    // --- NOUVELLE VARIABLE POUR L'ALERTE ---
    @State private var showComeHereAlert = false
    
    var body: some View {
        // On englobe tout dans un ZStack pour pouvoir afficher l'alerte par-dessus
        ZStack {
            
            TimeManager(isMonitoring: $isMonitoringActive) {
                NavigationStack(path: $navigationPath) {
                    HomeView(
                        webItems: webItems,
                        gameItems: gameItems,
                        onSelect: { selectedItem in
                            navigationPath.append(selectedItem)
                        },
                        onSettings: {
                            showSettingsModal = true
                        }
                    )
                    .navigationTitle("Kids Browser")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: {
                                isMonitoringActive = false
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.left.circle.fill")
                                    Text("Changer de profil")
                                }
                                .foregroundColor(.blue)
                            }
                        }
                    }
                    .navigationDestination(for: MenuItem.self) { item in
                        Group {
                            switch item.type {
                            case .web(let urlString):
                                WebView(url: URL(string: urlString)!)
                                    .onAppear { isMonitoringActive = true }
                            case .quiz:
                                GameView(onUnlock: { returnToHome() })
                                    .onAppear { isMonitoringActive = false }
                            case .write:
                                WriteGameView(onFinished: { returnToHome() })
                                    .onAppear { isMonitoringActive = false }
                            case .math:
                                SuperMaths(onFinished: { returnToHome() })
                                    .onAppear { isMonitoringActive = false }
                            case .lecture:
                                LectureGameView(isTrainingMode: true, onFinished: { returnToHome() })
                                    .onAppear { isMonitoringActive = false }
                            }
                        }
                        .navigationBarTitleDisplayMode(.inline)
                    }
                }
                .fullScreenCover(isPresented: $showSettingsModal) {
                    // On passe la variable d'alerte au GateView (qui la passera aux réglages)
                    ParentGateView(triggerAlert: $showComeHereAlert)
                }
                // --- COMPATIBILITÉ iOS 16 ---
                .onChange(of: navigationPath) { newPath in
                    if newPath.isEmpty { isMonitoringActive = false }
                }
            }
            
            // --- ÉCRAN D'ALERTE "VENEZ ICI" ---
            if showComeHereAlert {
                Color.black.edgesIgnoringSafeArea(.all)
                    .overlay(
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.yellow)
                            
                            Text("VENEZ ICI\nTOUT DE SUITE !")
                                .font(.system(size: 50, weight: .black))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        }
                    )
                    .zIndex(999) // S'assure d'être au-dessus de tout
            }
        }
        .onAppear { requestNotificationPermission() }
    }
    
    func returnToHome() {
        navigationPath = NavigationPath()
        isMonitoringActive = false
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }
}
