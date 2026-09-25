//
//  KalorienKompassWatchWidgetBundle.swift
//  KalorienKompassWatch
//
//  Erstellt von André Claaßen am 06.02.26.
//
//  Widget Bundle fuer watchOS Komplikationen.
//  Wird als separates Widget Extension Target kompiliert.
//

#if os(watchOS)
import SwiftUI
import WidgetKit

/// Widget Bundle fuer watchOS Komplikationen
@main
struct KalorienKompassWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        CalorieWidget()
        WaterWidget()
    }
}
#endif
