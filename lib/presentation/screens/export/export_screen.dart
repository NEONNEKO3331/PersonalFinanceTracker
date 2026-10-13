import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme.dart';
import '../../../domain/services/export_service.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/bee_brand.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  bool _exporting = false;
  String? _lastPath;

  Future<void> _export(HomePeriod period) async {
    if (_exporting) return;
    setState(() {
      _exporting = true;
      _lastPath = null;
    });

    try {
      final list = ref.read(transactionsProvider).valueOrNull ?? [];
      final filtered =
          ref.read(transactionsProvider.notifier).filterByPeriod(list, period);

      if (filtered.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                period == HomePeriod.week
                    ? 'No transactions this week'
                    : 'No transactions this month',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final path = await ExportService().exportToXlsx(
        transactions: filtered,
        period: period,
      );

      await Share.shareXFiles(
        [XFile(path)],
        subject: period == HomePeriod.week
            ? 'MoneyBee — this week'
            : 'MoneyBee — this month',
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

  @override
  Widget build(BuildContext context) {
    final asyncTx = ref.watch(transactionsProvider);
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
          final weekSum = notifier.summary(weekList);
          final monthSum = notifier.summary(monthList);

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
                    fontSize: 12,
                    color: onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Mini(
                    label: 'Income',
                    value: income,
                    color: BeeColors.nectarGreen,
                  ),
                ),
                Expanded(
                  child: _Mini(
                    label: 'Expense',
                    value: expense,
                    color: BeeColors.stingRed,
                  ),
                ),
                Expanded(
                  child: _Mini(
                    label: 'Balance',
                    value: balance,
                    color: BeeColors.honey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: busy || count == 0 ? null : onExport,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_download_outlined),
              label: Text(busy ? 'Exporting…' : 'Export .xlsx'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Mini({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: muted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            color: color,
          ),
        ),
      ],
    );
  }
}