//
//  LoginView.swift
//  Loop
//
//  FIXED: Uses AuthEnvironment
//

import SwiftUI

struct LoginView: View {
    @Environment(AuthEnvironment.self) private var auth
    
    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isConnecting = false
    
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
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(10)
                
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
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
            
            if let error = auth.authError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button {
                Task { await validateAndConnect() }
            } label: {
                if isConnecting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Connect")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)
            .disabled(isConnecting || serverURL.isEmpty || username.isEmpty || password.isEmpty)
            
            Spacer()
        }
        .padding()
    }
    
    private func validateAndConnect() async {
        // Basic validation
        var cleanURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanURL.hasSuffix("/") {
            cleanURL.removeLast()
        }
        if !cleanURL.hasPrefix("http") {
            cleanURL = "https://" + cleanURL
        }
        
        isConnecting = true
        
        let credentials = Credentials(
            baseURL: cleanURL,
            username: username.trimmingCharacters(in: .whitespaces),
            password: password
        )
        
        await auth.login(credentials: credentials)
        
        isConnecting = false
    }
}
