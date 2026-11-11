# Money Tracker

[![GitHub](https://img.shields.io/badge/github-%23121011.svg?style=for-the-badge&logo=github&logoColor=white)](https://github.com/HeatherShein/expense-charts)

A Flutter app for tracking personal expenses and income against a monthly budget. Everything stays on the device (SQLite), with CSV and database import / export.

## Table of Contents

1. [Features](#features)
2. [Architecture](#architecture)
3. [Installation](#installation)
4. [Usage](#usage)
5. [CSV](#csv)
6. [Development](#development)

## Features

### Screens
- **Overview**: money left to spend this month, progress against an "even pace" marker, daily allowance, income vs expenses, a donut of the top 4 categories, and the 4 latest entries.
- **Analytics**: one bar chart with a Daily / Weekly / Monthly / Yearly switch, a dashed average line, tap a bar to see its value, average / highest / lowest tiles, and totals per category.
- **Activity**: search, category chips, month totals, and entries grouped by day. Multi-day entries show a *Period* tag and the cost per day (or night for trips).
- **Add entry** (the + button): expense or income, amount in any of your currencies, category grid, one day or a period.
- **Budget & data**: monthly budget, 80% alert, CSV / database import and export, backup, currencies, week start, appearance (light / dark / system).

### Currencies
Pick the preferred currency and manage the others with their rates in *Budget & data → Currency*. An entry typed in another currency is converted with the stored rate; the typed amount is kept so editing shows it. Changing the preferred currency re-bases the rates and can convert the stored amounts.

### Periods
An entry covering several days counts `amount / days` on each day in every chart and total.

### Categories
Grocery, Restaurant, Regular, Trip, Leisure, Health, Alcohol, Exceptional. Each has a fixed color and icon used on every screen. *Manage categories* is read-only for now.

## Architecture

```
lib/
├── constants/   # Categories: names, colors, icons, CSV names
├── models/      # Expense, Currency
├── pages/       # Overview, Analytics, Activity, Budget, Currencies, entry sheet
├── providers/   # ExpenseStore (entries in memory), CurrencyProvider, SettingsProvider
├── services/    # CSV codec, import / export / backup flows
├── theme/       # Design tokens (colors, sizes, fonts) and ThemeData
├── utils/       # Analytics calculations, dates, formatting, DatabaseHelper
└── widgets/     # Cards, pill switch, entry row, bottom bar, text prompt dialog
scripts/
└── data_process.py  # Processes the exported CSV
```

- Entries are loaded once into `ExpenseStore`; every screen computes its view with the pure functions in `utils/analytics.dart`.
- Settings are saved with `shared_preferences`; currencies live in the SQLite `currencies` table (database version 3, upgraded automatically from v1 / v2).
- Fonts: Inter and Space Grotesk are bundled in `assets/fonts` (SIL Open Font License). Icons: `lucide_icons_flutter`.

## Installation

### Prerequisites
- Flutter SDK 3.35 or newer (tested with 3.47.9)
- JDK 17
- Android SDK with platform 36 (`ANDROID_HOME` set)
- An Android phone with USB debugging enabled, or an emulator

The Android build uses Gradle 8.14.3, Android Gradle Plugin 8.11.1 and Kotlin 2.2.20, the minimums required by Flutter 3.47.

### Setup
1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Check the toolchain and that the phone is listed:
   ```bash
   flutter doctor
   flutter devices
   ```
4. Run the app:
   ```bash
   flutter run
   ```

### Building APK
```bash
flutter build apk --release
```

## Usage

### Adding and editing entries
- Tap **+**, enter the amount (tap the currency symbol to change currency), a label, a category, and the day or period. Tap **Save expense**.
- Tap an entry in Overview or Activity to edit or delete it. Long-press an entry in Activity to delete it.

### Budget
- Set the monthly budget with **Edit budget** (Overview) or **Change** (Budget & data).
- With the 80% alert on, the app warns you when a new expense takes the month past 80% of the budget.

### Data
- **Import CSV**: adds the rows that are not already in the database.
- **Import database**: merge a `.db` file into the current data, or replace it (asks for confirmation).
- **Export CSV**: this month, this year, everything, or a custom range.
- **Back up database**: saves a full copy of the SQLite file.

## CSV

Export and import use the same format as `scripts/data_process.py`, so an exported file can be imported again. Import also accepts the older raw-column format.
- **Columns**: Date, Intitulé, Montant, Type, Revenu/Dépense
- **Dates**: MM/DD/YYYY
- **Type**: French category name (Alcool, Course, …); empty for income
- **Revenu/Dépense**: -1 for an expense, 1 for income
- Period entries are exported with their start date only.

## Development

### Dependencies
- **sqflite** (+ `sqflite_common_ffi`): local database
- **provider**: state management
- **shared_preferences**: settings
- **fl_chart**: bar and donut charts
- **file_picker**: file selection for import / export
- **lucide_icons_flutter**: category and UI icons

### Testing
```bash
dart analyze lib test
flutter test
# Save PNGs of every screen (mockup sample data, 10 Nov 2026):
SCREENSHOT_DIR=/some/folder flutter test test/screens_test.dart
```

## License

MIT License.
