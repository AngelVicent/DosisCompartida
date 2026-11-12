import SwiftUI

// MARK: - Historial de administración
// Muestra quién dio cada dosis y a qué hora, agrupado por día.
// Es lo que permite a varios cuidadores compartir el seguimiento.

struct HistorialView: View {
    @EnvironmentObject var app: AppState
    @State private var filtro = "Todos"

    // "Todos" más cada cuidador que aparece en el historial.
    private var opciones: [String] {
        let nombres = Set(app.historial.map { $0.cuidador }).sorted()
        return ["Todos"] + nombres
    }

    private var registros: [RegistroDosis] {
        app.historial
            .filter { filtro == "Todos" || $0.cuidador == filtro }
            .sorted { $0.fecha > $1.fecha }
    }

    // Días con registros, del más reciente al más antiguo.
    private var dias: [Date] {
        let inicios = Set(registros.map { Calendar.current.startOfDay(for: $0.fecha) })
        return inicios.sorted(by: >)
    }

    private func registros(de dia: Date) -> [RegistroDosis] {
        registros.filter { Calendar.current.startOfDay(for: $0.fecha) == dia }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Cuidador", selection: $filtro) {
                        ForEach(opciones, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)
                }

                if registros.isEmpty {
                    Section {
                        Text("Aún no hay dosis registradas.")
                            .foregroundColor(.secondary)
                    }
                }

                ForEach(dias, id: \.self) { dia in
                    Section(titulo(de: dia)) {
                        ForEach(registros(de: dia)) { registro in
                            FilaHistorial(registro: registro)
                        }
                    }
                }
            }
            .navigationTitle("Historial")
            .refreshable { await app.recargar() }
        }
    }

    private func titulo(de dia: Date) -> String {
        if Calendar.current.isDateInToday(dia) { return "Hoy" }
        if Calendar.current.isDateInYesterday(dia) { return "Ayer" }
        let formato = DateFormatter()
        formato.locale = Locale(identifier: "es_MX")
        formato.dateFormat = "EEEE d 'de' MMMM"
        return formato.string(from: dia).capitalized
    }
}

struct FilaHistorial: View {
    let registro: RegistroDosis

    private var horaReal: String {
        let formato = DateFormatter()
        formato.dateFormat = "HH:mm"
        return formato.string(from: registro.fecha)
    }

    // Cómo se verificó la etiqueta (nil en registros antiguos o de ejemplo).
    private var verificacion: (texto: String, icono: String, color: Color)? {
        switch registro.verificacion {
        case "coincide": return ("Etiqueta verificada", "checkmark.seal.fill", .green)
        case "no_coincide": return ("Con diferencia en la etiqueta", "exclamationmark.triangle.fill", .red)
        case "omitida": return ("Sin verificar", "questionmark.circle", .orange)
        default: return nil
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text(registro.medicamento)
                    .font(.headline)
                Text("\(registro.indicacion) · programada \(registro.horaProgramada)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Label(registro.cuidador, systemImage: "person.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let verificacion {
                    Label(verificacion.texto, systemImage: verificacion.icono)
                        .font(.caption)
                        .foregroundColor(verificacion.color)
                }
            }

            Spacer()

            Text(horaReal)
                .font(.headline)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }
}
