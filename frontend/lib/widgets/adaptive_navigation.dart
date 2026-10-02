import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/auth_service.dart';

/// Descreve uma opção contextual exibida no menu lateral de um perfil.
class AppNavigationItem {
  const AppNavigationItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;
}

/// Padroniza a navegação lateral responsiva para todos os perfis autenticados.
class AdaptiveNavigationScaffold extends StatelessWidget {
  const AdaptiveNavigationScaffold({
    required this.session,
    required this.authService,
    required this.body,
    required this.onOpenAbout,
    this.items = const [],
    this.trailingActions = const [],
    super.key,
  });

  final AuthSession session;
  final AuthService authService;
  final Widget body;
  final VoidCallback onOpenAbout;
  final List<AppNavigationItem> items;
  final List<Widget> trailingActions;

  /// Monta uma barra fixa em telas amplas e um Drawer deslizante no celular.
  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    final panel = _NavigationPanel(
      session: session,
      authService: authService,
      items: items,
      onOpenAbout: onOpenAbout,
      closeDrawerAfterTap: !isDesktop,
    );

    return Scaffold(
      drawer: isDesktop ? null : Drawer(child: SafeArea(child: panel)),
      appBar: isDesktop
          ? null
          : AppBar(
              title: const Text('Lanche Fácil'),
              actions: trailingActions,
            ),
      body: SafeArea(
        child: Row(
          children: [
            if (isDesktop)
              SizedBox(
                width: 270,
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: panel,
                ),
              ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// Renderiza identidade, atalhos e o acesso discreto às configurações.
class _NavigationPanel extends StatelessWidget {
  const _NavigationPanel({
    required this.session,
    required this.authService,
    required this.items,
    required this.onOpenAbout,
    required this.closeDrawerAfterTap,
  });

  final AuthSession session;
  final AuthService authService;
  final List<AppNavigationItem> items;
  final VoidCallback onOpenAbout;
  final bool closeDrawerAfterTap;

  /// Fecha o menu móvel antes de executar a navegação solicitada.
  void _openItem(BuildContext context, VoidCallback callback) {
    if (closeDrawerAfterTap) Navigator.of(context).pop();
    callback();
  }

  /// Abre as preferências; a saída fica intencionalmente dentro desta área.
  Future<void> _openSettings(BuildContext context) async {
    if (closeDrawerAfterTap) Navigator.of(context).pop();
    await showDialog<void>(
      context: context,
      builder: (_) => _SettingsDialog(authService: authService),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Row(
            children: [
              ClipRRect(
                key: const Key('app-brand-icon'),
                borderRadius: BorderRadius.circular(12),
                // Exibe a identidade oficial no cabeçalho de todos os perfis.
                child: Image.asset(
                  'assets/icons/app_icon.png',
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Lanche Fácil',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    Text(
                      session.name,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          // Somente as funções do perfil rolam; as preferências ficam isoladas no rodapé.
          child: ListView(
            padding: const EdgeInsets.only(top: 10, bottom: 10),
            children: [
              for (final item in items)
                ListTile(
                  leading: Icon(item.icon),
                  title: Text(item.label),
                  trailing: item.badgeCount > 0
                      ? Badge(label: Text('${item.badgeCount}'))
                      : null,
                  onTap: () => _openItem(context, item.onTap),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        SafeArea(
          top: false,
          // Mantém informações e preferências na base do menu em todas as telas.
          child: Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  key: const Key('open-about-application'),
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Sobre o aplicativo'),
                  onTap: () => _openItem(context, onOpenAbout),
                ),
                ListTile(
                  key: const Key('open-settings'),
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Configurações'),
                  onTap: () => _openSettings(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Permite seguir o aparelho ou substituir manualmente o tema do aplicativo.
class _SettingsDialog extends StatelessWidget {
  const _SettingsDialog({required this.authService});

  final AuthService authService;

  /// Solicita confirmação para evitar encerramento acidental da sessão persistida.
  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (confirmationContext) => AlertDialog(
            title: const Text('Sair da conta?'),
            content: const Text(
              'Você precisará entrar novamente para acessar seus pedidos.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(confirmationContext, false),
                child: const Text('Continuar conectado'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(confirmationContext, true),
                child: const Text('Sair da conta'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    // Remove avisos da tela autenticada para que não atravessem para o formulário de login.
    ScaffoldMessenger.of(context).clearSnackBars();
    Navigator.pop(context);
    await authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configurações'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: AppTheme.mode,
          builder: (context, selectedMode, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Aparência',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.settings_suggest_outlined),
                    label: Text('Aparelho'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Claro'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Escuro'),
                  ),
                ],
                selected: {selectedMode},
                onSelectionChanged: (selection) =>
                    AppTheme.setMode(selection.first),
              ),
              const Divider(),
              TextButton.icon(
                key: const Key('settings-sign-out'),
                onPressed: () => _confirmSignOut(context),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sair da conta'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Concluir'),
        ),
      ],
    );
  }
}
