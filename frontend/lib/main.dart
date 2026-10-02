import 'package:flutter/material.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'demo/demo_services.dart';
import 'services/auth_service.dart';
import 'services/product_service.dart';

/// Abre diretamente o visual do cliente, usando somente dados locais.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NovoIFood());
}

/// Define a raiz da aplicação e conecta tema, título e navegação.
class NovoIFood extends StatefulWidget {
  const NovoIFood({this.authService, this.productService, super.key});

  /// Permite substituir o Firebase por uma implementação controlada nos testes.
  final AuthService? authService;

  /// Permite usar um catálogo em memória nos testes automatizados.
  final ProductService? productService;

  /// Cria uma única instância do serviço e do roteador durante a execução.
  @override
  State<NovoIFood> createState() => _NovoIFoodState();
}

/// Preserva autenticação e navegação mesmo quando o usuário troca o tema.
class _NovoIFoodState extends State<NovoIFood> {
  late final AuthService _authService;
  late final ProductService _productService;
  late final RouterConfig<Object> _router;

  /// Inicializa dependências uma vez para não recriar streams ou histórico de navegação.
  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? DemoAuthService();
    _productService = widget.productService ?? MemoryProductService();
    _router = createRouter(_authService, _productService);
  }

  /// Constrói o aplicativo Material Design exibido no navegador ou celular.
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.mode,
      // O MaterialApp interpreta ThemeMode.system com o brilho informado pelo aparelho.
      builder: (context, themeMode, _) => MaterialApp.router(
        title: 'Lanche Fácil',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
