import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../widgets/bee_brand.dart';

/// Placeholder for week/month XLSX export (next step).
class ExportScreen extends StatelessWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const BeeSectionTitle(title: 'Export to Excel'),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.table_view_rounded,
                    size: 48,
                    color: BeeColors.honey.withValues(alpha: 0.85),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Coming next',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Export this week or this month’s income & expenses as an .xlsx file.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: onSurface.withValues(alpha: 0.65),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.file_download_outlined),
                    label: const Text('Export (next step)'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}