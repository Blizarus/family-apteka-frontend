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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final semantic = theme.extension<SemanticColors>() ?? SemanticColors.light;
    final textMuted = theme.textTheme.bodySmall?.color ?? cs.onSurface.withValues(alpha: 0.6);
    final textSecondary = theme.textTheme.bodyMedium?.color ?? cs.onSurface.withValues(alpha: 0.75);

    final state = context.watch<AppState>();
    final report = state.adherenceReport;
    final isLoading = state.isLoadingReport;
    final profiles = state.profiles;

    final currentProfile = profiles.cast<Profile?>().firstWhere(
          (p) => p?.id == _selectedProfileId,
          orElse: () => null,
        );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Отчёт для врача',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cs.onSurface),
            ),
            Text(
              'Комплаенс и фармакотерапия',
              style: TextStyle(fontSize: 11, color: textMuted),
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
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                      )
                    : Icon(Icons.picture_as_pdf_rounded, color: cs.primary),
                onPressed: _isExporting ? null : () => _exportPdf(report, currentProfile),
              ),
            ),
        ],
      ),
      body: isLoading && report == null
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                // 1. Фильтры: Пациент и Период
                _buildFilterCard(profiles, state, cs, textMuted),
                const SizedBox(height: 16),

                if (report != null) ...[
                  // 2. Главная карточка комплаенса (Hero KPI)
                  _buildAdherenceHeroCard(report, cs, semantic, textSecondary, textMuted),
                  const SizedBox(height: 16),

                  // 3. Посуточная динамика приёмов (Интерактивный график)
                  _buildDailyChartCard(report.dailyStats, cs, semantic, textMuted),
                  const SizedBox(height: 16),

                  // 4. Дисциплина по препаратам
                  _buildMedicinesSummaryCard(report.medicinesSummary, cs, semantic, textSecondary, textMuted),
                  const SizedBox(height: 16),

                  // 5. Заметки к приёму врача & Кнопка печати
                  _buildDoctorNotesSection(report, currentProfile, cs, textMuted),
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

  Widget _buildFilterCard(List<Profile> profiles, AppState state, ColorScheme cs, Color textMuted) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ПАЦИЕНТ И ПЕРИОД АНАЛИЗА',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: textMuted,
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
                  cs: cs,
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
                      cs: cs,
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
                child: _buildPeriodButton('7 дней', '7_days', state, cs),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPeriodButton('30 дней', '30_days', state, cs),
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
    required ColorScheme cs,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        avatar: Text(avatar, style: const TextStyle(fontSize: 13)),
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: cs.primaryContainer,
        backgroundColor: cs.surfaceContainerHighest,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? cs.primary : cs.onSurface,
        ),
        side: BorderSide(
          color: isSelected ? cs.primary : cs.outlineVariant,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildPeriodButton(String title, String periodCode, AppState state, ColorScheme cs) {
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
          color: isSelected ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? cs.primary : cs.outlineVariant,
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? cs.onPrimary : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdherenceHeroCard(
    AdherenceReport report,
    ColorScheme cs,
    SemanticColors semantic,
    Color textSecondary,
    Color textMuted,
  ) {
    final rate = report.adherenceRate;
    final isHigh = rate >= 80.0;
    final isModerate = rate >= 60.0 && rate < 80.0;

    final primaryColor = isHigh
        ? semantic.success
        : (isModerate ? semantic.warning : semantic.danger);
    final bgColor = isHigh
        ? semantic.successBg
        : (isModerate ? semantic.warningBg : semantic.dangerBg);
    final borderColor = isHigh
        ? semantic.successBorder
        : (isModerate ? semantic.warningBorder : semantic.dangerBorder);

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
                      backgroundColor: cs.surface,
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
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: cs.outlineVariant),
          const SizedBox(height: 12),

          // Нижняя плашка показателей
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricItem(
                label: 'Принято',
                value: '${report.takenCount}',
                sub: 'из ${report.scheduledCount}',
                color: semantic.success,
                textMuted: textMuted,
                textSecondary: textSecondary,
              ),
              Container(width: 1, height: 32, color: cs.outlineVariant),
              _buildMetricItem(
                label: 'Пропущено',
                value: '${report.missedCount}',
                sub: PdfReportService.formatIntakeNoun(report.missedCount),
                color: report.missedCount > 0 ? semantic.danger : textMuted,
                textMuted: textMuted,
                textSecondary: textSecondary,
              ),
              Container(width: 1, height: 32, color: cs.outlineVariant),
              _buildMetricItem(
                label: 'Серия дней',
                value: '${report.streakDays}',
                sub: 'без пропусков 🔥',
                color: semantic.warning,
                textMuted: textMuted,
                textSecondary: textSecondary,
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
    required Color textMuted,
    required Color textSecondary,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color),
        ),
        Text(
          sub,
          style: TextStyle(fontSize: 9, color: textSecondary),
        ),
      ],
    );
  }

  Widget _buildDailyChartCard(List<DailyStat> stats, ColorScheme cs, SemanticColors semantic, Color textMuted) {
    if (stats.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ПОСУТОЧНАЯ ДИНАМИКА ПРИЁМОВ',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                children: [
                  _buildLegendDot(semantic.success, 'Принято', textMuted),
                  const SizedBox(width: 8),
                  _buildLegendDot(semantic.danger, 'Пропуск', textMuted),
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
                                  color: stat.hasMissed ? semantic.danger : textMuted,
                                ),
                              )
                            else
                              const SizedBox(height: 10),
                            const SizedBox(height: 4),
                            Container(
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: stat.scheduled == 0
                                    ? cs.outlineVariant
                                    : (stat.hasMissed
                                        ? semantic.dangerBg
                                        : semantic.successBg),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: stat.hasMissed ? semantic.danger : semantic.success,
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
                                          ? semantic.danger
                                          : semantic.success,
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
                              style: TextStyle(fontSize: 8, color: textMuted),
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

  Widget _buildLegendDot(Color color, String label, Color textMuted) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 9, color: textMuted)),
      ],
    );
  }

  Widget _buildMedicinesSummaryCard(
    List<MedicineAdherence> items,
    ColorScheme cs,
    SemanticColors semantic,
    Color textSecondary,
    Color textMuted,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ДИСЦИПЛИНА ПО ПРЕПАРАТАМ',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              'Нет назначенных препаратов за этот период',
              style: TextStyle(fontSize: 12, color: textMuted),
            )
          else
            ...items.map((m) {
              final isGood = m.adherenceRate >= 80;
              final rateColor = isGood ? semantic.success : semantic.danger;
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
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface),
                          ),
                        ),
                        Text(
                          '${m.adherenceRate.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: rateColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: (m.adherenceRate / 100).clamp(0.0, 1.0),
                      backgroundColor: cs.outlineVariant,
                      color: rateColor,
                      borderRadius: BorderRadius.circular(4),
                      minHeight: 6,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Принято: ${m.takenCount} из ${m.scheduledCount}',
                          style: TextStyle(fontSize: 10, color: textSecondary),
                        ),
                        if (m.missedCount > 0)
                          Text(
                            'Пропусков: ${m.missedCount}',
                            style: TextStyle(fontSize: 10, color: semantic.danger, fontWeight: FontWeight.w600),
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

  Widget _buildDoctorNotesSection(
    AdherenceReport report,
    Profile? profile,
    ColorScheme cs,
    Color textMuted,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'КОММЕНТАРИИ ДЛЯ ВРАЧА (КЛИНИЧЕСКИЙ ОТЧЁТ)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _doctorNotesController,
            maxLines: 2,
            style: TextStyle(fontSize: 13, color: cs.onSurface),
            decoration: InputDecoration(
              hintText: 'Введите жалобы или примечания для терапевта перед печатью...',
              hintStyle: TextStyle(fontSize: 12, color: textMuted),
              filled: true,
              fillColor: cs.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: cs.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: cs.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: cs.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isExporting ? null : () => _exportPdf(report, profile),
              icon: _isExporting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
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
