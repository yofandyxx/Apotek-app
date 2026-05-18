import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/medicine.dart';
import '../models/category.dart';
import '../models/batch.dart';
import 'medicine_form_screen.dart';
import '../widgets/rupiah_formatter.dart';

class MedicineScreen extends StatefulWidget {
  const MedicineScreen({super.key});

  @override
  State<MedicineScreen> createState() => _MedicineScreenState();
}

class _MedicineScreenState extends State<MedicineScreen> {
  List<Medicine> medicines = [];
  List<Category> categories = [];
  Map<int, List<Batch>> batchesMap = {};
  String searchQuery = '';
  int? selectedCategoryId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    medicines = await DatabaseHelper.instance.getMedicines();
    categories = await DatabaseHelper.instance.getCategories();

    for (var medicine in medicines) {
      final batches =
          await DatabaseHelper.instance.getBatchesByMedicine(medicine.id!);
      batchesMap[medicine.id!] = batches;
    }
    setState(() => isLoading = false);
  }

  List<Medicine> get filteredMedicines {
    return medicines.where((medicine) {
      if (searchQuery.isNotEmpty &&
          !medicine.name.toLowerCase().contains(searchQuery.toLowerCase())) {
        return false;
      }
      if (selectedCategoryId != null &&
          medicine.categoryId != selectedCategoryId) {
        return false;
      }
      return true;
    }).toList();
  }

  String getStockStatus(int stock) {
    if (stock == 0) return 'Habis';
    if (stock < 10) return 'Hampir Habis';
    return 'Tersedia';
  }

  Color getStockColor(int stock) {
    if (stock == 0) return Colors.red;
    if (stock < 10) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Obat'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MedicineFormScreen()),
              );
              if (result == true) _loadData();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
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
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Semua'),
                        selected: selectedCategoryId == null,
                        onSelected: (_) =>
                            setState(() => selectedCategoryId = null),
                      ),
                      const SizedBox(width: 8),
                      ...categories.map((category) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(category.name),
                              selected: selectedCategoryId == category.id,
                              onSelected: (_) => setState(
                                  () => selectedCategoryId = category.id),
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredMedicines.isEmpty
                    ? const Center(child: Text('Tidak ada data obat'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredMedicines.length,
                        itemBuilder: (context, index) {
                          final medicine = filteredMedicines[index];
                          final batches = batchesMap[medicine.id!] ?? [];
                          final totalStock =
                              batches.fold<int>(0, (sum, b) => sum + b.stock);
                          final category = categories.firstWhere(
                            (c) => c.id == medicine.categoryId,
                            orElse: () => Category(name: 'Unknown'),
                          );

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ExpansionTile(
                              leading: Container(
                                width: 8,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: getStockColor(totalStock),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              title: Text(
                                medicine.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${category.name} - ${RupiahFormatter.format(medicine.price)}',
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: getStockColor(
                                        totalStock,
                                      ).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      getStockStatus(totalStock),
                                      style: TextStyle(
                                        color: getStockColor(totalStock),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Text(
                                'Stok: $totalStock',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Batch List:',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 8),
                                      ...batches.map((batch) => ListTile(
                                            dense: true,
                                            leading: Icon(
                                              Icons.inventory,
                                              color: batch.getExpiredColor(),
                                            ),
                                            title: Text(
                                                'Batch: ${batch.batchNumber}'),
                                            subtitle:
                                                Text('Stok: ${batch.stock}'),
                                            trailing: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  batch.getExpiredStatus(),
                                                  style: TextStyle(
                                                    color:
                                                        batch.getExpiredColor(),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                Text(
                                                  'Exp: ${batch.expiredDate.day}/${batch.expiredDate.month}/${batch.expiredDate.year}',
                                                  style: const TextStyle(
                                                      fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          )),
                                      if (batches.isEmpty)
                                        const Padding(
                                          padding: EdgeInsets.all(8),
                                          child: Text('Belum ada batch'),
                                        ),
                                      const Divider(),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: () async {
                                              final result =
                                                  await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      MedicineFormScreen(
                                                    medicine: medicine,
                                                  ),
                                                ),
                                              );
                                              if (result == true) _loadData();
                                            },
                                            icon: const Icon(Icons.edit),
                                            label: const Text('Edit'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.blue,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            onPressed: () async {
                                              final confirm =
                                                  await showDialog<bool>(
                                                context: context,
                                                builder: (_) => AlertDialog(
                                                  title:
                                                      const Text('Hapus Obat'),
                                                  content: Text(
                                                      'Hapus ${medicine.name}?'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context, false),
                                                      child:
                                                          const Text('Batal'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context, true),
                                                      child:
                                                          const Text('Hapus'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (confirm == true) {
                                                await DatabaseHelper.instance
                                                    .deleteMedicine(
                                                        medicine.id!);
                                                _loadData();
                                              }
                                            },
                                            icon: const Icon(Icons.delete),
                                            label: const Text('Hapus'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                            ),
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
          ),
        ],
      ),
    );
  }
}
