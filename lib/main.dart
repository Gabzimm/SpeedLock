import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/router.dart';
import 'app/theme.dart';
// import 'firebase_options.dart'; // gerado pelo `flutterfire configure` — ver README

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    // options: DefaultFirebaseOptions.currentPlatform, // depois do flutterfire configure
  );

  runApp(const ProviderScope(child: SpeedLockApp()));
}

class SpeedLockApp extends ConsumerWidget {
  const SpeedLockApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'SpeedLock',
      debugShowCheckedModeBanner: false,
      theme: SpeedLockTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
