import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/transaction.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/bee_brand.dart';

/// Detailed spend analysis: pie chart + category breakdown + period toggle.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTx = ref.watch(transactionsProvider);
    final period = ref.watch(homePeriodProvider);
    final currency = NumberFormat.currency(symbol: 'RM ', decimalDigits: 2);
    final notifier = ref.read(transactionsProvider.notifier);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
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
          final filtered = notifier.filterByPeriod(list, period);
          final summary = notifier.summary(filtered);
          // All expense categories (no limit) for full pie.
          final catTotals = notifier.topExpenseCategories(filtered, limit: 99);
          final totalExpense = summary.expense;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              SegmentedButton<HomePeriod>(
                segments: const [
                  ButtonSegment(
                    value: HomePeriod.week,
                    label: Text('This week'),
                    icon: Icon(Icons.view_week_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: HomePeriod.month,
                    label: Text('This month'),
                    icon: Icon(Icons.calendar_month_outlined, size: 18),
                  ),
                ],
                selected: {period},
                onSelectionChanged: (s) {
                  ref.read(homePeriodProvider.notifier).state = s.first;
                },
              ),
              const SizedBox(height: 16),
              _SummaryStrip(
                income: currency.format(summary.income),
                expense: currency.format(summary.expense),
                balance: currency.format(summary.balance),
              ),
              const SizedBox(height: 22),
              const BeeSectionTitle(title: 'Expense by category'),
              const SizedBox(height: 12),
              if (catTotals.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 40,
                      horizontal: 24,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.pie_chart_outline_rounded,
                          size: 48,
                          color: onSurface.withValues(alpha: 0.35),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No expenses in this period',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add or scan a receipt to see the breakdown.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: onSurface.withValues(alpha: 0.55),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 220,
                          child: _ExpensePie(
                            items: catTotals,
                            total: totalExpense,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total expense  ${currency.format(totalExpense)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: onSurface,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const BeeSectionTitle(title: 'Breakdown'),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      children: [
                        for (var i = 0; i < catTotals.length; i++) ...[
                          if (i > 0) const SizedBox(height: 14),
                          _BreakdownRow(
                            category: catTotals[i].category,
                            amount: catTotals[i].amount,
                            fraction: totalExpense > 0
                                ? catTotals[i].amount / totalExpense
                                : 0,
                            currency: currency,
                          ),
                        ],
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

class _SummaryStrip extends StatelessWidget {
  final String income;
  final String expense;
  final String balance;

  const _SummaryStrip({
    required this.income,
    required this.expense,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatChip(
            label: 'Income',
            value: income,
            color: BeeColors.nectarGreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatChip(
            label: 'Expense',
            value: expense,
            color: BeeColors.stingRed,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatChip(
            label: 'Balance',
            value: balance,
            color: BeeColors.honey,
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpensePie extends StatefulWidget {
  final List<({String category, double amount})> items;
  final double total;

  const _ExpensePie({required this.items, required this.total});

  @override
  State<_ExpensePie> createState() => _ExpensePieState();
}

class _ExpensePieState extends State<_ExpensePie> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final sections = <PieChartSectionData>[];
    for (var i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      final color = Categories.color(item.category);
      final pct = widget.total > 0 ? (item.amount / widget.total * 100) : 0.0;
      final selected = i == _touched;
      sections.add(
        PieChartSectionData(
          color: color,
          value: item.amount,
          title: pct >= 6 ? '${pct.round()}%' : '',
          radius: selected ? 78 : 68,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            shadows: [Shadow(blurRadius: 2, color: Colors.black26)],
          ),
          badgeWidget: selected
              ? _PieBadge(
                  label: Categories.displayName(item.category),
                  color: color,
                )
              : null,
          badgePositionPercentageOffset: 1.25,
        ),
      );
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 36,
        pieTouchData: PieTouchData(
          touchCallback: (event, response) {
            setState(() {
              if (!event.isInterestedForInteractions ||
                  response == null ||
                  response.touchedSection == null) {
                _touched = -1;
                return;
              }
              _touched = response.touchedSection!.touchedSectionIndex;
            });
          },
        ),
        sections: sections,
      ),
    );
  }
}

class _PieBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _PieBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(blurRadius: 4, color: Colors.black26, offset: Offset(0, 1)),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String category;
  final double amount;
  final double fraction;
  final NumberFormat currency;

  const _BreakdownRow({
    required this.category,
    required this.amount,
    required this.fraction,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final color = Categories.color(category);
    final name = Categories.displayName(category);
    final pct = (fraction * 100).round();
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.65);

    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(Categories.icon(category), color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: onSurface,
                      ),
                    ),
                  ),
                  Text(
                    currency.format(amount),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: color,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraction.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: color.withValues(alpha: 0.12),
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '$pct%',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: muted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}