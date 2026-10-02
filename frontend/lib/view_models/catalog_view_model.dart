import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../services/product_service.dart';

/// Controla produtos, carregamento e filtro do catálogo fora da View.
class CatalogViewModel extends ChangeNotifier {
  CatalogViewModel({required ProductService productService})
      : _productService = productService;

  final ProductService _productService;
  StreamSubscription<List<Product>>? _subscription;
  List<Product> products = const [];
  String selectedCategory = 'Todos';
  bool loading = true;
  bool failed = false;

  /// Inicia a observação do estabelecimento selecionado.
  void start(String establishmentId) {
    _subscription = _productService.watchProducts(establishmentId).listen(
      (value) {
        products = value.where((product) => product.active).toList();
        loading = false;
        failed = false;
        notifyListeners();
      },
      onError: (_) {
        loading = false;
        failed = true;
        notifyListeners();
      },
    );
  }

  /// Atualiza o filtro sem misturar estado com os controles visuais.
  void selectCategory(String category) {
    selectedCategory = category;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
