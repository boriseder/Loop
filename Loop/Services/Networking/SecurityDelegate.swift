//
//  SecurityDelegate.swift
//  Loop
//
//  Created by Boris Eder on 14.01.26.
//


//
//  SecurityDelegate.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import Foundation
import AVFoundation

final class SecurityDelegate: NSObject, AVAssetResourceLoaderDelegate, Sendable {
    
    // This method is called when AVPlayer encounters an authentication challenge (like a self-signed cert)
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForResponseTo authenticationChallenge: URLAuthenticationChallenge) -> Bool {
        
        // Check if the challenge is about Server Trust (SSL/TLS)
        if authenticationChallenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = authenticationChallenge.protectionSpace.serverTrust {
            
            // ✅ BLINDLY TRUST the certificate (Dev/Local only)
            authenticationChallenge.sender?.use(URLCredential(trust: trust), for: authenticationChallenge)
            return true
        }
        
        return false
    }
}