import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/transaction_provider.dart';

/// Matches pubspec.yaml version field.
const _appVersion = '1.0.0+1';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text(
          'This permanently deletes every transaction on this device.\nUseful for resetting before a demo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await ref.read(transactionsProvider.notifier).clearAll();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All data cleared'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('MoneyBee'),
            subtitle: Text('V1 · Offline personal finance tracker'),
          ),
          const ListTile(
            leading: Icon(Icons.tag),
            title: Text('App version'),
            subtitle: Text(_appVersion),
          ),
          const ListTile(
            leading: Icon(Icons.document_scanner_outlined),
            title: Text('OCR'),
            subtitle: Text('On-device PaddleOCR (PP-OCRv5)'),
          ),
          const ListTile(
            leading: Icon(Icons.storage_outlined),
            title: Text('Storage'),
            subtitle: Text('Local SQLite only · no cloud sync in V1'),
          ),
          const ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text('Privacy'),
            subtitle: Text('Receipt images & data stay on this device'),
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.delete_forever_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Clear all data',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: const Text('Delete all transactions (demo reset)'),
            onTap: () => _confirmClearAll(context, ref),
          ),
        ],
      ),
    );
  }
}