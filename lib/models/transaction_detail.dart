class TransactionDetail {
  int? id;
  int transactionId;
  int medicineId;
  int batchId;
  int qty;
  double price;
  double subtotal;

  TransactionDetail({
    this.id,
    required this.transactionId,
    required this.medicineId,
    required this.batchId,
    required this.qty,
    required this.price,
    required this.subtotal,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'medicine_id': medicineId,
      'batch_id': batchId,
      'qty': qty,
      'price': price,
      'subtotal': subtotal,
    };
  }

  factory TransactionDetail.fromMap(Map<String, dynamic> map) {
    return TransactionDetail(
      id: (map['id'] as num?)?.toInt(),
      transactionId: (map['transaction_id'] as num).toInt(),
      medicineId: (map['medicine_id'] as num).toInt(),
      batchId: (map['batch_id'] as num).toInt(),
      qty: (map['qty'] as num).toInt(),
      price: (map['price'] as num).toDouble(),
      subtotal: (map['subtotal'] as num).toDouble(),
    );
  }
}
