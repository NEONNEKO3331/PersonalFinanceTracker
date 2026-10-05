import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
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
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedAmount = isDark
        ? (isExpense ? const Color(0xFFEF9A9A) : const Color(0xFF81C784))
        : (isExpense ? BeeColors.stingRed : BeeColors.nectarGreen);
    final prefix = isExpense ? '-' : '+';
    final currency = NumberFormat.currency(symbol: 'RM ', decimalDigits: 2);
    final catColor = Categories.color(transaction.category);

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
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
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      subtitle: Text(
        '${Categories.displayName(transaction.category)} · '
        '${DateFormat('dd MMM yyyy').format(transaction.date)}',
        style: TextStyle(
          color: scheme.onSurface.withValues(alpha: 0.65),
          fontSize: 12,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$prefix${currency.format(transaction.amount)}',
            style: TextStyle(
              color: resolvedAmount,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (onDelete != null)
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: scheme.onSurface.withValues(alpha: 0.55),
              ),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}