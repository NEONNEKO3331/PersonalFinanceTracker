import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme.dart';
import '../../../domain/services/export_service.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/bee_brand.dart';
import '../../widgets/period_selector.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  bool _exporting = false;
  String? _lastPath;

  Future<void> _export(
    HomePeriod period, {
    DateRange? customRange,
  }) async {
    if (_exporting) return;
    setState(() {
      _exporting = true;
      _lastPath = null;
    });

    try {
      final list = ref.read(transactionsProvider).valueOrNull ?? [];
      final notifier = ref.read(transactionsProvider.notifier);
      final filtered = notifier.filterByPeriod(
        list,
        period,
        customRange: customRange,
      );

      final label = notifier.periodLabel(period, customRange: customRange);
      final detail =
          notifier.periodDetail(period, customRange: customRange);

      if (filtered.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No transactions for $label'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final stamp = period == HomePeriod.custom && customRange != null
          ? customRange.fileStamp
          : period == HomePeriod.week
              ? '${DateFormat('yyyy-MM-dd').format(DateTime.now())}_week'
              : DateFormat('yyyy-MM').format(DateTime.now());

      final path = await ExportService().exportToXlsx(
        transactions: filtered,
        period: period,
        customRange: customRange,
        periodLabel: label,
        periodDetail: detail,
        fileStamp: stamp,
      );

      await Share.shareXFiles(
        [XFile(path)],
        subject: 'MoneyBee — $label',
        text: 'MoneyBee transaction export',
      );

      if (mounted) {
        setState(() => _lastPath = path);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Exported ${filtered.length} transaction'
              '${filtered.length == 1 ? '' : 's'}',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _pickExportStart() async {
    final current = ref.read(customDateRangeProvider);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current.startDay,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Start date',
    );
    if (picked == null) return;
    final start = DateTime(picked.year, picked.month, picked.day);
    var end = current.endDay;
    if (end.isBefore(start)) {
      end = DateTime(start.year, start.month, start.day, 23, 59, 59, 999);
    }
    ref.read(customDateRangeProvider.notifier).state = DateRange(start, end);
  }

  Future<void> _pickExportEnd() async {
    final current = ref.read(customDateRangeProvider);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(
        current.end.year,
        current.end.month,
        current.end.day,
      ),
      firstDate: current.startDay,
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'End date',
    );
    if (picked == null) return;
    final end = DateTime(picked.year, picked.month, picked.day);
    ref.read(customDateRangeProvider.notifier).state =
        DateRange(current.startDay, end);
  }

  @override
  Widget build(BuildContext context) {
    final asyncTx = ref.watch(transactionsProvider);
    final customRange = ref.watch(customDateRangeProvider);
    final notifier = ref.read(transactionsProvider.notifier);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final currency = NumberFormat.currency(symbol: 'RM ', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: asyncTx.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          final weekList = notifier.filterByPeriod(list, HomePeriod.week);
          final monthList = notifier.filterByPeriod(list, HomePeriod.month);
          final customList = notifier.filterByPeriod(
            list,
            HomePeriod.custom,
            customRange: customRange,
          );
          final weekSum = notifier.summary(weekList);
          final monthSum = notifier.summary(monthList);
          final customSum = notifier.summary(customList);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              const BeeSectionTitle(title: 'Export to Excel'),
              const SizedBox(height: 6),
              Text(
                'Choose a period. The file includes a Summary sheet and a full Transactions sheet.',
                style: TextStyle(
                  color: onSurface.withValues(alpha: 0.65),
                  height: 1.35,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              _PeriodCard(
                title: 'This week',
                icon: Icons.view_week_outlined,
                count: weekList.length,
                income: currency.format(weekSum.income),
                expense: currency.format(weekSum.expense),
                balance: currency.format(weekSum.balance),
                busy: _exporting,
                onExport: () => _export(HomePeriod.week),
              ),
              const SizedBox(height: 12),
              _PeriodCard(
                title: 'This month',
                icon: Icons.calendar_month_outlined,
                count: monthList.length,
                income: currency.format(monthSum.income),
                expense: currency.format(monthSum.expense),
                balance: currency.format(monthSum.balance),
                busy: _exporting,
                onExport: () => _export(HomePeriod.month),
              ),
              const SizedBox(height: 12),
              _CustomRangeCard(
                range: customRange,
                count: customList.length,
                income: currency.format(customSum.income),
                expense: currency.format(customSum.expense),
                balance: currency.format(customSum.balance),
                busy: _exporting,
                onPickStart: _pickExportStart,
                onPickEnd: _pickExportEnd,
                onExport: () => _export(
                  HomePeriod.custom,
                  customRange: customRange,
                ),
              ),
              if (_lastPath != null) ...[
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: BeeColors.nectarGreen,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Last export ready',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _lastPath!.split('/').last,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PeriodCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final int count;
  final String income;
  final String expense;
  final String balance;
  final bool busy;
  final VoidCallback onExport;

  const _PeriodCard({
    required this.title,
    required this.icon,
    required this.count,
    required this.income,
    required this.expense,
    required this.balance,
    required this.busy,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: BeeColors.honey, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: onSurface,
                    ),
                  ),
                ),
                Text(
                  '$count tx',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _MiniStatRow(income: income, expense: expense, balance: balance),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy ? null : onExport,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_download_outlined, size: 18),
              label: Text(busy ? 'Exporting…' : 'Export XLSX'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomRangeCard extends StatelessWidget {
  final DateRange range;
  final int count;
  final String income;
  final String expense;
  final String balance;
  final bool busy;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onExport;

  const _CustomRangeCard({
    required this.range,
    required this.count,
    required this.income,
    required this.expense,
    required this.balance,
    required this.busy,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.date_range_outlined,
                    color: BeeColors.honey, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Custom range',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: onSurface,
                    ),
                  ),
                ),
                Text(
                  '$count tx',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                DateChipButton(
                  label: 'From',
                  date: range.start,
                  onTap: onPickStart,
                ),
                const SizedBox(width: 10),
                DateChipButton(
                  label: 'To',
                  date: range.end,
                  onTap: onPickEnd,
                ),
              ],
            ),
            const SizedBox(height: 10),
            _MiniStatRow(income: income, expense: expense, balance: balance),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy ? null : onExport,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_download_outlined, size: 18),
              label: Text(busy ? 'Exporting…' : 'Export XLSX'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStatRow extends StatelessWidget {
  final String income;
  final String expense;
  final String balance;

  const _MiniStatRow({
    required this.income,
    required this.expense,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Expanded(
          child: _stat('Income', income, BeeColors.nectarGreen, onSurface),
        ),
        Expanded(
          child: _stat('Expense', expense, Colors.redAccent, onSurface),
        ),
        Expanded(
          child: _stat('Balance', balance, BeeColors.honey, onSurface),
        ),
      ],
    );
  }

  Widget _stat(String label, String value, Color color, Color onSurface) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}