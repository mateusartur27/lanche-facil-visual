import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../view_models/auth_view_model.dart';

/// Exibe login e cadastro no mesmo fluxo, adaptando o painel à largura disponível.
class AuthScreen extends StatefulWidget {
  const AuthScreen({required this.authService, super.key});

  final AuthService authService;

  /// Cria o estado responsável pelos campos, validação e envio do formulário.
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

/// Mantém somente dados temporários do formulário e nunca persiste a senha localmente.
class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final AuthViewModel _viewModel;
  bool _hidePassword = true;

  @override
  void initState() {
    super.initState();
    _viewModel = AuthViewModel(authService: widget.authService)
      ..addListener(_refreshFromViewModel);
  }

  /// Reconstrói o formulário quando o ViewModel altera seu estado.
  void _refreshFromViewModel() {
    if (mounted) setState(() {});
  }

  /// Libera os controladores quando a tela deixa de existir para evitar vazamento de memória.
  @override
  void dispose() {
    _viewModel
      ..removeListener(_refreshFromViewModel)
      ..dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Monta o fundo e limita o formulário para continuar legível em monitores grandes.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 850;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: constraints.maxHeight - 40),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: wide
                        ? Row(children: [
                            const Expanded(child: _AuthIntroduction()),
                            const SizedBox(width: 48),
                            Expanded(child: _buildFormCard()),
                          ])
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const _AuthIntroduction(compact: true),
                              const SizedBox(height: 24),
                              _buildFormCard(),
                            ],
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Cria o cartão que alterna entre entrada e criação de uma nova conta.
  Widget _buildFormCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(
              _viewModel.isRegistering ? 'Criar conta de cliente' : 'Entrar',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _viewModel.isRegistering
                  ? 'Este cadastro é exclusivo para clientes. Funcionários são vinculados com segurança pelo gerente da loja.'
                  : 'Use sua conta para acessar o cardápio e seus pedidos.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            if (_viewModel.isRegistering) ...[
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: _validateName,
              ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              key: const Key('login-email'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: _validateEmail,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('login-password'),
              controller: _passwordController,
              obscureText: _hidePassword,
              textInputAction: TextInputAction.done,
              autofillHints: _viewModel.isRegistering
                  ? const [AutofillHints.newPassword]
                  : const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Senha',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _hidePassword ? 'Mostrar senha' : 'Ocultar senha',
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(_hidePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                ),
              ),
              validator: _validatePassword,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_viewModel.errorMessage != null) ...[
              const SizedBox(height: 14),
              Text(
                _viewModel.errorMessage!,
                key: const Key('auth-error'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _viewModel.isLoading ? null : _submit,
              child: _viewModel.isLoading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_viewModel.isRegistering
                      ? 'Cadastrar como cliente'
                      : 'Entrar'),
            ),
            if (!_viewModel.isRegistering)
              TextButton(
                onPressed:
                    _viewModel.isLoading ? null : _showPasswordResetDialog,
                child: const Text('Esqueci minha senha'),
              ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _viewModel.isLoading ? null : _toggleForm,
              child: Text(_viewModel.isRegistering
                  ? 'Já tenho uma conta'
                  : 'Ainda não tenho uma conta'),
            ),
            const SizedBox(height: 14),
            Text(
              'Desenvolvido por: Rafael Araújo Nascimento e Mateus Artur Santos',
              key: const Key('developer-credit'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.55),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /// Alterna o formulário e remove mensagens pertencentes à tentativa anterior.
  void _toggleForm() {
    _viewModel.toggleMode();
  }

  /// Abre uma solicitação curta sem informar se o e-mail existe no cadastro.
  Future<void> _showPasswordResetDialog() async {
    final resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    final resetFormKey = GlobalKey<FormState>();
    final sent = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        var sending = false;
        String? dialogError;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            /// Valida e envia o pedido mantendo o diálogo responsivo durante a espera.
            Future<void> sendRequest() async {
              if (sending ||
                  !(resetFormKey.currentState?.validate() ?? false)) {
                return;
              }
              setDialogState(() {
                sending = true;
                dialogError = null;
              });
              try {
                await _viewModel.sendPasswordReset(resetEmailController.text);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              } on AuthServiceException catch (error) {
                setDialogState(() {
                  sending = false;
                  dialogError = error.message;
                });
              }
            }

            return AlertDialog(
              title: const Text('Redefinir senha'),
              content: Form(
                key: resetFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informe seu e-mail. Se houver uma conta, enviaremos um link seguro.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('reset-email'),
                      controller: resetEmailController,
                      keyboardType: TextInputType.emailAddress,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'E-mail'),
                      validator: _validateEmail,
                      onFieldSubmitted: (_) => sendRequest(),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        dialogError!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: sending
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  key: const Key('send-reset'),
                  onPressed: sending ? null : sendRequest,
                  child: sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enviar link'),
                ),
              ],
            );
          },
        );
      },
    );
    // Aguarda o diálogo sair da árvore antes de liberar o controlador do campo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      resetEmailController.dispose();
    });

    if (sent == true && mounted) {
      // A mensagem neutra mantém o fluxo simples sem confirmar contas cadastradas.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Se houver uma conta com esse e-mail, o link de redefinição será enviado.',
          ),
        ),
      );
    }
  }

  /// Valida os campos antes de chamar o serviço de autenticação assíncrono.
  Future<void> _submit() async {
    if (_viewModel.isLoading || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await _viewModel.submit(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  /// Exige um nome útil somente durante a criação da conta.
  String? _validateName(String? value) {
    if (_viewModel.isRegistering &&
        (value == null || value.trim().length < 2)) {
      return 'Informe seu nome com pelo menos 2 caracteres.';
    }
    return null;
  }

  /// Faz uma validação básica de formato antes do Firebase validar o endereço.
  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    return !email.contains('@') || !email.contains('.')
        ? 'Informe um e-mail válido.'
        : null;
  }

  /// Mantém o mesmo requisito mínimo aplicado pelo Firebase Authentication.
  String? _validatePassword(String? value) {
    return value == null || value.length < 6
        ? 'A senha precisa ter pelo menos 6 caracteres.'
        : null;
  }
}

/// Apresenta o propósito do aplicativo ao lado ou acima do formulário.
class _AuthIntroduction extends StatelessWidget {
  const _AuthIntroduction({this.compact = false});

  final bool compact;

  /// Reduz texto e espaçamento no celular sem esconder informações essenciais.
  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    // Combina largura e altura para a marca crescer de forma fluida sem dominar a tela.
    final minimumLogoSize = compact ? 132.0 : 190.0;
    final maximumLogoSize = compact
        ? (viewport.height * 0.22).clamp(132.0, 190.0)
        : (viewport.height * 0.32).clamp(190.0, 260.0);
    final logoSize = (viewport.width * (compact ? 0.42 : 0.18))
        .clamp(minimumLogoSize, maximumLogoSize);

    return Column(
      crossAxisAlignment:
          compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        ClipRRect(
          key: const Key('auth-brand-icon'),
          borderRadius: BorderRadius.circular(logoSize * 0.14),
          // Apresenta a identidade visual oficial já na entrada da aplicação.
          child: Image.asset(
            'assets/icons/app_icon.png',
            width: logoSize,
            height: logoSize,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Lanche Fácil',
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: 10),
        Text(
          'Escolha, pague pelo aplicativo e retire seu pedido sem enfrentar fila.',
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
        ),
      ],
    );
  }
}
