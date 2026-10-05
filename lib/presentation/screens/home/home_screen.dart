import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/transaction.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/transaction_tile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Transaction t,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text(
          'Remove "${t.merchant}" (${NumberFormat.currency(symbol: 'RM ', decimalDigits: 2).format(t.amount)})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await ref.read(transactionsProvider.notifier).remove(t.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deleted'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTx = ref.watch(transactionsProvider);
    final period = ref.watch(homePeriodProvider);
    final currency = NumberFormat.currency(symbol: 'RM ', decimalDigits: 2);
    final notifier = ref.read(transactionsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MoneyBee'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
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
          final topCats = notifier.topExpenseCategories(filtered, limit: 5);
          final totalExpense = summary.expense;

          return RefreshIndicator(
            onRefresh: () => notifier.refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Period toggle ──
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

                // ── Summary card ──
                _SummaryCard(
                  periodLabel:
                      period == HomePeriod.week ? 'This week' : 'This month',
                  income: currency.format(summary.income),
                  expense: currency.format(summary.expense),
                  balance: currency.format(summary.balance),
                ),
                const SizedBox(height: 20),

                // ── Top categories ──
                if (topCats.isNotEmpty) ...[
                  Text(
                    'Top spending',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _TopCategoriesCard(
                    items: topCats,
                    totalExpense: totalExpense,
                    currency: currency,
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Recent list ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text('${list.length} records'),
                  ],
                ),
                const SizedBox(height: 8),
                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Text('No transactions yet.\nTap + to add one.'),
                    ),
                  )
                else
                  ...list.map(
                    (t) => TransactionTile(
                      transaction: t,
                      onTap: () => context.push('/add', extra: t),
                      onDelete: () => _confirmDelete(context, ref, t),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'scan',
            tooltip: 'Scan receipt',
            onPressed: () => context.push('/scan'),
            child: const Icon(Icons.document_scanner_outlined),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'add',
            tooltip: 'Add transaction',
            onPressed: () => context.push('/add'),
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Summary card
// ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String periodLabel;
  final String income;
  final String expense;
  final String balance;

  const _SummaryCard({
    required this.periodLabel,
    required this.income,
    required this.expense,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.primaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              periodLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Text(
              balance,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Income',
                    value: income,
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Expense',
                    value: expense,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Top spending categories (progress bars)
// ─────────────────────────────────────────────────────────────

class _TopCategoriesCard extends StatelessWidget {
  final List<({String category, double amount})> items;
  final double totalExpense;
  final NumberFormat currency;

  const _TopCategoriesCard({
    required this.items,
    required this.totalExpense,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _CategoryRow(
                rank: i + 1,
                category: items[i].category,
                amount: items[i].amount,
                fraction: totalExpense > 0
                    ? (items[i].amount / totalExpense).clamp(0.0, 1.0)
                    : 0.0,
                currency: currency,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final int rank;
  final String category;
  final double amount;
  final double fraction;
  final NumberFormat currency;

  const _CategoryRow({
    required this.rank,
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Rank badge
        SizedBox(
          width: 28,
          child: Text(
            '#$rank',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        // Icon
        CircleAvatar(
          radius: 16,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(Categories.icon(category), color: color, size: 16),
        ),
        const SizedBox(width: 10),
        // Name + bar
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
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    currency.format(amount),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: color,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 6,
                        backgroundColor: color.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '$pct%',
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
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