//
//  KalorienKompassWidgetBundle.swift
//  KalorienKompassWidget
//
//  Erstellt von André Claaßen am 05.02.26.
//

import WidgetKit
import SwiftUI

@main
struct KalorienKompassWidgetBundle: WidgetBundle {
    var body: some Widget {
        WaterWidget()
        MealOverviewWidget()
        CalorieSummaryWidget()
        #if os(iOS)
        CalorieLockScreenWidget()
        #endif
        PresetQuickAddWidget()
    }
}
