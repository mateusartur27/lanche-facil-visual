import 'dart:async';
import '../models/order.dart';
import '../models/user.dart';
import '../repositories/order_repository.dart';
import '../repositories/payment_repository.dart';
import '../services/auth_service.dart';
import '../services/product_service.dart';

/// Identifica exclusivamente o APK visual, sem alterar o aplicativo conectado.
const visualDemo = true;

/// Simula entrada e cadastro de cliente; nenhuma senha é salva ou enviada.
class DemoAuthService implements AuthService {
  AuthSession? _session;
  final _changes = StreamController<AuthSession?>.broadcast();
  @override
  Stream<AuthSession?> get sessionChanges async* {
    yield _session;
    yield* _changes.stream;
  }

  /// Usa uma identidade local fixa para preservar os pedidos durante a sessão.
  void _enter(String name, String email) {
    _session = AuthSession(
        userId: 'cliente-visual',
        email: email,
        name: name,
        role: UserRole.client);
    _changes.add(_session);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    _enter('Cliente demonstração', email);
  }

  @override
  Future<void> register(
          {required String name,
          required String email,
          required String password}) async =>
      _enter(name, email);

  /// A recuperação é apenas visual e nunca envia e-mail.
  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}
  @override
  Future<void> signOut() async {
    _session = null;
    _changes.add(null);
  }
}

/// Compartilha pedidos entre catálogo e histórico sem persistência ou rede.
class DemoOrderRepository implements OrderRepository {
  final _orders = <Order>[];
  final _changes = StreamController<List<Order>>.broadcast();
  final _requests = <String, CreateOrderResult>{};

  /// Calcula o pedido com o catálogo embarcado e preserva preços em centavos.
  @override
  Future<CreateOrderResult> createOrder(
      {required String establishmentId,
      required String requestId,
      required List<Map<String, dynamic>> items,
      required String notes}) async {
    if (_requests.containsKey(requestId)) return _requests[requestId]!;
    final products = sampleProducts(establishmentId);
    final snapshots = items.map((item) {
      final product = products.firstWhere((p) => p.id == item['productId']);
      final quantity = item['quantity'] as int;
      if (quantity <= 0 || quantity > product.stockQuantity) {
        throw StateError('Quantidade indisponível na demonstração.');
      }
      return OrderItem(
          productId: product.id,
          name: product.name,
          quantity: quantity,
          unitPrice: product.price,
          subtotal: quantity * product.price);
    }).toList();
    final now = DateTime.now();
    final order = Order(
        id: 'visual-${_orders.length + 1}',
        userId: 'cliente-visual',
        establishmentId: establishmentId,
        items: snapshots,
        totalAmount: snapshots.fold<int>(0, (s, i) => s + i.subtotal),
        status: OrderStatus.awaitingPayment,
        createdAt: now,
        updatedAt: now,
        notes: notes);
    _orders.insert(0, order);
    _changes.add(List.unmodifiable(_orders));
    return _requests[requestId] =
        CreateOrderResult(orderId: order.id, totalAmount: order.totalAmount);
  }

  @override
  Stream<List<Order>> watchCustomerOrders(
      {required String establishmentId, required String userId}) async* {
    // Cada nova tela recebe o estado atual antes das próximas atualizações.
    List<Order> filter(List<Order> orders) => orders
        .where(
            (o) => o.userId == userId && o.establishmentId == establishmentId)
        .toList();
    yield filter(_orders);
    yield* _changes.stream.map(filter);
  }

  /// Avança somente a simulação, sem autorizar pagamentos ou retiradas reais.
  void changeStatus(String orderId, OrderStatus status) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    final o = _orders[index];
    _orders[index] = Order(
        id: o.id,
        userId: o.userId,
        establishmentId: o.establishmentId,
        items: o.items,
        totalAmount: o.totalAmount,
        status: status,
        createdAt: o.createdAt,
        updatedAt: DateTime.now(),
        notes: o.notes);
    _changes.add(List.unmodifiable(_orders));
  }

  @override
  Future<void> cancelPendingOrder(
          {required String establishmentId, required String orderId}) async =>
      changeStatus(orderId, OrderStatus.canceled);
  @override
  Future<void> hideCanceledOrder(
      {required String establishmentId, required String orderId}) async {
    _orders.removeWhere(
        (o) => o.id == orderId && o.status == OrderStatus.canceled);
    _changes.add(List.unmodifiable(_orders));
  }

  @override
  Future<PickupCredentialResult> issuePickupToken(
          {required String establishmentId, required String orderId}) async =>
      PickupCredentialResult(
          orderId: orderId, qrPayload: 'DEMONSTRACAO-SEM-VALIDADE-$orderId');

  /// Recupera o total real da seleção local para desenhar a cobrança fictícia.
  int total(String id) => _orders.firstWhere((o) => o.id == id).totalAmount;
}

/// Simula o Pix e a preparação exclusivamente na memória do APK visual.
class DemoPaymentRepository implements PaymentRepository {
  final _confirmed = <String>{};
  @override
  Future<PixChargeResult> createPixCharge(
          {required String establishmentId, required String orderId}) async =>
      PixChargeResult(
          orderId: orderId,
          amount: demoOrders.total(orderId),
          qrCode: 'DEMONSTRACAO-NAO-PAGAR-$orderId',
          qrCodeBase64: '');
  @override
  Future<bool> refreshPixPaymentStatus(
          {required String establishmentId, required String orderId}) async =>
      _confirmed.contains(orderId);
  @override
  Future<PaymentApprovalResult> simulateApproval(
      {required String establishmentId, required String orderId}) async {
    final already = !_confirmed.add(orderId);
    if (!already) {
      demoOrders.changeStatus(orderId, OrderStatus.preparing);
      // A espera representa apenas o preparo visual; não expira o QR.
      Timer(const Duration(seconds: 4),
          () => demoOrders.changeStatus(orderId, OrderStatus.awaitingPickup));
    }
    return PaymentApprovalResult(orderId: orderId, alreadyConfirmed: already);
  }
}

/// Instâncias locais mantêm catálogo e histórico coerentes entre telas.
final demoOrders = DemoOrderRepository();
final demoPayments = DemoPaymentRepository();
