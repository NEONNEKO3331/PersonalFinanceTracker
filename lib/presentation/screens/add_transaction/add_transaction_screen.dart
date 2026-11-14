import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/transaction.dart';
import '../../../main.dart';
import '../../providers/transaction_provider.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  /// OCR prefill: merchant, amount, date, category
  final Map<String, dynamic>? prefill;

  /// When non-null, screen is in edit mode and updates existing row.
  final Transaction? existing;

  const AddTransactionScreen({super.key, this.prefill, this.existing});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _merchantCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  TransactionType _type = TransactionType.expense;
  String _category = Categories.expense.first;
  DateTime _date = DateTime.now();
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _merchantCtrl.text = existing.merchant;
      _amountCtrl.text = existing.amount.toStringAsFixed(2);
      _noteCtrl.text = existing.note ?? '';
      _type = existing.type;
      _category = existing.category;
      _date = existing.date;
      return;
    }

    final p = widget.prefill;
    if (p != null) {
      _merchantCtrl.text = (p['merchant'] as String?) ?? '';
      final amount = p['amount'];
      if (amount is num && amount > 0) {
        _amountCtrl.text = amount.toStringAsFixed(2);
      }
      final cat = p['category'] as String?;
      if (cat != null && Categories.expense.contains(cat)) {
        _category = cat;
      }
      final dateStr = p['date'] as String?;
      if (dateStr != null) {
        _date = DateTime.tryParse(dateStr) ?? DateTime.now();
      }
    }
  }

  @override
  void dispose() {
    _merchantCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  List<String> get _categories =>
      _type == TransactionType.expense ? Categories.expense : Categories.income;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;

    setState(() => _saving = true);
    try {
      final merchant = _merchantCtrl.text.trim().isEmpty
          ? 'Unknown'
          : _merchantCtrl.text.trim();
      final note =
          _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();

      if (_isEdit) {
        final updated = widget.existing!.copyWith(
          amount: amount,
          category: _category,
          date: _date,
          merchant: merchant,
          note: note,
          type: _type,
        );
        await ref
            .read(transactionsProvider.notifier)
            .updateTransaction(updated);
      } else {
        await ref.read(transactionsProvider.notifier).add(
              amount: amount,
              category: _category,
              date: _date,
              merchant: merchant,
              note: note,
              type: _type,
            );
      }
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(_isEdit ? 'Updated' : 'Saved'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      if (mounted) context.go('/');
    } catch (e) {
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Transaction' : 'Add Transaction'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          // Extra bottom inset so Save button clears system nav / gesture bar
          // (this route has no bottom navigation bar).
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text('Expense'),
                  icon: Icon(Icons.arrow_upward),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text('Income'),
                  icon: Icon(Icons.arrow_downward),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) {
                setState(() {
                  _type = s.first;
                  if (!_categories.contains(_category)) {
                    _category = _categories.first;
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: 'RM ',
              ),
              validator: (v) {
                final n = double.tryParse(v?.trim() ?? '');
                if (n == null || n <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _merchantCtrl,
              decoration: const InputDecoration(
                labelText: 'Merchant / Title',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(DateFormat('dd MMM yyyy').format(_date)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Category', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((c) {
                final selected = c == _category;
                final color = Categories.color(c);
                return ChoiceChip(
                  avatar: Icon(
                    Categories.icon(c),
                    size: 16,
                    color: selected ? color : color.withValues(alpha: 0.7),
                  ),
                  label: Text(Categories.displayName(c)),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = c),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit ? 'Update' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
