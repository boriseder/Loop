// AssetProvider.swift
import AVFoundation

protocol AssetProvider {
    /// Returns an AVAsset to play (either a local file or a remote URL)
    func asset(for songId: String) async -> AVAsset?
}
