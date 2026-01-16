//
//  LoginView.swift
//  Loop
//
//  Created by Boris Eder on 16.01.26.
//


//
//  LoginView.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import SwiftUI

struct LoginView: View {
    @Environment(AppContainer.self) private var container
    
    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Logo / Header
            VStack(spacing: 8) {
                Image(systemName: "infinity.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Color.accentColor)
                Text("Loop")
                    .font(.largeTitle.bold())
            }
            .padding(.bottom, 40)
            
            // Form Fields
            VStack(spacing: 16) {
                TextField("Server URL (e.g. https://music.com)", text: $serverURL)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(10)
                
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(10)
                
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            
            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
            
            Button {
                validateAndConnect()
            } label: {
                if isConnecting {
                    ProgressView()
                } else {
                    Text("Connect")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)
            .disabled(isConnecting || serverURL.isEmpty || username.isEmpty)
            
            Spacer()
        }
        .padding()
    }
    
    private func validateAndConnect() {
        // Basic validation
        var cleanURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanURL.hasSuffix("/") { cleanURL.removeLast() }
        if !cleanURL.hasPrefix("http") { cleanURL = "https://" + cleanURL }
        
        isConnecting = true
        errorMessage = nil
        
        // Save temporarily to container to test connection
        container.login(url: cleanURL, user: username, pass: password)
        
        // Test Ping
        Task {
            do {
                let _: SubsonicPingResponse = try await container.client.fetch("ping")
                // Success - AppContainer state is already Auth=true, UI will switch automatically
            } catch {
                container.logout() // Revert
                errorMessage = "Connection failed. Check your URL and credentials."
                isConnecting = false
            }
        }
    }
}

