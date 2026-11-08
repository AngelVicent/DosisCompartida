import SwiftUI

// MARK: - Inventario y reposición (RF-08, RF-09)

struct MedicinasView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        NavigationStack {
            List {
                Section("Inventario") {
                    ForEach(app.inventario) { item in
                        FilaInventario(item: item) {
                            app.enviarAFarmacia(item.id)
                        }
                    }
                }

                Section("Farmacia registrada") {
                    Label("Farmacia San José", systemImage: "cross.fill")
                    Text("Canal: correo electrónico")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Medicinas")
        }
    }
}

struct FilaInventario: View {
    let item: ItemInventario
    var alEnviar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.nombre)
                    .font(.headline)
                Spacer()
                if item.bajo {
                    Text("Bajo")
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15), in: Capsule())
                }
            }

            ProgressView(value: Double(item.cantidad), total: Double(max(item.umbral * 2, 1)))
                .tint(item.bajo ? .orange : .teal)

            Text("\(item.cantidad) disponibles · umbral \(item.umbral)")
                .font(.caption)
                .foregroundColor(.secondary)

            if item.bajo {
                if item.enviadoAFarmacia {
                    Label("Enviado a la farmacia", systemImage: "paperplane.fill")
                        .font(.subheadline)
                        .foregroundColor(.green)
                } else {
                    Button("Enviar a farmacia", action: alEnviar)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Notas de voz (RF-06, RF-07)

struct VozView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        NavigationStack {
            List {
                Section("Notas de \(app.paciente.nombre)") {
                    ForEach(app.notas) { nota in
                        HStack(spacing: 12) {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundColor(.teal)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(nota.fecha)
                                    .font(.headline)
                                Text(nota.autor)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(nota.duracion)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .navigationTitle("Notas de voz")
            .safeAreaInset(edge: .bottom) {
                Button {
                    // Grabación pendiente de implementar.
                } label: {
                    Label("Grabar nota (próximamente)", systemImage: "mic.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(true)
                .padding()
            }
        }
    }
}

// MARK: - Ajustes y cuenta

struct AjustesView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Modo demostración", isOn: $app.demoMode)
                    Text(app.demoMode
                         ? "Usa datos de ejemplo. No necesita servidor."
                         : "Inicia sesión contra tu servidor de la API.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section("Servidor") {
                    TextField("http://192.168.1.20:3000", text: $app.serverURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(app.demoMode)
                }

                if let cuidador = app.cuidador {
                    Section("Cuenta") {
                        LabeledContent("Cuidador", value: cuidador.nombre)
                        Button("Cerrar sesión", role: .destructive) {
                            app.cerrarSesion()
                        }
                    }
                }
            }
            .navigationTitle("Ajustes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }
}
