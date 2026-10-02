import '../demo/demo_services.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import '../models/product.dart';
import '../repositories/order_repository.dart';
import '../repositories/payment_repository.dart';
import '../services/auth_service.dart';
import '../services/product_service.dart';
import '../view_models/checkout_view_model.dart';
import '../view_models/catalog_view_model.dart';
import '../view_models/payment_view_model.dart';
import '../view_models/orders_view_model.dart';
import '../widgets/adaptive_navigation.dart';
import 'about_app_dialog.dart';
import 'orders_screen.dart';
import 'payment_dialog.dart';

/// Reúne as cores próprias da tela para facilitar futuras mudanças de identidade.
abstract final class HomeColors {
  static const Color blue = Color(0xFF0079BF);
  static const Color darkBlue = Color(0xFF172B4D);
  static const Color green = Color(0xFF5AAC44);
}

/// Representa um produto temporário usado apenas para visualizar o catálogo.
class ProductPreview {
  /// Cria os dados mínimos necessários para montar um cartão do cardápio.
  const ProductPreview({
    this.id = '',
    required this.name,
    required this.description,
    required this.category,
    required this.priceInCents,
    required this.icon,
    required this.tint,
    this.stockQuantity = 0,
    this.imageUrl,
    this.highlight,
  });

  final String id;
  final String name;
  final String description;
  final String category;

  /// Guarda dinheiro em centavos para evitar erros de arredondamento.
  final int priceInCents;
  final IconData icon;
  final Color tint;
  final int stockQuantity;
  final String? imageUrl;
  final String? highlight;
}

/// Exibe o catálogo responsivo e controla as interações visuais do protótipo.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.authService,
    required this.session,
    required this.productService,
    super.key,
  });

  /// Serviço compartilhado usado para encerrar a sessão pelo cabeçalho.
  final AuthService authService;

  /// Perfil confiável carregado do Firestore para personalizar a experiência.
  final AuthSession session;
  final ProductService productService;

  /// Cria o estado que guarda categoria selecionada e contador do carrinho.
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Mantém apenas estado visual; pedidos reais continuarão sendo validados no backend.
class _HomeScreenState extends State<HomeScreen> {
  late final CatalogViewModel _catalog;
  late final CheckoutViewModel _checkout;
  late final OrdersViewModel _orders;
  late final OrderRepository _orderRepository;
  late final PaymentRepository _paymentRepository;
  // Guarda a única observação do checkout, aplicada ao pedido completo.
  final TextEditingController _orderNotesController = TextEditingController();
  // Mantém a pesquisa como estado visual local, sem provocar novas leituras no banco.
  String _searchTerm = '';

  /// Converte modelos de domínio somente nas propriedades visuais do cartão.
  List<ProductPreview> get _products =>
      _catalog.products.map(_toPreview).toList(growable: false);

  /// Calcula a quantidade total de unidades selecionadas.
  int get _cartCount => _checkout.itemCount;

  /// Indica quantos pedidos do cliente ainda estão em andamento.
  int get _activeOrderCount => _orders.activeOrderCount;

  /// Soma os subtotais usando apenas valores inteiros em centavos.
  int get _cartTotalInCents => _checkout.totalInCents;

  /// Obtém as categorias diretamente dos produtos cadastrados.
  List<String> get _categories => [
        'Todos',
        ...{for (final product in _products) product.category},
      ];

  @override
  void initState() {
    super.initState();
    _catalog = CatalogViewModel(productService: widget.productService)
      ..addListener(_refreshFromViewModel)
      ..start(CatalogConfiguration.demonstrationEstablishmentId);
    // Compartilha pedidos e pagamento entre catálogo e histórico local.
    _orderRepository = demoOrders;
    _paymentRepository = demoPayments;
    _checkout = CheckoutViewModel(repository: _orderRepository)
      ..addListener(_refreshFromViewModel);
    _orders = OrdersViewModel(
      repository: _orderRepository,
      establishmentId: CatalogConfiguration.demonstrationEstablishmentId,
      userId: widget.session.userId,
    )..addListener(_refreshFromViewModel);
  }

  @override
  void dispose() {
    _catalog
      ..removeListener(_refreshFromViewModel)
      ..dispose();
    _checkout
      ..removeListener(_refreshFromViewModel)
      ..dispose();
    _orders
      ..removeListener(_refreshFromViewModel)
      ..dispose();
    _orderNotesController.dispose();
    super.dispose();
  }

  /// Reconstrói somente a apresentação quando o estado do checkout mudar.
  void _refreshFromViewModel() {
    if (mounted) setState(() {});
  }

  /// Adapta o documento persistido aos elementos visuais do catálogo.
  ProductPreview _toPreview(Product product) {
    return ProductPreview(
      id: product.id,
      name: product.name,
      description: product.description,
      category: product.categoryId,
      priceInCents: product.price,
      icon: product.categoryId == 'Bebidas'
          ? Icons.local_drink_rounded
          : Icons.lunch_dining_rounded,
      tint: const Color(0xFFFFE7D6),
      stockQuantity: product.stockQuantity,
      imageUrl: product.imageUrl,
    );
  }

  /// Combina a categoria escolhida com a pesquisa sobre o catálogo já carregado.
  List<ProductPreview> get _visibleProducts {
    return _products.where((product) {
      final matchesCategory = _catalog.selectedCategory == 'Todos' ||
          product.category == _catalog.selectedCategory;
      final searchableText =
          '${product.name} ${product.description} ${product.category}'
              .toLowerCase();
      final matchesSearch =
          _searchTerm.isEmpty || searchableText.contains(_searchTerm);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  /// Monta a página e limita sua largura para não esticar em monitores grandes.
  @override
  Widget build(BuildContext context) {
    return AdaptiveNavigationScaffold(
      session: widget.session,
      authService: widget.authService,
      onOpenAbout: () => showAboutApplicationDialog(context),
      items: [
        AppNavigationItem(
          label: 'Cardápio',
          icon: Icons.storefront_outlined,
          onTap: () {},
        ),
        AppNavigationItem(
          label: 'Pedidos',
          icon: Icons.receipt_long_outlined,
          onTap: _openOrders,
          badgeCount: _activeOrderCount,
        ),
        AppNavigationItem(
          label: 'Carrinho',
          icon: Icons.shopping_bag_outlined,
          onTap: _showCart,
          badgeCount: _cartCount,
        ),
      ],
      trailingActions: [
        _CartButton(count: _cartCount, onPressed: _showCart),
        const SizedBox(width: 8),
      ],
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCompactWelcomeCard(context),
                      const SizedBox(height: 16),
                      _buildProductSearch(),
                      const SizedBox(height: 24),
                      _buildSectionTitle(),
                      const SizedBox(height: 14),
                      _buildCategories(),
                      const SizedBox(height: 22),
                      _buildProductGrid(),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Recebe o cliente sem ocupar a área principal do cardápio em telas pequenas.
  Widget _buildCompactWelcomeCard(BuildContext context) {
    final firstName = widget.session.name.trim().split(' ').first;
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('compact-welcome-card'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.55),
        border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            child: const Icon(Icons.waving_hand_rounded, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Seja bem-vindo, $firstName!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Text(
                  'Escolha seus produtos e retire sem enfrentar fila.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Abre o histórico sem perder o estado atual do catálogo e do carrinho.
  void _openOrders() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => OrdersScreen(
        session: widget.session,
        repository: _orderRepository,
        paymentRepository: _paymentRepository,
      ),
    ));
  }

  /// Exibe somente a busca do catálogo, com largura confortável em telas amplas.
  Widget _buildProductSearch() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: TextField(
        key: const Key('product-search'),
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search_rounded),
          hintText: 'Pesquisar produtos',
        ),
        // Filtra a lista já carregada para responder imediatamente à digitação.
        onChanged: (value) {
          setState(() => _searchTerm = value.trim().toLowerCase());
        },
      ),
    );
  }

  /// Exibe o título da seção e a quantidade resultante do filtro atual.
  Widget _buildSectionTitle() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Cardápio de hoje',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          '${_visibleProducts.length} itens',
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  /// Desenha filtros horizontais semelhantes às colunas do Kanban de referência.
  Widget _buildCategories() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((category) {
          final selected = category == _catalog.selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(category),
              selected: selected,
              onSelected: (_) => _catalog.selectCategory(category),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Distribui cartões em uma, duas ou três colunas conforme a largura disponível.
  Widget _buildProductGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 3
            : constraints.maxWidth >= 620
                ? 2
                : 1;
        const spacing = 16.0;
        final cardWidth =
            (constraints.maxWidth - (columns - 1) * spacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: _visibleProducts.map((product) {
            return SizedBox(
              width: cardWidth,
              child: _ProductCard(
                  product: product, onAdd: () => _addToCart(product)),
            );
          }).toList(),
        );
      },
    );
  }

  /// Inclui uma unidade sem ultrapassar o estoque informado pela loja.
  void _addToCart(ProductPreview product) {
    final added = _checkout.addItem(
      productId: product.id,
      price: product.priceInCents,
      stock: product.stockQuantity,
    );
    if (!added) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantidade máxima disponível atingida.')),
      );
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1800),
        content: Text(
          '${product.name} adicionado. Carrinho: $_cartCount item(ns).',
          key: const Key('cart-add-feedback'),
        ),
        action: SnackBarAction(
          label: 'VER CARRINHO',
          onPressed: _showCart,
        ),
      ));
  }

  /// Exibe itens, remoção, observação geral e total antes da criação do pedido.
  void _showCart() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        // O estado local atualiza imediatamente o resumo quando um item é removido.
        builder: (context, updateDialog) {
          final selected = _products
              .where((product) => (_checkout.quantities[product.id] ?? 0) > 0)
              .toList();
          return AlertDialog(
            title: const Text('Confirmar pedido'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: selected.isEmpty
                    ? const Text('Seu carrinho está vazio.')
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final product in selected)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(product.name),
                              subtitle: Text(
                                  '${_checkout.quantities[product.id]} unidade(s) · ${_formatMoney(product.priceInCents * _checkout.quantities[product.id]!)}'),
                              trailing: IconButton(
                                tooltip: 'Remover ${product.name}',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  _checkout.removeItem(product.id);
                                  updateDialog(() {});
                                },
                              ),
                            ),
                          TextField(
                            controller: _orderNotesController,
                            maxLength: 500,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Observação geral do pedido',
                              hintText: 'Ex.: entregar todos os itens juntos',
                              prefixIcon: Icon(Icons.receipt_long_outlined),
                            ),
                          ),
                          const Divider(),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Total: ${_formatMoney(_cartTotalInCents)}',
                              key: const Key('cart-total'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Continuar comprando'),
              ),
              if (selected.isNotEmpty)
                FilledButton.icon(
                  key: const Key('confirm-order'),
                  onPressed: _checkout.isCreatingOrder
                      ? null
                      : () => _createOrder(dialogContext, updateDialog),
                  icon: _checkout.isCreatingOrder
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(_checkout.isCreatingOrder
                      ? 'Criando pedido...'
                      : 'Confirmar pedido'),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Envia somente IDs e quantidades; valores monetários nunca são confiados ao frontend.
  Future<void> _createOrder(
    BuildContext cartDialogContext,
    StateSetter updateDialog,
  ) async {
    if (_checkout.isCreatingOrder) return;
    try {
      final creation = _checkout.createOrder(
        establishmentId: CatalogConfiguration.demonstrationEstablishmentId,
        orderNotes: _orderNotesController.text,
      );
      // O ViewModel já marcou a operação como ativa; o diálogo reflete isso no mesmo clique.
      updateDialog(() {});
      final result = await creation;
      if (!mounted || !cartDialogContext.mounted) return;
      Navigator.pop(cartDialogContext);
      _orderNotesController.clear();
      await _showPaymentStep(
        orderId: result.orderId,
        total: result.totalAmount,
      );
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'O servidor demorou para responder. Tente confirmar novamente.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      // Exibe falhas inesperadas para que o botão nunca pareça sem resposta.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível criar o pedido: $error')),
      );
    } finally {
      // Se houver erro, restaura o botão dentro do próprio diálogo ainda aberto.
      if (cartDialogContext.mounted) updateDialog(() {});
    }
  }

  /// Abre a etapa financeira e libera simulação somente no build dos emuladores.
  Future<void> _showPaymentStep({
    required String orderId,
    required int total,
  }) async {
    final paymentViewModel = PaymentViewModel(repository: _paymentRepository);
    try {
      await showDialog<void>(
        context: context,
        builder: (context) => PaymentDialog(
          orderId: orderId,
          formattedTotal: _formatMoney(total),
          viewModel: paymentViewModel,
          simulationEnabled: visualDemo ||
              const bool.fromEnvironment(
                'USE_FIREBASE_EMULATORS',
                defaultValue: false,
              ),
        ),
      );
    } finally {
      paymentViewModel.dispose();
    }
  }

  /// Formata centavos no padrão monetário exibido ao cliente.
  String _formatMoney(int cents) =>
      'R\$ ${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')}';
}

/// Mostra o acesso ao carrinho junto de um contador visual de itens.
class _CartButton extends StatelessWidget {
  const _CartButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  /// Monta um botão branco para criar contraste com o cabeçalho azul.
  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: const Key('open-cart'),
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: HomeColors.darkBlue,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.shopping_bag_outlined),
      ),
      label: MediaQuery.sizeOf(context).width >= 900
          ? const Text('Carrinho')
          : const SizedBox.shrink(),
    );
  }
}

/// Desenha um produto em cartão branco, seguindo a referência visual do Kanban.
class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onAdd});

  final ProductPreview product;
  final VoidCallback onAdd;

  /// Converte os centavos para uma apresentação monetária simples em reais.
  String get _formattedPrice {
    final reais = product.priceInCents ~/ 100;
    final centavos = (product.priceInCents % 100).toString().padLeft(2, '0');
    return 'R\$ $reais,$centavos';
  }

  /// Monta um cartão com ilustração, descrição, preço e chamada para ação.
  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 124,
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: product.tint,
                      borderRadius: BorderRadius.circular(14)),
                  child: product.imageUrl == null || product.imageUrl!.isEmpty
                      ? Icon(product.icon, size: 62, color: HomeColors.darkBlue)
                      : Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            product.icon,
                            size: 62,
                            color: HomeColors.darkBlue,
                          ),
                        ),
                ),
                if (product.highlight != null)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        product.highlight!,
                        style: const TextStyle(
                          color: HomeColors.blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              product.category.toUpperCase(),
              style: const TextStyle(
                color: HomeColors.blue,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              product.name,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Text(
              product.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4),
            ),
            const SizedBox(height: 18),
            Text(
              product.stockQuantity > 0
                  ? '${product.stockQuantity} unidade(s) disponível(is)'
                  : 'Produto indisponível',
              style: TextStyle(
                color: product.stockQuantity > 0
                    ? HomeColors.green
                    : Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formattedPrice,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w900),
                  ),
                ),
                FilledButton.icon(
                  onPressed: product.stockQuantity > 0 ? onAdd : null,
                  icon: const Icon(Icons.add_rounded, size: 19),
                  label: const Text('Adicionar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
