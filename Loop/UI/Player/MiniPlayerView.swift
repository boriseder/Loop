import SwiftUI

struct MiniPlayerView: View {
    let audio: AudioEngine
    @State private var isExpanded = false
    
    var body: some View {
        VStack {
            HStack(spacing: 12) {
                // We'd ideally fetch cover here too, but for mini player let's keep it simple
                Image(systemName: "music.note")
                    .frame(width: 44, height: 44)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                
                VStack(alignment: .leading) {
                    Text(audio.currentSong?.title ?? "Not Playing")
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    Text(audio.currentSong?.artistName ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button {
                    audio.togglePlayPause()
                } label: {
                    Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                .padding(.trailing, 8)
            }
            .padding(12)
            .background(Material.regular)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 5)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .onTapGesture {
                isExpanded = true
            }
        }
        // NOTE: In a real app, you would pass dependencies for the full player
        // For this refactor, we are focusing on the architecture separation
        .sheet(isPresented: $isExpanded) {
            // We need to access the AppContainer's cache here.
            // In a strict refactor, we pass it down.
            // Placeholder:
            Text("Full Player requires cache injection")
        }
    }
}
