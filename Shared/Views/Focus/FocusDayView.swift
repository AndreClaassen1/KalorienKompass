//
//  FocusDayView.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 13.07.26.
//
//  Hauptscreen des minimalistischen Fokus-Modus: Restkalorien als reine Zahl,
//  darunter der Eingabebereich, darunter die Mahlzeiten-Rubriken. Einziger
//  Erfassungsweg ist Text (Sprache folgt in Etappe 2).
//

import SwiftUI
import SwiftData
import AppChangelog
import UniformTypeIdentifiers
import PhotosUI
#if canImport(AppKit)
import AppKit
#endif

struct FocusDayView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("showAllMealTypes") private var showAllMealTypes = false

    @State private var dayViewModel: DayViewModel?
    @State private var focusViewModel: FocusViewModel?
    @State private var leverViewModel: FocusLeverViewModel?
    /// Detailansicht des Hebels (setzen, Trigger, Wochenauswertung)
    @State private var showLeverDetail = false
    /// Rubrik, ueber der gerade ein Eintrag per Drag & Drop schwebt (fuer Highlight)
    @State private var dropTargetMeal: MealType?
    @State private var selectedDate: Date = Date().startOfDay
    /// Ist der Kalorienring nach oben aus der Liste gescrollt? Dann zeigt die
    /// Kopfzeile die Restkalorien als Pille (Issue #87).
    @State private var ringScrolledAway = false
    /// Aktuelle Scrollposition der Liste, 0 am oberen Anschlag.
    @State private var scrollOffset: CGFloat = 0
    /// Der Tag, der beim letzten Blick auf die Uhr "heute" war. Merkposten fuer
    /// den Nachtwechsel (Issue #84): nur wenn `selectedDate` noch auf ihm steht,
    /// war die Ansicht auf "heute" und darf mitwandern.
    @State private var knownToday: Date = Date().startOfDay
    @Environment(\.scenePhase) private var scenePhase
    @State private var editingEntry: DiaryEntry?
    /// Mit der Befehlstaste gesammelte Eintraege (nur macOS). Steht hier
    /// plattformneutral, damit `rowTint` und `move` keine Weiche brauchen.
    @State private var selectedEntryIds: Set<String> = []
    @State private var showSettings = false
    @State private var showWeightSheet = false
    @State private var showBudgetSheet = false
    @State private var showWaterSheet = false
    /// Foto-Eingabe: Live-Kamera (iOS) bzw. Fotomediathek
    @State private var showCamera = false
    @State private var showLibraryPicker = false
    @State private var libraryItem: PhotosPickerItem?
    /// Barcode-Scanner (nur iOS) — Scan → Lookup → Mengen-Sheet
    @State private var showBarcodeScanner = false
    /// Lebensmitteldatenbank-Suche (iOS + macOS)
    @State private var showFoodSearch = false
    /// Ausstehende Fotos, die im Notiz-Sheet auf optionalen Text + Analyse warten
    #if os(iOS)
    @State private var capturedCameraImage: UIImage?
    @State private var pendingCameraImage: FocusPendingCameraImage?
    /// Gescannter Barcode, der nach dem Schliessen des Scanners aufgeloest wird
    @State private var pendingBarcode: String?
    /// Aufgeloestes Lebensmittel — oeffnet das Mengen-Sheet (FoodAddView)
    @State private var scannedFood: FoodItem?
    #endif
    @State private var pendingLibraryData: FocusPendingLibraryData?

    #if os(iOS)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Horizontaler Versatz der Tagesflaeche waehrend und nach der Wischgeste
    @State private var pageOffset: CGFloat = 0
    /// Achse der laufenden Geste — `nil`, solange sie noch unentschieden ist.
    /// Ohne diese Sperre wuerde jedes vertikale Scrollen den Tag mitziehen.
    @State private var gestureIsHorizontal: Bool?
    /// Breite der Tagesflaeche, Bezugsgroesse fuer Schwelle und Auswurf
    @State private var pageWidth: CGFloat = 375
    #endif

    #if os(iOS)
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    #endif

    /// iPhone im Querformat: Hoehe knapp, Breite im Ueberfluss. Trifft nicht auf das
    /// iPad zu, das auch quer eine regulaere Hoehenklasse hat.
    private var isLandscapePhone: Bool {
        #if os(iOS)
        verticalSizeClass == .compact
        #else
        false
        #endif
    }

    /// Horizontaler Rand der Hero-Elemente (Eingabefeld, Hebel, Undo). Auf iOS breiter,
    /// damit sie buendig mit der staerker eingerueckten insetGrouped-Liste (Vitals,
    /// Mahlzeiten) abschliessen. Auf macOS liegen alle bei 16.
    private var heroHorizontalPadding: CGFloat {
        #if os(iOS)
        32
        #else
        16
        #endif
    }

    /// Zeilen-Insets fuer die scrollenden Karten (Hebel, Vitals) in der Liste.
    /// Auf macOS ohne zusaetzlichen Seitenrand, weil die `.inset`-Liste die Zeilen
    /// bereits selbst einrueckt — ein extra 16 liesse die Karten schmaler wirken als
    /// das Eingabefeld daruber. Auf iOS bleibt der Rand vorerst bei 16.
    private var scrollingCardRowInsets: EdgeInsets {
        #if os(iOS)
        EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16)
        #else
        EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0)
        #endif
    }

    /// Aktueller Tages-Score — steuert Ambient-Hintergrundfarbe und Ringfarbe.
    private var dayScore: DayScore {
        guard let vm = dayViewModel else { return DayScore(level: .fresh, value: nil) }
        return DayScore.compute(
            eatenCalories: vm.summary.totalCalories,
            calorieGoal: vm.effectiveCalorieGoal,
            protein: vm.summary.totalProtein,
            proteinGoal: vm.profile?.proteinGoalGrams ?? 50,
            waterMl: vm.dayRecord?.waterIntakeMl ?? 0,
            waterGoalMl: vm.profile?.dailyWaterGoalMl ?? 2000
        )
    }

    var body: some View {
        NavigationStack {
            content
                .background {
                    FocusAmbientBackground(scoreColor: dayScore.color)
                }
                // macOS: kein Titel (Fenstertitel faellt auf den App-Namen zurueck),
                // damit oben kein "Fokus"-Text erscheint.
                #if os(iOS)
                .navigationTitle("focus_title")
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    #if os(macOS)
                    // Auf dem Mac gibt es keine Wochenleiste, in der die Pille sitzen
                    // koennte. Die Titelzeile ist ohnehin leer, dort faellt sie nicht
                    // ins Gehege (#87).
                    ToolbarItem(placement: .principal) {
                        if ringScrolledAway, let dayVM = dayViewModel {
                            remainingPill(dayVM)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    // Ohne sichtbaren Titel (hiddenTitleBar seit #52) rutscht ein einzelnes
                    // primaryAction-Item auf macOS nach links neben die Ampel-Buttons. Ein
                    // flexibler Spacer davor schiebt das Zahnrad zurueck an den rechten Rand.
                    ToolbarSpacer(.flexible)
                    #endif
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
        }
        .onAppear(perform: setupIfNeeded)
        // Tageswechsel bei laufender App: die Ansicht wandert mit.
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            syncToCurrentDay()
        }
        // Zweiter Weg fuer den Fall, dass die Benachrichtigung niemanden antrifft:
        // im Ruhezustand oder im Hintergrund wird sie nicht nachgeliefert. Genau
        // das ist der Alltagsfall — der Mac schlaeft ueber Nacht.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            syncToCurrentDay()
        }
        // Leichte Rueckmeldung beim Einrasten — gilt fuer die Wischgeste ebenso
        // wie fuer die Pfeile, die sonst voellig stumm sind.
        #if os(iOS)
        .sensoryFeedback(.selection, trigger: selectedDate)
        #endif
        // Nach einem Versionssprung einmalig zeigen, was dazugekommen ist.
        // Beim Erststart bleibt es still (Issue #71).
        .whatsNewOnLaunch(
            appName: "KalorienKompass",
            currentVersion: BuildInfo.semanticVersion,
            changelog: BuildInfo.changelog
        )
        // macOS-Menuebefehle steuern die Fokus-Ansicht
        .onReceive(NotificationCenter.default.publisher(for: .focusPreviousDay)) { _ in
            changeDay(-1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusNextDay)) { _ in
            changeDay(1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusGoToToday)) { _ in
            goTo(Date().startOfDay)
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusOpenSettings)) { _ in
            showSettings = true
        }
        .sheet(item: $editingEntry) { entry in
            FocusEntryEditSheet(entry: entry) { reload() }
        }
        .sheet(isPresented: $showSettings) {
            settingsSheet
        }
        .sheet(isPresented: $showBudgetSheet) {
            if let dayVM = dayViewModel {
                CalorieBudgetSheet(
                    breakdown: dayVM.goalBreakdown,
                    eaten: Int(dayVM.summary.totalCalories),
                    date: selectedDate
                )
            }
        }
        .sheet(isPresented: $showLeverDetail, onDismiss: { leverViewModel?.load(for: selectedDate) }) {
            NavigationStack {
                FocusLeverDetailView(isPresentedAsSheet: true)
            }
        }
        .sheet(isPresented: $showWeightSheet) {
            if let dayVM = dayViewModel {
                WeightEntrySheet(
                    currentWeight: dayVM.dayRecord?.weight
                ) { kg in
                    dayVM.updateWeight(kg, for: selectedDate)
                }
                .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showWaterSheet) {
            if let dayVM = dayViewModel {
                WaterManualEntrySheet(
                    currentMl: dayVM.dayRecord?.waterIntakeMl ?? 0
                ) { ml in
                    dayVM.setWaterIntake(ml: ml, for: selectedDate)
                }
                .presentationDetents([.medium])
            }
        }
        #if os(iOS)
        // Live-Kamera → nach dem Schliessen erscheint das Notiz-Sheet (zwei Sheets nicht
        // gleichzeitig: Foto in onDismiss durchreichen, dann Notiz-Sheet praesentieren).
        .sheet(isPresented: $showCamera, onDismiss: {
            if let image = capturedCameraImage {
                capturedCameraImage = nil
                pendingCameraImage = FocusPendingCameraImage(image: image)
            }
        }) {
            NavigationStack {
                AIFoodCameraView { image in
                    capturedCameraImage = image
                    showCamera = false
                }
            }
        }
        .sheet(item: $pendingCameraImage) { pending in
            FocusPhotoNoteSheet(
                preview: Image(uiImage: pending.image),
                initialNote: focusViewModel?.inputText ?? "",
                onAnalyze: { note in bookPhoto(image: pending.image, note: note) },
                onCancel: {}
            )
        }
        // Barcode: Scanner schliesst sich beim Scan selbst → in onDismiss aufloesen,
        // dann das Mengen-Sheet (FoodAddView) zeigen (zwei Sheets nicht gleichzeitig).
        .sheet(isPresented: $showBarcodeScanner, onDismiss: {
            guard let barcode = pendingBarcode else { return }
            pendingBarcode = nil
            resolveBarcode(barcode)
        }) {
            NavigationStack {
                BarcodeScannerView { barcode in
                    pendingBarcode = barcode
                }
            }
        }
        .sheet(item: $scannedFood) { food in
            NavigationStack {
                FoodAddView(
                    foodItem: food,
                    selectedDate: selectedDate,
                    selectedMealType: focusViewModel?.contextMeal ?? MealType.currentBasedOnTime,
                    editingEntry: nil
                ) { grams, mealType in
                    bookScannedFood(food, grams: grams, mealType: mealType)
                }
            }
        }
        #endif
        // Fotomediathek (iOS + macOS): nach der Auswahl das Notiz-Sheet zeigen.
        .photosPicker(isPresented: $showLibraryPicker, selection: $libraryItem, matching: .images)
        .onChange(of: libraryItem) { _, newValue in
            guard let newValue else { return }
            Task {
                // Full-Resolution-Loader umgeht auf macOS die Thumbnail-Falle von
                // loadTransferable(type: Data.self) — siehe PhotosPickerItem+FullResolution.
                if let data = await newValue.loadFullResolutionData() {
                    pendingLibraryData = FocusPendingLibraryData(data: data)
                }
                libraryItem = nil
            }
        }
        .sheet(item: $pendingLibraryData) { pending in
            FocusPhotoNoteSheet(
                preview: photoPreview(from: pending.data),
                initialNote: focusViewModel?.inputText ?? "",
                onAnalyze: { note in bookPhoto(data: pending.data, note: note) },
                onCancel: {}
            )
        }
        // Lebensmitteldatenbank-Suche (iOS + macOS). FoodSearchView bucht selbst und
        // schliesst sich danach; onDismiss laedt den Fokus-Tag neu.
        .sheet(isPresented: $showFoodSearch, onDismiss: { reload() }) {
            NavigationStack {
                FoodSearchView(
                    selectedDate: selectedDate,
                    selectedMealType: focusViewModel?.contextMeal ?? MealType.currentBasedOnTime,
                    plannedMealOverride: focusViewModel?.contextMeal
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("cancel") { showFoodSearch = false }
                    }
                }
            }
            #if os(macOS)
            .frame(minWidth: 520, idealWidth: 640, minHeight: 480, idealHeight: 640)
            #endif
        }
        #if os(macOS)
        // Breite an den Inhalt binden (kein Stranden in breiten Fenstern),
        // Hoehe bleibt frei resizable. Zusammen mit .windowResizability(.contentSize)
        // in CaloryGuardApp haelt das Fenster eine ruhige, inhaltsgerechte Groesse.
        .frame(minWidth: 460, idealWidth: 560, maxWidth: 620, minHeight: 640, idealHeight: 900)
        #endif
    }

    // MARK: - Inhalt

    @ViewBuilder
    private var content: some View {
        if let dayVM = dayViewModel, let focusVM = focusViewModel {
            #if os(iOS)
            // Die Wochenleiste ist Navigation und bleibt stehen, alles darunter
            // blaettert als eine Flaeche weg (Issue #81).
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    if ringScrolledAway {
                        remainingPill(dayVM)
                            .transition(.scale.combined(with: .opacity))
                    }

                    FocusWeekStrip(
                        days: dayVM.week,
                        selectedDate: selectedDate,
                        dragProgress: reduceMotion ? 0 : -pageOffset / pageWidth,
                        onSelect: { goToDay($0) }
                    )
                }
                .padding(.leading, ringScrolledAway ? 12 : 0)
                .simultaneousGesture(daySwipe)

                dayStack(dayVM, focusVM)
                    .offset(x: pageOffset)
                    .scaleEffect(1 - pageProgress * 0.04)
                    .opacity(1 - pageProgress * 0.45)
            }
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { pageWidth = $0 }
            #else
            dayStack(dayVM, focusVM)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            #endif
        } else {
            ProgressView()
        }
    }

    /// Der Tag selbst: Datum, Kalorien, Eingabe und Mahlzeiten. Auf iOS ist das
    /// die Flaeche, die beim Wischen wegwandert.
    ///
    /// Fest steht nur die Eingabe (Issue #86). Datum und Kalorienring liegen als
    /// erste Zeile in der Liste und scrollen mit hinaus: im Querformat blieb sonst
    /// kaum Flaeche zum Scrollen uebrig, und beim Durchsehen der Mahlzeiten wird
    /// der Ring ohnehin nicht gebraucht. Das Eingabefeld dagegen schon, jederzeit.
    private func dayStack(_ dayVM: DayViewModel, _ focusVM: FocusViewModel) -> some View {
        VStack(spacing: 14) {
            mealList(dayVM, focusVM)
                .safeAreaInset(edge: .top, spacing: 10) {
                    inputHeader(focusVM)
                        // Der Nebel haengt an der Unterkante des Aufsatzes und
                        // ragt nach unten heraus, ohne Platz zu beanspruchen.
                        .overlay(alignment: .bottom) { scrollFadeVeil }
                }

            #if os(macOS)
            buildInfoFooter
            #endif
        }
    }

    /// Nebelzone direkt unter dem Eingabefeld: die Zeilen verlieren sich darin,
    /// statt an der Kante des Feldes abgeschnitten zu werden.
    ///
    /// Bewusst ein Overlay und keine Maske. Eine Maske auf einer Liste wirkt im
    /// Koordinatensystem des Inhalts, wandert also mit ihm und verschluckt immer
    /// dieselben ersten Zeilen statt eines festen Streifens. Der Schleier ist
    /// Material, kein Farbverlauf: der Ambient-Hintergrund wechselt die Farbe,
    /// eine feste Farbe daraufgelegt saehe nur an einem Tagesstand richtig aus.
    ///
    /// Gestaffelt in Streifen, weil sich Material nicht mit einem Verlauf
    /// maskieren laesst: der Weichzeichner wird dabei hart beschnitten und
    /// hinterlaesst genau die Kante, die hier verschwinden soll. Die Stufen
    /// verwischt das Material selbst.
    private var scrollFadeVeil: some View {
        let height = 52 * fadeIntensity
        let steps = 13

        return VStack(spacing: 0) {
            ForEach(0..<steps, id: \.self) { step in
                // Quadratischer Ausklang: linear bliebe unten ein Rest Deckung
                // stehen und riss genau die Kante auf, um die es hier geht.
                let progress = Double(step) / Double(steps - 1)
                Rectangle()
                    .fill(.regularMaterial)
                    .opacity(pow(1 - progress, 2))
                    .frame(height: height / CGFloat(steps))
            }
        }
        .offset(y: height)
        .allowsHitTesting(false)
    }

    /// Wie stark der Nebel unter dem Eingabefeld liegt, 0 bis 1. Am oberen Anschlag
    /// muss er verschwinden: dort beginnt der Inhalt erst unterhalb des Feldes, und
    /// eine feste Nebelzone verschluckte dann die Datumszeile und den Ringrand.
    private var fadeIntensity: CGFloat {
        min(max(scrollOffset / 40, 0), 1)
    }

    /// Der feste Aufsatz der Liste: Eingabefeld und, solange es steht, das
    /// Rueckgaengig-Banner. Es gehoert zur letzten Buchung und wandert deshalb
    /// mit der Eingabe, nicht mit dem Inhalt.
    private func inputHeader(_ focusVM: FocusViewModel) -> some View {
        // Steht das Banner, fasst ein gemeinsamer Rahmen beide Karten zusammen.
        // Sonst bliebe der Abstand dazwischen durchsichtig, und die Zeilen der
        // Liste liefen sichtbar durch diesen Spalt hindurch. Ein Rahmen ueber die
        // volle Breite waere der einfachere Weg gewesen, zog aber einen Balken
        // quer durch den Ambient-Hintergrund.
        let grouped = focusVM.canUndo

        return VStack(spacing: grouped ? 8 : 0) {
            FocusInputView(
                viewModel: focusVM,
                onSubmit: { submit() },
                onOpenSettings: { showSettings = true },
                onTakePhoto: { showCamera = true },
                onPickFromLibrary: { showLibraryPicker = true },
                onScanBarcode: { showBarcodeScanner = true },
                onSearchDatabase: { showFoodSearch = true }
            )

            if focusVM.canUndo {
                undoBanner(focusVM)
            }
        }
        .padding(grouped ? 6 : 0)
        .background {
            if grouped {
                RoundedRectangle(cornerRadius: 22)
                    .fill(.regularMaterial)
            }
        }
        .padding(.horizontal, heroHorizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 6)
        // Bewusst ohne eigene Hintergrundflaeche: ein Materialbalken zoege einen
        // harten Streifen quer durch den Ambient-Hintergrund. Das Ausblenden der
        // durchscrollenden Zeilen uebernimmt der weiche Scrollrand der Liste.
    }

    #if os(macOS)
    /// Fusszeile mit allen Build-Infos (Version, Build-Nummer, Debug/Release, Datum + Zeit)
    private var buildInfoFooter: some View {
        HStack {
            Text("KalorienKompass \(BuildInfo.version) (\(BuildInfo.buildNumber)) \u{2022} \(BuildInfo.configuration)")
            Spacer()
            Text(BuildInfo.buildDate)
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .padding(.horizontal)
        .padding(.bottom, 6)
    }
    #endif

    #if os(iOS)

    // MARK: - Blaettern zwischen Tagen

    /// Wie weit die Seite weggezogen ist, 0 bis 1 — steuert Dimmen und Schrumpfen.
    private var pageProgress: CGFloat {
        min(abs(pageOffset) / max(pageWidth, 1), 1)
    }

    /// Wischen wechselt den Tag. Bewusst nur im Kopfbereich und auf der
    /// Wochenleiste: in der Mahlzeitenliste liegen mit `swipeActions` und
    /// `onDrag` bereits zwei horizontale Gesten, denen eine dritte die
    /// Erkennung streitig machen wuerde.
    private var daySwipe: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                if gestureIsHorizontal == nil {
                    gestureIsHorizontal = abs(value.translation.width) > abs(value.translation.height)
                }
                guard gestureIsHorizontal == true, !reduceMotion else { return }
                pageOffset = value.translation.width
            }
            .onEnded { value in
                let wasHorizontal = gestureIsHorizontal == true
                gestureIsHorizontal = nil
                guard wasHorizontal else { return }

                // Ein kurzer, schneller Wisch soll so viel zaehlen wie ein
                // langsamer ueber die halbe Seite.
                let travelled = value.translation.width
                let projected = value.predictedEndTranslation.width
                let passed = abs(travelled) > pageWidth / 3 || abs(projected) > pageWidth

                if passed {
                    commitDayChange(travelled < 0 ? 1 : -1)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        pageOffset = 0
                    }
                }
            }
    }

    /// Wirft den aktuellen Tag zur Seite, laedt den neuen und laesst ihn von der
    /// Gegenseite einlaufen. Der Nachbartag wird nicht vorab geladen: das waeren
    /// zwei zusaetzliche Tagesabfragen bei jeder Beruehrung.
    private func commitDayChange(_ delta: Int) {
        guard delta != 0 else { return }
        guard !reduceMotion else {
            pageOffset = 0
            changeDay(delta)
            return
        }
        let width = pageWidth
        withAnimation(.easeIn(duration: 0.16)) {
            pageOffset = delta > 0 ? -width : width
        }
        Task {
            try? await Task.sleep(for: .milliseconds(170))
            changeDay(delta)
            pageOffset = delta > 0 ? width : -width
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                pageOffset = 0
            }
        }
    }

    /// Direktsprung aus der Wochenleiste, in der Richtung animiert, in der der
    /// Tag auch in der Leiste liegt.
    private func goToDay(_ date: Date) {
        let target = date.startOfDay
        guard !target.isSameDay(as: selectedDate) else { return }
        let delta = Calendar.current.dateComponents(
            [.day], from: selectedDate, to: target
        ).day ?? 0
        commitDayChange(delta)
    }

    #endif

    // MARK: - Datums- und Kalorien-Kopf

    private func dateHeader(_ dayVM: DayViewModel) -> some View {
        VStack(spacing: 6) {
            HStack {
                Button { changeDay(-1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.plain)
                Spacer()
                Button { selectedDate = Date().startOfDay; reload() } label: {
                    Text(dateLabel)
                        .font(.headline)
                }
                .buttonStyle(.plain)
                Spacer()
                Button { changeDay(1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(.plain)
            }
            .padding(.horizontal)

            CalorieHeroView(
                eaten: Int(dayVM.summary.totalCalories),
                remaining: dayVM.effectiveCalorieGoal - Int(dayVM.summary.totalCalories),
                burned: dayVM.dayRecord?.activeEnergyKcal ?? 0,
                goal: dayVM.effectiveCalorieGoal,
                ringSize: 110,
                ringLineWidth: 8,
                ringTint: dayScore.color,
                remainingColorOverride: .primary
            )
            .padding(.horizontal)
            .padding(.top, 2)
            // Wie aus verbrannter Energie ein Budget wird, ist sonst nicht
            // nachvollziehbar: der Alltagsanteil steckt schon im Grundziel (#80).
            .contentShape(.rect)
            .onTapGesture { showBudgetSheet = true }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(Text("budget_hint"))
        }
        .padding(.top, 8)
    }

    /// Restkalorien als Pille, sobald der grosse Ring nach oben hinausgescrollt ist
    /// (Issue #87). Sie traegt denselben Fortschritt und dieselbe Farbe wie der Ring
    /// und oeffnet auf Tipp dieselbe Aufschluesselung.
    private func remainingPill(_ dayVM: DayViewModel) -> some View {
        let goal = dayVM.effectiveCalorieGoal
        let eaten = Int(dayVM.summary.totalCalories)
        let progress = goal > 0 ? Double(eaten) / Double(goal) : 0

        return Button {
            showBudgetSheet = true
        } label: {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(.quaternary, lineWidth: 2.5)
                    Circle()
                        .trim(from: 0, to: min(progress, 1))
                        .stroke(dayScore.color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 14, height: 14)

                Text(goal - eaten, format: .number)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.regularMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("widget_remaining"))
        .accessibilityHint(Text("budget_hint"))
    }

    private var dateLabel: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return String(localized: "focus_today")
        }
        return selectedDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    // MARK: - Rueckgaengig-Banner

    private func undoBanner(_ focusVM: FocusViewModel) -> some View {
        HStack {
            Label("focus_entry_added", systemImage: "checkmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Button("focus_undo") {
                focusVM.undoLastBatch()
                reload()
            }
            .font(.footnote.bold())
        }
        .padding(10)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Eintragszeile

    private func entryRow(_ entry: DiaryEntry, dayVM: DayViewModel, isHighlighted: Bool) -> some View {
        HStack {
            DiaryEntryRowView(entry: entry)

            #if os(macOS)
            // Mahlzeit der Zeile, zugleich Menue zum Umbuchen. Dauerhaft sichtbar
            // und nicht erst beim Ueberfahren: sonst ist nicht zu erkennen, dass
            // sich ein Eintrag ueberhaupt umhaengen laesst (Issue #113).
            MealPickerMenu(current: entry.mealType, onSelect: { meal in
                if let meal { move(entry, to: meal, dayVM: dayVM) }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: entry.mealType.symbolName)
                    Text(entry.mealType.localizedName)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .overlay(Capsule().stroke(.quaternary))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("move_to_meal")

            // macOS: sichtbarer Loesch-Button (Swipe ist hier umstaendlich)
            Button {
                dayVM.deleteEntry(entry)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("delete")
            #endif
        }
        .background(.tint.opacity(rowTint(entry, isHighlighted: isHighlighted)))
        .contentShape(Rectangle())
        #if os(macOS)
        // Befehlstaste plus Klick sammelt Zeilen, statt den Bearbeiten-Sheet zu
        // oeffnen. `highPriorityGesture` ist noetig, damit der einfache Tap
        // darunter nicht zusaetzlich feuert.
        .highPriorityGesture(
            TapGesture().modifiers(.command).onEnded {
                toggleSelection(entry.entryId)
            }
        )
        #endif
        .onTapGesture { editingEntry = entry }
        .onDrag {
            // Eintrag per Drag & Drop in eine andere Mahlzeit verschieben
            NSItemProvider(object: entry.entryId as NSString)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                dayVM.deleteEntry(entry)
            } label: {
                Label("delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                editingEntry = entry
            } label: {
                Label("edit", systemImage: "pencil")
            }
            MealPickerMenu(current: entry.mealType, onSelect: { meal in
                if let meal { move(entry, to: meal, dayVM: dayVM) }
            }) {
                Label("move_to_meal", systemImage: "arrow.turn.down.right")
            }
            Button(role: .destructive) {
                dayVM.deleteEntry(entry)
            } label: {
                Label("delete", systemImage: "trash")
            }
        }
    }

    #if os(macOS)
    /// Leiste ueber den Mahlzeiten, sobald Zeilen gesammelt sind. Ohne sie bliebe
    /// eine Auswahl unsichtbar, sobald man weiterscrollt.
    private func selectionBar(_ dayVM: DayViewModel) -> some View {
        HStack(spacing: 10) {
            Text("selection_count \(selectedEntryIds.count)")
                .font(.callout)

            MealPickerMenu(current: nil, onSelect: { meal in
                guard let meal else { return }
                dayVM.moveEntries(Array(selectedEntryIds), to: meal)
                selectedEntryIds.removeAll()
            }) {
                Label("move_to_meal", systemImage: "arrow.turn.down.right")
            }
            .fixedSize()

            Spacer()

            Button("selection_clear") { selectedEntryIds.removeAll() }
                .buttonStyle(.borderless)
        }
        .padding(10)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }
    #endif

    /// Menue mit allen Mahlzeiten. Bewusst `MealType.allCases` und nicht
    /// `visibleMeals`: gerade die noch leere Rubrik ist ein haeufiges Ziel, und
    /// per Ziehen ist sie gar nicht erreichbar, weil sie dann nicht angezeigt wird.
    /// Verschiebt die Auswahl, wenn die angetippte Zeile darin liegt, sonst nur
    /// diese eine Zeile. Das entspricht dem, was der Finder mit einer Auswahl tut.
    private func move(_ entry: DiaryEntry, to meal: MealType, dayVM: DayViewModel) {
        let inAuswahl = selectedEntryIds.contains(entry.entryId)
        dayVM.moveEntries(inAuswahl ? Array(selectedEntryIds) : [entry.entryId], to: meal)
        selectedEntryIds.removeAll()
    }

    private func toggleSelection(_ entryId: String) {
        if selectedEntryIds.contains(entryId) {
            selectedEntryIds.remove(entryId)
        } else {
            selectedEntryIds.insert(entryId)
        }
    }

    /// Auswahl faerbt staerker als die Hervorhebung frisch gebuchter Eintraege.
    private func rowTint(_ entry: DiaryEntry, isHighlighted: Bool) -> Double {
        if selectedEntryIds.contains(entry.entryId) { return 0.18 }
        return isHighlighted ? 0.08 : 0
    }

    /// Ausgegraute Zeile fuer einen geplanten Eintrag (Issue #99). Zaehlt in keine
    /// Summe; ein Tap uebernimmt ihn sofort als echten Eintrag, Swipe und
    /// Kontextmenue verwerfen ihn spurlos.
    private func plannedRow(_ plan: PlannedEntry, dayVM: DayViewModel) -> some View {
        HStack {
            Image(systemName: "calendar.badge.clock")

            VStack(alignment: .leading, spacing: 2) {
                Text(plan.foodItem?.name ?? "—")
                    .font(.body)
                Text("planned_badge")
                    .font(.caption)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(plan.calories)) kcal")
                    .font(.body.bold())
                Text("\(Int(plan.amountGrams)) g")
                    .font(.caption)
            }

            #if os(macOS)
            // macOS: sichtbarer Verwerfen-Button (Swipe ist hier umstaendlich)
            Button {
                dayVM.discardPlannedEntry(plan)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("planned_discard")
            #endif
        }
        .padding(.vertical, 2)
        .foregroundStyle(.secondary)
        .opacity(0.55)
        .contentShape(Rectangle())
        .onTapGesture { dayVM.acceptPlannedEntry(plan) }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                dayVM.discardPlannedEntry(plan)
            } label: {
                Label("planned_discard", systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                dayVM.acceptPlannedEntry(plan)
            } label: {
                Label("planned_accept", systemImage: "checkmark.circle")
            }
            Button(role: .destructive) {
                dayVM.discardPlannedEntry(plan)
            } label: {
                Label("planned_discard", systemImage: "trash")
            }
        }
    }

    // MARK: - Mahlzeiten-Liste

    private func mealList(_ dayVM: DayViewModel, _ focusVM: FocusViewModel) -> some View {
        let highlighted = Set(focusVM.lastBatchEntryIds)
        return List {
            // Datum und Kalorienring scrollen als erste Zeile mit hinaus (#86).
            // Ohne eigene Zeilen-Insets, damit die Tagespfeile am Rand stehen
            // bleiben, wo sie vorher standen.
            Section {
                dateHeader(dayVM)
                    #if os(iOS)
                    .simultaneousGesture(daySwipe)
                    #endif
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            // Hebel und Vitals-Kacheln — scrollen mit dem restlichen Inhalt (statt fest
            // ueber der Liste zu stehen). Fix bleiben nur Datum, Kalorienring und
            // Eingabefeld.
            cardRows(dayVM, focusVM)

            #if os(macOS)
            if !selectedEntryIds.isEmpty {
                Section {
                    cardRow { selectionBar(dayVM) }
                }
            }
            #endif

            ForEach(visibleMeals(dayVM)) { meal in
                mealSection(meal, dayVM: dayVM, focusVM: focusVM, highlighted: highlighted)
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        #else
        .listStyle(.inset)
        #endif
        // Listen-Hintergrund ausblenden, damit der Ambient-Hintergrund durchscheint
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 4, for: .scrollContent)
        // Ist der Ring hinausgescrollt, uebernimmt die Pille oben seine Zahl (#87).
        // Die Schwelle liegt hinter Datumszeile und Ring, nicht davor, damit die
        // Pille nicht erscheint, solange der Ring noch zu sehen ist.
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            // Auf 4 Punkte gerundet: der Wert steuert den Nebel und wuerde sonst
            // bei jedem Frame eine neue Zeichnung ausloesen.
            ((geometry.contentOffset.y + geometry.contentInsets.top) / 4).rounded() * 4
        } action: { _, offset in
            scrollOffset = offset

            let away = offset > 150
            guard away != ringScrolledAway else { return }
            withAnimation(.easeInOut(duration: 0.2)) { ringScrolledAway = away }
        }
    }

    /// Hebel und Vitals-Kacheln. Im Querformat des iPhones stehen sie nebeneinander
    /// (Issue #85): dort ist die Hoehe knapp und die Breite frei, und zwei Zeilen
    /// haetten die Mahlzeiten vollends aus dem Bild geschoben.
    @ViewBuilder
    private func cardRows(_ dayVM: DayViewModel, _ focusVM: FocusViewModel) -> some View {
        let lever = leverViewModel.flatMap { $0.displayedLever == nil ? nil : $0 }

        if isLandscapePhone, let lever {
            Section {
                cardRow {
                    HStack(alignment: .top, spacing: 10) {
                        leverBar(lever, focusVM, isCompact: true)
                            .frame(maxWidth: .infinity)
                        vitalsTiles(dayVM)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        } else {
            if let lever {
                Section {
                    cardRow { leverBar(lever, focusVM, isCompact: false) }
                }
            }
            Section {
                cardRow { vitalsTiles(dayVM) }
            }
        }
    }

    private func leverBar(
        _ leverVM: FocusLeverViewModel,
        _ focusVM: FocusViewModel,
        isCompact: Bool
    ) -> some View {
        FocusLeverBar(
            viewModel: leverVM,
            lastBookedMeal: focusVM.lastBookedMeal,
            onOpenDetail: { showLeverDetail = true },
            isCompact: isCompact
        )
    }

    /// Zeilenkleid der mitscrollenden Karten: eigener Rand, keine Trennlinie,
    /// durchsichtiger Zeilenhintergrund, damit der Ambient-Hintergrund traegt.
    private func cardRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .listRowInsets(scrollingCardRowInsets)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    /// Eine einzelne Mahlzeiten-Rubrik mit Eintraegen, Header und Drop-Ziel.
    /// Ausgelagert, damit der Type-Checker den `mealList`-Ausdruck bewaeltigt.
    private func mealSection(
        _ meal: MealType,
        dayVM: DayViewModel,
        focusVM: FocusViewModel,
        highlighted: Set<String>
    ) -> some View {
        Section {
            ForEach(dayVM.entriesForMeal(meal)) { entry in
                entryRow(entry, dayVM: dayVM, isHighlighted: highlighted.contains(entry.entryId))
                #if os(iOS)
                    // Buendig mit Eingabefeld, Hebel und Vitals (alle bei 16 → 32 pt Rand).
                    // Ohne dies rueckt die insetGrouped-Liste die Zeilen weiter ein („flattrig").
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                #endif
            }
            ForEach(dayVM.plannedEntriesForMeal(meal), id: \.plannedEntryId) { plan in
                plannedRow(plan, dayVM: dayVM)
                #if os(iOS)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                #endif
            }
        } header: {
            mealHeader(meal, dayVM: dayVM, focusVM: focusVM)
                #if os(iOS)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 4, trailing: 16))
                #endif
        }
        // Transparente Zeilen: der Ambient-Hintergrund schimmert durch das Glas-Veil
        .listRowBackground(Color.clear)
        .onDrop(
            of: [.text],
            isTargeted: Binding(
                get: { dropTargetMeal == meal },
                set: { dropTargetMeal = $0 ? meal : nil }
            )
        ) { providers in
            handleDrop(providers, to: meal, dayVM: dayVM)
        }
    }

    private func mealHeader(_ meal: MealType, dayVM: DayViewModel, focusVM: FocusViewModel) -> some View {
        Button {
            // Rubrik als Ziel fuer die naechste Eingabe waehlen (toggle)
            focusVM.contextMeal = (focusVM.contextMeal == meal) ? nil : meal
        } label: {
            HStack {
                Image(systemName: meal.symbolName)
                Text(meal.localizedName)
                if focusVM.contextMeal == meal {
                    Image(systemName: "arrow.turn.down.right")
                        .foregroundStyle(.tint)
                }
                Spacer()
                Text("\(Int(dayVM.summaryForMeal(meal).totalCalories.rounded())) kcal")
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.tint.opacity(dropTargetMeal == meal ? 0.15 : 0))
            )
        }
        .buttonStyle(.plain)
    }

    private func visibleMeals(_ dayVM: DayViewModel) -> [MealType] {
        MealType.visibleTypes(showAll: showAllMealTypes) { meal in
            dayVM.entries.contains { $0.mealType == meal }
                || dayVM.plannedEntries.contains { $0.mealType == meal }
        }
    }

    /// Nimmt einen per Drag & Drop fallengelassenen Eintrag entgegen und verschiebt
    /// ihn in die Ziel-Mahlzeit (nutzt die bestehende DayViewModel-Logik).
    private func handleDrop(_ providers: [NSItemProvider], to meal: MealType, dayVM: DayViewModel) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadObject(ofClass: NSString.self) { reading, _ in
            guard let entryId = reading as? String, !entryId.isEmpty else { return }
            Task { @MainActor in
                dayVM.moveEntry(entryId, to: meal)
            }
        }
        return true
    }

    // MARK: - Einstellungen-Sheet

    private var settingsSheet: some View {
        NavigationStack {
            SettingsView()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("done") { showSettings = false }
                    }
                }
        }
        #if os(macOS)
        .frame(minWidth: 480, idealWidth: 560, minHeight: 480, idealHeight: 620)
        #endif
    }

    // MARK: - Aktionen

    private func setupIfNeeded() {
        if dayViewModel == nil {
            let vm = DayViewModel(modelContext: modelContext)
            vm.loadDay(date: selectedDate)
            dayViewModel = vm
        }
        if focusViewModel == nil {
            focusViewModel = FocusViewModel(modelContext: modelContext)
        }
        if leverViewModel == nil {
            leverViewModel = FocusLeverViewModel(modelContext: modelContext)
        }
    }

    private func submit() {
        guard let focusVM = focusViewModel else { return }
        Task {
            await focusVM.submit(date: selectedDate)
            reload()
        }
    }

    /// Analysiert Bilddaten (Fotomediathek) per KI, optional mit Notiz, und bucht sie (mit Undo-Banner).
    private func bookPhoto(data: Data, note: String?) {
        guard let focusVM = focusViewModel else { return }
        Task {
            await focusVM.submit(imageData: data, note: note, date: selectedDate)
            reload()
        }
    }

    #if os(iOS)
    /// Bucht ein Kamera-Foto ueber den bildbasierten Pfad (einmalige Kompression im Service), optional mit Notiz.
    private func bookPhoto(image: UIImage, note: String?) {
        guard let focusVM = focusViewModel else { return }
        Task {
            await focusVM.submit(image: image, note: note, date: selectedDate)
            reload()
        }
    }

    /// Loest einen gescannten Barcode auf (3-Tier: Offline-DB → SwiftData → OpenFoodFacts)
    /// und oeffnet bei Treffer das Mengen-Sheet; sonst ein Hinweis im Eingabebereich.
    private func resolveBarcode(_ barcode: String) {
        Task {
            let searchVM = FoodSearchViewModel(modelContext: modelContext)
            if let food = await searchVM.lookupBarcode(barcode) {
                scannedFood = food
            } else {
                focusViewModel?.errorMessage = String(localized: "focus_barcode_not_found")
            }
        }
    }

    /// Bucht das gescannte Lebensmittel mit gewaehlter Menge und Mahlzeit (mit Tagesreload).
    private func bookScannedFood(_ food: FoodItem, grams: Double, mealType: MealType) {
        let entry = DiaryEntry(
            date: selectedDate,
            mealType: mealType,
            amountGrams: grams,
            foodItem: food
        )
        modelContext.insert(entry)
        try? modelContext.save()
        focusViewModel?.contextMeal = nil
        reload()
    }
    #endif

    /// Baut eine plattformneutrale Vorschau fuer das Notiz-Sheet aus rohen Bilddaten.
    private func photoPreview(from data: Data) -> Image {
        #if canImport(UIKit)
        if let ui = UIImage(data: data) { return Image(uiImage: ui) }
        #elseif canImport(AppKit)
        if let ns = NSImage(data: data) { return Image(nsImage: ns) }
        #endif
        return Image(systemName: "photo")
    }

    /// Zieht die Ansicht auf den heutigen Tag nach, wenn seit dem letzten Blick
    /// ein Kalendertag vergangen ist (Issue #84). Der Tag beginnt um Mitternacht,
    /// wie ueberall sonst in der App.
    ///
    /// Wer bewusst einen vergangenen Tag geoeffnet hat, behaelt ihn: nachgezogen
    /// wird nur, was zuvor auf "heute" stand. Der Merkposten wandert trotzdem
    /// mit, sonst gaelte der Wechsel beim naechsten Aufruf als noch ausstehend.
    private func syncToCurrentDay() {
        let today = Date().startOfDay
        guard today != knownToday else { return }

        let wasOnToday = selectedDate.isSameDay(as: knownToday)
        knownToday = today
        guard wasOnToday else { return }

        goTo(today)
    }

    private func changeDay(_ delta: Int) {
        goTo(selectedDate.addingDays(delta).startOfDay)
    }

    /// Schlaegt einen Tag auf. Das Rueckgaengig-Banner gehoert zur letzten
    /// Buchung und wuerde sonst ueber einem fremden Tag stehen bleiben.
    private func goTo(_ date: Date) {
        selectedDate = date
        focusViewModel?.clearUndo()
        reload()
    }

    private func reload() {
        dayViewModel?.loadDay(date: selectedDate)
        leverViewModel?.load(for: selectedDate)
    }
}

// MARK: - Vitals-Kacheln (kompakt)

extension FocusDayView {
    /// Kompakte Kachelzeile fuer Gewicht, Wasser und Kaffee — bewusst reduziert
    /// fuer den Fokus-Modus, nutzt dieselben DayViewModel-Aktionen wie das Dashboard.
    fileprivate func vitalsTiles(_ dayVM: DayViewModel) -> some View {
        HStack(alignment: .top, spacing: 10) {
            weightTile(dayVM)
            waterTile(dayVM)
            coffeeTile(dayVM)
        }
    }

    /// Gemeinsamer Kachel-Rahmen: gleiche Hoehe, abgerundeter Hintergrund.
    fileprivate func vitalTileContainer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 6, content: content)
            .padding(.horizontal, 8)
            .padding(.top, 12)
            // Oben ausrichten: so sitzen die Icons aller drei Kacheln auf gleicher
            // Hoehe, auch wenn die Gewicht-Kachel keine +/- Buttons hat.
            .frame(maxWidth: .infinity)
            // Hoch genug, dass Icon, Wert und die +/- Buttons harmonisch in die Kachel
            // passen (kein Ueberstehen der Buttons ueber den abgerundeten Rand).
            .frame(height: 112, alignment: .top)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(.quaternary, lineWidth: 0.5)
            )
    }

    /// Fortschritt vom Start- zum Zielgewicht (0…1). `nil`, wenn Start oder Ziel
    /// fehlen oder identisch sind — dann zeigt die Kachel nur das Icon ohne Ring.
    fileprivate func weightProgress(_ dayVM: DayViewModel) -> Double? {
        guard let start = dayVM.profile?.startWeightKg,
              let goal = dayVM.profile?.weightGoalKg,
              start != goal else { return nil }
        let current = dayVM.dayRecord?.weight ?? dayVM.profile?.bodyWeightKg
        guard let current else { return nil }
        // Funktioniert fuer Abnehmen (start > goal) und Zunehmen (start < goal),
        // weil Zaehler und Nenner das gleiche Vorzeichen tragen.
        return min(max((start - current) / (start - goal), 0), 1)
    }

    fileprivate func weightTile(_ dayVM: DayViewModel) -> some View {
        vitalTileContainer {
            Group {
                if let progress = weightProgress(dayVM) {
                    VitalRingIcon(progress: progress, color: .purple, systemImage: "scalemass.fill")
                } else {
                    ZStack {
                        Circle().fill(Color.purple.opacity(0.15))
                        Image(systemName: "scalemass.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.purple)
                    }
                }
            }
            .frame(width: 42, height: 42)

            if let weight = dayVM.dayRecord?.weight {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.1f", weight)).font(.subheadline.bold())
                    Text("kg").font(.caption2).foregroundStyle(.secondary)
                }
            } else {
                Text(verbatim: "–").font(.subheadline.bold()).foregroundStyle(.secondary)
            }
            Text("weight_title").font(.caption2).foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture { showWeightSheet = true }
    }

    fileprivate func waterTile(_ dayVM: DayViewModel) -> some View {
        let ml = dayVM.dayRecord?.waterIntakeMl ?? 0
        let goal = dayVM.profile?.dailyWaterGoalMl ?? 2000
        return vitalTileContainer {
            VitalRingIcon(progress: Double(ml) / Double(max(goal, 1)), color: .blue, systemImage: "drop.fill")
                .frame(width: 42, height: 42)
            Text("\(ml) ml").font(.subheadline.bold())
            HStack(spacing: 6) {
                vitalButton(action: { dayVM.addWater(ml: 250, for: selectedDate) }) {
                    Text(verbatim: "+250").lineLimit(1).minimumScaleFactor(0.7)
                }
                vitalButton(action: { dayVM.addWater(ml: 500, for: selectedDate) }) {
                    Text(verbatim: "+500").lineLimit(1).minimumScaleFactor(0.7)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { showWaterSheet = true }
    }

    fileprivate func coffeeTile(_ dayVM: DayViewModel) -> some View {
        let cups = dayVM.dayRecord?.coffeeCups ?? 0
        let goal = dayVM.coffeeGoal(for: selectedDate)
        let streak = dayVM.coffeeStreak
        return vitalTileContainer {
            VitalRingIcon(progress: goal > 0 ? Double(cups) / Double(goal) : 0, color: .brown, systemImage: "cup.and.saucer.fill")
                .frame(width: 42, height: 42)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(cups)").font(.subheadline.bold())
                Text(verbatim: "/\(goal)").font(.caption2).foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                vitalButton(action: { dayVM.removeCoffee(for: selectedDate) }) {
                    Image(systemName: "minus")
                }
                .disabled(cups <= 0)
                vitalButton(action: { dayVM.addCoffee(for: selectedDate) }) {
                    Image(systemName: "plus")
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if streak > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill").font(.system(size: 10))
                    Text("\(streak)").font(.caption2.bold())
                }
                .foregroundStyle(.orange)
                .padding(7)
            }
        }
    }

    /// Kompakter Glass-Button fuer die Vitals-Kacheln. Bewusst schlank
    /// (controlSize .small, geringe Hoehe), damit er auf iOS nicht wuchtig wirkt.
    private func vitalButton<Label: View>(
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button(action: action) {
            label()
                .font(.caption2.bold())
                .frame(maxWidth: .infinity, minHeight: 16)
        }
        .buttonStyle(.glass)
        .controlSize(.small)
    }
}

/// Identifiable-Wrapper, damit ein Kamera-Foto ein `.sheet(item:)` ausloesen kann.
#if os(iOS)
private struct FocusPendingCameraImage: Identifiable {
    let id = UUID()
    let image: UIImage
}
#endif

/// Identifiable-Wrapper fuer ein aus der Mediathek geladenes Foto.
private struct FocusPendingLibraryData: Identifiable {
    let id = UUID()
    let data: Data
}

/// Fortschrittsring mit zentriertem Symbol — fuer Wasser- und Kaffee-Kachel.
private struct VitalRingIcon: View {
    let progress: Double
    let color: Color
    let systemImage: String

    var body: some View {
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 3)
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: systemImage).font(.system(size: 15)).foregroundStyle(color)
        }
    }
}

#Preview {
    FocusDayView()
        .modelContainer(PreviewSampleData.container)
}
