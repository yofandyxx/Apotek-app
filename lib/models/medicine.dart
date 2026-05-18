class Medicine {
  int? id;
  String name;
  int categoryId;
  double price;
  int stockTotal;

  Medicine({
    this.id,
    required this.name,
    required this.categoryId,
    required this.price,
    required this.stockTotal,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category_id': categoryId,
      'price': price,
      'stock_total': stockTotal,
    };
  }

  factory Medicine.fromMap(Map<String, dynamic> map) {
    return Medicine(
      id: (map['id'] as num?)?.toInt(),
      name: map['name'] as String,
      categoryId: (map['category_id'] as num).toInt(),
      price: (map['price'] as num).toDouble(),
      stockTotal: (map['stock_total'] as num).toInt(),
    );
  }
}
