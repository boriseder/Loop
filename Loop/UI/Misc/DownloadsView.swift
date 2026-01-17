//
//  DownloadsView.swift
//  Loop
//
//  FIXED: Removed nested NavigationStack & Fixed Preview
//

import SwiftUI

struct DownloadsView: View {
    @Environment(MusicEnvironment.self) private var music
    @Environment(DownloadEnvironment.self) private var downloads
    @Environment(Router.self) private var router
    
    @State private var downloadedAlbums: [AlbumDTO] = []
    @State private var totalSize: String = "Calculating..."
    @State private var isLoading = true
    @State private var showDeleteAlert = false
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 16)
    ]
    
    var body: some View {
        // ❌ REMOVED: NavigationStack (Inherits from LoopApp)
        ScrollView {
            if isLoading {
                ProgressView()
                    .padding(.top, 40)
            } else if downloadedAlbums.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 24) {
                    // Storage Info Card
                    storageInfoCard
                        .padding(.horizontal)
                        .padding(.top)
                    
                    // Downloaded Albums Grid
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(downloadedAlbums) { album in
                            NavigationLink(value: Router.Destination.albumDetail(albumId: album.id)) {
                                DownloadedAlbumCell(album: album)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteAlbum(album)
                                } label: {
                                    Label("Delete Download", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Downloads")
        .toolbar {
            if !downloadedAlbums.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .alert("Delete All Downloads?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                deleteAllDownloads()
            }
        } message: {
            Text("This will remove all offline music from your device. You can re-download albums anytime.")
        }
        .task {
            await loadDownloads()
        }
        .refreshable {
            await loadDownloads()
        }
    }
    
    // MARK: - Storage Info Card
    
    private var storageInfoCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Storage")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(totalSize)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Albums")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(downloadedAlbums.count)")
                        .font(.title2.bold())
                        .foregroundStyle(Color.accentColor)
                }
            }
            
            Divider()
            
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Available offline")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Downloads",
            systemImage: "arrow.down.circle",
            description: Text("Downloaded albums will appear here for offline listening")
        )
        .padding(.top, 60)
    }
    
    // MARK: - Data Loading
    
    private func loadDownloads() async {
        isLoading = true
        
        do {
            // Get all albums
            var allAlbums: [AlbumDTO] = []
            var offset = 0
            let pageSize = 500
            var hasMore = true
            
            while hasMore {
                let batch = try await music.getAlbums(offset: offset, limit: pageSize)
                allAlbums.append(contentsOf: batch)
                
                if batch.count < pageSize {
                    hasMore = false
                } else {
                    offset += pageSize
                }
            }
            
            // Filter for downloaded albums
            var downloaded: [AlbumDTO] = []
            
            for album in allAlbums {
                let songs = try await music.getSongs(for: album.id)
                let songIds = songs.map { $0.id }
                
                if downloads.isAlbumFullyDownloaded(songIds: songIds) {
                    downloaded.append(album)
                }
            }
            
            downloadedAlbums = downloaded
            
            // Calculate total size
            let fileManager = FileManager.default
            let musicDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Music")
            
            var totalBytes: Int64 = 0
            if let files = try? fileManager.contentsOfDirectory(at: musicDir, includingPropertiesForKeys: [.fileSizeKey]) {
                for file in files {
                    if let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                        totalBytes += Int64(size)
                    }
                }
            }
            
            totalSize = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
            
        } catch {
            print("Failed to load downloads: \(error)")
        }
        
        isLoading = false
    }
    
    private func deleteAlbum(_ album: AlbumDTO) {
        Task {
            do {
                let songs = try await music.getSongs(for: album.id)
                for song in songs {
                    downloads.deleteDownload(songId: song.id)
                }
                await loadDownloads()
            } catch {
                print("Failed to delete album: \(error)")
            }
        }
    }
    
    private func deleteAllDownloads() {
        Task {
            for album in downloadedAlbums {
                do {
                    let songs = try await music.getSongs(for: album.id)
                    for song in songs {
                        downloads.deleteDownload(songId: song.id)
                    }
                } catch {
                    print("Failed to delete album \(album.id): \(error)")
                }
            }
            await loadDownloads()
        }
    }
}

// MARK: - Downloaded Album Cell

struct DownloadedAlbumCell: View {
    let album: AlbumDTO
    @Environment(MusicEnvironment.self) private var music
    @State private var coverImage: UIImage?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let image = coverImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        ZStack {
                            Color.secondary.opacity(0.1)
                            Image(systemName: "music.note")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: 180, height: 180)
                
                // Downloaded badge
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .background(
                        Circle()
                            .fill(.green)
                            .frame(width: 24, height: 24)
                    )
                    .padding(8)
            }
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 4)
            
            Text(album.title)
                .font(.headline)
                .lineLimit(1)
                .foregroundStyle(.primary)
            
            Text(album.artistName ?? "Unknown")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .task(id: album.coverArtId) {
            if let coverId = album.coverArtId {
                coverImage = await music.getCoverImage(for: coverId, size: 360)
            }
        }
    }
}

// MARK: - Preview Logic
#Preview {
    let client = NavidromeClient()
    let db = MusicDatabase()
    let repo = MusicRepository(db: db)
    let coverCache = CoverArtCache(client: client)
    let downloadManager = DownloadManager(client: client)
    let syncManager = SyncManager(repo: repo, client: client, cache: coverCache)
    
    // ✅ FIXED: Correctly initializes MusicEnvironment (4 arguments)
    let musicEnv = MusicEnvironment(repo: repo, sync: syncManager, coverCache: coverCache, downloads: downloadManager)
    let downloadEnv = DownloadEnvironment(manager: downloadManager)
    let router = Router()
    
    return DownloadsView()
        .environment(musicEnv)
        .environment(downloadEnv)
        .environment(router)
}
