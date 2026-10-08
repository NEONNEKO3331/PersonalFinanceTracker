import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/entities/transaction.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/add_transaction/add_transaction_screen.dart';
import '../presentation/screens/scan_receipt/scan_receipt_screen.dart';
import '../presentation/screens/settings/settings_screen.dart';
import '../presentation/screens/history/history_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/add',
      builder: (context, state) {
        final extra = state.extra;
        if (extra is Transaction) {
          return AddTransactionScreen(existing: extra);
        }
        return AddTransactionScreen(
          prefill: extra is Map<String, dynamic> ? extra : null,
        );
      },
    ),
    GoRoute(
      path: '/scan',
      builder: (context, state) => const ScanReceiptScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryScreen(),
    ),
  ],
);