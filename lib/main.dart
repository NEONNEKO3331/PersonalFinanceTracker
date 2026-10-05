import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';

/// Root messenger so SnackBars survive navigation (e.g. after Save → go home).
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MoneyBeeApp()));
}

class MoneyBeeApp extends StatelessWidget {
  const MoneyBeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MoneyBee',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}