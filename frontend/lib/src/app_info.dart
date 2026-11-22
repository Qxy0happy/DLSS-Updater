/// Application version, injected at build time with
/// `--dart-define=APP_VERSION=<contents of VERSION>`.
const String appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '0.0.0-dev',
);
