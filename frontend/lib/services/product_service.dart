import '../models/product.dart';

/// Identifica a loja fictícia compartilhada pelo catálogo e pedidos.
abstract final class CatalogConfiguration {
  static const demonstrationEstablishmentId = 'campus-principal';
}

/// Fornece o catálogo embarcado, sem consultas externas.
abstract interface class ProductService {
  Stream<List<Product>> watchProducts(String establishmentId);
}

/// Mantém produtos disponíveis para navegar e montar o carrinho local.
class MemoryProductService implements ProductService {
  @override
  Stream<List<Product>> watchProducts(String establishmentId) =>
      Stream.value(sampleProducts(establishmentId));
}

/// Fornece dados coerentes para a primeira demonstração do catálogo e do cálculo.
List<Product> sampleProducts(String establishmentId) {
  final now = DateTime(2026, 8, 16);
  return [
    Product(
        id: 'salgado',
        establishmentId: establishmentId,
        name: 'Salgado assado',
        description:
            'Opções de frango, presunto e queijo conforme disponibilidade.',
        price: 900,
        categoryId: 'Salgados',
        active: true,
        available: true,
        stockQuantity: 30,
        createdAt: now),
    Product(
        id: 'refrigerante',
        establishmentId: establishmentId,
        name: 'Refrigerante lata',
        description: 'Lata de 350 ml servida gelada.',
        price: 600,
        categoryId: 'Bebidas',
        active: true,
        available: true,
        stockQuantity: 24,
        createdAt: now),
    Product(
        id: 'trident',
        establishmentId: establishmentId,
        name: 'Trident',
        description: 'Goma de mascar em sabores variados.',
        price: 350,
        categoryId: 'Conveniência',
        active: true,
        available: true,
        stockQuantity: 40,
        createdAt: now),
    Product(
        id: 'x-salada',
        establishmentId: establishmentId,
        name: 'X-Salada especial',
        description: 'Hambúrguer, queijo, salada fresca e molho da casa.',
        price: 1800,
        categoryId: 'Lanches',
        active: true,
        available: true,
        stockQuantity: 15,
        createdAt: now),
    Product(
        id: 'cachorro-quente',
        establishmentId: establishmentId,
        name: 'Cachorro-quente',
        description:
            'Pão, salsicha, molho, milho, batata palha e complementos.',
        price: 1400,
        categoryId: 'Lanches',
        active: true,
        available: true,
        stockQuantity: 18,
        createdAt: now),
  ];
}
