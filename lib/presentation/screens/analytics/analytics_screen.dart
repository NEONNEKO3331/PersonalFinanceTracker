import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/services/ai_insight_service.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/bee_brand.dart';
import '../../widgets/period_selector.dart';

/// Detailed spend analysis: pie chart + category breakdown + period toggle + AI insight.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTx = ref.watch(transactionsProvider);
    final period = ref.watch(homePeriodProvider);
    final customRange = ref.watch(customDateRangeProvider);
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
          final filtered = notifier.filterByPeriod(
            list,
            period,
            customRange: customRange,
          );
          final summary = notifier.summary(filtered);
          final catTotals = notifier.topExpenseCategories(filtered, limit: 99);
          final totalExpense = summary.expense;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              const PeriodSelector(),
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
              const SizedBox(height: 22),
              const BeeSectionTitle(title: 'AI monthly insight'),
              const SizedBox(height: 10),
              _AiInsightCard(
                income: summary.income,
                expense: summary.expense,
                balance: summary.balance,
                categoryTotals: {
                  for (final c in catTotals) c.category: c.amount,
                },
              ),
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

class _AiInsightCard extends StatefulWidget {
  final double income;
  final double expense;
  final double balance;
  final Map<String, double> categoryTotals;

  const _AiInsightCard({
    required this.income,
    required this.expense,
    required this.balance,
    required this.categoryTotals,
  });

  @override
  State<_AiInsightCard> createState() => _AiInsightCardState();
}

class _AiInsightCardState extends State<_AiInsightCard> {
  bool _loading = false;
  String? _insight;
  String? _error;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final text = await AiInsightService().monthlyInsight(
        income: widget.income,
        expense: widget.expense,
        balance: widget.balance,
        categoryTotals: widget.categoryTotals,
      );
      if (!mounted) return;
      setState(() {
        _insight = text;
        _loading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('AI monthly insight failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _error = _describeError(error);
        _loading = false;
      });
    }
  }

  String _describeError(Object error) {
    if (error is InvalidApiKey) {
      return 'API key rejected\n${error.message}';
    }
    if (error is ServiceApiNotEnabled) {
      return 'Firebase AI is not enabled\n${error.message}';
    }
    if (error is UnsupportedUserLocation) {
      return 'Location not supported\n${error.message}';
    }
    if (error is QuotaExceeded) {
      return 'AI quota exceeded\n${error.message}';
    }
    if (error is ServerException) {
      return 'AI service error\n${error.message}';
    }
    if (error is FirebaseAIException) {
      return 'Firebase AI error\n${error.message}';
    }
    if (error is FirebaseException) {
      return 'Firebase error (${error.plugin}, ${error.code})\n${error.message}';
    }
    if (error is TimeoutException) {
      return 'Request timed out\n${error.message ?? error}';
    }
    return '${error.runtimeType}\n$error';
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final empty = widget.expense == 0 && widget.income == 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Uses this period’s totals only. Needs internet.',
              style: TextStyle(
                fontSize: 12,
                color: onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_insight != null) ...[
              _buildInsight(_insight!, onSurface),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Regenerate'),
              ),
            ] else ...[
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: BeeColors.stingRed, fontSize: 13),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                onPressed: empty ? null : _generate,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Generate AI insight'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInsight(String text, Color onSurface) {
    final sections = <_InsightSection>[
      const _InsightSection(
        title: 'Overview',
        icon: Icons.insights_outlined,
        color: BeeColors.honey,
        labels: ['overview'],
      ),
      const _InsightSection(
        title: 'Top spending pattern',
        icon: Icons.pie_chart_outline,
        color: BeeColors.stingRed,
        labels: ['top spending pattern', 'spending pattern'],
      ),
      const _InsightSection(
        title: 'What to watch',
        icon: Icons.visibility_outlined,
        color: BeeColors.stingRed,
        labels: ['what to watch', 'watch out', 'risk'],
      ),
      const _InsightSection(
        title: 'Next month tip',
        icon: Icons.lightbulb_outline,
        color: BeeColors.nectarGreen,
        labels: ['next month tip', 'practical tip', 'tip'],
      ),
    ];

    final parsed = <String, String>{};
    String? currentKey;
    for (final line in text.split('\n')) {
      final cleaned = line
          .trim()
          .replaceFirst(RegExp(r'^\d+[.)]\s*'), '')
          .replaceAll('*', '');
      final colon = cleaned.indexOf(':');
      final label = colon < 0
          ? ''
          : cleaned.substring(0, colon).trim().toLowerCase();
      final section = sections.where((item) => item.labels.contains(label));
      if (section.isNotEmpty) {
        currentKey = section.first.title;
        parsed[currentKey] = cleaned.substring(colon + 1).trim();
      } else if (currentKey != null && cleaned.isNotEmpty) {
        parsed[currentKey] = '${parsed[currentKey]} $cleaned'.trim();
      }
    }

    if (parsed.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          height: 1.5,
          color: onSurface.withValues(alpha: 0.9),
        ),
      );
    }

    final visibleSections = sections
        .where((section) => parsed[section.title]?.isNotEmpty ?? false)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < visibleSections.length; i++) ...[
          if (i > 0) const Divider(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(visibleSections[i].icon,
                  size: 20, color: visibleSections[i].color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visibleSections[i].title,
                      style: TextStyle(
                        color: visibleSections[i].color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      parsed[visibleSections[i].title]!,
                      style: TextStyle(
                        height: 1.45,
                        color: onSurface.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _InsightSection {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> labels;

  const _InsightSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.labels,
  });
}