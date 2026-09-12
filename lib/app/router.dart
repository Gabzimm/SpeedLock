import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/auth_provider.dart';
import '../screens/onboarding/abertura_screen.dart';
import '../screens/onboarding/boas_vindas_screen.dart';
import '../screens/onboarding/login_screen.dart';
import '../screens/onboarding/criar_conta_screen.dart';
import '../screens/onboarding/recuperar_senha_screen.dart';
import '../screens/onboarding/ligar_screen.dart';
import '../screens/home/controlo_screen.dart';
import '../screens/account/perfil_screen.dart';
import '../screens/account/dispositivos_screen.dart';
import '../screens/account/historico_screen.dart';
import '../screens/account/configuracoes_screen.dart';
import 'router_refresh_stream.dart';

/// Rotas acessíveis sem sessão. `/ligar` está aqui porque o mockup tem
/// "Continuar sem login" a ir direto para lá (modo convidado) — mas ver
/// nota no README: o backend (`requestDeviceCommand`) exige sessão, por
/// isso o modo convidado real precisa de decidir entre exigir login
/// antes de qualquer comando, ou usar autenticação anónima da Firebase.
/// Isto ainda não está resolvido, só o routing está pronto para os dois
/// casos.
const _publicRoutes = {
  '/',
  '/boas-vindas',
  '/login',
  '/criar-conta',
  '/recuperar-senha',
  '/ligar',
};

/// Rotas que não fazem sentido ver depois de já ter sessão (login,
/// registo, boas-vindas) — entrar aí redireciona logo para o Controlo.
const _authOnlyEntryRoutes = {'/login', '/criar-conta', '/boas-vindas'};

final routerProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(authService.authStateChanges),
    redirect: (context, state) {
      final fb.User? user = authService.currentUser;
      final loggedIn = user != null;
      final loc = state.matchedLocation;

      // Abertura (splash) decide sozinha para onde ir a seguir.
      if (loc == '/') return null;

      if (!loggedIn && !_publicRoutes.contains(loc)) {
        return '/boas-vindas';
      }
      if (loggedIn && _authOnlyEntryRoutes.contains(loc)) {
        return '/controlo';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const AberturaScreen()),
      GoRoute(path: '/boas-vindas', builder: (context, state) => const BoasVindasScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/criar-conta', builder: (context, state) => const CriarContaScreen()),
      GoRoute(path: '/recuperar-senha', builder: (context, state) => const RecuperarSenhaScreen()),
      GoRoute(path: '/ligar', builder: (context, state) => const LigarScreen()),
      GoRoute(path: '/controlo', builder: (context, state) => const ControloScreen()),
      GoRoute(path: '/perfil', builder: (context, state) => const PerfilScreen()),
      GoRoute(path: '/dispositivos', builder: (context, state) => const DispositivosScreen()),
      GoRoute(path: '/historico', builder: (context, state) => const HistoricoScreen()),
      GoRoute(path: '/configuracoes', builder: (context, state) => const ConfiguracoesScreen()),
    ],
  );
});
