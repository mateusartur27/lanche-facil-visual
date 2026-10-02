import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

/// Representa os estados possíveis durante a restauração da sessão autenticada.
enum SessionStatus { loading, authenticated, unauthenticated, failed }

/// Observa a autenticação e entrega à interface um estado simples e previsível.
class SessionViewModel extends ChangeNotifier {
  SessionViewModel({required AuthService authService})
      : _authService = authService {
    _subscription = _authService.sessionChanges.listen(
      (value) {
        session = value;
        status = value == null
            ? SessionStatus.unauthenticated
            : SessionStatus.authenticated;
        notifyListeners();
      },
      onError: (_) {
        status = SessionStatus.failed;
        notifyListeners();
      },
    );
  }

  final AuthService _authService;
  late final StreamSubscription<AuthSession?> _subscription;

  AuthSession? session;
  SessionStatus status = SessionStatus.loading;

  /// Encerra uma sessão incompleta para permitir uma nova tentativa de entrada.
  Future<void> signOut() => _authService.signOut();

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
