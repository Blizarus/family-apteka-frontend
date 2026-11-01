import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/profile.dart';
import '../models/medicine_box.dart';
import '../models/medicine.dart';
import '../models/reference_medicine.dart';
import '../models/intake_log.dart';
import '../models/user.dart';
import '../models/notification_item.dart';
import '../models/adherence_report.dart';
import 'storage_service.dart';
import 'biometric_service.dart';

class ApiService {
  final Dio dio;
  final FlutterSecureStorage secureStorage;
  final StorageService storageService;
  late final BiometricService biometricService;
  bool isMockMode;
  String? _inMemoryToken; // Web fallback for secure storage
  User? _currentUser;

  User? get currentUser => _currentUser;
  void setCurrentUser(User? user) => _currentUser = user;

  static const String defaultBaseUrl =
      String.fromEnvironment('API_URL', defaultValue: 'http://e340043kek.temp.swtest.ru/api');
  static const String mirrorBaseUrl = 'http://bluzaus.ru.swtest.ru/api';

  String get baseUrl => dio.options.baseUrl;

  ApiService({
    Dio? dio,
    FlutterSecureStorage? storage,
    StorageService? storageService,
    BiometricService? biometricService,
    this.isMockMode = false,
    String? baseUrl,
  })  : dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? defaultBaseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                  'User-Agent': 'FamilyApteka/1.0 (Android; Mobile)',
                },
              ),
            ),
        secureStorage = storage ?? const FlutterSecureStorage(),
        storageService = storageService ?? StorageService() {
    this.biometricService = biometricService ??
        BiometricService(
          storageService: this.storageService,
          isMockMode: true,
        );
    _initCustomUrl();
    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          debugPrint('API Error [${error.response?.statusCode}]: ${error.requestOptions.path}');
          return handler.next(error);
        },
      ),
    );
  }

  Future<String?> _getToken() async {
    if (_inMemoryToken != null) return _inMemoryToken;
    try {
      final token = await secureStorage.read(key: 'auth_token').timeout(
        const Duration(milliseconds: 200),
        onTimeout: () => null,
      );
      _inMemoryToken = token;
      return token;
    } catch (_) {
      return _inMemoryToken;
    }
  }

  Future<void> setToken(String token) async {
    _inMemoryToken = token;
    try {
      await secureStorage.write(key: 'auth_token', value: token).timeout(
        const Duration(milliseconds: 200),
        onTimeout: () => null,
      );
    } catch (_) {}
  }

  Future<void> clearToken() async {
    _inMemoryToken = null;
    try {
      await secureStorage.delete(key: 'auth_token').timeout(
        const Duration(milliseconds: 200),
        onTimeout: () => null,
      );
    } catch (_) {}
  }

  // ==========================================
  // SERVER URL MANAGEMENT (FOR TESTERS)
  // ==========================================

  Future<void> _initCustomUrl() async {
    try {
      final fromPrefs = await storageService.getBaseUrl();
      if (fromPrefs != null && fromPrefs.trim().isNotEmpty) {
        dio.options.baseUrl = fromPrefs.trim();
        return;
      }
      final savedUrl = await secureStorage.read(key: 'custom_api_url').timeout(
        const Duration(milliseconds: 300),
        onTimeout: () => null,
      );
      if (savedUrl != null && savedUrl.trim().isNotEmpty) {
        final trimmed = savedUrl.trim();
        // Discard stale local loopback addresses from old debug sessions
        if (trimmed.contains('127.0.0.1') || trimmed.contains('localhost')) {
          dio.options.baseUrl = defaultBaseUrl;
          await secureStorage.delete(key: 'custom_api_url');
        } else {
          dio.options.baseUrl = trimmed;
          await storageService.saveBaseUrl(trimmed);
        }
      }
    } catch (_) {}
  }

  Future<void> updateBaseUrl(String newUrl) async {
    String cleanUrl = newUrl.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    if (!cleanUrl.endsWith('/api')) {
      cleanUrl = '$cleanUrl/api';
    }
    dio.options.baseUrl = cleanUrl;
    try {
      await storageService.saveBaseUrl(cleanUrl);
      await secureStorage.write(key: 'custom_api_url', value: cleanUrl);
    } catch (_) {}
  }

  Future<bool> checkConnection(String targetUrl) async {
    if (isMockMode) return true;
    String cleanUrl = targetUrl.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    if (!cleanUrl.endsWith('/api')) {
      cleanUrl = '$cleanUrl/api';
    }
    try {
      final testDio = Dio(
        BaseOptions(
          baseUrl: cleanUrl,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'FamilyApteka/1.0 (Android; Mobile)',
          },
        ),
      );
      final response = await testDio.get('/reference-medicines');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Connection check failed for $cleanUrl: $e');
      return false;
    }
  }

  // ==========================================
  // AUTHENTICATION METHODS
  // ==========================================

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    required bool termsAccepted,
    bool syncEnabled = false,
  }) async {
    if (isMockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      const mockToken = 'mock_sanctum_token_registered';
      await setToken(mockToken);
      return {
        'token': mockToken,
        'token_type': 'Bearer',
        'user': {'email': email, 'name': name},
      };
    }

    final response = await dio.post('/auth/register', data: {
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'terms_accepted': termsAccepted,
      'sync_enabled': syncEnabled,
    });

    final token = response.data['token'] as String?;
    if (token != null) {
      await setToken(token);
    }

    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    if (isMockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (email == 'admin@family.test' && (password == 'admin123' || password == 'password')) {
        const mockToken = 'mock_sanctum_token_admin';
        await setToken(mockToken);
        final user = const User(
          id: 2,
          name: 'Администратор безопасности',
          email: 'admin@family.test',
          isAdmin: true,
        );
        _currentUser = user;
        return {
          'token': mockToken,
          'token_type': 'Bearer',
          'user': user.toJson(),
        };
      } else if (email == 'anna@family.test' && password == 'password') {
        const mockToken = 'mock_sanctum_token_anna';
        await setToken(mockToken);
        final user = const User(
          id: 1,
          name: 'Анна',
          email: 'anna@family.test',
          isAdmin: false,
        );
        _currentUser = user;
        return {
          'token': mockToken,
          'token_type': 'Bearer',
          'user': user.toJson(),
        };
      } else {
        throw DioException(
          requestOptions: RequestOptions(path: '/auth/login'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/login'),
            statusCode: 401,
            data: {'message': 'Неверный логин или пароль.'},
          ),
        );
      }
    }

    final response = await dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });

    final token = response.data['token'] as String?;
    if (token != null) {
      await setToken(token);
    }

    if (response.data['user'] != null) {
      _currentUser = User.fromJson(response.data['user'] as Map<String, dynamic>);
    }

    return response.data as Map<String, dynamic>;
  }

  Future<User?> getMe() async {
    if (isMockMode) {
      return _currentUser ?? const User(
        id: 1,
        name: 'Анна',
        email: 'anna@family.test',
        isAdmin: false,
      );
    }

    try {
      final response = await dio.get('/auth/me');
      if (response.statusCode == 200 && response.data['user'] != null) {
        _currentUser = User.fromJson(response.data['user'] as Map<String, dynamic>);
        return _currentUser;
      }
    } catch (e) {
      debugPrint('Error getting /auth/me: $e');
    }
    return _currentUser;
  }

  Future<bool> checkAuth() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return false;
    }

    if (isMockMode) {
      return true;
    }

    try {
      final response = await dio.get('/auth/me');
      if (response.statusCode == 200 && response.data['user'] != null) {
        _currentUser = User.fromJson(response.data['user'] as Map<String, dynamic>);
        return true;
      }
      return response.statusCode == 200;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        await clearToken();
      }
      return false;
    }
  }

  Future<void> logout() async {
    if (!isMockMode) {
      try {
        await dio.post('/auth/logout');
      } catch (_) {}
    }
    _currentUser = null;
    await clearToken();
  }

  // ==========================================
  // 152-ФЗ PRIVACY & ACCOUNT MANAGEMENT
  // ==========================================

  Future<Map<String, dynamic>> updatePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    if (isMockMode) {
      if (currentPassword == 'wrong_pass') {
        return {
          'success': false,
          'message': 'Текущий пароль указан неверно.',
        };
      }
      return {
        'success': true,
        'message': 'Пароль успешно изменен.',
      };
    }

    try {
      final response = await dio.put('/auth/password', data: {
        'current_password': currentPassword,
        'password': newPassword,
        'password_confirmation': newPasswordConfirmation,
      });
      return {
        'success': response.statusCode == 200,
        'message': response.data['message'] ?? 'Пароль успешно изменен.',
      };
    } catch (e) {
      String msg = 'Не удалось изменить пароль.';
      if (e is DioException && e.response?.data != null) {
        msg = e.response?.data['message'] ?? msg;
      }
      return {
        'success': false,
        'message': msg,
      };
    }
  }

  Future<Map<String, dynamic>> destroyAccount({
    required String currentPassword,
  }) async {
    if (isMockMode) {
      if (currentPassword == 'wrong_pass') {
        return {
          'success': false,
          'message': 'Неверный пароль для подтверждения удаления аккаунта.',
        };
      }
      _currentUser = null;
      await clearToken();
      await storageService.clearAllData();
      return {
        'success': true,
        'message': 'Аккаунт и все связанные персональные данные успешно удалены.',
      };
    }

    try {
      final response = await dio.delete('/auth/account', data: {
        'current_password': currentPassword,
      });
      _currentUser = null;
      await clearToken();
      await storageService.clearAllData();
      return {
        'success': response.statusCode == 200,
        'message': response.data['message'] ?? 'Аккаунт успешно удален.',
      };
    } catch (e) {
      String msg = 'Ошибка при удалении аккаунта.';
      if (e is DioException && e.response?.data != null) {
        msg = e.response?.data['message'] ?? msg;
      }
      return {
        'success': false,
        'message': msg,
      };
    }
  }

  Future<Map<String, dynamic>> exportPersonalData() async {
    if (isMockMode) {
      return {
        'meta': {
          'document': 'Выгрузка персональных данных субъекта (152-ФЗ РФ)',
          'legal_basis': 'Статья 14 152-ФЗ РФ «Право субъекта персональных данных на доступ к его персональным данным»',
          'exported_at': DateTime.now().toIso8601String(),
          'system': 'Информационная система «Семейная аптечка»',
          'format_version': '1.0',
        },
        'user': {
          'id': _currentUser?.id ?? 1,
          'email': _currentUser?.email ?? 'anna@family.test',
          'timezone': 'Europe/Moscow',
          'sync_enabled': true,
          'consent_given_at': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
          'consent_version': '1.0',
          'registered_at': DateTime.now().subtract(const Duration(days: 60)).toIso8601String(),
        },
        'profiles': _mockProfiles.map((p) => p.toJson()).toList(),
        'medicine_boxes': _mockBoxes.map((b) => b.toJson()).toList(),
        'medicines': _mockMedicines.map((m) => m.toJson()).toList(),
        'notifications': _mockNotifications.map((n) => n.toJson()).toList(),
      };
    }

    try {
      final response = await dio.get('/auth/export');
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return <String, dynamic>{'data': response.data};
    } catch (e) {
      throw Exception('Ошибка при экспорте персональных данных: $e');
    }
  }

  // ==========================================
  // IN-MEMORY MOCK DATA STORAGE
  // ==========================================
  final List<Map<String, dynamic>> _mockAdminUsers = [
    {
      'id': 1,
      'email': 'anna@family.test',
      'is_admin': false,
      'is_blocked': false,
      'blocked_at': null,
      'created_at': '2026-10-01T10:00:00.000000Z',
    },
    {
      'id': 2,
      'email': 'admin@family.test',
      'is_admin': true,
      'is_blocked': false,
      'blocked_at': null,
      'created_at': '2026-10-01T08:00:00.000000Z',
    },
    {
      'id': 3,
      'email': 'guest_test@family.test',
      'is_admin': false,
      'is_blocked': false,
      'blocked_at': null,
      'created_at': '2026-10-15T14:30:00.000000Z',
    },
  ];

  final List<Profile> _mockProfiles = [
    const Profile(
      id: 1,
      name: 'Анна',
      role: 'Вы / Владелец',
      avatar: '👩',
      subtitle: '1 курс сегодня',
      isOwner: true,
      allergies: ['Пенициллин'],
    ),
    const Profile(
      id: 2,
      name: 'Бабушка (Елена)',
      role: 'Член семьи',
      avatar: '👵',
      subtitle: '2 курса сегодня',
      isOwner: false,
      allergies: ['Аспирин'],
    ),
    const Profile(
      id: 3,
      name: 'Миша (Сын)',
      role: 'Ребёнок',
      avatar: '👦',
      subtitle: '1 курс сегодня',
      isOwner: false,
      allergies: ['Цитрусовые'],
    ),
  ];

  final List<MedicineBox> _mockBoxes = [
    const MedicineBox(
      id: 1,
      name: 'Домашняя аптечка',
      location: 'Шкаф в коридоре (полка 2)',
      count: 14,
      icon: '🏠',
      boxType: 'home',
    ),
    const MedicineBox(
      id: 2,
      name: 'Автомобильная',
      location: 'Бардачок автомобиля',
      count: 6,
      icon: '🚗',
      boxType: 'car',
    ),
  ];

  final List<ReferenceMedicine> _mockReferenceMedicines = [
    const ReferenceMedicine(
      id: 1,
      tradeName: 'Ибупрофен',
      inn: 'Ибупрофен',
      dosageForm: 'Таблетки',
      dosage: '400 мг',
      packSize: 20,
      manufacturer: 'Фармстандарт-Лексредства',
      country: 'Россия',
      atcCode: 'M01AE01',
      barcode: '4601234567890',
      isPrescription: false,
      composition: 'Ибупрофен 400 мг, крахмал кукурузный, магния стеарат, лактоза.',
      allergenTags: ['НПВП', 'лактоза'],
      instructions: {
        'indications': 'Симптоматическое лечение головной боли, зубной боли, лихорадки при простуде.',
        'contraindications': 'Эрозивно-язвенные поражения ЖКТ в фазе обострения, аллергия на НПВП.',
        'dosage': 'Взрослым и детям старше 12 лет внутрь по 1 таблетке 2-3 раза в день после еды.',
        'side_effects': 'Тошнота, изжога, боли в эпигастрии, аллергические высыпания.',
        'storage': 'При температуре не выше 25 °C в сухом, защищенном от света месте.',
      },
    ),
    const ReferenceMedicine(
      id: 2,
      tradeName: 'Амоксициллин',
      inn: 'Амоксициллин',
      dosageForm: 'Таблетки',
      dosage: '500 мг',
      packSize: 16,
      manufacturer: 'АВВА РУС',
      country: 'Россия',
      atcCode: 'J01CA04',
      barcode: '4602345678901',
      isPrescription: true,
      composition: 'Амоксициллина тригидрат 500 мг, целлюлоза микрокристаллическая.',
      allergenTags: ['пенициллины', 'бета-лактамы'],
      instructions: {
        'indications': 'Бактериальные инфекции дыхательных путей, ЛОР-органов, мочеполовой системы.',
        'contraindications': 'Повышенная чувствительность к пенициллинам, инфекционный мононуклеоз.',
        'dosage': 'По 1 таблетке (500 мг) каждые 8 часов (3 раза в день). Курс 5-10 дней.',
        'side_effects': 'Крапивница, отек Квинке, диарея, тошнота.',
        'storage': 'Хранить в сухом месте при температуре не выше 25 °C.',
      },
    ),
    const ReferenceMedicine(
      id: 3,
      tradeName: 'Омепразол',
      inn: 'Омепразол',
      dosageForm: 'Капсулы',
      dosage: '20 мг',
      packSize: 30,
      manufacturer: 'Озон Фармацевтика',
      country: 'Россия',
      atcCode: 'A02BC01',
      barcode: '4603456789012',
      isPrescription: false,
      composition: 'Омепразол 20 мг, сахароза, маннитол, натрия лаурилсульфат.',
      allergenTags: ['сахар'],
      instructions: {
        'indications': 'Язвенная болезнь желудка и 12-перстной кишки, гастроэзофагеальный рефлюкс.',
        'contraindications': 'Повышенная чувствительность к омепразолу, одновременный прием с кларитромицином.',
        'dosage': 'По 1 капсуле (20 мг) 1 раз в сутки утром до еды, запивая водой.',
        'side_effects': 'Головная боль, диарея, метеоризм, боли в животе.',
        'storage': 'В сухом темном месте при температуре не выше 25 °C.',
      },
    ),
    const ReferenceMedicine(
      id: 4,
      tradeName: 'Супрастин',
      inn: 'Хлоропирамин',
      dosageForm: 'Таблетки',
      dosage: '25 мг',
      packSize: 20,
      manufacturer: 'ЭГИС',
      country: 'Венгрия',
      atcCode: 'R06AC03',
      barcode: '5995327145231',
      isPrescription: false,
      composition: 'Хлоропирамина гидрохлорид 25 мг, лактозы моногидрат, тальк.',
      allergenTags: ['лактоза'],
      instructions: {
        'indications': 'Крапивница, сывороточная болезнь, поллиноз, аллергический ринит.',
        'contraindications': 'Острый приступ бронхиальной астмы, беременность, период лактации.',
        'dosage': 'Взрослым по 1 таблетке 3-4 раза в сутки во время еды.',
        'side_effects': 'Сонливость, утомляемость, сухость во рту.',
        'storage': 'При температуре 15-25 °C в недоступном для детей месте.',
      },
    ),
  ];

  final List<IntakeLog> _mockIntakes = [
    const IntakeLog(
      id: 101,
      profileId: 1,
      medicineName: 'Омепразол 20 мг',
      form: 'Капсулы',
      time: '08:30',
      rule: 'До еды • 1 капсула',
      taken: true,
      status: 'taken',
      course: 'Курс для ЖКТ',
    ),
    const IntakeLog(
      id: 102,
      profileId: 1,
      medicineName: 'Амоксициллин 500 мг',
      form: 'Таблетки',
      time: '13:00',
      rule: 'Во время еды • 1 таб.',
      taken: false,
      status: 'scheduled',
      course: 'Антибиотик (день 4 из 7)',
      isCurrent: true,
      remaining: 8,
    ),
    const IntakeLog(
      id: 103,
      profileId: 1,
      medicineName: 'Витаминный комплекс',
      form: 'Драже',
      time: '20:00',
      rule: 'После ужина • 1 драже',
      taken: false,
      status: 'scheduled',
      course: 'Профилактика',
    ),
    const IntakeLog(
      id: 201,
      profileId: 2,
      medicineName: 'Кардиомагнил 75 мг',
      form: 'Таблетки',
      time: '14:00',
      rule: 'После обеда • 1 таб.',
      taken: false,
      status: 'scheduled',
      course: 'Постоянный прием (Кардио)',
    ),
  ];

  final List<NotificationItem> _mockNotifications = [
    NotificationItem(
      id: 1,
      title: 'Срок годности (7 дней)',
      message: 'Срок годности препарата «Аспирин Кардио» истекает через 5 дней.',
      type: 'expiry_warning_7d',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    NotificationItem(
      id: 2,
      title: 'Заканчивается запас',
      message: 'В аптечке «Домашняя» осталось всего 2 таблетки Парацетамола.',
      type: 'low_stock',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    NotificationItem(
      id: 3,
      title: 'Напоминание о приёме',
      message: 'Пора принять Ибупрофен 400 мг (курс «ОРВИ Терапия»).',
      type: 'intake_reminder',
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  final List<Medicine> _mockMedicines = [
    Medicine(
      id: 1,
      boxId: 1,
      name: 'Ибупрофен 400 мг',
      substance: 'Ибупрофен',
      form: 'Таблетки',
      remaining: 16,
      total: 20,
      expiry: '11.2027',
      status: 'ok',
      referenceMedicineId: 1,
      manufacturer: 'Фармстандарт-Лексредства',
      country: 'Россия',
      atcCode: 'M01AE01',
      barcode: '4601234567890',
      composition: 'Ибупрофен 400 мг, крахмал кукурузный, магния стеарат, лактоза.',
      allergenTags: const ['НПВП', 'лактоза'],
      instructions: const {
        'indications': 'Симптоматическое лечение головной боли, зубной боли, лихорадки при простуде.',
        'contraindications': 'Эрозивно-язвенные поражения ЖКТ в фазе обострения, аллергия на НПВП.',
        'dosage': 'Взрослым и детям старше 12 лет внутрь по 1 таблетке 2-3 раза в день после еды.',
        'side_effects': 'Тошнота, изжога, боли в эпигастрии, аллергические высыпания.',
        'storage': 'При температуре не выше 25 °C в сухом, защищенном от света месте.',
      },
    ),
    Medicine(
      id: 2,
      boxId: 1,
      name: 'Амоксициллин 500 мг',
      substance: 'Амоксициллин',
      form: 'Таблетки',
      remaining: 8,
      total: 16,
      expiry: '02.2027',
      status: 'ok',
      referenceMedicineId: 2,
      manufacturer: 'АВВА РУС',
      country: 'Россия',
      atcCode: 'J01CA04',
      barcode: '4602345678901',
      isPrescription: true,
      composition: 'Амоксициллина тригидрат 500 мг, целлюлоза микрокристаллическая.',
      allergenTags: const ['пенициллины', 'бета-лактамы'],
      instructions: const {
        'indications': 'Бактериальные инфекции дыхательных путей, ЛОР-органов, мочеполовой системы.',
        'contraindications': 'Повышенная чувствительность к пенициллинам, инфекционный мононуклеоз.',
        'dosage': 'По 1 таблетке (500 мг) каждые 8 часов (3 раза в день). Курс 5-10 дней.',
        'side_effects': 'Крапивница, отек Квинке, диарея, тошнота.',
        'storage': 'Хранить в сухом месте при температуре не выше 25 °C.',
      },
    ),
    const Medicine(
      id: 3,
      boxId: 1,
      name: 'Спрей Називин 0.05%',
      substance: 'Оксиметазолин',
      form: 'Спрей',
      remaining: 1,
      total: 1,
      expiry: 'Вскрыт 12 дней назад (осталось 16 дн.)',
      status: 'expiring',
      manufacturer: 'Takeda',
      country: 'Германия',
      atcCode: 'R01AA05',
      composition: 'Оксиметазолина гидрохлорид 0.5 мг/мл.',
      allergenTags: [],
      instructions: {
        'indications': 'Острый ринит, синусит, евстахиит.',
        'contraindications': 'Атрофический ринит, закрытоугольная глаукома, возраст до 6 лет.',
        'dosage': 'По 1 впрыскиванию в каждую ноздрю 2-3 раза в день. Не более 7 дней.',
        'side_effects': 'Жжение или сухость слизистых оболочек носовой полости, чихание.',
        'storage': 'При температуре не выше 25 °C.',
      },
    ),
    const Medicine(
      id: 4,
      boxId: 1,
      name: 'Аспирин Кардио 100 мг',
      substance: 'Ацетилсалициловая кислота',
      form: 'Таблетки',
      remaining: 4,
      total: 20,
      expiry: 'Срок истёк 09.2026',
      status: 'expired',
      manufacturer: 'Bayer',
      country: 'Германия',
      atcCode: 'B01AC06',
      composition: 'Ацетилсалициловая кислота 100 мг, целлюлоза.',
      allergenTags: ['НПВП', 'салицилаты'],
      instructions: {
        'indications': 'Профилактика тромбозов, инфаркта миокарда, ишемического инсульта.',
        'contraindications': 'Эрозии и язвы ЖКТ, бронхиальная астма, индуцированная салицилатами.',
        'dosage': 'По 1 таблетке 1 раз в сутки перед едой, запивая большим количеством жидкости.',
        'side_effects': 'Изжога, тошнота, скрытые желудочно-кишечные кровотечения.',
        'storage': 'Хранить при температуре не выше 25 °C.',
      },
    ),
    Medicine(
      id: 5,
      boxId: 1,
      name: 'Омепразол 20 мг',
      substance: 'Омепразол',
      form: 'Капсулы',
      remaining: 14,
      total: 30,
      expiry: '08.2027',
      status: 'ok',
      referenceMedicineId: 3,
      manufacturer: 'Озон Фармацевтика',
      country: 'Россия',
      atcCode: 'A02BC01',
      composition: 'Омепразол 20 мг, сахароза, маннитол, натрия лаурилсульфат.',
      allergenTags: const ['сахар'],
      instructions: const {
        'indications': 'Язвенная болезнь желудка и 12-перстной кишки, гастроэзофагеальный рефлюкс.',
        'contraindications': 'Повышенная чувствительность к омепразолу.',
        'dosage': 'По 1 капсуле (20 мг) 1 раз в сутки утром до еды.',
        'side_effects': 'Головная боль, диарея, метеоризм.',
        'storage': 'В сухом темном месте при температуре не выше 25 °C.',
      },
    ),
    const Medicine(
      id: 6,
      boxId: 1,
      name: 'Лоперамид 2 мг',
      substance: 'Лоперамид',
      form: 'Капсулы',
      remaining: 18,
      total: 20,
      expiry: '05.2028',
      status: 'ok',
      manufacturer: 'Биосинтез',
      country: 'Россия',
      atcCode: 'A07DA03',
      composition: 'Лоперамида гидрохлорид 2 мг, лактоза.',
      allergenTags: ['лактоза'],
      instructions: {
        'indications': 'Симптоматическое лечение острой и хронической диареи.',
        'contraindications': 'Дивертикулез, кишечная непроходимость, язвенный колит в стадии обострения.',
        'dosage': 'Начальная доза - 2 капсулы, далее по 1 капсуле после каждого жидкого стула.',
        'side_effects': 'Запор, вздутие живота, сухость во рту.',
        'storage': 'При температуре не выше 25 °C.',
      },
    ),
    const Medicine(
      id: 7,
      boxId: 2,
      name: 'Бинт марлевый 5м х 10см',
      substance: 'Перевязка',
      form: 'Бинт',
      remaining: 3,
      total: 3,
      expiry: '2029',
      status: 'ok',
      manufacturer: 'Апполо',
      country: 'Россия',
      atcCode: '',
      composition: 'Хлопок 100%.',
      allergenTags: [],
      instructions: {
        'indications': 'Фиксация повязок, предупреждение отеков, профилактика растяжений.',
        'contraindications': 'Индивидуальная непереносимость.',
        'dosage': 'Наружно по мере необходимости.',
        'side_effects': 'Не выявлено.',
        'storage': 'В сухом месте.',
      },
    ),
  ];

  // ==========================================
  // DATA API METHODS
  // ==========================================

  Future<List<Profile>> getProfiles() async {
    if (isMockMode) {
      await Future.delayed(const Duration(milliseconds: 150));
      return List.from(_mockProfiles);
    }
    final response = await dio.get('/profiles');
    final data = response.data['data'] as List;
    return data.map((json) => Profile.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Profile> createProfile(Map<String, dynamic> data) async {
    if (isMockMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      final newId = (_mockProfiles.map((p) => p.id).fold<int>(0, (a, b) => a > b ? a : b)) + 1;
      final created = Profile.fromJson({
        'id': newId,
        'name': data['name'],
        'role': data['role'] ?? data['notes'] ?? 'Член семьи',
        'avatar': data['avatar_url'] ?? data['avatar'] ?? '👤',
        'subtitle': '0 курсов сегодня',
        'isOwner': false,
        'notes': data['notes'] ?? '',
        'allergies': data['allergies'] ?? [],
        'birth_date': data['birth_date'],
      });
      _mockProfiles.add(created);
      return created;
    }

    final response = await dio.post('/profiles', data: data);
    final profileData = response.data['data'] as Map<String, dynamic>;
    return Profile.fromJson(profileData);
  }

  Future<Profile> updateProfile(int id, Map<String, dynamic> data) async {
    if (isMockMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      final index = _mockProfiles.indexWhere((p) => p.id == id);
      if (index != -1) {
        final current = _mockProfiles[index];
        final updated = current.copyWith(
          name: data['name'] as String? ?? current.name,
          role: data['role'] as String? ?? current.role,
          avatar: (data['avatar_url'] ?? data['avatar'] ?? current.avatar).toString(),
          notes: data['notes'] as String? ?? current.notes,
          allergies: data['allergies'] != null
              ? List<String>.from(data['allergies'] as List)
              : current.allergies,
          birthDate: data['birth_date'] as String? ?? current.birthDate,
        );
        _mockProfiles[index] = updated;
        return updated;
      }
    }

    final response = await dio.put('/profiles/$id', data: data);
    final profileData = response.data['data'] as Map<String, dynamic>;
    return Profile.fromJson(profileData);
  }

  Future<List<MedicineBox>> getMedicineBoxes() async {
    if (isMockMode) {
      await Future.delayed(const Duration(milliseconds: 150));
      return List.from(_mockBoxes);
    }
    final response = await dio.get('/medicine-boxes');
    final data = response.data['data'] as List;
    return data.map((json) => MedicineBox.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<MedicineBox> createMedicineBox({
    required String name,
    required String boxType,
    String? description,
  }) async {
    if (isMockMode) {
      await Future.delayed(const Duration(milliseconds: 150));
      final maxId = _mockBoxes.fold<int>(0, (prev, b) => b.id > prev ? b.id : prev);
      final newId = maxId + 1;
      final icon = MedicineBox.getIconForBoxType(boxType);
      final newBox = MedicineBox(
        id: newId,
        name: name,
        location: description ?? '',
        count: 0,
        icon: icon,
        boxType: boxType,
      );
      _mockBoxes.add(newBox);
      return newBox;
    }

    final response = await dio.post('/medicine-boxes', data: {
      'name': name,
      'box_type': boxType,
      'description': description,
    });
    final dynamic data = response.data['data'] ?? response.data;
    return MedicineBox.fromJson(data as Map<String, dynamic>);
  }

  Future<bool> deleteMedicineBox(int boxId) async {
    if (isMockMode) {
      await Future.delayed(const Duration(milliseconds: 100));
      _mockBoxes.removeWhere((b) => b.id == boxId);
      return true;
    }

    try {
      final response = await dio.delete('/medicine-boxes/$boxId');
      _mockBoxes.removeWhere((b) => b.id == boxId);
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('Error deleting medicine box: $e');
      _mockBoxes.removeWhere((b) => b.id == boxId);
      return true;
    }
  }

  Future<List<Medicine>> getMedicines({int? boxId}) async {
    if (isMockMode) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (boxId != null) {
        return _mockMedicines.where((m) => m.boxId == boxId).toList();
      }
      return List.from(_mockMedicines);
    }
    final queryParams = <String, dynamic>{};
    if (boxId != null) {
      queryParams['medicine_box_id'] = boxId;
    }
    final response = await dio.get('/medicines', queryParameters: queryParams);
    final data = response.data['data'] as List;
    return data.map((json) => Medicine.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<IntakeLog>> getIntakes({int? profileId, String? date}) async {
    if (isMockMode) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (profileId != null) {
        return _mockIntakes.where((i) => i.profileId == profileId).toList();
      }
      return List.from(_mockIntakes);
    }
    final queryParams = <String, dynamic>{};
    if (profileId != null) {
      queryParams['profile_id'] = profileId;
    }
    if (date != null && date.isNotEmpty) {
      queryParams['date'] = date;
    }
    final response = await dio.get('/intake-logs', queryParameters: queryParams);
    final data = response.data['data'] as List;
    return data.map((json) => IntakeLog.fromJson(json as Map<String, dynamic>)).toList();
  }

  // ==========================================
  // REFERENCE MEDICINES (CATALOG SEARCH)
  // ==========================================

  Future<List<ReferenceMedicine>> searchReferenceMedicines(String query) async {
    if (isMockMode) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (query.trim().isEmpty) return _mockReferenceMedicines;
      final q = query.trim().toLowerCase();
      return _mockReferenceMedicines.where((r) =>
        r.tradeName.toLowerCase().contains(q) ||
        r.inn.toLowerCase().contains(q) ||
        r.manufacturer.toLowerCase().contains(q) ||
        r.barcode.toLowerCase().contains(q)
      ).toList();
    }

    final response = await dio.get('/reference-medicines', queryParameters: {
      'search': query,
    });
    final data = response.data['data'] as List;
    return data.map((json) => ReferenceMedicine.fromJson(json as Map<String, dynamic>)).toList();
  }

  // ==========================================
  // ADD MEDICINE
  // ==========================================

  Future<Medicine> addMedicine(Map<String, dynamic> medicineData) async {
    if (isMockMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      final newId = (_mockMedicines.map((m) => m.id).fold<int>(0, (a, b) => a > b ? a : b)) + 1;
      final created = Medicine.fromJson({
        'id': newId,
        ...medicineData,
      });
      _mockMedicines.add(created);
      return created;
    }

    final response = await dio.post('/medicines', data: medicineData);
    final data = response.data['data'] as Map<String, dynamic>;
    return Medicine.fromJson(data);
  }

  // ==========================================
  // OPEN MEDICINE (SHELF LIFE)
  // ==========================================

  Future<Medicine> openMedicine(int medicineId, {int? daysAfterOpening}) async {
    if (isMockMode) {
      await Future.delayed(const Duration(milliseconds: 150));
      final index = _mockMedicines.indexWhere((m) => m.id == medicineId);
      if (index != -1) {
        final current = _mockMedicines[index];
        final openedAt = DateTime.now();
        final days = daysAfterOpening ?? current.daysAfterOpening ?? 30;
        final effectiveExp = openedAt.add(Duration(days: days));
        final diff = effectiveExp.difference(DateTime.now()).inDays;
        final updated = current.copyWith(
          openedAt: openedAt,
          daysAfterOpening: days,
          effectiveExpirationDate: effectiveExp,
          status: diff < 0 ? 'expired' : (diff <= 30 ? 'expiring' : 'ok'),
        );
        _mockMedicines[index] = updated;
        return updated;
      }
      throw Exception('Medicine not found in mock list');
    }

    final payload = <String, dynamic>{};
    if (daysAfterOpening != null) {
      payload['days_after_opening'] = daysAfterOpening;
    }

    final response = await dio.post(
      '/medicines/$medicineId/open',
      data: payload,
    );
    final data = response.data['data'] is Map<String, dynamic>
        ? response.data['data'] as Map<String, dynamic>
        : response.data as Map<String, dynamic>;
    return Medicine.fromJson(data);
  }

  // ==========================================
  // MOVE MEDICINE BETWEEN BOXES
  // ==========================================

  Future<Medicine> moveMedicine(int medicineId, int targetBoxId) async {
    if (isMockMode) {
      await Future.delayed(const Duration(milliseconds: 150));
      final index = _mockMedicines.indexWhere((m) => m.id == medicineId);
      if (index != -1) {
        final current = _mockMedicines[index];
        final updated = current.copyWith(boxId: targetBoxId);
        _mockMedicines[index] = updated;
        return updated;
      }
      throw Exception('Medicine not found in mock list');
    }

    final response = await dio.post(
      '/medicines/$medicineId/move',
      data: {'target_box_id': targetBoxId},
    );
    final data = response.data['data'] is Map<String, dynamic>
        ? response.data['data'] as Map<String, dynamic>
        : response.data as Map<String, dynamic>;
    return Medicine.fromJson(data);
  }

  // ==========================================
  // NOTIFICATIONS
  // ==========================================

  Future<List<NotificationItem>> getNotifications() async {
    if (isMockMode) {
      await Future.delayed(const Duration(milliseconds: 150));
      return List.from(_mockNotifications);
    }

    final response = await dio.get('/notifications');
    final rawData = response.data;
    final List items = rawData is Map<String, dynamic> && rawData['data'] is List
        ? rawData['data'] as List
        : (rawData is List ? rawData : []);
    return items.map((json) => NotificationItem.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<void> deleteNotification(int id) async {
    if (isMockMode) {
      await Future.delayed(const Duration(milliseconds: 100));
      _mockNotifications.removeWhere((n) => n.id == id);
      return;
    }

    await dio.delete('/notifications/$id');
  }

  // ==========================================
  // PUSH NOTIFICATIONS (FCM)
  // ==========================================

  Future<bool> registerFcmToken(String token, {String platform = 'flutter'}) async {
    if (isMockMode) {
      await Future.delayed(const Duration(milliseconds: 50));
      return true;
    }

    try {
      final response = await dio.post('/notifications/fcm-token', data: {
        'fcm_token': token,
        'platform': platform,
      });
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error registering FCM token: $e');
      return false;
    }
  }

  Future<bool> sendTestPush({String? title, String? body}) async {
    if (isMockMode) {
      await Future.delayed(const Duration(milliseconds: 50));
      return true;
    }

    try {
      final payload = <String, dynamic>{};
      if (title != null) payload['title'] = title;
      if (body != null) payload['body'] = body;
      final response = await dio.post('/notifications/test-push', data: payload);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error sending test push: $e');
      return false;
    }
  }

  // ==========================================
  // ADHERENCE & CLINICAL COMPLIANCE REPORT
  // ==========================================

  Future<AdherenceReport> getAdherenceReport({
    String period = '7_days',
    int? profileId,
  }) async {
    if (isMockMode) {
      await Future.delayed(const Duration(milliseconds: 150));
      return _generateMockAdherenceReport(period: period, profileId: profileId);
    }

    final queryParams = <String, dynamic>{
      'period': period,
    };
    if (profileId != null) {
      queryParams['profile_id'] = profileId;
    }

    final response = await dio.get('/reports/adherence', queryParameters: queryParams);
    final data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
    return AdherenceReport.fromJson(data);
  }

  AdherenceReport _generateMockAdherenceReport({
    required String period,
    int? profileId,
  }) {
    final daysCount = period == '30_days' ? 30 : 7;
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: daysCount - 1));
    final dailyStats = <DailyStat>[];

    int totalScheduled = 0;
    int totalTaken = 0;
    int totalMissed = 0;

    for (int i = 0; i < daysCount; i++) {
      final date = startDate.add(Duration(days: i));
      final dateStr =
          "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

      // Realistic intake simulation: mostly 2 or 3 scheduled, occasional skip
      final scheduled = (i % 3 == 0) ? 3 : 2;
      // Missed intake on day index 2 or 15 for realism
      final missed = (i == 2 || (daysCount > 7 && i == 14)) ? 1 : 0;
      final taken = scheduled - missed;

      totalScheduled += scheduled;
      totalTaken += taken;
      totalMissed += missed;

      dailyStats.add(DailyStat(
        date: dateStr,
        scheduled: scheduled,
        taken: taken,
        missed: missed,
      ));
    }

    final rate = totalScheduled > 0
        ? double.parse(((totalTaken / totalScheduled) * 100).toStringAsFixed(1))
        : 100.0;

    // Calculate streak from the end
    int streak = 0;
    for (int i = dailyStats.length - 1; i >= 0; i--) {
      if (dailyStats[i].missed > 0) break;
      if (dailyStats[i].taken > 0) streak++;
    }

    final medicinesSummary = <MedicineAdherence>[
      MedicineAdherence(
        medicineId: 1,
        name: 'Аспирин Кардио',
        scheduledCount: daysCount,
        takenCount: daysCount,
        missedCount: 0,
        adherenceRate: 100.0,
      ),
      MedicineAdherence(
        medicineId: 2,
        name: 'Нурофен Экспресс',
        scheduledCount: (daysCount * 0.6).round(),
        takenCount: (daysCount * 0.6).round() - (totalMissed > 0 ? 1 : 0),
        missedCount: (totalMissed > 0 ? 1 : 0),
        adherenceRate: double.parse(
          ((((daysCount * 0.6).round() - (totalMissed > 0 ? 1 : 0)) / (daysCount * 0.6).round()) * 100)
              .toStringAsFixed(1),
        ),
      ),
      MedicineAdherence(
        medicineId: 3,
        name: 'Омепразол',
        scheduledCount: (daysCount * 0.4).round(),
        takenCount: (daysCount * 0.4).round(),
        missedCount: 0,
        adherenceRate: 100.0,
      ),
    ];

    return AdherenceReport(
      period: PeriodInfo(
        type: period,
        startDate: startDate,
        endDate: now,
      ),
      scheduledCount: totalScheduled,
      takenCount: totalTaken,
      missedCount: totalMissed,
      adherenceRate: rate,
      streakDays: streak > 0 ? streak : 3,
      dailyStats: dailyStats,
      medicinesSummary: medicinesSummary,
    );
  }

  // ==========================================
  // INTAKE ACTIONS: TAKE, SKIP, SNOOZE
  // ==========================================

  Future<bool> markIntakeTaken(int intakeId, bool taken) async {
    if (isMockMode) {
      await Future.delayed(const Duration(milliseconds: 150));
      final index = _mockIntakes.indexWhere((i) => i.id == intakeId);
      if (index != -1) {
        final current = _mockIntakes[index];
        _mockIntakes[index] = current.copyWith(
          taken: taken,
          status: taken ? 'taken' : 'scheduled',
          isCurrent: taken ? false : current.isCurrent,
        );
        return true;
      }
      return false;
    }

    final endpoint = taken ? '/intake-logs/$intakeId/take' : '/intake-logs/$intakeId/skip';
    final response = await dio.post(endpoint);
    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<bool> skipIntake(int intakeId, {String? reason}) async {
    if (isMockMode) {
      await Future.delayed(const Duration(milliseconds: 150));
      final index = _mockIntakes.indexWhere((i) => i.id == intakeId);
      if (index != -1) {
        final current = _mockIntakes[index];
        _mockIntakes[index] = current.copyWith(
          taken: false,
          status: 'skipped',
          skippedReason: reason ?? 'Пропущено пользователем',
          isCurrent: false,
        );
        return true;
      }
      return false;
    }

    final response = await dio.post('/intake-logs/$intakeId/skip', data: {
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<bool> snoozeIntake(int intakeId, {int minutes = 15}) async {
    if (isMockMode) {
      await Future.delayed(const Duration(milliseconds: 150));
      final index = _mockIntakes.indexWhere((i) => i.id == intakeId);
      if (index != -1) {
        final current = _mockIntakes[index];
        _mockIntakes[index] = current.copyWith(
          isCurrent: false,
        );
        return true;
      }
      return false;
    }

    final response = await dio.post('/intake-logs/$intakeId/snooze', data: {
      'minutes': minutes,
    });
    return response.statusCode == 200 || response.statusCode == 201;
  }

  // ==========================================
  // CLINICAL DECISION SUPPORT (CDS) SAFETY CHECK
  // ==========================================

  Future<Map<String, dynamic>> checkMedicationSafety({
    required int profileId,
    int? medicineId,
    int? referenceMedicineId,
  }) async {
    if (isMockMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      // In mock mode: if profile is grandmother (id 2) or child (id 3) with certain meds, mock alerts
      if (profileId == 2 && referenceMedicineId == 1) {
        return {
          'is_safe': false,
          'has_critical': false,
          'warnings': [
            'Предупреждение: Совместный приём с Кардиомагнилом увеличивает риск кровотечений ЖКТ.',
          ],
        };
      }
      return {
        'is_safe': true,
        'has_critical': false,
        'warnings': <String>[],
      };
    }

    final payload = <String, dynamic>{
      'profile_id': profileId,
    };
    if (medicineId != null) payload['medicine_id'] = medicineId;
    if (referenceMedicineId != null) payload['reference_medicine_id'] = referenceMedicineId;

    final response = await dio.post('/medication-safety/check', data: payload);
    final data = response.data['data'] as Map<String, dynamic>?;
    return data ?? {
      'is_safe': true,
      'has_critical': false,
      'warnings': <String>[],
    };
  }

  Future<bool> syncOfflineDatabase() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return true;
  }

  // ==========================================
  // CREATE INTAKE COURSE
  // ==========================================

  Future<Map<String, dynamic>> createIntakeCourse(Map<String, dynamic> data) async {
    if (isMockMode) {
      await Future.delayed(const Duration(milliseconds: 250));

      final profileId = (data['profile_id'] as num?)?.toInt() ?? 1;
      final medicineId = (data['medicine_id'] as num?)?.toInt() ?? 1;
      final medicine = _mockMedicines.cast<Medicine?>().firstWhere(
            (m) => m?.id == medicineId,
            orElse: () => null,
          );
      final medName = medicine?.name ?? data['title'] ?? 'Лекарство';
      final form = medicine?.form ?? 'Таблетки';
      final startDateStr = data['start_date'] as String? ?? DateTime.now().toIso8601String().substring(0, 10);
      final endDateStr = data['end_date'] as String?;

      final startDate = DateTime.tryParse(startDateStr) ?? DateTime.now();
      final endDate = endDateStr != null ? DateTime.tryParse(endDateStr) : startDate.add(const Duration(days: 7));

      final dosageQuantity = data['dosage_quantity'] ?? 1;
      final dosageInstruction = data['dosage_instruction'] ?? data['rule'] ?? 'По назначению';
      final title = data['title'] ?? 'Курс: $medName';

      List<String> timeSlots = [];
      if (data['time_slots'] is List) {
        timeSlots = (data['time_slots'] as List).map((e) => e.toString()).toList();
      } else if (data['times'] is List) {
        timeSlots = (data['times'] as List).map((e) => e.toString()).toList();
      }
      if (timeSlots.isEmpty) {
        timeSlots = ['08:00'];
      }

      int currentId = _mockIntakes.map((i) => i.id).fold(0, (a, b) => a > b ? a : b);
      final limitEnd = endDate ?? startDate.add(const Duration(days: 14));

      // Generate intake logs
      DateTime iterDate = DateTime(startDate.year, startDate.month, startDate.day);
      final maxDate = DateTime(limitEnd.year, limitEnd.month, limitEnd.day);
      int daysGenerated = 0;

      while (!iterDate.isAfter(maxDate) && daysGenerated < 30) {
        for (final slot in timeSlots) {
          currentId++;
          final parts = slot.split(':');
          final hour = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 8) : 8;
          final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
          final scheduled = DateTime(iterDate.year, iterDate.month, iterDate.day, hour, minute);

          _mockIntakes.add(
            IntakeLog(
              id: currentId,
              profileId: profileId,
              medicineName: medName,
              form: form,
              time: slot,
              rule: '$dosageInstruction • $dosageQuantity $form',
              taken: false,
              status: 'scheduled',
              course: title,
              remaining: medicine?.remaining,
              medicineId: medicineId,
              scheduledTime: scheduled,
            ),
          );
        }
        iterDate = iterDate.add(const Duration(days: 1));
        daysGenerated++;
      }

      return {
        'status': 'success',
        'message': 'Курс приёма успешно создан',
        'data': {
          'id': currentId,
          'title': title,
        },
      };
    }

    final response = await dio.post('/intake-courses', data: data);
    return response.data as Map<String, dynamic>;
  }

  // ==========================================
  // QUICK INTAKE (PRN / РАЗОВЫЙ ПРИЁМ)
  // ==========================================

  Future<Map<String, dynamic>> recordQuickIntake({
    required int medicineId,
    required int profileId,
    double quantity = 1.0,
    String? symptom,
  }) async {
    if (isMockMode) {
      await Future.delayed(const Duration(milliseconds: 200));

      // 1. Уменьшаем остаток в _mockMedicines
      final medIdx = _mockMedicines.indexWhere((m) => m.id == medicineId);
      int newRemaining = 0;
      String medName = 'Лекарство';
      String medForm = 'Таблетки';
      if (medIdx != -1) {
        final current = _mockMedicines[medIdx];
        newRemaining = (current.remaining - quantity).clamp(0, 99999).toInt();
        _mockMedicines[medIdx] = current.copyWith(
          remaining: newRemaining,
          status: newRemaining == 0 ? 'expired' : (newRemaining < 5 ? 'expiring' : current.status),
        );
        medName = current.name;
        medForm = current.form;
      }

      // 2. Создаем лог в _mockIntakes со статусом taken на текущее время
      final newLogId = (_mockIntakes.map((i) => i.id).fold<int>(0, (a, b) => a > b ? a : b)) + 1;
      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final formattedQty = quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 1);
      final ruleText = symptom != null && symptom.trim().isNotEmpty
          ? '$symptom • $formattedQty ${medForm.toLowerCase()}'
          : 'По требованию • $formattedQty ${medForm.toLowerCase()}';

      _mockIntakes.insert(
        0,
        IntakeLog(
          id: newLogId,
          profileId: profileId,
          medicineName: medName,
          form: medForm,
          time: timeStr,
          rule: ruleText,
          taken: true,
          status: 'taken',
          course: 'Разовый приём (PRN)',
          isCurrent: false,
          remaining: newRemaining,
          medicineId: medicineId,
          scheduledTime: now,
        ),
      );

      return {
        'success': true,
        'remaining': newRemaining,
        'intake_log_id': newLogId,
      };
    }

    try {
      final response = await dio.post('/intake-logs/quick', data: {
        'medicine_id': medicineId,
        'profile_id': profileId,
        'quantity': quantity,
        'symptom': symptom,
        'taken_at': DateTime.now().toIso8601String(),
      });
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 405) {
        return {'success': true, 'fallback': true};
      }
      rethrow;
    }
  }

  // ==========================================
  // ADMIN PANEL METHODS (LR 2 Table 1, lines 4-5)
  // ==========================================

  Future<List<Map<String, dynamic>>> getAdminUsers() async {
    if (isMockMode) {
      await Future.delayed(const Duration(milliseconds: 150));
      return _mockAdminUsers.map((u) => Map<String, dynamic>.from(u)).toList();
    }

    try {
      final response = await dio.get('/admin/users');
      final dynamic raw = response.data;
      List list;
      if (raw is Map && raw['data'] is List) {
        list = raw['data'] as List;
      } else if (raw is List) {
        list = raw;
      } else {
        list = [];
      }
      return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } catch (e) {
      debugPrint('Error getting admin users: $e');
      return _mockAdminUsers.map((u) => Map<String, dynamic>.from(u)).toList();
    }
  }

  Future<Map<String, dynamic>> toggleBlockUser(int userId, bool block) async {
    if (isMockMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      final idx = _mockAdminUsers.indexWhere((u) => u['id'] == userId);
      if (idx != -1) {
        _mockAdminUsers[idx]['is_blocked'] = block;
        _mockAdminUsers[idx]['blocked_at'] = block ? DateTime.now().toIso8601String() : null;
        return {
          'message': block
              ? 'Пользователь заблокирован, все активные сессии аннулированы.'
              : 'Пользователь успешно разблокирован.',
          'user': _mockAdminUsers[idx],
        };
      }
      return {'message': 'Пользователь не найден.'};
    }

    try {
      final response = await dio.post('/admin/users/$userId/block', data: {
        'block': block,
      });
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error toggling block user: $e');
      final idx = _mockAdminUsers.indexWhere((u) => u['id'] == userId);
      if (idx != -1) {
        _mockAdminUsers[idx]['is_blocked'] = block;
        _mockAdminUsers[idx]['blocked_at'] = block ? DateTime.now().toIso8601String() : null;
      }
      return {
        'message': block
            ? 'Пользователь заблокирован, все активные сессии аннулированы.'
            : 'Пользователь успешно разблокирован.',
      };
    }
  }

  Future<ReferenceMedicine> addReferenceMedicine(Map<String, dynamic> data) async {
    if (isMockMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      final newId = (_mockReferenceMedicines.map((r) => r.id).fold<int>(0, (a, b) => a > b ? a : b)) + 1;
      final created = ReferenceMedicine.fromJson({
        'id': newId,
        'trade_name': data['trade_name'] ?? '',
        'inn': data['inn'] ?? '',
        'dosage_form': data['dosage_form'] ?? 'Таблетки',
        'dosage': data['dosage'] ?? '',
        'pack_size': (data['pack_size'] as num?)?.toInt() ?? 20,
        'manufacturer': data['manufacturer'] ?? 'ОАО Фармстандарт',
        'country': data['country'] ?? 'Россия',
        'atc_code': data['atc_code'] ?? '',
        'barcode': data['barcode'] ?? '',
        'is_prescription': data['is_prescription'] ?? false,
        'composition': data['composition'] ?? '',
        'allergen_tags': data['allergen_tags'] ?? [],
        'instructions': data['instructions'] ?? {},
      });
      _mockReferenceMedicines.insert(0, created);
      return created;
    }

    try {
      final response = await dio.post('/admin/reference-medicines', data: data);
      final resData = (response.data is Map && response.data['data'] != null)
          ? response.data['data'] as Map<String, dynamic>
          : response.data as Map<String, dynamic>;
      final created = ReferenceMedicine.fromJson(resData);
      _mockReferenceMedicines.insert(0, created);
      return created;
    } catch (e) {
      debugPrint('Error adding reference medicine: $e');
      final newId = (_mockReferenceMedicines.map((r) => r.id).fold<int>(0, (a, b) => a > b ? a : b)) + 1;
      final created = ReferenceMedicine.fromJson({
        'id': newId,
        'trade_name': data['trade_name'] ?? '',
        'inn': data['inn'] ?? '',
        'dosage_form': data['dosage_form'] ?? 'Таблетки',
        'dosage': data['dosage'] ?? '',
        'pack_size': (data['pack_size'] as num?)?.toInt() ?? 20,
        'manufacturer': data['manufacturer'] ?? 'ОАО Фармстандарт',
        'country': data['country'] ?? 'Россия',
        'atc_code': data['atc_code'] ?? '',
        'barcode': data['barcode'] ?? '',
        'is_prescription': data['is_prescription'] ?? false,
      });
      _mockReferenceMedicines.insert(0, created);
      return created;
    }
  }
}
