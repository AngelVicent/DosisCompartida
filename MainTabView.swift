import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HoyView()
                .tabItem { Label("Hoy", systemImage: "house.fill") }
            MedicinasView()
                .tabItem { Label("Medicinas", systemImage: "pills.fill") }
            VozView()
                .tabItem { Label("Notas", systemImage: "waveform") }
            AjustesView()
                .tabItem { Label("Ajustes", systemImage: "gearshape.fill") }
        }
    }
}

// MARK: - Pantalla Hoy

struct HoyView: View {
    @EnvironmentObject var app: AppState
    @State private var dosisSeleccionada: Dosis?

    private var alertas: [ItemInventario] {
        app.inventario.filter { $0.bajo }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(app.paciente.nombre)
                            .font(.title2.bold())
                        Text("\(app.paciente.edad) años · \(app.paciente.padecimientos)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Label("Alergia: \(app.paciente.alergias.joined(separator: ", "))",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    .padding(.vertical, 4)

                    Label("En turno: \(app.cuidador?.nombre ?? "")", systemImage: "person.fill.checkmark")
                }

                Section("Dosis de hoy") {
                    ForEach(app.dosis) { dosis in
                        FilaDosis(dosis: dosis) {
                            dosisSeleccionada = dosis
                        }
                    }
                }

                if !alertas.isEmpty {
                    Section("Alertas") {
                        ForEach(alertas) { item in
                            Label("Reponer \(item.nombre): quedan \(item.cantidad)",
                                  systemImage: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Hoy")
            .sheet(item: $dosisSeleccionada) { dosis in
                RegistrarDosisView(dosis: dosis)
            }
        }
    }
}

struct FilaDosis: View {
    let dosis: Dosis
    var alRegistrar: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dosis.hora)
                    .font(.headline)
                Text(dosis.medicamento)
                Text(dosis.indicacion)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()

            if dosis.estado == .pendiente {
                Button("Registrar", action: alRegistrar)
                    .buttonStyle(.borderedProminent)
            } else {
                Label("Registrada \(dosis.horaRegistro ?? "")", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
        }
    }
}

// MARK: - Registro de una dosis en tres pasos (RNF-06)

struct RegistrarDosisView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    let dosis: Dosis

    @State private var paso = 1
    @State private var verificando = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ProgressView(value: Double(paso), total: 3.0)
                    .tint(.teal)

                contenido

                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Paso \(paso) de 3")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var contenido: some View {
        switch paso {
        case 1:
            pasoVerificar
        case 2:
            pasoConfirmar
        default:
            pasoListo
        }
    }

    // Paso 1: verificación de la pastilla (RF-02, RF-03).
    // El reconocimiento visual real requiere un modelo de visión; aquí se simula.
    private var pasoVerificar: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.black.opacity(0.85))
                .frame(height: 260)
                .overlay {
                    Image(systemName: "pills.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.orange)
                }

            Text("Centra la pastilla dentro del marco")
                .font(.footnote)
                .foregroundColor(.secondary)

            VStack(spacing: 4) {
                Text("Esperado")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(dosis.medicamento) · \(dosis.indicacion)")
                    .font(.headline)
            }

            Button {
                verificando = true
                Task {
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    verificando = false
                    paso = 2
                }
            } label: {
                Text(verificando ? "Verificando..." : "Capturar y verificar")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(verificando)

            Text("Demostración: el reconocimiento visual es simulado.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // Paso 2: confirmar los datos (RF-04).
    private var pasoConfirmar: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Coincide con la dosis programada", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundColor(.green)

            LabeledContent("Medicamento", value: dosis.medicamento)
            LabeledContent("Dosis", value: dosis.indicacion)
            LabeledContent("Hora programada", value: dosis.hora)
            LabeledContent("Cuidador", value: app.cuidador?.nombre ?? "")

            Spacer()

            Button {
                app.registrarDosis(dosis.id)
                paso = 3
            } label: {
                Text("Registrar administración")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // Paso 3: confirmación.
    private var pasoListo: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 84))
                .foregroundColor(.green)

            Text("Administración registrada")
                .font(.title2.bold())

            Text("\(dosis.medicamento) · \(app.cuidador?.nombre ?? "") · \(app.horaActual())")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Label("Guardada en el teléfono", systemImage: "iphone")
                .font(.subheadline)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Volver al inicio")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}
