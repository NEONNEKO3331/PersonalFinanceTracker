import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'presentation/providers/theme_provider.dart';
///firebase_core: ^3.0.0
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart'; // 為了 kReleaseMode

/// Root messenger so SnackBars survive navigation (e.g. after Save → go home).
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  /*
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kReleaseMode
      ? const AndroidPlayIntegrityProvider()
      : const AndroidDebugProvider(
          debugToken: '',
        ),         // debug / 測試
    providerApple: kReleaseMode
        ? const AppleAppAttestProvider()         // release (或 AppleDeviceCheckProvider())
        : const AppleDebugProvider(),            // debug
  );
  */
  await FirebaseAppCheck.instance.activate(
  providerAndroid: const AndroidDebugProvider(
    debugToken: 'YourDebugTokenHere', // Replace with your actual debug token
  ),
  providerApple: const AppleDebugProvider(),
);

  runApp(const ProviderScope(child: MoneyBeeApp()));
}

class MoneyBeeApp extends ConsumerWidget {
  const MoneyBeeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'MoneyBee',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}