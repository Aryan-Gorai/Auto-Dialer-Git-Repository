# Copilot / AI Agent Instructions for mynotes_flutter_main

Short, actionable guidance for coding agents working on this Flutter app.

1. Big picture
   - This is a Flutter mobile app (Android/iOS) with Firebase backend. Entrypoint: `lib/main.dart`.
   - Major areas:
     - `lib/services/` — service implementations (auth, firebase providers, BLoC wiring)
     - `lib/views/` — UI screens grouped by feature (list, dialer, notes, profile)
     - `lib/constants/` — routes and other small constants
     - `lib/new-login-pages/` — custom login/register screens
   - Auth is handled with a custom BLoC: `services/auth/bloc/auth_bloc.dart` and `services/auth/firebase_auth_provider.dart`.

2. What to change and how (concrete patterns)
   - Use the existing BlocProvider pattern in `lib/main.dart` when adding auth-protected screens.
   - Initialize Firebase before making Firestore calls. See `lib/views/list/list_view_visible.dart` which calls `Firebase.initializeApp()` in `initState()` — prefer centralizing initialization in `main()` when refactoring.
   - Firestore collections used: `lists_collection`, `lists`, `contact_notes`. Follow existing field names (`user_id`, `list_name`, `description`, `timestamp`) when reading/writing.
   - Navigation: app uses `MaterialApp.routes` in `main.dart`. Add new route constants in `lib/constants/routes.dart` and register them in `main.dart`.

3. Code patterns and conventions
   - File naming: most widgets use snake_case filenames (e.g., `list_view_visible.dart`) and classes may use lowerCamelCase for widget class names — preserve local style when editing.
   - UI state: widgets mostly use StatefulWidget; use `mounted` checks when updating state after async calls (existing code already follows this pattern).
   - Database access: direct Firestore calls in views are common. When adding complex logic, prefer moving queries into `lib/views/list/firebase_services.dart` or `lib/services/` to keep UI lean.

4. Build, test and run
   - Typical Flutter commands apply. From repo root use:
     - `flutter pub get` — fetch dependencies
     - `flutter run` — run on connected device or simulator
     - `flutter test` — run unit tests (project has `test/auth_test.dart`)
   - Firebase: uses native iOS/Android configs (`ios/Runner/`, `android/app/google-services.json`). Ensure platform-specific Firebase files are present before running on device.

5. Integration points & external deps
   - Firebase packages: `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_analytics` (see `pubspec.yaml`). Code assumes Firestore is used for lists and contact notes.
   - Contacts and permissions: `flutter_contacts`, `fast_contacts`, `permission_handler`, `fluttercontactpicker` — follow platform permission flows when editing contact-related features.

6. Files to reference when making changes (examples)
   - App entry & routes: `lib/main.dart`, `lib/constants/routes.dart`
   - Auth: `lib/services/auth/bloc/auth_bloc.dart`, `lib/services/auth/firebase_auth_provider.dart`
   - Lists UI & DB: `lib/views/list/list_view_visible.dart`, `lib/views/list/firebase_services.dart`
   - Dialer and contacts: `lib/views/dialer/dialer.dart`, `lib/views/call/contact_upload.dart`

7. Small, safe improvements agents should do automatically
   - Move scattered `Firebase.initializeApp()` calls into `main()` as a one-line central init.
   - Replace repeated Firestore query logic with helper functions in `lib/views/list/firebase_services.dart`.
   - Add `mounted` checks after async awaits before calling `setState()` (some files already do this; ensure consistency).

If anything in these instructions is unclear or you want the agent to include additional conventions (code formatting rules, CI commands, preferred state-management patterns), tell me which areas to expand and I will iterate.