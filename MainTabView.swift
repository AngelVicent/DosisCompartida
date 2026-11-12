import SwiftUI
import UIKit

struct MainTabView: View {
    var body: some View {
        TabView {
            HoyView()
                .tabItem { Label("Hoy", systemImage: "house.fill") }
            MedicinasView()
                .tabItem { Label("Medicinas", systemImage: "pills.fill") }
            HistorialView()
                .tabItem { Label("Historial", systemImage: "clock.arrow.circlepath") }
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
    @State private var ahora = Date()

    private var alertas: [ItemInventario] {
        app.inventario.filter { $0.bajo }
    }

    private var atrasadas: [Dosis] {
        app.dosis.filter { $0.atrasada(ahora: ahora) }
    }

    var body: some View {
        NavigationStack {
            List {
                if let error = app.errorDatos {
                    Section {
                        Label(error, systemImage: "wifi.exclamationmark")
                            .foregroundColor(.orange)
                        Button("Reintentar") {
                            Task { await app.recargar() }
                        }
                    }
                }

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
                        FilaDosis(dosis: dosis, atrasada: dosis.atrasada(ahora: ahora)) {
                            dosisSeleccionada = dosis
                        }
                    }
                }

                if !atrasadas.isEmpty {
                    Section("Dosis atrasadas") {
                        ForEach(atrasadas) { dosis in
                            Label("\(dosis.medicamento): estaba programada a las \(dosis.hora)",
                                  systemImage: "clock.badge.exclamationmark.fill")
                                .foregroundColor(.red)
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
            .refreshable { await app.recargar() }
            // Refresca cada 30 s para que "atrasada" aparezca sin salir de la pantalla.
            .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { fecha in
                ahora = fecha
            }
            .sheet(item: $dosisSeleccionada) { dosis in
                RegistrarDosisView(dosis: dosis)
            }
        }
    }
}

struct FilaDosis: View {
    let dosis: Dosis
    let atrasada: Bool
    var alRegistrar: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dosis.hora)
                    .font(.headline)
                    .foregroundColor(atrasada ? .red : .primary)
                Text(dosis.medicamento)
                Text(dosis.indicacion)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()

            if dosis.estado == .pendiente {
                VStack(alignment: .trailing, spacing: 4) {
                    if atrasada {
                        Text("Atrasada")
                            .font(.caption.bold())
                            .foregroundColor(.red)
                    }
                    Button("Registrar", action: alRegistrar)
                        .buttonStyle(.borderedProminent)
                        .tint(atrasada ? .red : .accentColor)
                }
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
    @State private var mostrandoSelector = false
    @State private var fuenteSelector: UIImagePickerController.SourceType = .camera
    @State private var analizando = false
    @State private var resultado: ResultadoVerificacion?
    @State private var textoLeido: [String] = []
    @State private var verificacion = "omitida"     // "coincide", "no_coincide" u "omitida"
    @State private var registrando = false
    @State private var errorRegistro: String?

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

    // Paso 1: verificación del medicamento (RF-02, RF-03).
    // Se fotografía la etiqueta de la caja o del blíster; la app lee el texto (Vision) y lo compara
    // con la dosis programada. Si no coincide, avisa, pero el cuidador decide si continúa
    // (la lectura puede fallar) y la decisión queda registrada en el historial.
    private var pasoVerificar: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Esperado")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(dosis.medicamento) · \(dosis.indicacion)")
                        .font(.headline)
                }

                if analizando {
                    ProgressView("Leyendo la etiqueta...")
                        .padding(.vertical, 40)
                } else if let resultado {
                    resultadoVerificacion(resultado)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 64))
                            .foregroundColor(.teal)
                        Text("Toma una foto de la caja o del blíster donde se vea el nombre y los miligramos.")
                            .font(.callout)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))

                    botonFoto("Tomar foto de la etiqueta", prominente: true)

                    Button("Omitir verificación") {
                        verificacion = "omitida"
                        paso = 2
                    }
                    .font(.subheadline)
                }
            }
        }
        .sheet(isPresented: $mostrandoSelector) {
            SelectorImagen(fuente: fuenteSelector) { imagen in
                analizar(imagen)
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func resultadoVerificacion(_ resultado: ResultadoVerificacion) -> some View {
        let (icono, color, titulo): (String, Color, String) = {
            switch resultado.estado {
            case .coincide: return ("checkmark.seal.fill", .green, "Coincide")
            case .noCoincide: return ("exclamationmark.triangle.fill", .red, "Posible error")
            case .inconcluso: return ("questionmark.circle.fill", .orange, "No se pudo verificar")
            }
        }()

        VStack(spacing: 12) {
            Image(systemName: icono)
                .font(.system(size: 56))
                .foregroundColor(color)
            Text(titulo)
                .font(.title3.bold())
                .foregroundColor(color)
            Text(resultado.mensaje)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))

        if !textoLeido.isEmpty {
            DisclosureGroup("Ver texto leído") {
                Text(textoLeido.prefix(12).joined(separator: "\n"))
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.subheadline)
        }

        switch resultado.estado {
        case .coincide:
            Button {
                verificacion = "coincide"
                paso = 2
            } label: {
                Text("Continuar").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            botonFoto("Tomar otra foto", prominente: false)

        case .noCoincide:
            botonFoto("Tomar otra foto", prominente: true)
            Button(role: .destructive) {
                verificacion = "no_coincide"
                paso = 2
            } label: {
                Text("Continuar de todos modos").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            Text("La diferencia quedará registrada en el historial.")
                .font(.caption)
                .foregroundColor(.secondary)

        case .inconcluso:
            botonFoto("Tomar otra foto", prominente: true)
            Button {
                verificacion = "omitida"
                paso = 2
            } label: {
                Text("Continuar sin verificar").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    @ViewBuilder
    private func botonFoto(_ titulo: String, prominente: Bool) -> some View {
        let hayCamara = UIImagePickerController.isSourceTypeAvailable(.camera)
        let boton = Button {
            // En el simulador no hay cámara: se elige una foto de la fototeca.
            fuenteSelector = hayCamara ? .camera : .photoLibrary
            mostrandoSelector = true
        } label: {
            Label(hayCamara ? titulo : "Elegir foto", systemImage: hayCamara ? "camera.fill" : "photo")
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)

        if prominente {
            boton.buttonStyle(.borderedProminent)
        } else {
            boton.buttonStyle(.bordered)
        }
    }

    private func analizar(_ imagen: UIImage) {
        analizando = true
        resultado = nil
        Task {
            let lineas = await LectorTexto.leer(imagen)
            textoLeido = lineas
            let otros = app.inventario.map { $0.nombre }.filter { $0 != dosis.medicamento }
            resultado = VerificadorPastilla.verificar(lineas: lineas, esperado: dosis.medicamento, otros: otros)
            analizando = false
        }
    }

    // Paso 2: confirmar los datos (RF-04).
    private var pasoConfirmar: some View {
        VStack(alignment: .leading, spacing: 14) {
            etiquetaVerificacion
                .font(.headline)

            LabeledContent("Medicamento", value: dosis.medicamento)
            LabeledContent("Dosis", value: dosis.indicacion)
            LabeledContent("Hora programada", value: dosis.hora)
            LabeledContent("Cuidador", value: app.cuidador?.nombre ?? "")

            Spacer()

            if let errorRegistro {
                Text(errorRegistro)
                    .font(.callout)
                    .foregroundColor(.red)
            }

            Button {
                registrando = true
                errorRegistro = nil
                Task {
                    let fallo = await app.registrarDosis(dosis.id, verificacion: verificacion)
                    registrando = false
                    if let fallo {
                        errorRegistro = fallo
                    } else {
                        paso = 3
                    }
                }
            } label: {
                Text(registrando ? "Registrando..." : "Registrar administración")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(registrando)
        }
    }

    @ViewBuilder
    private var etiquetaVerificacion: some View {
        switch verificacion {
        case "coincide":
            Label("Etiqueta verificada", systemImage: "checkmark.seal.fill")
                .foregroundColor(.green)
        case "no_coincide":
            Label("Hay una diferencia con la etiqueta", systemImage: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
        default:
            Label("Medicamento sin verificar", systemImage: "questionmark.circle.fill")
                .foregroundColor(.orange)
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

            Label("Guardada en el historial", systemImage: "clock.arrow.circlepath")
                .font(.subheadline)

            if let item = app.inventarioDe(dosis.medicamento) {
                Label(item.bajo
                      ? "Quedan \(item.cantidad) de \(item.nombre): inventario bajo"
                      : "Quedan \(item.cantidad) de \(item.nombre)",
                      systemImage: "pills.fill")
                    .font(.subheadline)
                    .foregroundColor(item.bajo ? .orange : .secondary)
            }

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
