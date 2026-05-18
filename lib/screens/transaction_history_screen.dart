import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/transaction.dart';
import '../models/transaction_detail.dart';
import '../models/medicine.dart';
import '../widgets/rupiah_formatter.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  List<Transaction> transactions = [];
  Map<int, List<TransactionDetail>> detailsMap = {};
  Map<int, Medicine> medicinesMap = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    transactions = await DatabaseHelper.instance.getTransactions();
    
    for (var transaction in transactions) {
      final details = await DatabaseHelper.instance.getTransactionDetails(transaction.id!);
      detailsMap[transaction.id!] = details;
      
      for (var detail in details) {
        if (!medicinesMap.containsKey(detail.medicineId)) {
          final medicine = await DatabaseHelper.instance.getMedicine(detail.medicineId);
          if (medicine != null) {
            medicinesMap[detail.medicineId] = medicine;
          }
        }
      }
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : transactions.isEmpty
              ? const Center(child: Text('Belum ada transaksi'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    final details = detailsMap[transaction.id!] ?? [];
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ExpansionTile(
                        leading: const Icon(Icons.receipt, color: Colors.green),
                        title: Text(
                          '${transaction.date.day}/${transaction.date.month}/${transaction.date.year} ${transaction.date.hour.toString().padLeft(2, '0')}:${transaction.date.minute.toString().padLeft(2, '0')}',
                        ),
                        subtitle: Text(RupiahFormatter.format(transaction.total)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Kembalian:'),
                            Text(
                              RupiahFormatter.format(transaction.change),
                              style: const TextStyle(color: Colors.green),
                            ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Detail Item:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const Divider(),
                                ...details.map((detail) {
                                  final medicine = medicinesMap[detail.medicineId];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${medicine?.name ?? 'Unknown'} x${detail.qty}',
                                          ),
                                        ),
                                        Text(RupiahFormatter.format(detail.subtotal)),
                                      ],
                                    ),
                                  );
                                }),
                                const Divider(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Total Bayar:'),
                                    Text(
                                      RupiahFormatter.format(transaction.total),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Tunai:'),
                                    Text(RupiahFormatter.format(transaction.payment)),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Kembalian:'),
                                    Text(
                                      RupiahFormatter.format(transaction.change),
                                      style: const TextStyle(color: Colors.green),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}