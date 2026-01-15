//
//  AssetProvider.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import AVFoundation

protocol AssetProvider {
    /// Returns an AVAsset to play (either a local file or a remote URL)
    func asset(for songId: String) -> AVAsset?
}
