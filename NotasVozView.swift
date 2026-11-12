import SwiftUI

// MARK: - Notas de voz (RF-06, RF-07)
// Los cuidadores dejan notas habladas sobre el paciente y las demás las escuchan.

struct VozView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var grabadora = GrabadoraVoz()
    @StateObject private var reproductor = ReproductorNotas()
    @State private var guardando = false
    @State private var errorGuardado: String?

    var body: some View {
        NavigationStack {
            List {
                if let error = app.errorDatos {
                    Section {
                        Label(error, systemImage: "wifi.exclamationmark")
                            .foregroundColor(.orange)
                    }
                }

                Section("Notas de \(app.paciente.nombre)") {
                    if app.notas.isEmpty {
                        Text("Aún no hay notas de voz.")
                            .foregroundColor(.secondary)
                    }
                    ForEach(app.notas) { nota in
                        FilaNota(
                            nota: nota,
                            sonando: reproductor.sonando == nota.id,
                            cargando: reproductor.cargando == nota.id
                        ) {
                            Task { await reproductor.alternar(nota, app: app) }
                        }
                    }
                }

                if let error = reproductor.error {
                    Section {
                        Text(error)
                            .font(.callout)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Notas de voz")
            .refreshable { await app.recargar() }
            .safeAreaInset(edge: .bottom) { controles }
        }
        .onDisappear { reproductor.detener() }
    }

    // MARK: Controles de grabación

    @ViewBuilder
    private var controles: some View {
        VStack(spacing: 10) {
            if let error = grabadora.error ?? errorGuardado {
                Text(error)
                    .font(.callout)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            switch grabadora.estado {
            case .reposo:
                Button {
                    reproductor.detener()
                    Task { await grabadora.empezar() }
                } label: {
                    Label("Grabar nota", systemImage: "mic.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            case .grabando:
                Button {
                    grabadora.detener()
                } label: {
                    Label("Detener · \(app.formatoDuracion(grabadora.segundos))", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)

            case .grabado(let archivo, let segundos):
                Text("Nota de \(app.formatoDuracion(segundos)) lista para guardar")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    Button("Descartar", role: .destructive) {
                        errorGuardado = nil
                        grabadora.descartar()
                    }
                    .buttonStyle(.bordered)
                    .disabled(guardando)

                    Button {
                        guardar(archivo, segundos)
                    } label: {
                        Text(guardando ? "Guardando..." : "Guardar nota")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(guardando)
                }
                .controlSize(.large)
            }
        }
        .padding()
        .background(.bar)
    }

    private func guardar(_ archivo: URL, _ segundos: Int) {
        guardando = true
        errorGuardado = nil
        Task {
            let fallo = await app.guardarNota(desde: archivo, segundos: segundos)
            guardando = false
            if let fallo {
                errorGuardado = fallo          // la grabación se conserva para reintentar
            } else {
                grabadora.descartar()
            }
        }
    }
}

struct FilaNota: View {
    let nota: NotaVoz
    let sonando: Bool
    let cargando: Bool
    var alAlternar: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: alAlternar) {
                if cargando {
                    ProgressView()
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: sonando ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title)
                        .foregroundColor(.teal)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(sonando ? "Detener nota" : "Reproducir nota")

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
