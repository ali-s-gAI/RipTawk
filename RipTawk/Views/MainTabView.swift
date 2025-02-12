//
//  MainTabView.swift
//  RipTawk
//
//  Created by Zahad Ali Syed on 2/3/25.
//

import SwiftUI
import UIKit

struct MainTabView: View {
    @State private var selectedTab = 0
    
    init() {
        // Set the tab bar appearance with brand color
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor(Color.brandBackground)
        
        // Configure selected item appearance
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.brandPrimary)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Color.brandPrimary)
        ]
        
        // Configure unselected item appearance
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color.brandSecondary)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(Color.brandSecondary)
        ]
        
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().standardAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            FeedView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            DiscoverView()
                .tabItem {
                    Label("Discover", systemImage: "sparkles")
                }
                .tag(1)
            
            CreateView()
                .tabItem {
                    Label("Create", systemImage: "plus.circle.fill")
                }
                .tag(2)
            
            VideosView()
                .tabItem {
                    Label("Projects", systemImage: "film")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .tint(Color.brandPrimary) // Set the tint color for selected items
        .onAppear {
            print(" [AUTH] MainTabView appeared - verifying authentication...")
            Task {
                do {
                    try await AppwriteService.shared.initializeSession()
                    print(" [AUTH] MainTabView - Session verified")
                } catch {
                    print(" [AUTH] MainTabView - Invalid session, posting sign out notification")
                    NotificationCenter.default.post(name: .userDidSignOut, object: nil)
                }
            }
        }
    }
}

#Preview {
    MainTabView()
}
