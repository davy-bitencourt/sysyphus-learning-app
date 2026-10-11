# Sysyphus Learning App

## Overview

Sysyphus is a cross-platform study application built with Flutter. It lets users test their knowledge using customizable question banks, backed by a local database layer that stores questions, study sessions, review history, and user data.

What has been implemented so far:

- **Flutter project scaffolding** for Android, iOS, Web, Linux, macOS and Windows.
- **Local data layer (SQLite)** with dedicated schema classes for:
  - Questions
  - Packages (question banks)
  - Tags
  - Templates
  - Sessions
  - Review log (`revlog`) for detailed answer history
- **User system split into two entities**:
  - `profile` – in-app user data
  - `account` – authentication-related data
- **DAO layer (Data Access Objects)** for the entities above, adjusted to support the profile/account separation.
- **Existing screens** for questions, statistics and settings.
- **App icon configuration** for Android and iOS.

## Tech Stack

- **Language:** Dart (SDK `^3.9.2`)
- **Framework:** Flutter (Material Design)
- **Database:** SQLite via `sqflite` (with `sqflite_common_ffi` for desktop platforms)
- **Supported platforms:** Android, iOS, Web, Windows, macOS, Linux

## Dependencies

**Runtime**

| Package | Version |
| --- | --- |
| `cupertino_icons` | ^1.0.8 |
| `sqflite` | ^2.4.2 |
| `sqflite_common_ffi` | ^2.3.7+1 |
| `audioplayers` | ^6.1.0 |
| `image_picker` | ^1.1.2 |
| `file_picker` | ^8.1.2 |
| `path_provider` | ^2.1.4 |
| `path` | ^1.9.0 |
| `archive` | ^4.0.7 |

**Development**

| Package | Version |
| --- | --- |
| `flutter_test` | SDK |
| `flutter_lints` | ^5.0.0 |
| `flutter_launcher_icons` | ^0.13.1 |

## Setup

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) with Dart `^3.9.2`
- An emulator, a physical device, or a desktop/web target enabled in Flutter

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/davy-bitencourt/sysyphus-learning-app.git
   cd sysyphus-learning-app
   ```

2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Run the app:

   ```bash
   flutter run
   ```

   To run on the web:

   ```bash
   flutter run -d chrome
   ```

### Optional: regenerate launcher icons

```bash
dart run flutter_launcher_icons
```
