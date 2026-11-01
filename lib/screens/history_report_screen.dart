import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../models/adherence_report.dart';
import '../models/profile.dart';
import '../providers/app_state.dart';
import '../services/pdf_report_service.dart';
import '../theme/app_theme.dart';
import '../widgets/toast_helper.dart';

class HistoryReportScreen extends StatefulWidget {
  final int? initialProfileId;

  const HistoryReportScreen({
    super.key,
    this.initialProfileId,
  });

  static Future<void> show(BuildContext context, {int? profileId}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HistoryReportScreen(initialProfileId: profileId),
      ),
    );
  }

  @override
  State<HistoryReportScreen> createState() => _HistoryReportScreenState();
}

class _HistoryReportScreenState extends State<HistoryReportScreen> {
  int? _selectedProfileId;
  String _selectedPeriod = '7_days';
  final TextEditingController _doctorNotesController = TextEditingController();
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _selectedProfileId = widget.initialProfileId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      _selectedProfileId ??= state.selectedProfileId;
      state.fetchAdherenceReport(
        period: _selectedPeriod,
        profileId: _selectedProfileId,
      );
    });
  }

  @override
  void dispose() {
    _doctorNotesController.dispose();
    super.dispose();
  }

  Future<void> _exportPdf(AdherenceReport report, Profile? profile) async {
    setState(() => _isExporting = true);
    try {
      final pdfBytes = await PdfReportService.generateAdherencePdf(
        report: report,
        profile: profile,
        doctorNote: _doctorNotesController.text.trim(),
      );

      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: 'compliance_report_${profile?.name ?? "patient"}.pdf',
      );

      if (mounted) {
        ToastHelper.showSuccess(context, 'Отчёт успешно сформирован для врача');
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Ошибка формирования PDF: $e');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final report = state.adherenceReport;
    final isLoading = state.isLoadingReport;
    final profiles = state.profiles;

    final currentProfile = profiles.cast<Profile?>().firstWhere(
          (p) => p?.id == _selectedProfileId,
          orElse: () => null,
        );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Отчёт для врача',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(
              'Комплаенс и фармакотерапия',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          if (report != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip: 'Экспорт в PDF',
                icon: _isExporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      )
                    : const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary),
                onPressed: _isExporting ? null : () => _exportPdf(report, currentProfile),
              ),
            ),
        ],
      ),
      body: isLoading && report == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                // 1. Фильтры: Пациент и Период
                _buildFilterCard(profiles, state),
                const SizedBox(height: 16),

                if (report != null) ...[
                  // 2. Главная карточка комплаенса (Hero KPI)
                  _buildAdherenceHeroCard(report),
                  const SizedBox(height: 16),

                  // 3. Посуточная динамика приёмов (Интерактивный график)
                  _buildDailyChartCard(report.dailyStats),
                  const SizedBox(height: 16),

                  // 4. Дисциплина по препаратам
                  _buildMedicinesSummaryCard(report.medicinesSummary),
                  const SizedBox(height: 16),

                  // 5. Заметки к приёму врача & Кнопка печати
                  _buildDoctorNotesSection(report, currentProfile),
                ] else ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Нет данных по приёму за выбранный период'),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildFilterCard(List<Profile> profiles, AppState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ПАЦИЕНТ И ПЕРИОД АНАЛИЗА',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),

          // Переключатель членов семьи
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildProfileChip(
                  label: 'Вся семья',
                  isSelected: _selectedProfileId == null,
                  avatar: '👥',
                  onTap: () {
                    setState(() => _selectedProfileId = null);
                    state.fetchAdherenceReport(
                      period: _selectedPeriod,
                      profileId: null,
                    );
                  },
                ),
                ...profiles.map((p) => _buildProfileChip(
                      label: p.name,
                      isSelected: _selectedProfileId == p.id,
                      avatar: p.role == 'Ребёнок'
                          ? '👦'
                          : (p.role == 'Бабушка / Дедушка' ? '👵' : '👨'),
                      onTap: () {
                        setState(() => _selectedProfileId = p.id);
                        state.fetchAdherenceReport(
                          period: _selectedPeriod,
                          profileId: p.id,
                        );
                      },
                    )),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Переключатель периода (7 дней / 30 дней)
          Row(
            children: [
              Expanded(
                child: _buildPeriodButton('7 дней', '7_days', state),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPeriodButton('30 дней', '30_days', state),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileChip({
    required String label,
    required bool isSelected,
    required String avatar,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        avatar: Text(avatar, style: const TextStyle(fontSize: 13)),
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: const Color(0xFFCCFBF1), // Teal 100
        backgroundColor: AppColors.background,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? const Color(0xFF0D9488) : AppColors.textPrimary,
        ),
        side: BorderSide(
          color: isSelected ? const Color(0xFF0D9488) : AppColors.border,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildPeriodButton(String title, String periodCode, AppState state) {
    final isSelected = _selectedPeriod == periodCode;
    return InkWell(
      onTap: () {
        setState(() => _selectedPeriod = periodCode);
        state.fetchAdherenceReport(
          period: periodCode,
          profileId: _selectedProfileId,
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D9488) : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF0D9488) : AppColors.border,
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdherenceHeroCard(AdherenceReport report) {
    final rate = report.adherenceRate;
    final isHigh = rate >= 80.0;
    final isModerate = rate >= 60.0 && rate < 80.0;

    final primaryColor = isHigh
        ? const Color(0xFF0D9488)
        : (isModerate ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));
    final bgColor = isHigh
        ? const Color(0xFFF0FDFA)
        : (isModerate ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2));
    final borderColor = isHigh
        ? const Color(0xFF99F6E4)
        : (isModerate ? const Color(0xFFFDE68A) : const Color(0xFFFECACA));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Круговой индикатор процента комплаенса
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: CircularProgressIndicator(
                      value: (rate / 100).clamp(0.0, 1.0),
                      strokeWidth: 8,
                      backgroundColor: Colors.white,
                      color: primaryColor,
                    ),
                  ),
                  Text(
                    '${rate.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Описание клинического уровня
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        report.complianceLevelLabel.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isHigh
                          ? 'Отличная приверженность! Терапевтический эффект максимален.'
                          : (isModerate
                              ? 'Умеренный комплаенс. Рекомендуется устранить пропуски.'
                              : 'Низкий комплаенс! Высокий риск неэффективности курса.'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),

          // Нижняя плашка показателей
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricItem(
                label: 'Принято',
                value: '${report.takenCount}',
                sub: 'из ${report.scheduledCount}',
                color: const Color(0xFF0D9488),
              ),
              Container(width: 1, height: 32, color: AppColors.border),
              _buildMetricItem(
                label: 'Пропущено',
                value: '${report.missedCount}',
                sub: 'приёмов',
                color: report.missedCount > 0 ? const Color(0xFFEF4444) : AppColors.textMuted,
              ),
              Container(width: 1, height: 32, color: AppColors.border),
              _buildMetricItem(
                label: 'Серия дней',
                value: '${report.streakDays}',
                sub: 'без пропусков 🔥',
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    required String sub,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color),
        ),
        Text(
          sub,
          style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildDailyChartCard(List<DailyStat> stats) {
    if (stats.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ПОСУТОЧНАЯ ДИНАМИКА ПРИЁМОВ',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                children: [
                  _buildLegendDot(const Color(0xFF0D9488), 'Принято'),
                  const SizedBox(width: 8),
                  _buildLegendDot(const Color(0xFFEF4444), 'Пропуск'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Столбчатая диаграмма
          SizedBox(
            height: 140,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: (stats.length * 38.0).clamp(MediaQuery.of(context).size.width - 64, double.infinity),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: stats.map((stat) {
                    final maxVal = stats.map((s) => s.scheduled).fold<int>(1, (a, b) => a > b ? a : b);
                    final barHeight = stat.scheduled > 0 ? (stat.scheduled / maxVal) * 70 : 8.0;
                    final takenRatio = stat.scheduled > 0 ? (stat.taken / stat.scheduled) : 1.0;
                    final dateLabel = stat.date.length >= 5 ? stat.date.substring(5) : stat.date;

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (stat.scheduled > 0)
                              Text(
                                '${stat.taken}/${stat.scheduled}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: stat.hasMissed ? const Color(0xFFEF4444) : AppColors.textMuted,
                                ),
                              )
                            else
                              const SizedBox(height: 10),
                            const SizedBox(height: 4),
                            Container(
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: stat.scheduled == 0
                                    ? AppColors.border
                                    : (stat.hasMissed
                                        ? const Color(0xFFFECACA)
                                        : const Color(0xFFCCFBF1)),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: stat.hasMissed ? const Color(0xFFEF4444) : const Color(0xFF0D9488),
                                  width: 1,
                                ),
                              ),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: takenRatio,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: stat.hasMissed
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFF0D9488),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              dateLabel,
                              maxLines: 1,
                              style: const TextStyle(fontSize: 8, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
      ],
    );
  }

  Widget _buildMedicinesSummaryCard(List<MedicineAdherence> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ДИСЦИПЛИНА ПО ПРЕПАРАТАМ',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text(
              'Нет назначенных препаратов за этот период',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            )
          else
            ...items.map((m) {
              final isGood = m.adherenceRate >= 80;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            m.name,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          '${m.adherenceRate.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isGood ? const Color(0xFF0D9488) : const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: (m.adherenceRate / 100).clamp(0.0, 1.0),
                      backgroundColor: AppColors.border,
                      color: isGood ? const Color(0xFF0D9488) : const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(4),
                      minHeight: 6,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Принято: ${m.takenCount} из ${m.scheduledCount}',
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                        if (m.missedCount > 0)
                          Text(
                            'Пропусков: ${m.missedCount}',
                            style: const TextStyle(fontSize: 10, color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDoctorNotesSection(AdherenceReport report, Profile? profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'КОММЕНТАРИИ ДЛЯ ВРАЧА (КЛИНИЧЕСКИЙ ОТЧЁТ)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _doctorNotesController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Введите жалобы или примечания для терапевта перед печатью...',
              hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isExporting ? null : () => _exportPdf(report, profile),
              icon: _isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.print_rounded, size: 20),
              label: Text(
                _isExporting ? 'Формирование PDF...' : 'Распечатать отчёт для врача',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
