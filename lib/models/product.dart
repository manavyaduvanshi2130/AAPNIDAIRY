class Product {
  final int? id;
  final String name;
  final String code;
  final double rate;

  const Product({
    this.id,
    required this.name,
    required this.code,
    required this.rate,
  });

  Map<String, dynamic> toMap() {
    return {if (id != null) 'id': id, 'name': name, 'code': code, 'rate': rate};
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      code: map['code'] as String,
      rate: (map['rate'] as num).toDouble(),
    );
  }
}
