class Transaction {
  int? id;
  DateTime date;
  double total;
  double payment;
  double change;

  Transaction({
    this.id,
    required this.date,
    required this.total,
    required this.payment,
    required this.change,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'total': total,
      'payment': payment,
      'change': change,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: (map['id'] as num?)?.toInt(),
      date: DateTime.parse(map['date']),
      total: (map['total'] as num).toDouble(),
      payment: (map['payment'] as num).toDouble(),
      change: (map['change'] as num).toDouble(),
    );
  }
}
