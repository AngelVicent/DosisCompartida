import SwiftUI
import UIKit
import Vision

// MARK: - Lector de texto (Vision): lee la etiqueta de la caja o blíster en una foto

enum LectorTexto {

    // Devuelve las líneas de texto reconocidas en la imagen.
    static func leer(_ imagen: UIImage) async -> [String] {
        guard let cgImagen = imagen.cgImage else { return [] }
        let orientacion = CGImagePropertyOrientation(imagen.imageOrientation)

        return await withCheckedContinuation { continuacion in
            DispatchQueue.global(qos: .userInitiated).async {
                let peticion = VNRecognizeTextRequest()
                peticion.recognitionLevel = .accurate
                // Los nombres de medicamentos no son palabras de diccionario: la corrección los dañaría.
                peticion.usesLanguageCorrection = false

                let manejador = VNImageRequestHandler(cgImage: cgImagen, orientation: orientacion, options: [:])
                do {
                    try manejador.perform([peticion])
                } catch {
                    continuacion.resume(returning: [])
                    return
                }

                let lineas = (peticion.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                continuacion.resume(returning: lineas)
            }
        }
    }
}

// MARK: - Selector de imagen: abre la cámara (o la fototeca si no hay cámara, como en el simulador)

struct SelectorImagen: UIViewControllerRepresentable {
    let fuente: UIImagePickerController.SourceType
    var alElegir: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let selector = UIImagePickerController()
        selector.sourceType = fuente
        selector.delegate = context.coordinator
        return selector
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinador {
        Coordinador(self)
    }

    final class Coordinador: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let padre: SelectorImagen

        init(_ padre: SelectorImagen) {
            self.padre = padre
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let imagen = info[.originalImage] as? UIImage {
                padre.alElegir(imagen)
            }
            padre.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            padre.dismiss()
        }
    }
}
