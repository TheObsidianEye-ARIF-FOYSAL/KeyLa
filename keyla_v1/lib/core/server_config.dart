/// Base URL of the ARIF(KyLa) PHP server (the `server/` folder alongside
/// this Flutter project). Override at build time with
/// `flutter run --dart-define=SERVER_BASE_URL=https://your-host.example.com/server`,
/// matching how med_remind_v2's AuthService/UserAuthService are configured.
const kServerBaseUrl = String.fromEnvironment(
  'SERVER_BASE_URL',
  defaultValue: 'https://your-host.example.com/server',
);
