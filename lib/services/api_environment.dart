enum EnvironmentType {
  production,
  staging,
  local,
  custom,
}

class ApiEnvironment {
  final EnvironmentType type;
  final String name;
  final String baseUrl;
  final String description;

  const ApiEnvironment({
    required this.type,
    required this.name,
    required this.baseUrl,
    required this.description,
  });

  static const ApiEnvironment production = ApiEnvironment(
    type: EnvironmentType.production,
    name: 'Боевой сервер (Production)',
    baseUrl: 'http://e340043kek.temp.swtest.ru/api',
    description: 'Удаленный сервер SpaceWeb (MySQL 8.0, 19 миграций)',
  );

  static const ApiEnvironment staging = ApiEnvironment(
    type: EnvironmentType.staging,
    name: 'Тестовый контур (Staging Docker)',
    baseUrl: 'http://127.0.0.1:8080/api',
    description: 'Изолированный локальный Docker-контур (Nginx, PHP 8.4, MySQL 8.0)',
  );

  static const ApiEnvironment local = ApiEnvironment(
    type: EnvironmentType.local,
    name: 'Локальная разработка (Artisan Serve)',
    baseUrl: 'http://127.0.0.1:8000/api',
    description: 'Прямой запуск php artisan serve',
  );

  static List<ApiEnvironment> get all => [
        production,
        staging,
        local,
      ];

  static ApiEnvironment fromBaseUrl(String url) {
    final cleanUrl = url.trim().toLowerCase().replaceAll(RegExp(r'/+$'), '');
    for (final env in all) {
      if (env.baseUrl.toLowerCase().replaceAll(RegExp(r'/+$'), '') == cleanUrl) {
        return env;
      }
    }
    return ApiEnvironment(
      type: EnvironmentType.custom,
      name: 'Пользовательский сервер',
      baseUrl: url,
      description: 'Кастомный адрес сервера API',
    );
  }
}
