//
//  PhotosPickerItem+FullResolution.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 17.07.26.
//
//  Plattformuebergreifender Full-Resolution-Loader fuer PhotosPicker-Auswahlen.
//
//  Auf macOS liefert `loadTransferable(type: Data.self)` haeufig nur ein
//  Thumbnail statt des Originalbilds. Deshalb wird dort das Bild ueber einen
//  NSImage-Transferable-Wrapper in voller Aufloesung geladen und anschliessend
//  als JPEG serialisiert. Auf iOS ist der direkte `Data.self`-Weg der erprobte
//  (siehe iOS/AICamera/AIFoodCameraView.swift) und liefert die Originaldaten.
//

import SwiftUI
import PhotosUI

#if os(macOS)
import AppKit
import UniformTypeIdentifiers

/// Transferable-Wrapper fuer NSImage — laedt Bilder in voller Aufloesung aus PhotosPicker.
struct FullResolutionImage: Transferable {
    let image: NSImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            guard let nsImage = NSImage(data: data) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return FullResolutionImage(image: nsImage)
        }
    }
}
#endif

extension PhotosPickerItem {
    /// Laedt das ausgewaehlte Foto in voller Aufloesung als serialisierte Bilddaten.
    ///
    /// macOS: ueber `FullResolutionImage` (NSImage) → JPEG, um die Thumbnail-Falle
    /// von `loadTransferable(type: Data.self)` zu umgehen.
    /// iOS/andere: direkte Originaldaten via `loadTransferable(type: Data.self)`.
    func loadFullResolutionData() async -> Data? {
        #if os(macOS)
        guard let nsImage = try? await loadTransferable(type: FullResolutionImage.self)?.image else {
            return nil
        }
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
        #else
        return try? await loadTransferable(type: Data.self)
        #endif
    }
}
