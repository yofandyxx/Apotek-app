import 'package:flutter/material.dart';

class Batch {
  int? id;
  int medicineId;
  String batchNumber;
  int stock;
  DateTime expiredDate;
  DateTime createdAt;

  Batch({
    this.id,
    required this.medicineId,
    required this.batchNumber,
    required this.stock,
    required this.expiredDate,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicine_id': medicineId,
      'batch_number': batchNumber,
      'stock': stock,
      'expired_date': expiredDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Batch.fromMap(Map<String, dynamic> map) {
    return Batch(
      id: (map['id'] as num?)?.toInt(),
      medicineId: (map['medicine_id'] as num).toInt(),
      batchNumber: map['batch_number'] as String,
      stock: (map['stock'] as num).toInt(),
      expiredDate: DateTime.parse(map['expired_date']),
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  String getExpiredStatus() {
    final now = DateTime.now();
    final daysLeft = expiredDate.difference(now).inDays;

    if (daysLeft < 0) return 'Expired';
    if (daysLeft <= 30) return 'Hampir Expired';
    return 'Aman';
  }

  Color getExpiredColor() {
    final status = getExpiredStatus();
    switch (status) {
      case 'Expired':
        return Colors.red;
      case 'Hampir Expired':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }
}
