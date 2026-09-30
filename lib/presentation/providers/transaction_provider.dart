import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/transaction.dart';
import '../../data/repositories/transaction_repository.dart';

final transactionsProvider =
    AsyncNotifierProvider<TransactionsNotifier, List<Transaction>>(
  TransactionsNotifier.new,
);

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

  /// Monthly summary from current list.
  ({double income, double expense, double balance}) summaryForMonth(
    List<Transaction> list,
  ) {
    final now = DateTime.now();
    var income = 0.0;
    var expense = 0.0;
    for (final t in list) {
      if (t.date.year != now.year || t.date.month != now.month) continue;
      if (t.type == TransactionType.income) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    return (income: income, expense: expense, balance: income - expense);
  }
}