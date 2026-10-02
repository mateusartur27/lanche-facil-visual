import '../demo/demo_services.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/order.dart';
import '../repositories/order_repository.dart';
import '../repositories/payment_repository.dart';
import '../services/auth_service.dart';
import '../services/product_service.dart';
import '../view_models/orders_view_model.dart';
import '../view_models/payment_view_model.dart';
import 'payment_dialog.dart';
import 'pickup_qr_dialog.dart';

/// Exibe somente os pedidos pertencentes ao cliente autenticado.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({
    required this.session,
    this.repository,
    this.paymentRepository,
    super.key,
  });

  /// Identifica o usuário usado no filtro protegido também pelas regras do Firestore.
  final AuthSession session;
  final OrderRepository? repository;
  final PaymentRepository? paymentRepository;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

/// Liga o ciclo de vida da View ao ViewModel responsável pela consulta.
class _OrdersScreenState extends State<OrdersScreen> {
  late final OrdersViewModel _viewModel;
  late final OrderRepository _orderRepository;
  late final PaymentRepository _paymentRepository;
  final Set<String> _processingOrders = <String>{};
  _OrderFilter _selectedFilter = _OrderFilter.active;

  @override
  void initState() {
    super.initState();
    _orderRepository = widget.repository ?? demoOrders;
    _viewModel = OrdersViewModel(
      repository: _orderRepository,
      establishmentId: CatalogConfiguration.demonstrationEstablishmentId,
      userId: widget.session.userId,
    );
    _paymentRepository = widget.paymentRepository ?? demoPayments;
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  /// Monta uma página responsiva que funciona em celular e monitores amplos.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meus pedidos')),
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, _) {
          if (_viewModel.failed) {
            return const _Message(
              icon: Icons.cloud_off_outlined,
              text: 'Não foi possível carregar seus pedidos agora.',
            );
          }
          if (_viewModel.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = _viewModel.orders
              .where((order) => _selectedFilter.accepts(order.status))
              .toList(growable: false);
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: orders.isEmpty ? 2 : orders.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, index) {
                  if (index == 0) {
                    return _OrderFilters(
                      selected: _selectedFilter,
                      onSelected: (filter) =>
                          setState(() => _selectedFilter = filter),
                    );
                  }
                  if (orders.isEmpty) {
                    return const _Message(
                      icon: Icons.filter_alt_off_outlined,
                      text: 'Nenhum pedido encontrado neste filtro.',
                    );
                  }
                  final order = orders[index - 1];
                  return _OrderCard(
                    order: order,
                    onContinuePayment: () => _openPayment(order),
                    processing: _processingOrders.contains(order.id),
                    onCancel: () => _confirmCancellation(order),
                    onShowPickupQr: () => _showPickupQr(order),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  /// Reabre de forma segura a cobrança persistida para um pedido ainda não pago.
  Future<void> _openPayment(Order order) async {
    final paymentViewModel = PaymentViewModel(repository: _paymentRepository);
    // O backend devolve o Pix existente em vez de criar uma cobrança duplicada.
    unawaited(paymentViewModel.createPixCharge(
      establishmentId: order.establishmentId,
      orderId: order.id,
    ));
    try {
      await showDialog<void>(
        context: context,
        builder: (_) => PaymentDialog(
          orderId: order.id,
          formattedTotal: _money(order.totalAmount),
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

  /// Abre a credencial de retirada sem mantê-la salva depois que o diálogo fechar.
  Future<void> _showPickupQr(Order order) {
    return showDialog<void>(
      context: context,
      builder: (_) => PickupQrDialog(
        repository: _orderRepository,
        establishmentId: order.establishmentId,
        orderId: order.id,
      ),
    );
  }

  /// Formata valores em centavos para apresentar o total sem ponto flutuante.
  String _money(int cents) =>
      'R\$ ${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')}';

  /// Pede confirmação humana antes de invalidar a cobrança e devolver o estoque.
  Future<void> _confirmCancellation(Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar pedido?'),
        content: const Text(
          'O Pix será invalidado e os produtos voltarão ao estoque. '
          'Esta operação ficará registrada no histórico da loja.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancelar pedido'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runOrderAction(
      order,
      action: () => _orderRepository.cancelPendingOrder(
        establishmentId: order.establishmentId,
        orderId: order.id,
      ),
      successMessage: 'Pedido cancelado e estoque devolvido.',
    );
  }

  /// Centraliza carregamento e mensagens das operações protegidas do pedido.
  Future<void> _runOrderAction(
    Order order, {
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    if (_processingOrders.contains(order.id)) return;
    setState(() => _processingOrders.add(order.id));
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Não foi possível concluir esta operação.')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingOrders.remove(order.id));
    }
  }
}

/// Apresenta dados históricos e observações sem permitir alterações no pedido criado.
class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onContinuePayment,
    required this.onCancel,
    required this.onShowPickupQr,
    required this.processing,
  });

  final Order order;
  final VoidCallback onContinuePayment;
  final VoidCallback onCancel;
  final VoidCallback onShowPickupQr;
  final bool processing;

  /// Converte o estado técnico em uma mensagem simples para o cliente.
  String get _statusLabel => switch (order.status) {
        OrderStatus.created => 'Pedido criado',
        OrderStatus.awaitingPayment => 'Aguardando pagamento',
        OrderStatus.preparing => 'Em preparação',
        OrderStatus.awaitingPickup => 'Pronto para retirada',
        OrderStatus.pickedUp => 'Retirado',
        OrderStatus.canceled => 'Cancelado',
      };

  /// Escolhe uma cor visual sem alterar a situação oficial gravada pelo backend.
  Color _statusColor(BuildContext context) => switch (order.status) {
        OrderStatus.awaitingPickup => Colors.green,
        OrderStatus.canceled => Theme.of(context).colorScheme.error,
        OrderStatus.pickedUp => Colors.blueGrey,
        _ => Theme.of(context).colorScheme.primary,
      };

  /// Formata valores armazenados em centavos no padrão brasileiro.
  String _money(int cents) =>
      'R\$ ${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text(
                  'Pedido ${order.id.substring(0, 8).toUpperCase()}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Chip(
                  avatar: Icon(Icons.circle,
                      size: 10, color: _statusColor(context)),
                  label: Text(_statusLabel),
                ),
              ],
            ),
            const Divider(),
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${item.quantity}x ${item.name} · ${_money(item.subtotal)}'),
                    if (item.notes?.isNotEmpty ?? false)
                      Text(
                        'Observação: ${item.notes}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            if (order.notes?.isNotEmpty ?? false) ...[
              const SizedBox(height: 4),
              Text('Observação geral: ${order.notes}'),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Total: ${_money(order.totalAmount)}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (order.status == OrderStatus.awaitingPayment) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: Key('continue-payment-${order.id}'),
                  onPressed: onContinuePayment,
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: const Text('Continuar pagamento'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: Key('cancel-order-${order.id}'),
                  onPressed: processing ? null : onCancel,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancelar pedido'),
                ),
              ),
            ],
            if (order.status == OrderStatus.preparing ||
                order.status == OrderStatus.awaitingPickup) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: Key('pickup-qr-${order.id}'),
                  onPressed: onShowPickupQr,
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: const Text('Mostrar QR de retirada'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Define filtros visuais sem alterar os estados oficiais armazenados no banco.
enum _OrderFilter {
  active('Em andamento'),
  awaitingPayment('Em espera'),
  preparing('Em preparo'),
  paid('Pagos'),
  pickedUp('Retirados'),
  canceled('Cancelados'),
  all('Todos');

  const _OrderFilter(this.label);
  final String label;

  /// Agrupa estados relacionados para o cliente localizar rapidamente cada pedido.
  bool accepts(OrderStatus status) => switch (this) {
        _OrderFilter.active => status == OrderStatus.awaitingPayment ||
            status == OrderStatus.preparing ||
            status == OrderStatus.awaitingPickup,
        _OrderFilter.awaitingPayment => status == OrderStatus.awaitingPayment,
        _OrderFilter.preparing => status == OrderStatus.preparing,
        _OrderFilter.paid => status == OrderStatus.preparing ||
            status == OrderStatus.awaitingPickup ||
            status == OrderStatus.pickedUp,
        _OrderFilter.pickedUp => status == OrderStatus.pickedUp,
        _OrderFilter.canceled => status == OrderStatus.canceled,
        _OrderFilter.all => true,
      };
}

/// Apresenta filtros roláveis para manter o uso confortável em celulares estreitos.
class _OrderFilters extends StatelessWidget {
  const _OrderFilters({required this.selected, required this.onSelected});

  final _OrderFilter selected;
  final ValueChanged<_OrderFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in _OrderFilter.values) ...[
            ChoiceChip(
              label: Text(filter.label),
              selected: selected == filter,
              onSelected: (_) => onSelected(filter),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// Centraliza mensagens de carregamento vazio e falhas de consulta.
class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
