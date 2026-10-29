import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/reference_medicine.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'barcode_scanner_sheet.dart';
import 'safety_alert_banner.dart';
import 'toast_helper.dart';

class AddMedicineSheet extends StatefulWidget {
  const AddMedicineSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const AddMedicineSheet(),
    );
  }

  @override
  State<AddMedicineSheet> createState() => _AddMedicineSheetState();
}

class _AddMedicineSheetState extends State<AddMedicineSheet> {
  int? _selectedBoxId;
  ReferenceMedicine? _selectedRefMed;
  bool _isManualEntry = false;
  String? _scannedBarcode;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(text: '20');

  String _selectedUnit = 'pill'; // 'pill', 'ml', 'mg', 'ampoule', 'unit'
  DateTime _expirationDate = DateTime.now().add(const Duration(days: 365));

  List<ReferenceMedicine> _suggestions = [];
  bool _isSearching = false;
  Timer? _debounceTimer;

  Map<String, dynamic>? _cdsSafetyReport;
  bool _isCheckingSafety = false;
  bool _isSubmitting = false;

  final List<Map<String, String>> _unitOptions = [
    {'value': 'pill', 'label': 'Таблетки / Капсулы'},
    {'value': 'ml', 'label': 'Миллилитры (мл)'},
    {'value': 'mg', 'label': 'Миллиграммы (мг)'},
    {'value': 'ampoule', 'label': 'Ампулы / Флаконы'},
    {'value': 'unit', 'label': 'Штуки / Упаковки'},
  ];

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _selectedBoxId = state.selectedBoxId;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _customNameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.length < 3) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _isSearching = true);
      try {
        final state = context.read<AppState>();
        final results = await state.apiService.searchReferenceMedicines(trimmed);
        if (mounted) {
          setState(() {
            _suggestions = results;
            _isSearching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  Future<void> _selectReferenceMedicine(ReferenceMedicine refMed) async {
    // Auto-detect unit based on dosage form
    String autoUnit = _selectedUnit;
    final form = refMed.dosageForm.toLowerCase();
    if (form.contains('капсул') || form.contains('таблет') || form.contains('драже')) {
      autoUnit = 'pill';
    } else if (form.contains('мл') || form.contains('раствор') || form.contains('капли') || form.contains('сироп') || form.contains('спрей')) {
      autoUnit = 'ml';
    } else if (form.contains('ампул') || form.contains('флакон')) {
      autoUnit = 'ampoule';
    } else if (form.contains('порошок') || form.contains('гранул') || form.contains('мг')) {
      autoUnit = 'mg';
    }

    setState(() {
      _selectedRefMed = refMed;
      _searchController.text = refMed.tradeName;
      _suggestions = [];
      _selectedUnit = autoUnit;
      _isCheckingSafety = true;
    });

    // Check CDS safety for this drug against active profile
    try {
      final state = context.read<AppState>();
      final profileId = state.selectedProfileId ?? state.profiles.firstOrNull?.id ?? 1;
      final report = await state.checkSafety(
        profileId: profileId,
        referenceMedicineId: refMed.id,
      );
      if (mounted) {
        setState(() {
          _cdsSafetyReport = report;
          _isCheckingSafety = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isCheckingSafety = false);
    }
  }

  Future<void> _startBarcodeScan() async {
    final barcode = await BarcodeScannerSheet.show(context);
    if (barcode == null || barcode.trim().isEmpty || !mounted) return;

    final cleanCode = barcode.trim();
    setState(() {
      _scannedBarcode = cleanCode;
      _isSearching = true;
    });

    try {
      final state = context.read<AppState>();
      final results = await state.apiService.searchReferenceMedicines(cleanCode);
      if (!mounted) return;

      if (results.isNotEmpty) {
        // Auto-select matched medicine from GRLS registry
        final matched = results.first;
        await _selectReferenceMedicine(matched);
        if (mounted) {
          ToastHelper.show(
            context,
            message: 'Препарат найден в ГРЛС: ${matched.tradeName} (${matched.dosage})',
            icon: '📷',
          );
        }
      } else {
        // Not found in registry: switch to manual entry and store barcode
        setState(() {
          _isManualEntry = true;
          _selectedRefMed = null;
          _cdsSafetyReport = null;
          _customNameController.text = _customNameController.text.isNotEmpty
              ? _customNameController.text
              : '';
        });
        if (mounted) {
          ToastHelper.show(
            context,
            message: 'Препарат не найден в реестре — введите название вручную (Штрихкод: $cleanCode)',
            icon: 'ℹ️',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.show(
          context,
          message: 'Ошибка поиска по штрихкоду: $e',
          icon: '⚠️',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _pickExpirationDate() async {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: _expirationDate.isAfter(tomorrow) ? _expirationDate : tomorrow,
      firstDate: tomorrow,
      lastDate: DateTime(now.year + 10),
      helpText: 'Выберите срок годности препарата',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );
    if (picked != null) {
      setState(() => _expirationDate = picked);
    }
  }

  Future<void> _submitForm() async {
    final state = context.read<AppState>();
    final boxId = _selectedBoxId ?? state.selectedBox?.id ?? 1;

    final String? customName = _isManualEntry || _selectedRefMed == null
        ? _customNameController.text.trim()
        : null;

    if (!_isManualEntry && _selectedRefMed == null && (customName == null || customName.isEmpty)) {
      ToastHelper.show(
        context,
        message: 'Выберите лекарство из справочника или введите вручную',
        icon: '⚠️',
        isError: true,
      );
      return;
    }

    if (_isManualEntry && (customName == null || customName.isEmpty)) {
      ToastHelper.show(
        context,
        message: 'Введите наименование препарата',
        icon: '⚠️',
        isError: true,
      );
      return;
    }

    final quantity = double.tryParse(_quantityController.text.trim()) ?? 0;
    if (quantity <= 0) {
      ToastHelper.show(
        context,
        message: 'Укажите количество препарата больше 0',
        icon: '⚠️',
        isError: true,
      );
      return;
    }

    final expMonth = _expirationDate.month.toString().padLeft(2, '0');
    final expDay = _expirationDate.day.toString().padLeft(2, '0');
    final formattedExpDate = '${_expirationDate.year}-$expMonth-$expDay';

    final payload = <String, dynamic>{
      'medicine_box_id': boxId,
      'quantity': quantity,
      'quantity_unit': _selectedUnit,
      'expiration_date': formattedExpDate,
    };

    if (_selectedRefMed != null && !_isManualEntry) {
      payload['reference_medicine_id'] = _selectedRefMed!.id;
    }
    if (customName != null && customName.isNotEmpty) {
      payload['custom_trade_name'] = customName;
    }
    if (_scannedBarcode != null && _scannedBarcode!.isNotEmpty) {
      payload['barcode'] = _scannedBarcode;
    } else if (_selectedRefMed != null && _selectedRefMed!.barcode.isNotEmpty) {
      payload['barcode'] = _selectedRefMed!.barcode;
    }

    setState(() => _isSubmitting = true);

    try {
      await state.addMedicine(payload);
      if (mounted) {
        Navigator.of(context).pop();
        ToastHelper.show(
          context,
          message: 'Препарат успешно добавлен в аптечку!',
          icon: '✅',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        String errorMsg = 'Ошибка сохранения: проверьте введенные данные';
        if (e is DioException) {
          final serverMsg = e.response?.data?['message']?.toString();
          final errors = e.response?.data?['errors'] as Map<String, dynamic>?;
          if (errors != null && errors.isNotEmpty) {
            errorMsg = errors.values.first.toString();
          } else if (serverMsg != null && serverMsg.isNotEmpty) {
            errorMsg = serverMsg;
          }
        }
        ToastHelper.show(
          context,
          message: errorMsg,
          icon: '❌',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Добавить препарат',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Form Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              children: [
                // 1. Storage Box Dropdown
                const Text(
                  'АПТЕЧКА ХРАНЕНИЯ',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedBoxId,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                      items: state.boxes.map((box) {
                        return DropdownMenuItem<int>(
                          value: box.id,
                          child: Text(
                            '${box.icon} ${box.name}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedBoxId = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Reference Search or Manual entry toggle with Checkbox
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ПРЕПАРАТ И СПРАВОЧНИК',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _isManualEntry,
                          activeColor: AppColors.primary,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          onChanged: (val) {
                            setState(() {
                              _isManualEntry = val ?? false;
                              if (_isManualEntry) {
                                _selectedRefMed = null;
                                _cdsSafetyReport = null;
                              }
                            });
                          },
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isManualEntry = !_isManualEntry;
                              if (_isManualEntry) {
                                _selectedRefMed = null;
                                _cdsSafetyReport = null;
                              }
                            });
                          },
                          child: const Text(
                            'Ввести вручную',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryHover,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                if (!_isManualEntry) ...[
                  // Catalog live search field + Barcode Scanner button
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Поиск по справочнику (от 3 букв, напр. Ибу)...',
                            hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
                            suffixIcon: _isSearching
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                    ),
                                  )
                                : _selectedRefMed != null
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 16),
                                        onPressed: () {
                                          setState(() {
                                            _selectedRefMed = null;
                                            _searchController.clear();
                                            _cdsSafetyReport = null;
                                            _scannedBarcode = null;
                                          });
                                        },
                                      )
                                    : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.primary),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _startBarcodeScan,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.primaryBorder),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.qr_code_scanner_rounded,
                            color: AppColors.primaryHover,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Scanned Barcode badge
                  if (_scannedBarcode != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.statusInfoBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primaryBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.qr_code_2_rounded, size: 16, color: AppColors.primaryHover),
                          const SizedBox(width: 6),
                          Text(
                            'Штрихкод: $_scannedBarcode',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryHover,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => setState(() => _scannedBarcode = null),
                            child: const Icon(Icons.close_rounded, size: 14, color: AppColors.primaryHover),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Suggestions list dropdown
                  if (_suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (ctx, index) {
                          final item = _suggestions[index];
                          return ListTile(
                            dense: true,
                            title: Text(
                              item.tradeName,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${item.inn} • ${item.dosageForm} ${item.dosage} (${item.manufacturer})',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                            trailing: item.isPrescription
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Rx', style: TextStyle(fontSize: 10, color: Color(0xFFB91C1C))),
                                  )
                                : null,
                            onTap: () => _selectReferenceMedicine(item),
                          );
                        },
                      ),
                    ),

                  // Selected medicine banner with auto-filled details
                  if (_selectedRefMed != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primaryBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Выбрано: ${_selectedRefMed!.tradeName}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDeep,
                                  ),
                                ),
                              ),
                              if (_selectedRefMed!.isPrescription)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('По рецепту', style: TextStyle(fontSize: 9, color: Color(0xFFB91C1C), fontWeight: FontWeight.w700)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'МНН: ${_selectedRefMed!.inn} • Дозировка: ${_selectedRefMed!.dosage}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          Text(
                            'Форма: ${_selectedRefMed!.dosageForm} • Производитель: ${_selectedRefMed!.manufacturer}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Live CDS Safety Alert
                    SafetyAlertBanner(
                      safetyData: _cdsSafetyReport,
                      isLoading: _isCheckingSafety,
                    ),
                  ],
                ] else ...[
                  // Manual entry TextField + Barcode scanner button
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customNameController,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Торговое наименование препарата...',
                            hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: const Icon(Icons.edit_note, size: 20, color: AppColors.textMuted),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.primary),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _startBarcodeScan,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.primaryBorder),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.qr_code_scanner_rounded,
                            color: AppColors.primaryHover,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Scanned Barcode badge in manual mode
                  if (_scannedBarcode != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.statusInfoBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primaryBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.qr_code_2_rounded, size: 16, color: AppColors.primaryHover),
                          const SizedBox(width: 6),
                          Text(
                            'Штрихкод: $_scannedBarcode',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryHover,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => setState(() => _scannedBarcode = null),
                            child: const Icon(Icons.close_rounded, size: 14, color: AppColors.primaryHover),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 14),

                // 3. Quantity & Unit
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quantity
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'КОЛИЧЕСТВО',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _quantityController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppColors.primary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Unit
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ЕДИНИЦА ИЗМЕРЕНИЯ',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedUnit,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.textSecondary),
                                items: _unitOptions.map((opt) {
                                  return DropdownMenuItem<String>(
                                    value: opt['value'],
                                    child: Text(
                                      opt['label']!,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedUnit = val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 4. Expiration DatePicker
                const Text(
                  'СРОК ГОДНОСТИ',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _pickExpirationDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined, color: AppColors.primaryHover, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          '${_expirationDate.day.toString().padLeft(2, '0')}.${_expirationDate.month.toString().padLeft(2, '0')}.${_expirationDate.year}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Изменить',
                          style: TextStyle(fontSize: 11, color: AppColors.primaryHover, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 5. Submit Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isSubmitting ? null : _submitForm,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Добавить в аптечку',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
