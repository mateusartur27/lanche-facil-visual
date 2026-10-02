import '../models/order.dart';

/// Resultado confiável devolvido pelo backend depois de criar o pedido.
class CreateOrderResult {
  const CreateOrderResult({required this.orderId, required this.totalAmount});

  final String orderId;
  final int totalAmount;
}

/// Transporta o conteúdo seguro usado exclusivamente para desenhar o QR de retirada.
class PickupCredentialResult {
  const PickupCredentialResult(
      {required this.orderId, required this.qrPayload});

  final String orderId;
  final String qrPayload;
}

/// Define as operações de pedido usadas pelos ViewModels.
abstract interface class OrderRepository {
  /// Cria o pedido no backend, que recalcula preços e estoque.
  Future<CreateOrderResult> createOrder({
    required String establishmentId,
    required String requestId,
    required List<Map<String, dynamic>> items,
    required String notes,
  });

  /// Emite somente os pedidos pertencentes ao cliente informado.
  Stream<List<Order>> watchCustomerOrders({
    required String establishmentId,
    required String userId,
  });

  /// Solicita ao backend o cancelamento seguro de um pedido ainda não pago.
  Future<void> cancelPendingOrder({
    required String establishmentId,
    required String orderId,
  });

  /// Oculta um pedido cancelado somente na visão do cliente.
  Future<void> hideCanceledOrder({
    required String establishmentId,
    required String orderId,
  });

  /// Solicita uma nova credencial somente para um pedido com pagamento confirmado.
  Future<PickupCredentialResult> issuePickupToken({
    required String establishmentId,
    required String orderId,
  });
}
