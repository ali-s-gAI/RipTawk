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
        // Set the tab bar appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
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
                    Label("Discover", systemImage: "magnifyingglass")
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
        .tint(.blue) // Set the tint color for selected items
    }
}

#Preview {
    MainTabView()
}

