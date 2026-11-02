import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/transaction.dart' as domain;
import '../database/app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(databaseProvider));
});

class TransactionRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  TransactionRepository(this._db);

  Future<List<domain.Transaction>> getAll() async {
    final rows = await _db.getAllTransactions();
    return rows.map(_toDomain).toList();
  }

  Future<List<domain.Transaction>> getThisMonth() async {
    final rows = await _db.getMonthTransactions(DateTime.now());
    return rows.map(_toDomain).toList();
  }

  Future<domain.Transaction> add({
    required double amount,
    required String category,
    required DateTime date,
    required String merchant,
    String? note,
    required domain.TransactionType type,
  }) async {
    final tx = domain.Transaction(
      id: _uuid.v4(),
      amount: amount,
      category: category,
      date: date,
      merchant: merchant,
      note: note,
      type: type,
      createdAt: DateTime.now(),
    );

    await _db.insertTx(TransactionsCompanion.insert(
      id: tx.id,
      amount: tx.amount,
      category: tx.category,
      date: tx.date,
      merchant: tx.merchant,
      note: Value(tx.note),
      type: tx.type.name,
      createdAt: tx.createdAt,
    ));

    return tx;
  }

  Future<void> update(domain.Transaction tx) async {
    await _db.updateTx(TransactionsCompanion(
      id: Value(tx.id),
      amount: Value(tx.amount),
      category: Value(tx.category),
      date: Value(tx.date),
      merchant: Value(tx.merchant),
      note: Value(tx.note),
      type: Value(tx.type.name),
      createdAt: Value(tx.createdAt),
    ));
  }

  Future<void> delete(String id) => _db.deleteTx(id);

  Future<void> deleteAll() => _db.deleteAllTx();

  /// Replace entire local DB with [items] (backup restore).
  Future<void> replaceAll(List<domain.Transaction> items) async {
    final companions = items
        .map(
          (tx) => TransactionsCompanion.insert(
            id: tx.id,
            amount: tx.amount,
            category: tx.category,
            date: tx.date,
            merchant: tx.merchant,
            note: Value(tx.note),
            type: tx.type.name,
            createdAt: tx.createdAt,
          ),
        )
        .toList();
    await _db.replaceAllTx(companions);
  }

  domain.Transaction _toDomain(Transaction row) {
    return domain.Transaction(
      id: row.id,
      amount: row.amount,
      category: row.category,
      date: row.date,
      merchant: row.merchant,
      note: row.note,
      type: row.type == 'income'
          ? domain.TransactionType.income
          : domain.TransactionType.expense,
      createdAt: row.createdAt,
    );
  }
}