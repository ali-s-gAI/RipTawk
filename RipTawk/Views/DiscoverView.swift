//
//  DiscoverView.swift
//  RipTawk
//
//  Created by Zahad Ali Syed on 2/3/25.
//

import SwiftUI

struct DiscoverView: View {
    init() {
        // Debug: Print all available fonts
        for family in UIFont.familyNames.sorted() {
            print("👉 Font Family: \(family)")
            for name in UIFont.fontNames(forFamilyName: family) {
                print("   - \(name)")
            }
        }
        
        // Debug: Print bundle contents
        if let bundlePath = Bundle.main.resourcePath {
            print("\n📦 Bundle Contents:")
            do {
                let items = try FileManager.default.contentsOfDirectory(atPath: bundlePath)
                for item in items where item.contains("Mono") {
                    print("   - \(item)")
                }
            } catch {
                print("❌ Error reading bundle: \(error)")
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Let's also try the font directly to test
                Text("Direct Font Test")
                    .font(.custom("Mono-Regular", size: 20))
                    .foregroundColor(.blue)
                
                Text("Discover View Coming Soon")
                    .font(.appTitle())
                    .foregroundColor(.primary)
                
                Text("This is a headline")
                    .font(.appHeadline())
                    .foregroundColor(.secondary)
                
                Text("This is body text")
                    .font(.appBody())
                
                Text("This is caption text")
                    .font(.appCaption())
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Discover")
        }
    }
}

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
            TextField("Search", text: $text)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

struct TrendingVideo: Identifiable {
    let id = UUID()
    let title: String
    let creator: String
    let thumbnail: String
    let views: Int
}

struct TrendingVideoCell: View {
    let video: TrendingVideo
    
    var body: some View {
        VStack {
            Image(video.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 120)
                .cornerRadius(10)
            
            Text(video.title)
                .font(.headline)
                .lineLimit(2)
            
            Text(video.creator)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("\(video.views) views")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

