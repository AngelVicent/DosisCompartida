import SwiftUI

// MARK: - Inventario y reposición (RF-08, RF-09)

struct MedicinasView: View {
    @EnvironmentObject var app: AppState
    @State private var itemParaReponer: ItemInventario?

    var body: some View {
        NavigationStack {
            List {
                if let error = app.errorDatos {
                    Section {
                        Label(error, systemImage: "wifi.exclamationmark")
                            .foregroundColor(.orange)
                    }
                }

                Section("Inventario") {
                    ForEach(app.inventario) { item in
                        FilaInventario(
                            item: item,
                            alEnviar: { Task { await app.enviarAFarmacia(item.id) } },
                            alReponer: { itemParaReponer = item }
                        )
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
            .refreshable { await app.recargar() }
            .sheet(item: $itemParaReponer) { item in
                ReposicionView(item: item)
            }
        }
    }
}

struct FilaInventario: View {
    let item: ItemInventario
    var alEnviar: () -> Void
    var alReponer: () -> Void

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

            Button("Registrar reposición", action: alReponer)
                .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Reposición: se registran las pastillas que llegaron de la farmacia

struct ReposicionView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    let item: ItemInventario

    @State private var cantidad = 10
    @State private var error: String?
    @State private var guardando = false

    var body: some View {
        NavigationStack {
            Form {
                Section(item.nombre) {
                    Text("Existencias actuales: \(item.cantidad) · umbral \(item.umbral)")
                    Stepper("Cantidad recibida: \(cantidad)", value: $cantidad, in: 1...1000)
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button(guardando ? "Guardando..." : "Registrar reposición") {
                        guardando = true
                        error = nil
                        Task {
                            let fallo = await app.reponer(item.id, cantidad: cantidad)
                            guardando = false
                            if let fallo {
                                error = fallo
                            } else {
                                dismiss()
                            }
                        }
                    }
                    .disabled(guardando)
                }
            }
            .navigationTitle("Reposición")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Ajustes y cuenta

struct AjustesView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var confirmarRestablecer = false

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

                Section("Recordatorios") {
                    Toggle("Recordar cada dosis", isOn: $app.recordatorios)
                    Text("Aviso a la hora de la dosis y otro \(Dosis.toleranciaMinutos) minutos después si sigue pendiente. Si no llegan, revisa Ajustes del iPhone > Notificaciones.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Button("Enviar recordatorio de prueba") {
                        Task { await app.enviarRecordatorioDePrueba() }
                    }
                }

                Section("Servidor") {
                    TextField("http://192.168.1.20:3000", text: $app.serverURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(app.demoMode)
                }

                Section("Datos") {
                    Button("Restablecer datos de demostración", role: .destructive) {
                        confirmarRestablecer = true
                    }
                    Text("Borra las dosis registradas y el historial, y vuelve a los datos de ejemplo.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
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
            .confirmationDialog("¿Restablecer los datos de demostración?",
                                isPresented: $confirmarRestablecer,
                                titleVisibility: .visible) {
                Button("Restablecer", role: .destructive) { app.restablecerDatosDemo() }
                Button("Cancelar", role: .cancel) { }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }
}
