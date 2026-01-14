import AVFoundation

protocol AssetProvider {
    func asset(for songId: String) -> AVURLAsset?
    func isAvailable(songId: String) -> Bool
}
