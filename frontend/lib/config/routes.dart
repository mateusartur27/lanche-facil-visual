import 'package:go_router/go_router.dart';

import '../screens/auth_gate.dart';
import '../services/auth_service.dart';
import '../services/product_service.dart';

/// Cria as rotas usando o serviço compartilhado que controla a sessão atual.
GoRouter createRouter(AuthService authService, ProductService productService) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        // A barreira decide entre autenticação e catálogo sem expor rotas privadas.
        builder: (context, state) => AuthGate(
          authService: authService,
          productService: productService,
        ),
      ),
    ],
  );
}
