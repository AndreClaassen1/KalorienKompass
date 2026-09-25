# KalorienKompass

A calorie tracker for iPhone, Apple Watch and the Mac menu bar, with a barcode scanner, AI photo recognition and a calorie budget that adapts to what your Apple Watch measures.

Commercial calorie trackers are often expensive, ad-funded or share data with third parties. KalorienKompass keeps your diary on your devices and in your own iCloud.

> **Language:** the user interface is German. The code, documentation and issues are in English.

## Features

- **Daily diary** by meal (breakfast, lunch, dinner, snacks)
- **Barcode scanner**: scan a product, nutrition values come from Open Food Facts
- **AI photo recognition**: take a photo of a meal, Claude (Anthropic) estimates calories and macros
- **AI quick entry**: describe a meal in free text (also via Siri and Shortcuts) and get an estimate
- **Dynamic calorie budget** in three modes:
  - *Dynamic*: TDEE plus the active energy your Apple Watch measured (HealthKit)
  - *Estimated*: TDEE times an activity factor, without a watch
  - *Manual*: your own daily target
- **BMR/TDEE** after Mifflin-St Jeor, deficit planning for weight goals (0.25 to 1.0 kg per week)
- **Nutrient traffic light** after the UK FSA scheme
- **Apple Watch app** and watch complications, **iOS widgets**, **Mac menu bar app**
- **iCloud sync** between devices (SwiftData with CloudKit)
- **Command line tool `kk`** on the Mac, reading and writing the same store

## Requirements

- iOS 26.2, watchOS 26.2, macOS 26.2 or later
- Xcode 26.2 or later
- An Apple Developer account for HealthKit, App Groups and iCloud sync
- For photo recognition and AI quick entry: your own [Anthropic API key](https://console.anthropic.com/). Every request is billed to that key.

## Build and run

```bash
git clone https://github.com/AndreClaassen1/KalorienKompass.git
cd KalorienKompass
cp Secrets.xcconfig.example Secrets.xcconfig   # add your CLAUDE_API_KEY, or leave it empty
open KalorienKompass.xcodeproj
```

### Use your own team and identifiers

All bundle identifiers, the App Group and the iCloud container are derived from **one prefix**. To build under your own Apple Developer team, change two places:

1. In Xcode, select the project (not a target), *Build Settings*, and set
   - `BUNDLE_ID_PREFIX` to your reverse domain, e.g. `com.example`
   - `DEVELOPMENT_TEAM` to your team ID
2. In `Shared/Model/AppGroupPaths.swift`, set `BundleIDs.prefix` to the same prefix.

The unit test `AppGroupPathsTests` fails if the two disagree. Then enable the App Group (`group.<prefix>.KalorienKompass`) and the iCloud container (`iCloud.<prefix>.KalorienKompass`) for your team, plus the `.Debug` variants for debug builds.

From the command line:

```bash
xcodebuild -project KalorienKompass.xcodeproj -scheme KalorienKompass \
  -destination 'generic/platform=iOS Simulator' \
  BUNDLE_ID_PREFIX=com.example DEVELOPMENT_TEAM= CODE_SIGNING_ALLOWED=NO build
```

### Offline food database

The barcode search first looks into an offline SQLite database of German Open Food Facts products, which the app downloads from the author's server (`baseURL` in `Shared/Logic/DatabaseDownloadManager.swift`). Without it, the app falls back to the live Open Food Facts API. To host your own copy, run `Server/build_off_db.py` weekly on a web server (`OFF_OUTPUT_DIR` sets the output directory) and point `baseURL` to it.

### Command line tool

```bash
cd KalorienKompassCLI
swift build -c release
.build/release/kk --help
```

`kk` reads the App Group container of the Mac app. With your own prefix, set `KK_STORE_PATH` to the store path, or adjust `Store.swift`.

## Tests

```bash
# App logic (Swift Testing), on any iOS simulator
xcodebuild test -project KalorienKompass.xcodeproj -scheme KalorienKompass \
  -destination 'platform=iOS Simulator,name=<an installed iPhone simulator>' \
  -only-testing:KalorienKompassTests

# Command line tool
cd KalorienKompassCLI && swift test
```

## Data sources and disclaimer

Product data comes from [Open Food Facts](https://world.openfoodfacts.org), available under the [Open Database License](https://opendatacommons.org/licenses/odbl/1-0/).

Calorie and nutrient values, including the AI estimates, are approximations. **This app is not medical or nutritional advice.** If you want to lose weight or have health conditions, talk to a doctor.

## Contributing

Issues and pull requests are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md). This is a personal project, so there is no guaranteed support.

## License

KalorienKompass is licensed under the [Functional Source License, Version 1.1, MIT Future License](LICENSE.md) (FSL-1.1-MIT).

In short: you may use, study, modify and share the app for any purpose **except** building a competing commercial product or service from it. Each released version automatically becomes available under the MIT license two years after its release.

The name "KalorienKompass" and the app icon are not covered by the license.
