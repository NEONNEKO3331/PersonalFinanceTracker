import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/transaction.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/bee_brand.dart';
import '../../widgets/transaction_tile.dart';

enum _TypeFilter { all, expense, income }

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  _TypeFilter _typeFilter = _TypeFilter.all;
  final _searchController = TextEditingController();
  String _query = '';
  bool _searchOpen = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(Transaction t) async {
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
    if (ok == true && mounted) {
      await ref.read(transactionsProvider.notifier).remove(t.id);
      if (mounted) {
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

  List<Transaction> _applyFilters(List<Transaction> list) {
    var result = list;
    if (_typeFilter == _TypeFilter.expense) {
      result = result.where((t) => t.type == TransactionType.expense).toList();
    } else if (_typeFilter == _TypeFilter.income) {
      result = result.where((t) => t.type == TransactionType.income).toList();
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((t) {
        final merchant = t.merchant.toLowerCase();
        final note = (t.note ?? '').toLowerCase();
        final cat = Categories.displayName(t.category).toLowerCase();
        return merchant.contains(q) || note.contains(q) || cat.contains(q);
      }).toList();
    }
    // Ensure newest first (repo already orders by date desc).
    result = List.of(result)
      ..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        if (byDate != 0) return byDate;
        return b.createdAt.compareTo(a.createdAt);
      });
    return result;
  }

  /// Group by calendar day; keys ordered newest → oldest.
  Map<String, List<Transaction>> _groupByDay(List<Transaction> list) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final map = <String, List<Transaction>>{};
    for (final t in list) {
      final d = DateTime(t.date.year, t.date.month, t.date.day);
      final String label;
      if (d == today) {
        label = 'Today';
      } else if (d == yesterday) {
        label = 'Yesterday';
      } else {
        label = DateFormat('dd MMM yyyy').format(d);
      }
      map.putIfAbsent(label, () => []).add(t);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final asyncTx = ref.watch(transactionsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: _searchOpen
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search merchant, note, category…',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text('History'),
        actions: [
          IconButton(
            icon: Icon(_searchOpen ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_searchOpen) {
                  _searchController.clear();
                  _query = '';
                }
                _searchOpen = !_searchOpen;
              });
            },
          ),
        ],
      ),
      body: asyncTx.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          final filtered = _applyFilters(list);
          final grouped = _groupByDay(filtered);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: SegmentedButton<_TypeFilter>(
                  segments: const [
                    ButtonSegment(
                      value: _TypeFilter.all,
                      label: Text('All'),
                    ),
                    ButtonSegment(
                      value: _TypeFilter.expense,
                      label: Text('Expense'),
                      icon: Icon(Icons.arrow_upward, size: 16),
                    ),
                    ButtonSegment(
                      value: _TypeFilter.income,
                      label: Text('Income'),
                      icon: Icon(Icons.arrow_downward, size: 16),
                    ),
                  ],
                  selected: {_typeFilter},
                  onSelectionChanged: (s) {
                    setState(() => _typeFilter = s.first);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${filtered.length} of ${list.length} records',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyHistory(
                        hasAny: list.isNotEmpty,
                        hasQuery: _query.trim().isNotEmpty ||
                            _typeFilter != _TypeFilter.all,
                      )
                    : RefreshIndicator(
                        onRefresh: () =>
                            ref.read(transactionsProvider.notifier).refresh(),
                        color: BeeColors.honey,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: grouped.length,
                          itemBuilder: (context, index) {
                            final entry = grouped.entries.elementAt(index);
                            final label = entry.key;
                            final items = entry.value;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (index > 0) const SizedBox(height: 12),
                                BeeSectionTitle(title: label),
                                const SizedBox(height: 8),
                                Card(
                                  child: Column(
                                    children: [
                                      for (var i = 0; i < items.length; i++) ...[
                                        if (i > 0)
                                          Divider(
                                            height: 1,
                                            indent: 16,
                                            endIndent: 16,
                                            color: BeeColors.honey
                                                .withValues(alpha: 0.2),
                                          ),
                                        TransactionTile(
                                          transaction: items[i],
                                          onTap: () => context.push(
                                            '/add',
                                            extra: items[i],
                                          ),
                                          onDelete: () =>
                                              _confirmDelete(items[i]),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  final bool hasAny;
  final bool hasQuery;

  const _EmptyHistory({
    required this.hasAny,
    required this.hasQuery,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final title = hasQuery
        ? 'No matches'
        : hasAny
            ? 'Nothing here'
            : 'Your hive is empty';
    final subtitle = hasQuery
        ? 'Try a different search or filter.'
        : hasAny
            ? 'No transactions for this filter.'
            : 'Tap + on Home to add a transaction\nor scan a receipt.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BeeMark(size: 48),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: onSurface,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
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