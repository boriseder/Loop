import SwiftUI

struct LoginView: View {
    @Bindable var auth: AuthenticationService
    
    @State private var url = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isBusy = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Loop").font(.largeTitle.bold())
            
            TextField("Server URL", text: $url)
                .textContentType(.URL)
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
            
            if let error = auth.authError {
                Text(error).foregroundStyle(.red).font(.caption)
            }
            
            Button("Connect") {
                isBusy = true
                Task {
                    let creds = Credentials(baseURL: url, username: username, password: password)
                    await auth.login(credentials: creds)
                    isBusy = false
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isBusy || url.isEmpty || username.isEmpty || password.isEmpty)
        }
        .padding()
    }
}
