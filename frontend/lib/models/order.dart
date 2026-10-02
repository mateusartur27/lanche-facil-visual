/// Lista os estados permitidos no ciclo de vida de um pedido.
enum OrderStatus {
  created,
  awaitingPayment,
  preparing,
  awaitingPickup,
  pickedUp,
  canceled,
}

/// Traduz os estados Dart para os valores estáveis armazenados no Firestore.
extension OrderStatusFirestore on OrderStatus {
  /// Retorna o nome explícito usado pelo backend e pelos documentos históricos.
  String get firestoreValue => switch (this) {
        OrderStatus.created => 'CREATED',
        OrderStatus.awaitingPayment => 'AWAITING_PAYMENT',
        OrderStatus.preparing => 'PREPARING',
        OrderStatus.awaitingPickup => 'AWAITING_PICKUP',
        OrderStatus.pickedUp => 'PICKED_UP',
        OrderStatus.canceled => 'CANCELED',
      };
}

/// Converte o texto recebido do Firestore em um estado de pedido conhecido.
OrderStatus orderStatusFromFirestore(Object? value) {
  return switch (value) {
    'CREATED' => OrderStatus.created,
    'AWAITING_PAYMENT' => OrderStatus.awaitingPayment,
    'PREPARING' => OrderStatus.preparing,
    'AWAITING_PICKUP' => OrderStatus.awaitingPickup,
    'PICKED_UP' => OrderStatus.pickedUp,
    'CANCELED' => OrderStatus.canceled,
    // Dados desconhecidos são recusados para não exibir um estado financeiro errado.
    _ => throw FormatException('Estado de pedido inválido: $value'),
  };
}

/// Representa um pedido e preserva os dados históricos da compra.
class Order {
  final String id;
  final String userId;
  final String establishmentId;
  final List<OrderItem> items;

  /// Valor total em centavos para evitar imprecisão de ponto flutuante.
  final int totalAmount;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? notes;

  /// Cria um pedido já calculado e associado ao usuário e estabelecimento.
  const Order({
    required this.id,
    required this.userId,
    required this.establishmentId,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
  });
}

/// Preserva a quantidade e o preço aplicado a um produto no momento da compra.
class OrderItem {
  final String productId;
  final String name;
  final int quantity;

  /// Preço unitário histórico em centavos.
  final int unitPrice;

  /// Resultado de quantidade multiplicada pelo preço unitário, em centavos.
  final int subtotal;
  final String? notes;

  /// Cria a fotografia histórica de um item incluído no pedido.
  const OrderItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.notes,
  });

  /// Reconstrói um item a partir do mapa armazenado dentro do pedido.
  factory OrderItem.fromMap(Map<String, dynamic> data) {
    return OrderItem(
      productId: data['productId'] as String,
      name: data['name'] as String,
      quantity: data['quantity'] as int,
      unitPrice: data['unitPrice'] as int,
      subtotal: data['subtotal'] as int,
      notes: data['notes'] as String?,
    );
  }

  /// Produz o mapa incorporado no documento do pedido no Firestore.
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'subtotal': subtotal,
      'notes': notes,
    };
  }
}
