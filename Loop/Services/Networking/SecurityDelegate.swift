//
//  SecurityDelegate.swift
//  Loop
//
//  Fixed: Certificate validation is now enforced in Release builds.
//

import Foundation
import AVFoundation

final class SecurityDelegate: NSObject, AVAssetResourceLoaderDelegate, Sendable {
    
    // This method is called when AVPlayer encounters an authentication challenge (like a self-signed cert)
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForResponseTo authenticationChallenge: URLAuthenticationChallenge) -> Bool {
        
        // Only allow self-signed certs in DEBUG mode
        #if DEBUG
        if authenticationChallenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = authenticationChallenge.protectionSpace.serverTrust {
            
            // ✅ BLINDLY TRUST the certificate (Dev/Local only)
            authenticationChallenge.sender?.use(URLCredential(trust: trust), for: authenticationChallenge)
            return true
        }
        #endif
        
        // In Release, we fall through to default handling (which rejects invalid certs)
        return false
    }
}
