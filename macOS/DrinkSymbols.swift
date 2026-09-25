//
//  DrinkSymbols.swift
//  KalorienKompass
//
//  Eigene Symbole fuer Wasser und Kaffee im MenuBar-Popover.
//
//  Warum selbst gezeichnet: SF Symbols kennt weder ein Trinkglas noch eine
//  Kaffeebohne. Vorhanden sind nur `drop`, `cup.and.saucer`, `cup.and.heat.waves`,
//  `mug`, `wineglass` und `waterbottle` — ein Weinglas fuers Wasser und ein Becher
//  fuer die Bohne waeren beide daneben. Als SwiftUI-`Shape` statt als Custom Symbol
//  im Asset-Katalog, weil ein Symbol-Set nur mit einem SF-Symbols-Template
//  entsteht und zusaetzlich in vier Xcode-Targets registriert werden muesste.
//

#if os(macOS)
import SwiftUI

/// Schlankes Trinkglas, leicht konisch. Zeichnet sich in seine `rect` ein und
/// laesst oben und unten etwas Luft, damit es neben `cup.and.saucer.fill`
/// gleich gross wirkt.
struct WaterGlassShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        // Relative Masse: oben breiter als unten, Boden leicht gerundet.
        let topInset = w * 0.16
        let bottomInset = w * 0.30
        let top = rect.minY + h * 0.06
        let bottom = rect.maxY - h * 0.04
        let corner = w * 0.10

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + topInset, y: top))
        path.addLine(to: CGPoint(x: rect.maxX - topInset, y: top))
        path.addLine(to: CGPoint(x: rect.maxX - bottomInset, y: bottom - corner))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - bottomInset - corner, y: bottom),
            control: CGPoint(x: rect.maxX - bottomInset, y: bottom)
        )
        path.addLine(to: CGPoint(x: rect.minX + bottomInset + corner, y: bottom))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + bottomInset, y: bottom - corner),
            control: CGPoint(x: rect.minX + bottomInset, y: bottom)
        )
        path.closeSubpath()
        return path
    }
}

/// Kaffeebohne: schraeg liegendes Oval mit der typischen Furche.
///
/// Die Furche ist ein eigener Pfad, deshalb liefert `path(in:)` beide
/// Teilpfade — bei `.fill` mit `.evenOdd` bleibt die Furche als Aussparung
/// stehen, was der Bohne ihre Form gibt.
struct CoffeeBeanShape: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let bean = CGRect(
            x: center.x - side * 0.30,
            y: center.y - side * 0.46,
            width: side * 0.60,
            height: side * 0.92
        )

        var path = Path(ellipseIn: bean)

        // Furche: leicht gebogenes Band von Spitze zu Spitze, mittig ausgestanzt.
        // Die beiden Kontrollpunkte liegen links und rechts derselben Hoehe; ihr
        // Abstand bestimmt, wie breit das Band in der Mitte auftraegt.
        let oben = CGPoint(x: bean.minX + bean.width * 0.34, y: bean.minY + bean.height * 0.08)
        let unten = CGPoint(x: bean.minX + bean.width * 0.66, y: bean.maxY - bean.height * 0.08)
        var furche = Path()
        furche.move(to: oben)
        furche.addQuadCurve(to: unten, control: CGPoint(x: bean.minX + bean.width * 0.28, y: center.y))
        furche.addQuadCurve(to: oben, control: CGPoint(x: bean.minX + bean.width * 0.64, y: center.y))
        path.addPath(furche)

        return path.rotation(.degrees(38), anchor: .center).path(in: rect)
    }
}

/// Die Kaffeebohne als Zeilensymbol. Kapselt das `evenOdd`-Fuellen, ohne das
/// die Furche zugemalt wuerde.
struct CoffeeBeanIcon: View {
    var color: Color = .brown

    var body: some View {
        CoffeeBeanShape()
            .fill(color, style: FillStyle(eoFill: true))
            .frame(width: 16, height: 16)
    }
}

/// Ein Glas der Wasserreihe. Gefuellt als Flaeche, leer als Umriss — dieselbe
/// Unterscheidung, die SF Symbols ueber die `.fill`-Variante macht.
struct WaterGlassIcon: View {
    let isFilled: Bool

    var body: some View {
        Group {
            if isFilled {
                WaterGlassShape().fill(.cyan)
            } else {
                WaterGlassShape().stroke(DrinkRow.emptyTint, lineWidth: 1.4)
            }
        }
        .frame(width: 15, height: 20)
        // Pflicht, nicht Kosmetik: eine Shape faengt Klicks nur dort, wo sie
        // zeichnet. Beim leeren Glas waere das die 1,4 Punkt dicke Umrisslinie,
        // und die Reihe liesse sich praktisch nicht bedienen (Issue #97).
        .contentShape(Rectangle())
    }
}

/// Eine Tasse der Kaffeereihe. Die Tasse selbst kommt aus SF Symbols
/// (`cup.and.saucer`), nur die Farbe unterscheidet Ziel von Ueberschreitung.
struct CoffeeCupIcon: View {
    let isFilled: Bool
    let isOverLimit: Bool

    var body: some View {
        Image(systemName: isFilled ? "cup.and.saucer.fill" : "cup.and.saucer")
            .font(.system(size: 15))
            .foregroundStyle(farbe)
            .frame(width: 19, height: 20)
            .contentShape(Rectangle())
    }

    private var farbe: Color {
        guard isFilled else { return DrinkRow.emptyTint }
        return isOverLimit ? .red : .brown
    }
}

/// Die Regeln, nach denen Glaeser- und Tassenreihe funktionieren. Beide gehoeren
/// zusammen: die Reihe traegt eine leere Zusatzposition, und genau die macht die
/// letzte gefuellte Position abwaehlbar. Getrennt abgelegt driften sie
/// auseinander, und dann laesst sich entweder nicht mehr ueberschreiten oder
/// nichts mehr zuruecknehmen.
enum DrinkRow {

    /// Farbe der noch leeren Positionen, fuer Glaeser wie Tassen dieselbe.
    static let emptyTint = Color.secondary.opacity(0.45)

    /// Positionen der Reihe: bis zum Ziel, mindestens bis zum bereits
    /// Getrunkenen, plus eine leere. Ohne die Zusatzposition endet die Reihe hart
    /// am Ziel, und mehr als das Ziel liesse sich per Klick nie eintragen
    /// (Issue #93).
    static func slotCount(goal: Int, filled: Int) -> Int {
        max(goal, filled, 0) + 1
    }

    /// Ein Tipp auf die letzte gefuellte Position nimmt sie zurueck, jeder andere
    /// setzt bis dorthin auf. So laesst sich jede Anzahl mit einem Klick setzen
    /// und die letzte wieder loeschen, ohne einen zweiten Bedienweg.
    static func newCount(tapped index: Int, filled: Int) -> Int {
        (index == filled - 1) ? index : index + 1
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 5) {
            CoffeeBeanIcon()
            ForEach(0..<8, id: \.self) { i in WaterGlassIcon(isFilled: i < 5) }
        }
        HStack(spacing: 5) {
            CoffeeBeanIcon(color: .red)
            ForEach(0..<6, id: \.self) { i in CoffeeCupIcon(isFilled: i < 4, isOverLimit: false) }
            CoffeeCupIcon(isFilled: true, isOverLimit: true)
        }
    }
    .padding()
}
#endif
