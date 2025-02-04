//
//  DiscoverView.swift
//  RipTawk
//
//  Created by Zahad Ali Syed on 2/3/25.
//

import SwiftUI

struct DiscoverView: View {
    @State private var searchText = ""
    @State private var trendingVideos: [TrendingVideo] = []

    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText)
                
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(trendingVideos) { video in
                            TrendingVideoCell(video: video)
                        }
                    }
                    .padding()
                }
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

