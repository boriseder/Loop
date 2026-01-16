// AssetProvider.swift
import AVFoundation

// ✅ FIX: Added ': AnyObject' to allow weak references
protocol AssetProvider: AnyObject {
    /// Returns an AVAsset to play (either a local file or a remote URL)
    func asset(for songId: String) async -> AVAsset?
}
