//
//  String+MD5.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import Foundation
import CryptoKit

extension String {
    /// Generates an MD5 hash of the string (required for Subsonic API tokens)
    var md5: String {
        guard let data = self.data(using: .utf8) else { return self }
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}
