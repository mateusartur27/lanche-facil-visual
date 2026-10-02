import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

/// Controla modo, carregamento e erros do formulário de autenticação.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel({required AuthService authService})
      : _authService = authService;
  final AuthService _authService;
  bool isRegistering = false;
  bool isLoading = false;
  String? errorMessage;

  /// Encerra tentativas sem resposta para o botão nunca ficar carregando indefinidamente.
  static const Duration _requestTimeout = Duration(seconds: 20);

  /// Alterna login e cadastro limpando mensagens da tentativa anterior.
  void toggleMode() {
    isRegistering = !isRegistering;
    errorMessage = null;
    notifyListeners();
  }

  /// Executa login ou cadastro e traduz o resultado em estado observável.
  Future<void> submit(
      {required String name,
      required String email,
      required String password}) async {
    if (isLoading) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      if (isRegistering) {
        await _authService
            .register(name: name, email: email, password: password)
            .timeout(_requestTimeout);
      } else {
        await _authService
            .signIn(email: email, password: password)
            .timeout(_requestTimeout);
      }
    } on TimeoutException {
      errorMessage = 'O servidor demorou para responder. Tente novamente.';
    } on AuthServiceException catch (error) {
      errorMessage = error.message;
    } catch (_) {
      errorMessage = 'Ocorreu um erro inesperado. Tente novamente.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Solicita redefinição sem revelar se o endereço possui cadastro.
  Future<void> sendPasswordReset(String email) =>
      _authService.sendPasswordResetEmail(email: email);
}
