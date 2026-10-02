import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/order.dart';
import '../repositories/order_repository.dart';

/// Mantém o estado da tela de pedidos sem expor Firebase à View.
class OrdersViewModel extends ChangeNotifier {
  OrdersViewModel({
    required OrderRepository repository,
    required String establishmentId,
    required String userId,
  }) : _repository = repository {
    _subscription = _repository
        .watchCustomerOrders(establishmentId: establishmentId, userId: userId)
        .listen(_receiveOrders, onError: _receiveError);
  }

  final OrderRepository _repository;
  late final StreamSubscription<List<Order>> _subscription;
  List<Order> orders = const [];
  bool loading = true;
  bool failed = false;

  /// Conta somente pedidos que ainda exigem pagamento, preparo ou retirada.
  int get activeOrderCount => orders.where((order) {
        return order.status == OrderStatus.awaitingPayment ||
            order.status == OrderStatus.preparing ||
            order.status == OrderStatus.awaitingPickup;
      }).length;

  /// Atualiza a lista observável sempre que o banco emitir uma alteração.
  void _receiveOrders(List<Order> value) {
    orders = value;
    loading = false;
    failed = false;
    notifyListeners();
  }

  /// Converte falhas técnicas em um estado simples que a View sabe apresentar.
  void _receiveError(Object _) {
    loading = false;
    failed = true;
    notifyListeners();
  }

  /// Cancela a consulta quando a tela deixa a árvore de widgets.
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
