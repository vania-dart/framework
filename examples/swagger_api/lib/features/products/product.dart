class Product {
  final int id;
  final String name;
  final int priceCents;

  const Product({
    required this.id,
    required this.name,
    required this.priceCents,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price_cents': priceCents,
      };
}
