/// Global app configuration for the Flutter frontend.
///
/// The backend base URL can be overridden at build time using:
///   flutter run --dart-define=BACKEND_BASE_URL=http://127.0.0.1:8000
const String kBackendBaseUrl = String.fromEnvironment(
  'BACKEND_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000',
);

