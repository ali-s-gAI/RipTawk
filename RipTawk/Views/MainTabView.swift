//
//  MainTabView.swift
//  RipTawk
//
//  Created by Zahad Ali Syed on 2/3/25.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            FeedView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            
            DiscoverView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Discover")
                }
                .tag(1)
            
            RecordUploadView()
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("Create")
                }
                .tag(2)
            
            VideosView()
                .tabItem {
                    Image(systemName: "film")
                    Text("Projects")
                }
                .tag(3)
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(4)
        }
    }
}

