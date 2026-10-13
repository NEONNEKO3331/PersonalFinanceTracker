import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/transaction.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/bee_brand.dart';
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
        title: const BeeAppTitle(subtitle: 'Track · Save · Thrive'),
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
          final topCats = notifier.topExpenseCategories(filtered, limit: 5);
          final totalExpense = summary.expense;

          return RefreshIndicator(
            onRefresh: () => notifier.refresh(),
            color: BeeColors.honey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
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
                _SummaryCard(
                  periodLabel:
                      period == HomePeriod.week ? 'This week' : 'This month',
                  income: currency.format(summary.income),
                  expense: currency.format(summary.expense),
                  balance: currency.format(summary.balance),
                ),
                const SizedBox(height: 22),
                if (topCats.isNotEmpty) ...[
                  const BeeSectionTitle(title: 'Top spending'),
                  const SizedBox(height: 10),
                  _TopCategoriesCard(
                    items: topCats,
                    totalExpense: totalExpense,
                    currency: currency,
                  ),
                  const SizedBox(height: 22),
                ],
                BeeSectionTitle(
                  title: 'Recent',
                  trailing: TextButton(
                    onPressed: () => context.go('/history'),
                    child: Text(
                      list.isEmpty ? 'History' : 'See all (${list.length})',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (list.isEmpty)
                  const _EmptyHive()
                else
                  Card(
                    child: Column(
                      children: [
                        for (var i = 0;
                            i < list.length && i < 8;
                            i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: BeeColors.honey.withValues(alpha: 0.2),
                            ),
                          TransactionTile(
                            transaction: list[i],
                            onTap: () => context.push('/add', extra: list[i]),
                            onDelete: () =>
                                _confirmDelete(context, ref, list[i]),
                          ),
                        ],
                      ],
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
          FloatingActionButton.extended(
            heroTag: 'add',
            tooltip: 'Add transaction',
            onPressed: () => context.push('/add'),
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _EmptyHive extends StatelessWidget {
  const _EmptyHive();

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(
          children: [
            const BeeMark(size: 48),
            const SizedBox(height: 16),
            Text(
              'Your hive is empty',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: onSurface,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap + to add a transaction\nor scan a receipt.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: onSurface.withValues(alpha: 0.7),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    // Honey gradient stays bright — always use dark text on it.
    const onHoney = BeeColors.charcoal;
    const onHoneyMuted = BeeColors.hiveBrown;

    return HoneyBanner(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const BeeMark(size: 22),
                const SizedBox(width: 8),
                Text(
                  periodLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: onHoney,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Balance',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: onHoneyMuted,
              ),
            ),
            Text(
              balance,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: onHoney,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Income',
                    value: income,
                    color: BeeColors.nectarGreen,
                    labelColor: onHoneyMuted,
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: onHoney.withValues(alpha: 0.15),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: _MiniStat(
                      label: 'Expense',
                      value: expense,
                      color: BeeColors.stingRed,
                      labelColor: onHoneyMuted,
                    ),
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
  final Color labelColor;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    this.labelColor = BeeColors.hiveBrown,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

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
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
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
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.65);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 28,
          child: Text(
            '#$rank',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: muted,
              fontSize: 13,
            ),
          ),
        ),
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
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 7,
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
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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