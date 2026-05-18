import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/batch.dart';
import '../models/medicine.dart';

class ExpiredScreen extends StatefulWidget {
  const ExpiredScreen({super.key});

  @override
  State<ExpiredScreen> createState() => _ExpiredScreenState();
}

class _ExpiredScreenState extends State<ExpiredScreen> {
  List<Batch> expiredBatches = [];
  List<Batch> nearExpiredBatches = [];
  List<Map<String, dynamic>> lowStockMedicines = [];
  Map<int, Medicine> medicinesMap = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    expiredBatches = await DatabaseHelper.instance.getExpiredBatches();
    nearExpiredBatches = await DatabaseHelper.instance.getNearExpiredBatches();
    lowStockMedicines = await DatabaseHelper.instance.getLowStockMedicines();

    for (var batch in [...expiredBatches, ...nearExpiredBatches]) {
      if (!medicinesMap.containsKey(batch.medicineId)) {
        final medicine =
            await DatabaseHelper.instance.getMedicine(batch.medicineId);
        if (medicine != null) {
          medicinesMap[batch.medicineId] = medicine;
        }
      }
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Peringatan Obat'),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Low Stock Section
                  _buildWarningSection(
                    title: '⚠️ Stok Rendah (< 10)',
                    icon: Icons.warning_amber,
                    color: Colors.orange,
                    children: lowStockMedicines.isEmpty
                        ? [const Text('Tidak ada obat dengan stok rendah')]
                        : lowStockMedicines.map((item) {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.inventory,
                                    color: Colors.orange),
                                title: Text(item['name']),
                                subtitle:
                                    Text('Kategori: ${item['category_name']}'),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Stok: ${item['stock_total']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Near Expired Section
                  _buildWarningSection(
                    title: '⚠️ Hampir Kadaluarsa (< 30 hari)',
                    icon: Icons.timer,
                    color: Colors.orange,
                    children: nearExpiredBatches.isEmpty
                        ? [const Text('Tidak ada obat yang hampir kadaluarsa')]
                        : nearExpiredBatches.map((batch) {
                            final medicine = medicinesMap[batch.medicineId];
                            final daysLeft = batch.expiredDate
                                .difference(DateTime.now())
                                .inDays;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.medication,
                                    color: Colors.orange),
                                title: Text(medicine?.name ?? 'Unknown'),
                                subtitle: Text('Batch: ${batch.batchNumber}'),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '$daysLeft hari lagi',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Exp: ${batch.expiredDate.day}/${batch.expiredDate.month}/${batch.expiredDate.year}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Expired Section
                  _buildWarningSection(
                    title: '❌ Kadaluarsa',
                    icon: Icons.cancel,
                    color: Colors.red,
                    children: expiredBatches.isEmpty
                        ? [const Text('Tidak ada obat kadaluarsa')]
                        : expiredBatches.map((batch) {
                            final medicine = medicinesMap[batch.medicineId];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.warning,
                                    color: Colors.red),
                                title: Text(medicine?.name ?? 'Unknown'),
                                subtitle: Text('Batch: ${batch.batchNumber}'),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.red.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'EXPIRED',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Exp: ${batch.expiredDate.day}/${batch.expiredDate.month}/${batch.expiredDate.year}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildWarningSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}
