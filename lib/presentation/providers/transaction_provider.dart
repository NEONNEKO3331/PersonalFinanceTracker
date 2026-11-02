import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/transaction.dart';
import '../../data/repositories/transaction_repository.dart';

final transactionsProvider =
    AsyncNotifierProvider<TransactionsNotifier, List<Transaction>>(
  TransactionsNotifier.new,
);

/// Dashboard / analytics / export period.
enum HomePeriod { week, month, custom }

/// Inclusive date-only range used when [HomePeriod.custom] is selected.
class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange(this.start, this.end);

  DateTime get startDay => DateTime(start.year, start.month, start.day);

  DateTime get endDay => DateTime(end.year, end.month, end.day, 23, 59, 59, 999);

  String get label {
    final fmt = DateFormat('dd MMM yyyy');
    return '${fmt.format(start)} – ${fmt.format(end)}';
  }

  String get shortLabel {
    final fmt = DateFormat('dd MMM');
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return DateFormat('dd MMM yyyy').format(start);
    }
    return '${fmt.format(start)} – ${fmt.format(end)}';
  }

  String get fileStamp {
    final fmt = DateFormat('yyyy-MM-dd');
    return '${fmt.format(start)}_to_${fmt.format(end)}';
  }
}

final homePeriodProvider = StateProvider<HomePeriod>((ref) => HomePeriod.month);

/// Default custom range: first day of current month → today.
final customDateRangeProvider = StateProvider<DateRange>((ref) {
  final now = DateTime.now();
  return DateRange(
    DateTime(now.year, now.month, 1),
    DateTime(now.year, now.month, now.day),
  );
});

class TransactionsNotifier extends AsyncNotifier<List<Transaction>> {
  @override
  Future<List<Transaction>> build() {
    return ref.read(transactionRepositoryProvider).getAll();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await ref.read(transactionRepositoryProvider).getAll());
  }

  Future<void> add({
    required double amount,
    required String category,
    required DateTime date,
    required String merchant,
    String? note,
    required TransactionType type,
  }) async {
    await ref.read(transactionRepositoryProvider).add(
          amount: amount,
          category: category,
          date: date,
          merchant: merchant,
          note: note,
          type: type,
        );
    await refresh();
  }

  Future<void> updateTransaction(Transaction tx) async {
    await ref.read(transactionRepositoryProvider).update(tx);
    await refresh();
  }

  Future<void> remove(String id) async {
    await ref.read(transactionRepositoryProvider).delete(id);
    await refresh();
  }

  Future<void> clearAll() async {
    await ref.read(transactionRepositoryProvider).deleteAll();
    await refresh();
  }

  /// Full restore from backup: replaces all local transactions.
  Future<void> restoreAll(List<Transaction> items) async {
    await ref.read(transactionRepositoryProvider).replaceAll(items);
    await refresh();
  }

  /// Human-readable period title.
  String periodLabel(HomePeriod period, {DateRange? customRange}) {
    switch (period) {
      case HomePeriod.week:
        return 'This week';
      case HomePeriod.month:
        return 'This month';
      case HomePeriod.custom:
        return customRange?.shortLabel ?? 'Custom range';
    }
  }

  /// Longer detail string (for export headers, etc.).
  String periodDetail(
    HomePeriod period, {
    DateTime? now,
    DateRange? customRange,
  }) {
    final n = now ?? DateTime.now();
    switch (period) {
      case HomePeriod.month:
        return DateFormat('MMMM yyyy').format(n);
      case HomePeriod.week:
        final weekday = n.weekday;
        final start = DateTime(n.year, n.month, n.day)
            .subtract(Duration(days: weekday - 1));
        final end = start.add(const Duration(days: 6));
        final fmt = DateFormat('dd MMM yyyy');
        return '${fmt.format(start)} – ${fmt.format(end)}';
      case HomePeriod.custom:
        return customRange?.label ?? '';
    }
  }

  /// Filter list to the given period.
  List<Transaction> filterByPeriod(
    List<Transaction> list,
    HomePeriod period, {
    DateTime? now,
    DateRange? customRange,
  }) {
    final n = now ?? DateTime.now();
    switch (period) {
      case HomePeriod.month:
        return list
            .where((t) => t.date.year == n.year && t.date.month == n.month)
            .toList();
      case HomePeriod.week:
        // This week: Monday 00:00 → now
        final weekday = n.weekday; // 1 = Mon … 7 = Sun
        final startOfWeek = DateTime(n.year, n.month, n.day)
            .subtract(Duration(days: weekday - 1));
        return list.where((t) => !t.date.isBefore(startOfWeek)).toList();
      case HomePeriod.custom:
        final range = customRange;
        if (range == null) return list;
        final start = range.startDay;
        final end = range.endDay;
        return list
            .where((t) => !t.date.isBefore(start) && !t.date.isAfter(end))
            .toList();
    }
  }

  /// Income / expense / balance for a filtered list.
  ({double income, double expense, double balance}) summary(
    List<Transaction> filtered,
  ) {
    var income = 0.0;
    var expense = 0.0;
    for (final t in filtered) {
      if (t.type == TransactionType.income) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    return (income: income, expense: expense, balance: income - expense);
  }

  /// Backward-compatible monthly summary.
  ({double income, double expense, double balance}) summaryForMonth(
    List<Transaction> list,
  ) {
    return summary(filterByPeriod(list, HomePeriod.month));
  }

  /// Top expense categories (sorted by amount desc), up to [limit].
  /// Returns category key + total amount.
  List<({String category, double amount})> topExpenseCategories(
    List<Transaction> filtered, {
    int limit = 5,
  }) {
    final map = <String, double>{};
    for (final t in filtered) {
      if (t.type != TransactionType.expense) continue;
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .take(limit)
        .map((e) => (category: e.key, amount: e.value))
        .toList();
  }
}