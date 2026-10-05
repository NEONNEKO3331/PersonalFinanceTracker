import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/transaction.dart';
import '../../data/repositories/transaction_repository.dart';

final transactionsProvider =
    AsyncNotifierProvider<TransactionsNotifier, List<Transaction>>(
  TransactionsNotifier.new,
);

/// Home dashboard period: this week or this month.
enum HomePeriod { week, month }

final homePeriodProvider = StateProvider<HomePeriod>((ref) => HomePeriod.month);

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

  /// Filter list to the given period (week or month), relative to [now].
  List<Transaction> filterByPeriod(
    List<Transaction> list,
    HomePeriod period, {
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    if (period == HomePeriod.month) {
      return list
          .where((t) => t.date.year == n.year && t.date.month == n.month)
          .toList();
    }
    // This week: Monday 00:00 → now
    final weekday = n.weekday; // 1 = Mon … 7 = Sun
    final startOfWeek = DateTime(n.year, n.month, n.day)
        .subtract(Duration(days: weekday - 1));
    return list.where((t) => !t.date.isBefore(startOfWeek)).toList();
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