//
//  SearchView.swift
//  Loop
//
//  FIXED: Added filter picker for All/Albums/Artists/Genres
//

import SwiftUI

struct SearchView: View {
    @Environment(MusicEnvironment.self) private var music
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var results: SearchResults?
    @State private var isSearching = false
    
    // ✅ NEW: Filter picker
    @State private var searchFilter: SearchFilter = .all
    
    enum SearchFilter: String, CaseIterable {
        case all = "All"
        case albums = "Albums"
        case artists = "Artists"
        case songs = "Songs"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ✅ NEW: Filter Picker
                Picker("Filter", selection: $searchFilter) {
                    ForEach(SearchFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                ScrollView {
                    if searchText.isEmpty {
                        emptyStateView
                    } else if isSearching {
                        ProgressView()
                            .padding(.top, 40)
                    } else if let results = results {
                        resultsView(results)
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .searchable(text: $searchText, prompt: "Search albums, artists, songs...")
            .onChange(of: searchText) { _, newValue in
                Task {
                    await performSearch(query: newValue)
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        ContentUnavailableView(
            "Search Your Library",
            systemImage: "magnifyingglass",
            description: Text("Find albums, artists, and songs in your offline library")
        )
        .padding(.top, 60)
    }
    
    // MARK: - Results View
    
    @ViewBuilder
    private func resultsView(_ results: SearchResults) -> some View {
        let filtered = filteredResults(results)
        let isEmpty = filtered.songs.isEmpty && filtered.albums.isEmpty && filtered.artists.isEmpty
        
        if isEmpty {
            ContentUnavailableView.search(text: searchText)
                .padding(.top, 60)
        } else {
            LazyVStack(alignment: .leading, spacing: 24) {
                // ✅ FIXED: Filter based on picker
                if searchFilter == .all || searchFilter == .songs {
                    if !results.songs.isEmpty {
                        sectionHeader("Songs", count: results.songs.count)
                        LazyVStack(spacing: 0) {
                            ForEach(results.songs.prefix(20)) { song in
                                Button {
                                    dismiss()
                                    router.navigateToAlbum(song.albumId)
                                } label: {
                                    SongRow(song: song)
                                }
                                .buttonStyle(.plain)
                                Divider().padding(.leading, 60)
                            }
                        }
                    }
                }
                
                if searchFilter == .all || searchFilter == .albums {
                    if !results.albums.isEmpty {
                        sectionHeader("Albums", count: results.albums.count)
                        LazyVStack(spacing: 12) {
                            ForEach(results.albums.prefix(10)) { album in
                                Button {
                                    dismiss()
                                    router.navigateToAlbum(album.id)
                                } label: {
                                    AlbumRow(album: album)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                if searchFilter == .all || searchFilter == .artists {
                    if !results.artists.isEmpty {
                        sectionHeader("Artists", count: results.artists.count)
                        LazyVStack(spacing: 0) {
                            ForEach(results.artists.prefix(10)) { artist in
                                Button {
                                    dismiss()
                                    router.navigateToArtist(artist.id)
                                } label: {
                                    ArtistRow(artist: artist)
                                }
                                .buttonStyle(.plain)
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private func sectionHeader(_ title: String, count: Int) -> some View {
        Text(title)
            .font(.title2.bold())
            .padding(.horizontal)
            .padding(.top, 8)
    }
    
    private func filteredResults(_ results: SearchResults) -> (songs: [SongDTO], albums: [AlbumDTO], artists: [ArtistDTO]) {
        switch searchFilter {
        case .all:
            return (results.songs, results.albums, results.artists)
        case .songs:
            return (results.songs, [], [])
        case .albums:
            return ([], results.albums, [])
        case .artists:
            return ([], [], results.artists)
        }
    }
    
    // MARK: - Search Logic
    
    private func performSearch(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            results = nil
            return
        }
        
        isSearching = true
        
        do {
            try await Task.sleep(nanoseconds: 300_000_000)
            
            guard searchText == query else { return }
            
            let searchResults = try await music.search(query: trimmed)
            self.results = searchResults
        } catch {
            print("Search failed: \(error)")
        }
        
        isSearching = false
    }
}

// MARK: - Row Components

struct SongRow: View {
    let song: SongDTO
    @Environment(MusicEnvironment.self) private var music
    @State private var coverImage: UIImage?
    
    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let image = coverImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.secondary.opacity(0.1)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.body)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                
                HStack(spacing: 4) {
                    if let artist = song.artistName {
                        Text(artist)
                    }
                    Text("•")
                    if let album = song.albumTitle {
                        Text(album)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .task(id: song.coverArtId) {
            if let coverId = song.coverArtId {
                coverImage = await music.getCoverImage(for: coverId, size: 88)
            }
        }
    }
}

struct AlbumRow: View {
    let album: AlbumDTO
    @Environment(MusicEnvironment.self) private var music
    @State private var coverImage: UIImage?
    
    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let image = coverImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.secondary.opacity(0.1)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(album.title)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                
                HStack(spacing: 4) {
                    if let artist = album.artistName {
                        Text(artist)
                    }
                    if let year = album.year {
                        Text("•")
                        Text(String(year))
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
        .task(id: album.coverArtId) {
            if let coverId = album.coverArtId {
                coverImage = await music.getCoverImage(for: coverId, size: 120)
            }
        }
    }
}

struct ArtistRow: View {
    let artist: ArtistDTO
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "music.mic.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.accentColor.opacity(0.7))
            
            Text(artist.name)
                .font(.body)
                .foregroundStyle(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}
