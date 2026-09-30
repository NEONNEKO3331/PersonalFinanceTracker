import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/transaction.dart';

class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == TransactionType.expense;
    final amountColor = isExpense ? Colors.redAccent : Colors.green;
    final prefix = isExpense ? '-' : '+';
    final currency = NumberFormat.currency(symbol: 'RM ', decimalDigits: 2);
    final catColor = Categories.color(transaction.category);

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: catColor.withValues(alpha: 0.15),
        child: Icon(
          Categories.icon(transaction.category),
          color: catColor,
          size: 18,
        ),
      ),
      title: Text(
        transaction.merchant,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${Categories.displayName(transaction.category)} · '
        '${DateFormat('dd MMM yyyy').format(transaction.date)}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$prefix${currency.format(transaction.amount)}',
            style: TextStyle(
              color: amountColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}