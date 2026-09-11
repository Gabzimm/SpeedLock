import 'dart:async';
import 'package:flutter/foundation.dart';

/// GoRouter só reavalia `redirect` quando este Listenable notifica — sem
/// isto, fazer login/logout não moveria a app automaticamente entre
/// Boas-vindas e Controlo até à próxima navegação manual.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
