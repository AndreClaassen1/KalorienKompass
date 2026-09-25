//
//  BMIBarView.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 05.02.26.
//

import SwiftUI

/// Farbcodierter BMI-Balken mit Zeiger
struct BMIBarView: View {
    let bmi: Double
    var compact: Bool = false

    private let scaleMin: Double = 15.0
    private let scaleMax: Double = 45.0

    var body: some View {
        if compact {
            compactView
        } else {
            fullView
        }
    }

    // MARK: - Kompakte Variante (Dashboard)

    private var compactView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("BMI \(bmi, specifier: "%.1f")")
                    .font(.caption.bold())
                Text("·")
                    .foregroundStyle(.secondary)
                Text(BMICalculator.category(bmi: bmi).localizedName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            GeometryReader { geometry in
                bmiBar(width: geometry.size.width, height: 6)
            }
            .frame(height: 6)
        }
    }

    // MARK: - Volle Variante (Settings)

    private var fullView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("bmi_title")
                .font(.subheadline.bold())

            GeometryReader { geometry in
                VStack(alignment: .leading, spacing: 4) {
                    bmiBar(width: geometry.size.width, height: 12)

                    // Kategorien-Labels
                    HStack(spacing: 0) {
                        ForEach(BMICategory.allCases) { category in
                            Text(category.localizedName)
                                .font(.system(size: 8))
                                .lineLimit(1)
                                .frame(
                                    width: geometry.size.width * category.scaleWidth / (scaleMax - scaleMin),
                                    alignment: .center
                                )
                        }
                    }
                }
            }
            .frame(height: 30)

            HStack {
                Text("BMI: \(bmi, specifier: "%.1f")")
                    .font(.subheadline.bold())
                Text("·")
                    .foregroundStyle(.secondary)
                Text(BMICalculator.category(bmi: bmi).localizedName)
                    .font(.subheadline)
                    .foregroundStyle(BMICalculator.category(bmi: bmi).color)
            }
        }
    }

    // MARK: - Gemeinsamer Balken

    private func bmiBar(width: Double, height: Double) -> some View {
        ZStack(alignment: .leading) {
            // Farbsegmente
            HStack(spacing: 0) {
                ForEach(BMICategory.allCases) { category in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(category.color)
                        .frame(
                            width: width * category.scaleWidth / (scaleMax - scaleMin),
                            height: height
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: height / 2))

            // Zeiger
            let clampedBMI = min(max(bmi, scaleMin), scaleMax)
            let position = (clampedBMI - scaleMin) / (scaleMax - scaleMin) * width

            Triangle()
                .fill(.primary)
                .frame(width: 8, height: 6)
                .offset(x: position - 4, y: height + 1)
        }
    }
}

/// Dreieck-Shape fuer den BMI-Zeiger
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview("Voll") {
    BMIBarView(bmi: 25.4, compact: false)
        .padding()
}

#Preview("Kompakt") {
    BMIBarView(bmi: 25.4, compact: true)
        .padding()
}
