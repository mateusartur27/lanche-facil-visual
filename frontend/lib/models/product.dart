/// Representa um produto pertencente ao catálogo de um estabelecimento.
class Product {
  final String id;
  final String establishmentId;
  final String name;
  final String description;

  /// Preço atual em centavos para evitar erros de arredondamento.
  final int price;
  final String categoryId;
  final bool active;
  final bool available;

  /// Quantidade disponível; zero impede novas inclusões no carrinho.
  final int stockQuantity;
  final String? imageUrl;
  final DateTime createdAt;

  /// Cria um produto com seu estado administrativo e sua disponibilidade.
  const Product({
    required this.id,
    required this.establishmentId,
    required this.name,
    required this.description,
    required this.price,
    required this.categoryId,
    required this.active,
    required this.available,
    this.stockQuantity = 0,
    this.imageUrl,
    required this.createdAt,
  });

  /// Retorna uma cópia com alterações administrativas ou operacionais.
  Product copyWith({
    String? id,
    String? name,
    String? description,
    int? price,
    String? categoryId,
    bool? active,
    bool? available,
    int? stockQuantity,
    String? imageUrl,
  }) {
    return Product(
      id: id ?? this.id,
      establishmentId: establishmentId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      categoryId: categoryId ?? this.categoryId,
      active: active ?? this.active,
      available: available ?? this.available,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt,
    );
  }
}
