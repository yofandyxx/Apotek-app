import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/medicine.dart';
import '../models/batch.dart';
import '../models/transaction.dart';
import '../models/transaction_detail.dart';
import '../widgets/rupiah_formatter.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  List<Medicine> medicines = [];
  Map<int, List<Batch>> batchesMap = {};
  Map<int, int> cart = {}; // medicineId -> qty
  Map<int, Batch> selectedBatches = {};
  String searchQuery = '';
  double discount = 0;
  double payment = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    medicines = await DatabaseHelper.instance.getMedicines();
    for (var medicine in medicines) {
      final batches =
          await DatabaseHelper.instance.getAvailableBatches(medicine.id!);
      batchesMap[medicine.id!] = batches;

      // Auto select batch with nearest expiry (FIFO)
      if (batches.isNotEmpty && selectedBatches[medicine.id!] == null) {
        batches.sort((a, b) => a.expiredDate.compareTo(b.expiredDate));
        selectedBatches[medicine.id!] = batches.first;
      }
    }
    setState(() => isLoading = false);
  }

  List<Medicine> get filteredMedicines {
    if (searchQuery.isEmpty) return medicines;
    return medicines
        .where((m) => m.name.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();
  }

  double get subtotal {
    double total = 0;
    cart.forEach((medicineId, qty) {
      final medicine = medicines.firstWhere((m) => m.id == medicineId);
      total += medicine.price * qty;
    });
    return total;
  }

  double get total => subtotal - discount;
  double get change => payment - total;

  void _addToCart(Medicine medicine) {
    final batches = batchesMap[medicine.id!] ?? [];
    if (batches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stok habis!')),
      );
      return;
    }

    setState(() {
      cart[medicine.id!] = (cart[medicine.id!] ?? 0) + 1;

      // Update batch stock for display
      final selectedBatch = selectedBatches[medicine.id!]!;
      final batchIndex =
          batchesMap[medicine.id!]!.indexWhere((b) => b.id == selectedBatch.id);
      if (batchIndex != -1) {
        final newStock = batchesMap[medicine.id!]![batchIndex].stock - 1;
        batchesMap[medicine.id!]![batchIndex].stock = newStock;

        if (newStock == 0) {
          // Find next batch if available
          final remainingBatches =
              batchesMap[medicine.id!]!.where((b) => b.stock > 0).toList();
          if (remainingBatches.isNotEmpty) {
            remainingBatches
                .sort((a, b) => a.expiredDate.compareTo(b.expiredDate));
            selectedBatches[medicine.id!] = remainingBatches.first;
          }
        }
      }
    });
  }

  void _removeFromCart(int medicineId) {
    setState(() {
      final qty = cart[medicineId]!;
      if (qty == 1) {
        cart.remove(medicineId);
      } else {
        cart[medicineId] = qty - 1;
      }
    });
  }

  Future<void> _checkout() async {
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keranjang kosong!')),
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pembayaran'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Total: ${RupiahFormatter.format(total)}'),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Jumlah Bayar',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  payment = double.tryParse(value) ?? 0;
                });
              },
            ),
            if (payment >= total)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Kembalian: ${RupiahFormatter.format(change)}',
                  style: const TextStyle(color: Colors.green),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (payment >= total) {
                Navigator.pop(context, {'payment': payment, 'change': change});
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pembayaran kurang!')),
                );
              }
            },
            child: const Text('Bayar'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _saveTransaction(result['payment'], result['change']);
    }
  }

  Future<void> _saveTransaction(double payment, double change) async {
    final transaction = Transaction(
      date: DateTime.now(),
      total: total,
      payment: payment,
      change: change,
    );

    final transactionId =
        await DatabaseHelper.instance.insertTransaction(transaction);

    for (var entry in cart.entries) {
      final medicineId = entry.key;
      final qty = entry.value;
      final medicine = medicines.firstWhere((m) => m.id == medicineId);

      // Get actual batch used (FIFO)
      var remainingQty = qty;
      final batches = (await DatabaseHelper.instance
          .getAvailableBatches(medicineId))
        ..sort((a, b) => a.expiredDate.compareTo(b.expiredDate));

      for (var batch in batches) {
        if (remainingQty <= 0) break;

        final int usedQty =
            remainingQty <= batch.stock ? remainingQty : batch.stock;
        final newStock = batch.stock - usedQty;

        await DatabaseHelper.instance.updateBatchStock(batch.id!, newStock);

        final detail = TransactionDetail(
          transactionId: transactionId,
          medicineId: medicineId,
          batchId: batch.id!,
          qty: usedQty,
          price: medicine.price,
          subtotal: medicine.price * usedQty,
        );
        await DatabaseHelper.instance.insertTransactionDetail(detail);

        remainingQty -= usedQty;
      }

      await DatabaseHelper.instance.updateMedicineStock(medicineId);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaksi berhasil!')),
    );

    setState(() {
      cart.clear();
      payment = 0;
      discount = 0;
    });

    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir'),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari obat...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) => setState(() => searchQuery = value),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredMedicines.length,
                    itemBuilder: (context, index) {
                      final medicine = filteredMedicines[index];
                      final batches = batchesMap[medicine.id!] ?? [];
                      final availableStock =
                          batches.fold(0, (sum, b) => sum + b.stock);
                      final selectedBatch = selectedBatches[medicine.id!];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(medicine.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(RupiahFormatter.format(medicine.price)),
                              if (selectedBatch != null)
                                Text(
                                  'Batch: ${selectedBatch.batchNumber} (Stok: $availableStock)',
                                  style: const TextStyle(fontSize: 12),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (cart.containsKey(medicine.id))
                                IconButton(
                                  icon: const Icon(Icons.remove,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _removeFromCart(medicine.id!),
                                ),
                              if (cart.containsKey(medicine.id))
                                Text(
                                  '${cart[medicine.id]}',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                              IconButton(
                                icon:
                                    const Icon(Icons.add, color: Colors.green),
                                onPressed: availableStock > 0
                                    ? () => _addToCart(medicine)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Subtotal:',
                                  style: TextStyle(fontSize: 16),
                                ),
                                Text(
                                  RupiahFormatter.format(subtotal),
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Diskon:',
                                  style: TextStyle(fontSize: 16),
                                ),
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 100,
                                      child: TextField(
                                        decoration: const InputDecoration(
                                          hintText: '0',
                                          border: OutlineInputBorder(),
                                          suffixText: '%',
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (value) {
                                          setState(() {
                                            discount = subtotal *
                                                (double.tryParse(value) ?? 0) /
                                                100;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total:',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  RupiahFormatter.format(total),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: cart.isNotEmpty ? _checkout : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Bayar',
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
