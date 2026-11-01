import 'package:flutter/material.dart';
import '../models/profile.dart';
import '../models/medicine_box.dart';
import '../models/medicine.dart';
import '../models/intake_log.dart';
import '../models/medical_note.dart';
import '../models/shopping_item.dart';
import '../models/user.dart';
import '../models/reference_medicine.dart';
import '../models/notification_item.dart';
import '../models/adherence_report.dart';
import '../services/api_service.dart';

class AppState extends ChangeNotifier {
  final ApiService apiService;

  User? _currentUser;
  int _activeTabIndex = 0; // 0: Сегодня, 1: Аптечка, 2: Заметки, 3: Семья
  int? _selectedProfileId = 1; // 1: Анна, null: Вся семья
  int _selectedBoxId = 1; // 1: Домашняя
  DateTime _selectedDate = DateTime.now();
  String _medicineFilter = 'all'; // 'all', 'expiring', 'expired'
  String _searchQuery = '';
  bool _isSyncing = false;
  bool _isLoading = true;

  AdherenceReport? _adherenceReport;
  bool _isLoadingReport = false;
  String _reportPeriod = '7_days'; // '7_days' | '30_days'

  List<Profile> _profiles = [];
  List<MedicineBox> _boxes = [];
  List<IntakeLog> _intakes = [];
  List<Medicine> _medicines = [];
  List<NotificationItem> _notifications = [];
  List<MedicalNote> _notes = [];
  final List<ShoppingItem> _shoppingItems = [
    const ShoppingItem(
      id: '1',
      name: 'Гексорал спрей',
      count: 1,
      dosage: '0.2%',
      patientName: 'Для Анны (ОРВИ)',
      sourceDescription: 'Из рецепта д-ра Иванова от 27 окт',
    ),
    const ShoppingItem(
      id: '2',
      name: 'Кардиомагнил',
      count: 1,
      dosage: '75 мг',
      patientName: 'Для Михаила (Гипертензия)',
      sourceDescription: 'Не хватает на курс',
    ),
    const ShoppingItem(
      id: '3',
      name: 'Бинт стерильный',
      count: 2,
      dosage: '7м х 14см',
      patientName: 'Общие',
      sourceDescription: 'Пополнение аптечки',
    ),
  ];
  final List<ShoppingItem> _purchasedItems = [];

  // Default times & notifications settings
  TimeOfDay _morningTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _lunchTime = const TimeOfDay(hour: 13, minute: 0);
  TimeOfDay _eveningTime = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay _nightTime = const TimeOfDay(hour: 22, minute: 0);
  bool _remindersEnabled = true;
  int _reminderOffsetMinutes = 15;
  bool _repeatOnMissed = true;

  AppState({required this.apiService}) {
    loadInitialData();
  }

  // Getters
  User? get currentUser => _currentUser;
  void setCurrentUser(User? user) {
    _currentUser = user;
    notifyListeners();
  }
  int get activeTabIndex => _activeTabIndex;
  int? get selectedProfileId => _selectedProfileId;
  int get selectedBoxId => _selectedBoxId;
  DateTime get selectedDate => _selectedDate;
  String get medicineFilter => _medicineFilter;
  String get searchQuery => _searchQuery;
  bool get isSyncing => _isSyncing;
  bool get isLoading => _isLoading;

  List<Profile> get profiles => _profiles;
  List<MedicineBox> get boxes => _boxes;
  List<IntakeLog> get intakes => _intakes;
  List<Medicine> get medicines => _medicines;
  List<NotificationItem> get notifications => _notifications;
  int get unreadNotificationsCount => _notifications.where((n) => !n.isRead).length;
  AdherenceReport? get adherenceReport => _adherenceReport;
  bool get isLoadingReport => _isLoadingReport;
  String get reportPeriod => _reportPeriod;
  List<MedicalNote> get notes => _notes;
  List<ShoppingItem> get shoppingItems => _shoppingItems;
  List<ShoppingItem> get purchasedItems => _purchasedItems;
  List<String> get shoppingList => _shoppingItems.map((e) => e.name).toList();
  int get shoppingListCount =>
      _shoppingItems.fold<int>(0, (sum, item) => sum + item.count);

  TimeOfDay get morningTime => _morningTime;
  TimeOfDay get lunchTime => _lunchTime;
  TimeOfDay get eveningTime => _eveningTime;
  TimeOfDay get nightTime => _nightTime;
  bool get remindersEnabled => _remindersEnabled;
  int get reminderOffsetMinutes => _reminderOffsetMinutes;
  bool get repeatOnMissed => _repeatOnMissed;

  void updateDefaultTime(String type, TimeOfDay time) {
    switch (type) {
      case 'morning':
        _morningTime = time;
        break;
      case 'lunch':
        _lunchTime = time;
        break;
      case 'evening':
        _eveningTime = time;
        break;
      case 'night':
        _nightTime = time;
        break;
    }
    notifyListeners();
  }

  void setRemindersEnabled(bool value) {
    _remindersEnabled = value;
    notifyListeners();
  }

  void setReminderOffsetMinutes(int minutes) {
    _reminderOffsetMinutes = minutes;
    notifyListeners();
  }

  void setRepeatOnMissed(bool value) {
    _repeatOnMissed = value;
    notifyListeners();
  }

  List<MedicalNote> get filteredNotes {
    var list = _notes;
    if (_selectedProfileId != null) {
      list = list.where((n) => n.profileId == _selectedProfileId).toList();
    }
    return list;
  }

  List<MedicalNote> get activeNotes =>
      filteredNotes.where((n) => !n.isArchived).toList();

  List<MedicalNote> get archivedNotes =>
      filteredNotes.where((n) => n.isArchived).toList();

  Profile? get selectedProfile {
    if (_selectedProfileId == null) return null;
    try {
      return _profiles.firstWhere((p) => p.id == _selectedProfileId);
    } catch (_) {
      return null;
    }
  }

  MedicineBox? get selectedBox {
    try {
      return _boxes.firstWhere((b) => b.id == _selectedBoxId);
    } catch (_) {
      return _boxes.isNotEmpty ? _boxes.first : null;
    }
  }

  void selectCalendarDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
    _fetchIntakesIfNeeded(_selectedDate);
  }

  Future<void> _fetchIntakesIfNeeded(DateTime date) async {
    if (apiService.isMockMode) return;
    final hasForDate = _intakes.any((i) => i.matchesDate(date));
    if (!hasForDate) {
      try {
        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final newLogs = await apiService.getIntakes(date: dateStr);
        if (newLogs.isNotEmpty) {
          final existingIds = _intakes.map((i) => i.id).toSet();
          for (final log in newLogs) {
            if (!existingIds.contains(log.id)) {
              _intakes.add(log);
            }
          }
          notifyListeners();
        }
      } catch (_) {}
    }
  }

  List<IntakeLog> getIntakesForDate(DateTime date, {int? profileId}) {
    final targetProfileId = profileId ?? _selectedProfileId;
    return _intakes.where((i) {
      final matchesProfile = targetProfileId == null || i.profileId == targetProfileId;
      return matchesProfile && i.matchesDate(date);
    }).toList();
  }

  List<IntakeLog> get filteredIntakes {
    return getIntakesForDate(_selectedDate);
  }

  int get takenIntakesCount => filteredIntakes.where((i) => i.isTaken).length;
  int get totalIntakesCount => filteredIntakes.length;

  List<Medicine> get currentBoxMedicines {
    return _medicines.where((m) => m.boxId == _selectedBoxId).toList();
  }

  int get countAllMedicines => currentBoxMedicines.length;
  int get countExpiringMedicines =>
      currentBoxMedicines.where((m) => m.status == 'expiring').length;
  int get countExpiredMedicines =>
      currentBoxMedicines.where((m) => m.status == 'expired').length;

  List<Medicine> get filteredMedicines {
    var list = currentBoxMedicines;

    if (_medicineFilter == 'expiring') {
      list = list.where((m) => m.status == 'expiring').toList();
    } else if (_medicineFilter == 'expired') {
      list = list.where((m) => m.status == 'expired').toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list
          .where((m) =>
              m.name.toLowerCase().contains(q) ||
              m.substance.toLowerCase().contains(q) ||
              m.manufacturer.toLowerCase().contains(q))
          .toList();
    }

    return list;
  }

  // Load Data
  Future<void> loadInitialData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        apiService.getProfiles(),
        apiService.getMedicineBoxes(),
        apiService.getIntakes(),
        apiService.getMedicines(),
        apiService.getMe(),
        apiService.getNotifications(),
      ]);
      _profiles = results[0] as List<Profile>;
      _boxes = results[1] as List<MedicineBox>;
      _intakes = results[2] as List<IntakeLog>;
      _medicines = results[3] as List<Medicine>;
      if (results[4] != null) {
        _currentUser = results[4] as User;
      }
      _notifications = results[5] as List<NotificationItem>;

      final savedBoxId = await apiService.storageService.getSelectedBoxId();
      if (savedBoxId != null && _boxes.any((b) => b.id == savedBoxId)) {
        _selectedBoxId = savedBoxId;
      } else if (_boxes.isNotEmpty && !_boxes.any((b) => b.id == _selectedBoxId)) {
        _selectedBoxId = _boxes.first.id;
      }

      final savedProfileId = await apiService.storageService.getSelectedProfileId();
      if (savedProfileId != null && _profiles.any((p) => p.id == savedProfileId)) {
        _selectedProfileId = savedProfileId;
      } else if (_profiles.isNotEmpty &&
          _selectedProfileId != null &&
          !_profiles.any((p) => p.id == _selectedProfileId)) {
        _selectedProfileId = _profiles.first.id;
      }

      if (_notes.isEmpty) {
        _notes = [
          MedicalNote(
            id: 1,
            profileId: 1,
            doctorName: 'Иванов А. В.',
            specialty: 'Терапевт',
            clinic: 'Городская поликлиника №4',
            diagnosis: 'ОРВИ, острый фарингит',
            date: DateTime.now().subtract(const Duration(days: 2)),
            content: 'Амоксиклав 500 мг 2 раза в день 7 дней, полоскание ромашкой, Нурофен 400 мг при температуре выше 38.5, Гексорал спрей 2 раза в день.',
            prescribedMedicines: MedicalNote.parseAndMatch(
              'Амоксиклав 500 мг 2 раза в день 7 дней, полоскание ромашкой, Нурофен 400 мг при температуре выше 38.5, Гексорал спрей 2 раза в день.',
              _medicines,
            ),
            isAudioDictated: true,
          ),
          MedicalNote(
            id: 2,
            profileId: 2,
            doctorName: 'Смирнова Е. П.',
            specialty: 'Кардиолог',
            clinic: 'Медицинский центр «Кардио»',
            diagnosis: 'Артериальная гипертензия II ст.',
            date: DateTime.now().subtract(const Duration(days: 10)),
            content: 'Кардиомагнил 75 мг вечером после ужина длительно, контроль артериального давления, диета с ограничением соли.',
            prescribedMedicines: MedicalNote.parseAndMatch(
              'Кардиомагнил 75 мг вечером после ужина длительно, контроль артериального давления, диета с ограничением соли.',
              _medicines,
            ),
          ),
          MedicalNote(
            id: 3,
            profileId: 3,
            doctorName: 'Кузнецова О. М.',
            specialty: 'Педиатр',
            clinic: 'Детская поликлиника №2',
            diagnosis: 'Острый ринофарингит',
            date: DateTime.now().subtract(const Duration(days: 5)),
            content: 'Називин 0.05% по 1 впрыскиванию 2 раза в день 5 дней, обильное теплое питье, витамины.',
            prescribedMedicines: MedicalNote.parseAndMatch(
              'Називин 0.05% по 1 впрыскиванию 2 раза в день 5 дней, обильное теплое питье, витамины.',
              _medicines,
            ),
          ),
        ];
      }
    } catch (e) {
      debugPrint('Error loading initial data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshData() async {
    try {
      final results = await Future.wait([
        apiService.getIntakes(),
        apiService.getMedicines(),
        apiService.getNotifications(),
      ]);
      _intakes = results[0] as List<IntakeLog>;
      _medicines = results[1] as List<Medicine>;
      _notifications = results[2] as List<NotificationItem>;

      // Обновляем сопоставления в существующих заметках
      _notes = _notes.map((note) {
        return note.copyWith(
          prescribedMedicines: MedicalNote.parseAndMatch(note.content, _medicines),
        );
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing data: $e');
    }
  }

  // Actions
  void setTab(int index) {
    if (_activeTabIndex != index) {
      _activeTabIndex = index;
      notifyListeners();
    }
  }

  void selectProfile(int? profileId) {
    _selectedProfileId = profileId;
    notifyListeners();
    if (profileId != null) {
      apiService.storageService.saveSelectedProfileId(profileId);
    }
  }

  void selectBox(int boxId) {
    _selectedBoxId = boxId;
    notifyListeners();
    apiService.storageService.saveSelectedBoxId(boxId);
  }

  Future<void> fetchAdherenceReport({String? period, int? profileId}) async {
    if (period != null) {
      _reportPeriod = period;
    }
    _isLoadingReport = true;
    notifyListeners();

    try {
      _adherenceReport = await apiService.getAdherenceReport(
        period: _reportPeriod,
        profileId: profileId ?? _selectedProfileId,
      );
    } catch (e) {
      debugPrint('Error fetching adherence report: $e');
    } finally {
      _isLoadingReport = false;
      notifyListeners();
    }
  }

  void setReportPeriod(String period) {
    if (_reportPeriod != period) {
      _reportPeriod = period;
      fetchAdherenceReport(period: period);
    }
  }

  Future<MedicineBox?> createMedicineBox({
    required String name,
    required String boxType,
    String? description,
  }) async {
    try {
      final newBox = await apiService.createMedicineBox(
        name: name,
        boxType: boxType,
        description: description,
      );
      _boxes.add(newBox);
      _selectedBoxId = newBox.id;
      notifyListeners();
      return newBox;
    } catch (e) {
      debugPrint('Error creating medicine box: $e');
      return null;
    }
  }

  Future<void> deleteMedicineBox(int boxId) async {
    try {
      final success = await apiService.deleteMedicineBox(boxId);
      if (success) {
        _boxes.removeWhere((b) => b.id == boxId);
        if (_selectedBoxId == boxId) {
          _selectedBoxId = _boxes.isNotEmpty ? _boxes.first.id : 1;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error deleting medicine box: $e');
    }
  }

  void setMedicineFilter(String filter) {
    _medicineFilter = filter;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<bool> markIntakeTaken(int intakeId) async {
    final success = await apiService.markIntakeTaken(intakeId, true);
    if (success) {
      await refreshData();
    }
    return success;
  }

  Future<bool> skipIntake(int intakeId, {String? reason}) async {
    final success = await apiService.skipIntake(intakeId, reason: reason);
    if (success) {
      await refreshData();
    }
    return success;
  }

  Future<bool> snoozeIntake(int intakeId, {int minutes = 15}) async {
    final success = await apiService.snoozeIntake(intakeId, minutes: minutes);
    if (success) {
      await refreshData();
    }
    return success;
  }

  Future<bool> toggleIntake(int intakeId) async {
    final item = _intakes.firstWhere((i) => i.id == intakeId);
    final nextStatus = !item.isTaken;
    final success = await apiService.markIntakeTaken(intakeId, nextStatus);
    if (success) {
      await refreshData();
    }
    return success;
  }

  Future<void> createIntakeCourse(Map<String, dynamic> payload) async {
    await apiService.createIntakeCourse(payload);
    await refreshData();
  }

  Future<void> loadMedicines() async {
    _medicines = await apiService.getMedicines();
    notifyListeners();
  }

  Future<void> loadIntakes({DateTime? date}) async {
    _intakes = await apiService.getIntakes();
    notifyListeners();
  }

  Future<Map<String, dynamic>> recordQuickIntake({
    required int medicineId,
    required int profileId,
    double quantity = 1.0,
    String? symptom,
  }) async {
    final result = await apiService.recordQuickIntake(
      medicineId: medicineId,
      profileId: profileId,
      quantity: quantity,
      symptom: symptom,
    );
    await refreshData();
    notifyListeners();
    return result;
  }

  Future<Medicine> addMedicine(Map<String, dynamic> data) async {
    final created = await apiService.addMedicine(data);
    _medicines = await apiService.getMedicines();
    notifyListeners();
    return created;
  }

  Future<Medicine> openMedicine(int medicineId, {int? daysAfterOpening}) async {
    final updated = await apiService.openMedicine(
      medicineId,
      daysAfterOpening: daysAfterOpening,
    );
    final idx = _medicines.indexWhere((m) => m.id == medicineId);
    if (idx != -1) {
      _medicines[idx] = updated;
    } else {
      _medicines.add(updated);
    }
    notifyListeners();
    return updated;
  }

  Future<void> fetchNotifications() async {
    try {
      _notifications = await apiService.getNotifications();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    }
  }

  Future<void> deleteNotification(int id) async {
    try {
      await apiService.deleteNotification(id);
      _notifications.removeWhere((n) => n.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  // Notes & Prescriptions actions
  void addNote(MedicalNote note) {
    _notes.insert(0, note);
    notifyListeners();
  }

  void deleteNote(int id) {
    _notes.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  void archiveNote(int id) {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notes[index] = _notes[index].copyWith(isArchived: true);
      notifyListeners();
    }
  }

  void unarchiveNote(int id) {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notes[index] = _notes[index].copyWith(isArchived: false);
      notifyListeners();
    }
  }

  void restoreNote(MedicalNote note, int atIndex) {
    final clamped = atIndex.clamp(0, _notes.length);
    _notes.insert(clamped, note);
    notifyListeners();
  }

  // Deduplication & quantity merge for shopping list
  void addToShoppingList(
    String medicineName, {
    int quantity = 1,
    String dosage = '',
    int? profileId,
    String? patientName,
    String? category,
    String? sourceDescription,
    int? sourceNoteId,
  }) {
    final cleanName = medicineName.trim();
    if (cleanName.isEmpty) return;

    final existingIndex = _shoppingItems.indexWhere(
      (item) => item.name.toLowerCase().trim() == cleanName.toLowerCase(),
    );

    if (existingIndex != -1) {
      final existing = _shoppingItems[existingIndex];
      _shoppingItems[existingIndex] = existing.copyWith(
        count: existing.count + quantity,
        patientName: patientName ?? existing.patientName,
        sourceDescription: sourceDescription ?? existing.sourceDescription,
        dosage: dosage.isNotEmpty ? dosage : existing.dosage,
      );
    } else {
      _shoppingItems.add(
        ShoppingItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: cleanName,
          count: quantity,
          dosage: dosage,
          profileId: profileId,
          patientName: patientName,
          category: category,
          sourceDescription: sourceDescription,
          sourceNoteId: sourceNoteId,
        ),
      );
    }
    notifyListeners();
  }

  ShoppingItem? removeFromShoppingList(String medicineName) {
    final cleanName = medicineName.trim().toLowerCase();
    final index = _shoppingItems.indexWhere(
      (item) => item.name.trim().toLowerCase() == cleanName || item.id == medicineName,
    );
    if (index != -1) {
      final removed = _shoppingItems.removeAt(index);
      notifyListeners();
      return removed;
    }
    return null;
  }

  void restoreShoppingItem(ShoppingItem item, [int? atIndex]) {
    final index = (atIndex ?? _shoppingItems.length).clamp(0, _shoppingItems.length);
    _shoppingItems.insert(index, item);
    notifyListeners();
  }

  /// Bridging data gap: upon marking medicine purchased in shopping list,
  /// add it to medicine box inventory and instantly update notes matching!
  Future<ShoppingItem?> purchaseShoppingItem(String medicineName, {int count = 1}) async {
    final cleanName = medicineName.trim();
    ShoppingItem? purchasedItem;

    final idx = _shoppingItems.indexWhere(
      (i) => i.name.trim().toLowerCase() == cleanName.toLowerCase() || i.id == cleanName,
    );
    if (idx != -1) {
      final item = _shoppingItems.removeAt(idx);
      purchasedItem = item.copyWith(isPurchased: true);
      _purchasedItems.insert(0, purchasedItem);
    } else {
      purchasedItem = ShoppingItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: cleanName,
        count: count,
        isPurchased: true,
      );
      _purchasedItems.insert(0, purchasedItem);
    }

    // Look for existing medicine in inventory
    final cleanLower = cleanName.toLowerCase();
    final existingMed = _medicines.cast<Medicine?>().firstWhere(
          (m) =>
              m != null &&
              (m.name.toLowerCase().contains(cleanLower) ||
                  cleanLower.contains(m.name.toLowerCase())),
          orElse: () => null,
        );

    if (existingMed != null) {
      final medIdx = _medicines.indexOf(existingMed);
      _medicines[medIdx] = existingMed.copyWith(
        remaining: existingMed.remaining + (count > 1 ? count * 10 : 20),
        total: existingMed.total + (count > 1 ? count * 10 : 20),
      );
    } else {
      final form = cleanLower.contains('спрей')
          ? 'Спрей'
          : (cleanLower.contains('капсул') ? 'Капсулы' : 'Таблетки');
      final quantity = form == 'Спрей' ? (count > 1 ? count : 1) : (count > 1 ? count * 10 : 20);

      final newId =
          (_medicines.map((m) => m.id).fold<int>(0, (a, b) => a > b ? a : b)) + 1;

      final created = Medicine(
        id: newId,
        boxId: _selectedBoxId,
        name: cleanName,
        substance: cleanName.split(' ').first,
        form: form,
        remaining: quantity,
        total: quantity,
        expiry: '12.2028',
        status: 'ok',
        manufacturer: 'Отечественный производитель',
        country: 'Россия',
      );
      _medicines.add(created);
    }

    // Reactive sync: immediately refresh note stock matches so 🔴 turns to 🟢 in active notes
    _notes = _notes.map((note) {
      return note.copyWith(
        prescribedMedicines: MedicalNote.parseAndMatch(note.content, _medicines),
      );
    }).toList();

    notifyListeners();
    return purchasedItem;
  }

  void unpurchaseShoppingItem(ShoppingItem item) {
    _purchasedItems.removeWhere(
      (i) => i.id == item.id || i.name.toLowerCase() == item.name.toLowerCase(),
    );
    _shoppingItems.add(item.copyWith(isPurchased: false));

    // Rollback inventory increment
    final cleanLower = item.name.trim().toLowerCase();
    final existingMed = _medicines.cast<Medicine?>().firstWhere(
          (m) =>
              m != null &&
              (m.name.toLowerCase().contains(cleanLower) ||
                  cleanLower.contains(m.name.toLowerCase())),
          orElse: () => null,
        );
    if (existingMed != null) {
      final medIdx = _medicines.indexOf(existingMed);
      final dec = item.count > 1 ? item.count * 10 : 20;
      final newRemaining = (existingMed.remaining - dec).clamp(0, 9999);
      if (newRemaining <= 0) {
        _medicines.removeAt(medIdx);
      } else {
        _medicines[medIdx] = existingMed.copyWith(remaining: newRemaining);
      }
    }

    _notes = _notes.map((note) {
      return note.copyWith(
        prescribedMedicines: MedicalNote.parseAndMatch(note.content, _medicines),
      );
    }).toList();

    notifyListeners();
  }

  void deletePurchasedItem(String id) {
    _purchasedItems.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  Future<Profile> updateProfile({
    required int id,
    required String name,
    required String role,
    DateTime? birthDate,
    List<String> allergies = const [],
    String notes = '',
  }) async {
    final avatar = role == 'Ребёнок'
        ? '👦'
        : (role == 'Родитель' || role == 'Папа'
            ? '👨'
            : (role == 'Мама'
                ? '👩'
                : (role == 'Бабушка' ||
                        role == 'Бабушка / Дедушка' ||
                        role == 'Дедушка'
                    ? '👵'
                    : '👤')));

    final formattedBirthDate = birthDate != null
        ? "${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}"
        : null;

    final data = {
      'name': name,
      'role': role,
      'notes': notes.isNotEmpty ? notes : role,
      'avatar_url': avatar,
      'birth_date': formattedBirthDate,
      'allergies': allergies,
    };

    final profile = await apiService.updateProfile(id, data);
    await loadInitialData();
    return profile;
  }

  Future<Profile> addProfile({
    required String name,
    required String role,
    DateTime? birthDate,
    List<String> allergies = const [],
  }) async {
    final avatar = role == 'Ребёнок'
        ? '👦'
        : (role == 'Родитель'
            ? '👨'
            : (role == 'Бабушка / Дедушка' ? '👵' : '👤'));

    final formattedBirthDate = birthDate != null
        ? "${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}"
        : null;

    final data = {
      'name': name,
      'role': role,
      'notes': role,
      'avatar_url': avatar,
      'birth_date': formattedBirthDate,
      'allergies': allergies,
    };

    final profile = await apiService.createProfile(data);
    await loadInitialData();
    return profile;
  }

  Future<Map<String, dynamic>> checkSafety({
    required int profileId,
    int? medicineId,
    int? referenceMedicineId,
  }) async {
    return apiService.checkMedicationSafety(
      profileId: profileId,
      medicineId: medicineId,
      referenceMedicineId: referenceMedicineId,
    );
  }

  Future<bool> triggerSync() async {
    _isSyncing = true;
    notifyListeners();

    final success = await apiService.syncOfflineDatabase();

    _isSyncing = false;
    notifyListeners();
    return success;
  }

  // ==========================================
  // ADMIN PANEL METHODS (LR 2 Table 1, lines 4-5)
  // ==========================================

  Future<List<Map<String, dynamic>>> getAdminUsers() async {
    return apiService.getAdminUsers();
  }

  Future<Map<String, dynamic>> toggleBlockUser(int userId, bool block) async {
    final res = await apiService.toggleBlockUser(userId, block);
    notifyListeners();
    return res;
  }

  Future<ReferenceMedicine> addReferenceMedicine(Map<String, dynamic> data) async {
    final created = await apiService.addReferenceMedicine(data);
    notifyListeners();
    return created;
  }

  Future<List<ReferenceMedicine>> searchReferenceMedicines(String query) async {
    return apiService.searchReferenceMedicines(query);
  }
}
