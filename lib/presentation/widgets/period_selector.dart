import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../providers/transaction_provider.dart';

/// Shared week / month / custom period control used on Home & Analytics.
class PeriodSelector extends ConsumerWidget {
  const PeriodSelector({super.key});

  Future<void> _pickCustomRange(BuildContext context, WidgetRef ref) async {
    final current = ref.read(customDateRangeProvider);
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 5);
    final lastDate = DateTime(now.year, now.month, now.day);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: DateTimeRange(
        start: current.startDay,
        end: DateTime(current.end.year, current.end.month, current.end.day),
      ),
      helpText: 'Select date range',
      saveText: 'Apply',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: BeeColors.honey,
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref.read(customDateRangeProvider.notifier).state = DateRange(
        DateTime(picked.start.year, picked.start.month, picked.start.day),
        DateTime(picked.end.year, picked.end.month, picked.end.day),
      );
      ref.read(homePeriodProvider.notifier).state = HomePeriod.custom;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(homePeriodProvider);
    final range = ref.watch(customDateRangeProvider);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<HomePeriod>(
          segments: const [
            ButtonSegment(
              value: HomePeriod.week,
              label: Text('Week'),
              icon: Icon(Icons.view_week_outlined, size: 18),
            ),
            ButtonSegment(
              value: HomePeriod.month,
              label: Text('Month'),
              icon: Icon(Icons.calendar_month_outlined, size: 18),
            ),
            ButtonSegment(
              value: HomePeriod.custom,
              label: Text('Custom'),
              icon: Icon(Icons.date_range_outlined, size: 18),
            ),
          ],
          selected: {period},
          onSelectionChanged: (s) {
            final next = s.first;
            ref.read(homePeriodProvider.notifier).state = next;
            if (next == HomePeriod.custom) {
              // Open picker when user switches to Custom.
              _pickCustomRange(context, ref);
            }
          },
        ),
        if (period == HomePeriod.custom) ...[
          const SizedBox(height: 10),
          Material(
            color: BeeColors.honey.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _pickCustomRange(context, ref),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.edit_calendar_outlined,
                      size: 20,
                      color: BeeColors.honey,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        range.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: onSurface,
                        ),
                      ),
                    ),
                    Text(
                      'Change',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: BeeColors.honey.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Compact date chip used on Export custom card.
class DateChipButton extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const DateChipButton({
    super.key,
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final fmt = DateFormat('dd MMM yyyy');

    return Expanded(
      child: Material(
        color: onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fmt.format(date),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}