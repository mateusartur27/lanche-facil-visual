import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../repositories/order_repository.dart';

/// Controla carrinho, observação geral e criação do pedido fora da interface visual.
class CheckoutViewModel extends ChangeNotifier {
  CheckoutViewModel({required OrderRepository repository})
      : _repository = repository;

  final OrderRepository _repository;
  final Map<String, int> _quantities = {};
  final Map<String, int> _prices = {};
  bool isCreatingOrder = false;
  String? _pendingRequestId;

  Map<String, int> get quantities => Map.unmodifiable(_quantities);
  int get itemCount => _quantities.values.fold(0, (sum, value) => sum + value);
  int get totalInCents => _quantities.entries.fold(
        0,
        (sum, entry) => sum + (_prices[entry.key] ?? 0) * entry.value,
      );

  /// Inclui uma unidade respeitando o estoque apresentado pelo catálogo.
  bool addItem(
      {required String productId, required int price, required int stock}) {
    final current = _quantities[productId] ?? 0;
    if (current >= stock) return false;
    _quantities[productId] = current + 1;
    _prices[productId] = price;
    notifyListeners();
    return true;
  }

  /// Remove completamente um produto e seu preço auxiliar do carrinho.
  void removeItem(String productId) {
    _quantities.remove(productId);
    _prices.remove(productId);
    notifyListeners();
  }

  /// Solicita ao Repository a criação segura e limpa o carrinho somente após sucesso.
  Future<CreateOrderResult> createOrder({
    required String establishmentId,
    required String orderNotes,
  }) async {
    if (isCreatingOrder) throw StateError('O pedido já está sendo criado.');
    isCreatingOrder = true;
    // Conserva o mesmo UUID em novas tentativas após falha de rede para o servidor devolver o pedido original.
    _pendingRequestId ??= const Uuid().v4();
    notifyListeners();
    try {
      final result = await _repository.createOrder(
        establishmentId: establishmentId,
        requestId: _pendingRequestId!,
        notes: orderNotes.trim(),
        items: _quantities.entries
            .where((entry) => entry.value > 0)
            .map((entry) => {
                  'productId': entry.key,
                  'quantity': entry.value,
                  // Mantém o contrato da API sem exibir observações individuais no checkout.
                  'notes': '',
                })
            .toList(),
      );
      _quantities.clear();
      _prices.clear();
      _pendingRequestId = null;
      return result;
    } finally {
      isCreatingOrder = false;
      notifyListeners();
    }
  }
}
