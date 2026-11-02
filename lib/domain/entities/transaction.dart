import 'package:flutter/material.dart';

enum TransactionType { expense, income }

class Transaction {
  final String id;
  final double amount;
  final String category;
  final DateTime date;
  final String merchant;
  final String? note;
  final TransactionType type;
  final DateTime createdAt;

  const Transaction({
    required this.id,
    required this.amount,
    required this.category,
    required this.date,
    required this.merchant,
    this.note,
    required this.type,
    required this.createdAt,
  });

  Transaction copyWith({
    String? id,
    double? amount,
    String? category,
    DateTime? date,
    String? merchant,
    String? note,
    TransactionType? type,
    DateTime? createdAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      merchant: merchant ?? this.merchant,
      note: note ?? this.note,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'category': category,
        'date': date.toIso8601String(),
        'merchant': merchant,
        'note': note,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] as String?)?.toLowerCase() ?? 'expense';
    return Transaction(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String,
      date: DateTime.parse(json['date'] as String),
      merchant: (json['merchant'] as String?) ?? '',
      note: json['note'] as String?,
      type: typeStr == 'income' ? TransactionType.income : TransactionType.expense,
      createdAt: DateTime.parse(
        (json['createdAt'] as String?) ?? json['date'] as String,
      ),
    );
  }
}

/// Expense / income category keys used across the app.
class Categories {
  static const expense = <String>[
    'food_dining',
    'transportation',
    'shopping',
    'entertainment',
    'healthcare',
    'education',
    'bills_utilities',
    'groceries',
    'other_expense',
  ];

  static const income = <String>[
    'salary',
    'freelance',
    'gift',
    'other_income',
  ];

  static const names = <String, String>{
    'food_dining': 'Food & Dining',
    'transportation': 'Transportation',
    'shopping': 'Shopping',
    'entertainment': 'Entertainment',
    'healthcare': 'Healthcare',
    'education': 'Education',
    'bills_utilities': 'Bills & Utilities',
    'groceries': 'Groceries',
    'other_expense': 'Other',
    'salary': 'Salary',
    'freelance': 'Freelance',
    'gift': 'Gift',
    'other_income': 'Other Income',
  };

  static String displayName(String key) => names[key] ?? key;

  static IconData icon(String key) {
    switch (key) {
      case 'food_dining':
        return Icons.restaurant;
      case 'transportation':
        return Icons.directions_car;
      case 'shopping':
        return Icons.shopping_bag;
      case 'entertainment':
        return Icons.movie;
      case 'healthcare':
        return Icons.local_hospital;
      case 'education':
        return Icons.school;
      case 'bills_utilities':
        return Icons.receipt_long;
      case 'groceries':
        return Icons.local_grocery_store;
      case 'salary':
        return Icons.payments;
      case 'freelance':
        return Icons.work;
      case 'gift':
        return Icons.card_giftcard;
      default:
        return Icons.category;
    }
  }

  static Color color(String key) {
    switch (key) {
      case 'food_dining':
        return const Color(0xFFE65100);
      case 'transportation':
        return const Color(0xFF1565C0);
      case 'shopping':
        return const Color(0xFF6A1B9A);
      case 'entertainment':
        return const Color(0xFFAD1457);
      case 'healthcare':
        return const Color(0xFFC62828);
      case 'education':
        return const Color(0xFF283593);
      case 'bills_utilities':
        return const Color(0xFF455A64);
      case 'groceries':
        return const Color(0xFF2E7D32);
      case 'salary':
        return const Color(0xFF00695C);
      case 'freelance':
        return const Color(0xFF00838F);
      case 'gift':
        return const Color(0xFF6A1B9A);
      default:
        return const Color(0xFF546E7A);
    }
  }
}