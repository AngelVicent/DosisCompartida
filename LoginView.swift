import SwiftUI

struct LoginView: View {
    @EnvironmentObject var app: AppState
    @State private var correo = ""
    @State private var password = ""
    @State private var mostrarAjustes = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.teal.opacity(0.15))
                    .frame(width: 96, height: 96)
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 42))
                    .foregroundColor(.teal)
            }

            Text("Dosis Compartida")
                .font(.largeTitle.bold())
            Text("Coordinación de medicamentos")
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                TextField("Correo electrónico", text: $correo)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                SecureField("Contraseña", text: $password)
                    .textContentType(.password)
                    .padding(14)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }

            if let error = app.errorLogin {
                Text(error)
                    .font(.callout)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await app.iniciarSesion(correo: correo, password: password) }
            } label: {
                if app.cargando {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Iniciar sesión")
                        .bold()
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(app.cargando || correo.isEmpty || password.isEmpty)

            if app.demoMode {
                Text("Modo demostración: \(DemoData.correoDemo) / \(DemoData.passwordDemo)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Configurar servidor") {
                mostrarAjustes = true
            }
            .font(.subheadline)
        }
        .padding(24)
        .sheet(isPresented: $mostrarAjustes) {
            AjustesView()
        }
    }
}
