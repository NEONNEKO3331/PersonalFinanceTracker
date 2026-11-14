import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/services/backup_service.dart';
import '../../providers/theme_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/bee_brand.dart';

/// Matches pubspec.yaml version field.
const _appVersion = '1.0.0+1';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

  Future<void> _confirmClearAll(BuildContext context) async {
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

  Future<void> _backup() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final list = ref.read(transactionsProvider).valueOrNull ?? [];
      if (list.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No transactions to back up'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final service = BackupService();
      final path = await service.createBackupFile(list);
      await service.shareBackup(path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Backup ready · ${list.length} transaction'
              '${list.length == 1 ? '' : 's'}',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: false,
      dialogTitle: 'Select MoneyBee backup',
    );
    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read the selected file'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final List<Transaction> items;
    try {
      final service = BackupService();
      items = await service.loadBackupFile(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid backup file: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final count = items.length;
    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore backup?'),
        content: Text(
          'This will replace all current data with $count transaction'
          '${count == 1 ? '' : 's'} from the backup.\n\n'
          'Tip: export a backup first if you want to keep today’s data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(transactionsProvider.notifier).restoreAll(items);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Restored $count transaction${count == 1 ? '' : 's'}',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final iconColor = onSurface.withValues(alpha: 0.85);
    final themeMode = ref.watch(themeModeProvider);
    final txCount =
        ref.watch(transactionsProvider).valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        // Extra bottom inset so last tiles clear system nav / gesture bar
        // (this route has no bottom navigation bar).
        padding: EdgeInsets.fromLTRB(
          0,
          8,
          0,
          8 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const BeeMark(size: 44),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MoneyBee',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'V1 · Offline personal finance tracker',
                            style: TextStyle(
                              color: onSurface.withValues(alpha: 0.7),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Appearance ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Appearance',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: onSurface,
                fontSize: 15,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto, size: 18),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_outlined, size: 18),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_outlined, size: 18),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (set) {
                ref.read(themeModeProvider.notifier).setMode(set.first);
              },
            ),
          ),
          const SizedBox(height: 8),
          const Divider(indent: 16, endIndent: 16),

          // ── Data ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Data',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: onSurface,
                fontSize: 15,
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.backup_outlined, color: iconColor),
            title: const Text('Backup'),
            subtitle: Text(
              txCount == 0
                  ? 'No transactions yet'
                  : 'Export all $txCount transaction'
                      '${txCount == 1 ? '' : 's'} as JSON',
            ),
            trailing: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _busy ? null : _backup,
          ),
          ListTile(
            leading: Icon(Icons.restore_outlined, color: iconColor),
            title: const Text('Restore'),
            subtitle: const Text('Import a MoneyBee JSON backup'),
            trailing: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _busy ? null : _restore,
          ),
          const Divider(indent: 16, endIndent: 16),

          ListTile(
            leading: Icon(Icons.tag, color: iconColor),
            title: const Text('App version'),
            subtitle: const Text(_appVersion),
          ),
          ListTile(
            leading: Icon(Icons.document_scanner_outlined, color: iconColor),
            title: const Text('OCR'),
            subtitle: const Text('On-device PaddleOCR (PP-OCRv5)'),
          ),
          ListTile(
            leading: Icon(Icons.storage_outlined, color: iconColor),
            title: const Text('Storage'),
            subtitle: const Text('Local SQLite only · no cloud sync in V1'),
          ),
          ListTile(
            leading: Icon(Icons.privacy_tip_outlined, color: iconColor),
            title: const Text('Privacy'),
            subtitle: const Text('Receipt images & data stay on this device'),
          ),
          const Divider(indent: 16, endIndent: 16),
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
            onTap: _busy ? null : () => _confirmClearAll(context),
          ),
        ],
      ),
    );
  }
}
