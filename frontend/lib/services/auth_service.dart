import '../models/user.dart';

/// Contém apenas os dados de sessão necessários para decidir qual tela exibir.
class AuthSession {
  const AuthSession({
    required this.userId,
    required this.email,
    required this.name,
    required this.role,
    this.establishments = const [],
  });

  final String userId;
  final String? email;
  final String name;
  final UserRole role;

  /// Identifica as lojas nas quais gerente ou funcionário pode atuar.
  final List<String> establishments;
}

/// Define o contrato de autenticação para desacoplar a interface do Firebase nos testes.
abstract interface class AuthService {
  /// Emite uma sessão quando o usuário entra e `null` quando ele sai.
  Stream<AuthSession?> get sessionChanges;

  /// Autentica uma conta existente usando e-mail e senha.
  Future<void> signIn({required String email, required String password});

  /// Solicita um link oficial do Firebase para o usuário definir uma nova senha.
  Future<void> sendPasswordResetEmail({required String email});

  /// Cria a conta e solicita ao backend um perfil público com papel de cliente.
  Future<void> register({
    required String name,
    required String email,
    required String password,
  });

  /// Encerra a sessão atual em todas as telas do aplicativo.
  Future<void> signOut();
}

/// Representa uma falha segura que pode ser apresentada diretamente ao usuário.
class AuthServiceException implements Exception {
  const AuthServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
