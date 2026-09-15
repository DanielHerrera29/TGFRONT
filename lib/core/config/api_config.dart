/// El arranque local fuerza este valor mediante --dart-define.
class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://tgback-api.onrender.com',
  );
}
