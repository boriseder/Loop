import SwiftUI

struct PlayerView: View {
    @Bindable var audio: AudioEngine
    let cache: CoverArtCache
    @Binding var isPresented: Bool

    @State private var coverImage: UIImage?
    @State private var isSeeking = false
    @State private var seekPosition: Double = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [Color.white.opacity(0.8), Color.white],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top Bar
                    HStack {
                        Button { isPresented = false } label: {
                            Image(systemName: "chevron.down")
                                .font(.title2)
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        Text("Now Playing")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Color.clear.frame(width: 44, height: 44)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    Spacer()

                    // Cover Art
                    let coverSize = min(geometry.size.width, geometry.size.height) * 0.75
                    Group {
                        if let coverImage {
                            Image(uiImage: coverImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Color.secondary.opacity(0.2)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 60))
                                        .foregroundStyle(.secondary)
                                )
                        }
                    }
                    .frame(width: coverSize, height: coverSize)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)

                    Spacer()

                    // Song Info
                    VStack(spacing: 8) {
                        Text(audio.currentSong?.title ?? "Not Playing")
                            .font(.title2.bold())
                            .lineLimit(2)
                            .multilineTextAlignment(.center)

                        Text(audio.currentSong?.artistName ?? "")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        if let album = audio.currentSong?.albumTitle {
                            Text(album)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 20)

                    // Progress Slider
                    VStack(spacing: 8) {
                        Slider(
                            value: isSeeking ? $seekPosition : Binding(
                                get: { audio.progress },
                                set: { newValue in
                                    seekPosition = newValue
                                    isSeeking = true
                                }
                            ),
                            in: 0...max(audio.duration, 1),
                            onEditingChanged: { editing in
                                if !editing {
                                    Task {
                                        await audio.seekTo(seconds: seekPosition)
                                        isSeeking = false
                                    }
                                }
                            }
                        )
                        .tint(.primary)

                        HStack {
                            Text(formatTime(isSeeking ? seekPosition : audio.progress))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            Spacer()
                            Text(formatTime(audio.duration))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 20)

                    // Main Controls
                    HStack(spacing: 40) {
                        Button {
                            Task { await audio.skipToPrevious() }
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.primary)
                        }

                        Button {
                            audio.togglePlayPause()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.primary)
                                    .frame(width: 75, height: 75)
                                Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(Color(uiColor: .systemBackground))
                                    .offset(x: audio.isPlaying ? 0 : 2)
                            }
                        }

                        Button {
                            Task { await audio.skipToNext() }
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(.top, 20)

                    // Secondary Controls — Shuffle & Repeat (now functional)
                    HStack(spacing: 50) {
                        // Shuffle
                        Button {
                            Task { await audio.toggleShuffle() }
                        } label: {
                            Image(systemName: "shuffle")
                                .font(.title3)
                                .foregroundStyle(audio.isShuffled ? Color.accentColor : .secondary)
                                .overlay(alignment: .bottom) {
                                    // Active dot indicator
                                    if audio.isShuffled {
                                        Circle()
                                            .fill(Color.accentColor)
                                            .frame(width: 4, height: 4)
                                            .offset(y: 8)
                                    }
                                }
                        }

                        Spacer()

                        // Repeat
                        Button {
                            Task { await audio.cycleRepeatMode() }
                        } label: {
                            Image(systemName: audio.repeatMode.systemImageName)
                                .font(.title3)
                                .foregroundStyle(audio.repeatMode.isActive ? Color.accentColor : .secondary)
                                .overlay(alignment: .bottom) {
                                    if audio.repeatMode.isActive {
                                        Circle()
                                            .fill(Color.accentColor)
                                            .frame(width: 4, height: 4)
                                            .offset(y: 8)
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 60)
                    .padding(.top, 25)
                    .padding(.bottom, 30)
                }
            }
        }
        .task(id: audio.currentSong?.coverArtId) {
            if let coverArtId = audio.currentSong?.coverArtId {
                coverImage = await cache.image(for: coverArtId, size: 800)
            } else {
                coverImage = nil
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
