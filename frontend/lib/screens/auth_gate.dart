import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/product_service.dart';
import '../view_models/session_view_model.dart';
import 'auth_screen.dart';
import 'home_screen.dart';

/// Protege o catálogo e escolhe a tela conforme o estado real da autenticação.
class AuthGate extends StatefulWidget {
  const AuthGate(
      {required this.authService, required this.productService, super.key});

  final AuthService authService;
  final ProductService productService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

/// Mantém o ciclo de vida do ViewModel responsável pela sessão do usuário.
class _AuthGateState extends State<AuthGate> {
  late final SessionViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = SessionViewModel(authService: widget.authService);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  /// Aguarda o Firebase restaurar a sessão antes de liberar conteúdo protegido.
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        if (_viewModel.status == SessionStatus.failed) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 44),
                    const SizedBox(height: 14),
                    const Text(
                      'Não foi possível carregar seu perfil.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      // Sair permite tentar novamente sem manter uma sessão incompleta.
                      onPressed: _viewModel.signOut,
                      child: const Text('Voltar ao login'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (_viewModel.status == SessionStatus.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (_viewModel.status == SessionStatus.unauthenticated) {
          return AuthScreen(authService: widget.authService);
        }

        final session = _viewModel.session!;
        return HomeScreen(
          authService: widget.authService,
          session: session,
          productService: widget.productService,
        );
      },
    );
  }
}
